<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\UserContact;
use App\Support\PhoneNumber;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class UserContactController extends Controller
{
    /** Contacts accepted per request; the app uploads a big phone book in chunks. */
    public const MAX_PER_REQUEST = 500;

    /**
     * Upserts a chunk of the device's phone book. Public so guests can share
     * contacts before signing in (keyed by the same install_id as the
     * heartbeat); with a bearer token every row of this install, including
     * ones uploaded as a guest, is linked to the user. An empty `contacts`
     * list only does that linking, which the app sends right after login.
     */
    public function sync(Request $request): JsonResponse
    {
        $data = $request->validate([
            'install_id' => ['required', 'string', 'min:16', 'max:64'],
            'contacts' => ['present', 'array', 'max:'.self::MAX_PER_REQUEST],
            'contacts.*.name' => ['nullable', 'string', 'max:255'],
            'contacts.*.phone' => ['required', 'string', 'max:40'],
        ]);

        $user = auth('sanctum')->user();
        $userId = $user instanceof User ? $user->getKey() : null;
        $installId = $data['install_id'];

        if ($userId !== null) {
            UserContact::query()
                ->where('install_id', $installId)
                ->where(fn ($q) => $q->whereNull('user_id')->orWhere('user_id', '!=', $userId))
                ->update(['user_id' => $userId]);
        }

        $now = now();
        $rows = collect($data['contacts'])
            ->map(fn (array $contact) => [
                'name' => trim($contact['name'] ?? '') ?: null,
                'phone' => PhoneNumber::normalize($contact['phone']),
            ])
            // Short codes and garbage are useless for matching accounts.
            ->filter(fn (array $contact) => $contact['phone'] !== null
                && strlen($contact['phone']) >= 8
                && strlen($contact['phone']) <= 15)
            ->unique('phone')
            ->map(fn (array $contact) => [
                'id' => (string) Str::ulid(),
                'install_id' => $installId,
                'user_id' => $userId,
                'name' => $contact['name'],
                'phone' => $contact['phone'],
                'created_at' => $now,
                'updated_at' => $now,
            ])
            ->values()
            ->all();

        if ($rows !== []) {
            // A guest sync (e.g. after logging out) must not unlink rows the
            // owner uploaded while signed in.
            $update = $userId !== null ? ['user_id', 'name', 'updated_at'] : ['name', 'updated_at'];
            UserContact::query()->upsert($rows, ['install_id', 'phone'], $update);
        }

        return ApiResponse::success(['synced' => count($rows)], 'Contacts synced successfully.');
    }
}
