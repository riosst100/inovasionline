<?php

namespace App\Support\DataTransfer\Handlers;

use App\Models\AdminUser;
use App\Models\Role;
use App\Support\DataTransfer\ImportResult;
use App\Support\DataTransfer\RowSkippedException;
use App\Support\DataTransfer\TransferHandler;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/**
 * Rows are matched on `email` (case-insensitive); unmatched rows create a courier, which needs `password`.
 * Passwords are never exported; on an existing courier an empty `password` keeps the current one.
 * An email that belongs to a non-courier admin account (or a deleted one) is skipped.
 */
class DriverTransferHandler implements TransferHandler
{
    public function label(): string
    {
        return 'Kurir';
    }

    public function headers(): array
    {
        return ['name', 'email', 'phone', 'vehicle_type', 'vehicle_plate_number', 'is_active', 'password'];
    }

    public function sampleRow(): array
    {
        return [
            // Deliberately not a real courier and without a password, so importing the untouched template is skipped.
            'name' => 'Contoh Kurir',
            'email' => 'contoh.kurir@example.com',
            'phone' => '081200000000',
            'vehicle_type' => 'Motor',
            'vehicle_plate_number' => 'B 1234 XYZ',
            'is_active' => '1',
            'password' => '',
        ];
    }

    public function exportQuery(array $filters): Builder
    {
        return AdminUser::query()
            ->whereHas('role', fn ($q) => $q->where('slug', 'driver'))
            ->orderBy('name');
    }

    public function exportRow(Model $model): array
    {
        /** @var AdminUser $model */
        return [
            'name' => $model->name,
            'email' => $model->email,
            'phone' => $model->phone,
            'vehicle_type' => $model->vehicle_type,
            'vehicle_plate_number' => $model->vehicle_plate_number,
            'is_active' => $model->is_active ? 1 : 0,
            'password' => null,
        ];
    }

    public function prepareImport(array $rows): array
    {
        return $rows;
    }

    public function importRow(array $row): string
    {
        $name = trim((string) ($row['name'] ?? ''));
        $email = mb_strtolower(trim((string) ($row['email'] ?? '')));
        if ($name === '') {
            throw new RowSkippedException('Kolom name wajib diisi.');
        }
        if (mb_strlen($name) > 150) {
            throw new RowSkippedException('Kolom name maksimal 150 karakter.');
        }
        if ($email === '' || ! filter_var($email, FILTER_VALIDATE_EMAIL) || mb_strlen($email) > 150) {
            throw new RowSkippedException('Kolom email wajib diisi dengan email yang valid.');
        }

        $existing = AdminUser::withTrashed()->with('role')->whereRaw('lower(email) = ?', [$email])->first();
        if ($existing && $existing->trashed()) {
            throw new RowSkippedException("Email {$email} dipakai akun yang sudah dihapus.");
        }
        if ($existing && $existing->role?->slug !== 'driver') {
            throw new RowSkippedException("Email {$email} sudah dipakai user admin yang bukan kurir.");
        }

        $data = ['name' => $name, 'email' => $email];

        if (array_key_exists('phone', $row)) {
            $phone = filled($row['phone']) ? trim($row['phone']) : null;
            if ($phone !== null && mb_strlen($phone) > 30) {
                throw new RowSkippedException('Kolom phone maksimal 30 karakter.');
            }
            if ($phone !== null && AdminUser::withTrashed()->where('phone', $phone)->when($existing, fn ($q) => $q->whereKeyNot($existing->id))->exists()) {
                throw new RowSkippedException("Nomor HP {$phone} sudah dipakai akun lain.");
            }
            $data['phone'] = $phone;
        }
        if (filled($row['vehicle_type'] ?? null)) {
            if (mb_strlen(trim($row['vehicle_type'])) > 50) {
                throw new RowSkippedException('Kolom vehicle_type maksimal 50 karakter.');
            }
            $data['vehicle_type'] = trim($row['vehicle_type']);
        }
        if (array_key_exists('vehicle_plate_number', $row)) {
            $plate = filled($row['vehicle_plate_number']) ? trim($row['vehicle_plate_number']) : null;
            if ($plate !== null && mb_strlen($plate) > 30) {
                throw new RowSkippedException('Kolom vehicle_plate_number maksimal 30 karakter.');
            }
            $data['vehicle_plate_number'] = $plate;
        }
        if (filled($row['is_active'] ?? null)) {
            $data['is_active'] = in_array(strtolower(trim($row['is_active'])), ['1', 'true', 'yes', 'ya', 'aktif', 'active'], true);
        }

        $password = (string) ($row['password'] ?? '');
        if ($password !== '') {
            if (mb_strlen($password) < 6) {
                throw new RowSkippedException('Kolom password minimal 6 karakter.');
            }
            $data['password'] = $password; // hashed by the model cast
        }

        if ($existing) {
            $existing->update($data);

            return ImportResult::UPDATED;
        }

        if (! isset($data['password'])) {
            throw new RowSkippedException('Kolom password wajib diisi untuk kurir baru.');
        }

        AdminUser::create([
            'vehicle_type' => 'Motor',
            'is_active' => true,
            ...$data,
            'role_id' => Role::driver()->id,
        ]);

        return ImportResult::CREATED;
    }
}
