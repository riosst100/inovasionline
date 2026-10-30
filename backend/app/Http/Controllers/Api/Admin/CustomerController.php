<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\AppInstall;
use App\Models\UserContact;
use App\Models\User;
use App\Services\CodVerificationService;
use App\Support\Enums\UserRole;
use App\Support\Responses\ApiResponse;
use App\Support\UserAgent;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\PersonalAccessToken;
use RuntimeException;

class CustomerController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $paginator = User::query()
            ->withLastSeen()
            ->where('role', '!=', UserRole::PLATFORM_ADMIN->value)
            ->when($request->string('search')->toString(), function ($query, $search) {
                $query->where(function ($q) use ($search) {
                    $q->where('name', 'like', "%{$search}%")
                        ->orWhere('email', 'like', "%{$search}%")
                        ->orWhere('phone', 'like', "%{$search}%");
                });
            })
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return ApiResponse::paginated($paginator, UserResource::class, 'Daftar customer berhasil dimuat.');
    }

    /**
     * App installs that never logged in / registered (no linked user).
     * Search matches device, platform, IP and install id.
     */
    public function guests(Request $request): JsonResponse
    {
        $paginator = AppInstall::query()
            ->whereNull('user_id')
            ->when($request->string('search')->toString(), function ($query, $search) {
                $query->where(function ($q) use ($search) {
                    $q->where('install_id', 'like', "%{$search}%")
                        ->orWhere('device_name', 'like', "%{$search}%")
                        ->orWhere('device_brand', 'like', "%{$search}%")
                        ->orWhere('device_model', 'like', "%{$search}%")
                        ->orWhere('ip_address', 'like', "%{$search}%");
                });
            })
            ->orderByDesc('last_seen_at')
            ->paginate($request->integer('per_page', 15));

        return ApiResponse::success(
            $paginator->getCollection()->map(fn (AppInstall $i) => $this->guestPayload($i))->values(),
            'Daftar guest berhasil dimuat.',
            [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ]
        );
    }

    /** Everything known about one guest install, including the raw device report. */
    public function guestShow(AppInstall $install): JsonResponse
    {
        return ApiResponse::success($this->installDetail($install), 'Detail guest berhasil dimuat.');
    }

    /** Full device / network / location report of one app install. */
    private function installDetail(AppInstall $install): array
    {
        $contacts = UserContact::query()->where('install_id', $install->install_id);

        return [
            ...$this->guestPayload($install),
            'device_id' => $install->device_id,
            'first_ip_address' => $install->first_ip_address,
            'build_number' => $install->build_number,
            'user_agent' => $install->user_agent,
            'device_details' => $install->device_details,
            'latitude' => $install->latitude,
            'longitude' => $install->longitude,
            'location_accuracy' => $install->location_accuracy,
            'location_at' => $install->location_at?->toIso8601String(),
            'user' => $install->user ? ['id' => $install->user->id, 'name' => $install->user->name] : null,
            'contacts_count' => (clone $contacts)->count(),
            'contacts' => (clone $contacts)->orderBy('name')->limit(200)->get(['name', 'phone']),
            // Other installs sharing this physical device (reinstall / many installs).
            'same_device_installs' => $install->device_id
                ? AppInstall::query()
                    ->where('device_id', $install->device_id)
                    ->whereKeyNot($install->getKey())
                    ->orderByDesc('last_seen_at')
                    ->get(['id', 'install_id', 'user_id', 'last_seen_at'])
                : [],
            'created_at' => $install->created_at?->toIso8601String(),
            'updated_at' => $install->updated_at?->toIso8601String(),
        ];
    }

    private function guestPayload(AppInstall $i): array
    {
        return [
            'id' => $i->id,
            'install_id' => $i->install_id,
            'device_name' => $i->device_name,
            'device_brand' => $i->device_brand,
            'device_model' => $i->device_model,
            'os_version' => $i->os_version,
            'is_emulator' => (bool) $i->is_emulator,
            'platform' => $i->platform,
            'app_version' => $i->app_version,
            'ip_address' => $i->ip_address,
            'current_screen' => $i->current_screen,
            'first_seen_at' => $i->first_seen_at?->toIso8601String(),
            'last_seen_at' => $i->last_seen_at?->toIso8601String(),
        ];
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|max:255|unique:users,email',
            'phone' => 'nullable|string|max:30|unique:users,phone',
            'password' => 'required|string|min:8',
        ]);

        $user = new User([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'phone' => $validated['phone'] ?? null,
            'password' => $validated['password'],
        ]);
        $user->forceFill([
            'role' => UserRole::CUSTOMER,
            'email_verified_at' => now(),
        ])->save();

        return ApiResponse::success(new UserResource($user), 'Customer berhasil ditambahkan.', [], 201);
    }

    public function show(Request $request, User $user): JsonResponse
    {
        $tokens = $user->tokens()
            ->where(fn ($q) => $q->whereNull('expires_at')->orWhere('expires_at', '>', now()))
            ->orderByDesc('last_used_at')
            ->orderByDesc('created_at')
            ->get();

        $webSessions = config('session.driver') === 'database'
            ? DB::table(config('session.table', 'sessions'))
                ->where('user_id', $user->id)
                ->orderByDesc('last_activity')
                ->get(['id', 'ip_address', 'user_agent', 'last_activity'])
            : collect();

        $sessions = $tokens->map(fn (PersonalAccessToken $t) => [
            'id' => (string) $t->id,
            'type' => 'token',
            'device' => $t->name,
            'ip_address' => $t->ip_address,
            'user_agent' => $t->user_agent,
            'last_active_at' => ($t->last_used_at ?? $t->created_at)?->toIso8601String(),
            'created_at' => $t->created_at?->toIso8601String(),
            'expires_at' => $t->expires_at?->toIso8601String(),
        ])->concat($webSessions->map(fn ($s) => [
            'id' => $s->id,
            'type' => 'web',
            'device' => UserAgent::label($s->user_agent),
            'ip_address' => $s->ip_address,
            'user_agent' => $s->user_agent,
            'last_active_at' => Carbon::createFromTimestamp($s->last_activity)->toIso8601String(),
            'created_at' => null,
            'expires_at' => null,
        ]))->sortByDesc('last_active_at')->values();

        $history = $user->loginLogs()->latest('id')->limit(50)->get();
        $lastLogin = $history->first();

        // Every IP seen for this customer, from login history plus currently active sessions.
        $ipAddresses = $user->loginLogs()
            ->whereNotNull('ip_address')
            ->selectRaw('ip_address, count(*) as login_count, min(created_at) as first_seen_at, max(created_at) as last_seen_at')
            ->groupBy('ip_address')
            ->get()
            ->keyBy('ip_address')
            ->map(fn ($row) => [
                'ip_address' => $row->ip_address,
                'login_count' => (int) $row->login_count,
                'first_seen_at' => Carbon::parse($row->first_seen_at)->toIso8601String(),
                'last_seen_at' => Carbon::parse($row->last_seen_at)->toIso8601String(),
                'active_sessions' => 0,
            ]);

        foreach ($sessions as $s) {
            if (! $s['ip_address']) {
                continue;
            }
            $row = $ipAddresses->get($s['ip_address'], [
                'ip_address' => $s['ip_address'],
                'login_count' => 0,
                'first_seen_at' => $s['created_at'] ?? $s['last_active_at'],
                'last_seen_at' => $s['last_active_at'],
                'active_sessions' => 0,
            ]);
            $row['active_sessions']++;
            if ($s['last_active_at'] > $row['last_seen_at']) {
                $row['last_seen_at'] = $s['last_active_at'];
            }
            $ipAddresses->put($s['ip_address'], $row);
        }

        return ApiResponse::success([
            'customer' => (new UserResource(User::query()->withLastSeen()->findOrFail($user->id)))->toArray($request) + [
                'wallet_balance' => $user->wallet_balance,
                'phone_verified_at' => $user->phone_verified_at,
            ],
            'login' => [
                'has_password' => $user->password !== null,
                'google_linked' => $user->google_id !== null,
                'email_verified_at' => $user->email_verified_at,
                'phone_verified_at' => $user->phone_verified_at,
                'last_login_at' => $lastLogin?->created_at?->toIso8601String(),
                'last_login_ip' => $lastLogin?->ip_address,
                'last_login_method' => $lastLogin?->method,
                'login_count' => $user->loginLogs()->count(),
                'active_session_count' => $sessions->count(),
            ],
            'sessions' => $sessions,
            'push_devices' => $user->deviceTokens()->latest('updated_at')->get()->map(fn ($d) => [
                'id' => $d->id,
                'platform' => $d->platform,
                'token_preview' => mb_substr($d->token, 0, 12).'…'.mb_substr($d->token, -6),
                'registered_at' => $d->created_at?->toIso8601String(),
                'updated_at' => $d->updated_at?->toIso8601String(),
            ]),
            'app_installs' => AppInstall::query()
                ->where('user_id', $user->id)
                ->orderByDesc('last_seen_at')
                ->get()
                ->map(fn (AppInstall $i) => $this->installDetail($i))
                ->values(),
            'ip_addresses' => $ipAddresses->sortByDesc('last_seen_at')->values(),
            'login_history' => $history->map(fn ($log) => [
                'id' => $log->id,
                'method' => $log->method,
                'client' => $log->client,
                'device' => $log->device_name,
                'ip_address' => $log->ip_address,
                'user_agent' => $log->user_agent,
                'created_at' => $log->created_at?->toIso8601String(),
            ]),
        ], 'Detail customer berhasil dimuat.');
    }

    public function revokeSession(User $user, string $session): JsonResponse
    {
        $deleted = ctype_digit($session)
            ? $user->tokens()->whereKey((int) $session)->delete()
            : (config('session.driver') === 'database'
                ? DB::table(config('session.table', 'sessions'))->where('user_id', $user->id)->where('id', $session)->delete()
                : 0);

        if (! $deleted) {
            return ApiResponse::error('Sesi tidak ditemukan.', [], 404);
        }

        return ApiResponse::success(null, 'Sesi customer berhasil dihentikan.');
    }

    public function block(Request $request, User $user): JsonResponse
    {
        $validated = $request->validate([
            'reason' => 'nullable|string|max:500',
        ]);

        if ($user->isPlatformAdmin()) {
            return ApiResponse::error('Akun admin tidak dapat diblokir.', [], 422);
        }

        $user->forceFill([
            'blocked_at' => now(),
            'block_reason' => $validated['reason'] ?? null,
        ])->save();

        return ApiResponse::success(new UserResource($user), 'Customer berhasil diblokir.');
    }

    public function ban(Request $request, User $user): JsonResponse
    {
        $validated = $request->validate([
            'features' => 'required|array|min:1',
            'features.*' => ['string', \Illuminate\Validation\Rule::in(User::BANNABLE_FEATURES)],
            'reason' => 'nullable|string|max:500',
        ]);

        if ($user->isPlatformAdmin()) {
            return ApiResponse::error('Akun admin tidak dapat dibatasi.', [], 422);
        }

        $user->forceFill([
            'banned_features' => array_values(array_unique($validated['features'])),
            'ban_reason' => $validated['reason'] ?? null,
        ])->save();

        return ApiResponse::success(new UserResource($user), 'Pembatasan fitur customer berhasil disimpan.');
    }

    public function unban(User $user): JsonResponse
    {
        $user->forceFill(['banned_features' => null, 'ban_reason' => null])->save();

        return ApiResponse::success(new UserResource($user), 'Pembatasan fitur customer berhasil dicabut.');
    }

    public function unblock(User $user): JsonResponse
    {
        $user->forceFill(['blocked_at' => null, 'block_reason' => null])->save();

        return ApiResponse::success(new UserResource($user), 'Blokir customer berhasil dibuka.');
    }

    /** Revokes the event that currently verifies the customer; the user then points at that event. */
    public function revokeVerification(Request $request, User $user, CodVerificationService $service): JsonResponse
    {
        $validated = $request->validate(['reason' => 'required|string|max:500']);

        try {
            $service->revokeUser($user, $validated['reason']);
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 422);
        }

        return ApiResponse::success(new UserResource($user->fresh()), 'Verifikasi customer berhasil dicabut.');
    }
}
