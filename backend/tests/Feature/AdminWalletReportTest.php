<?php

namespace Tests\Feature;

use App\Models\AdminUser;
use App\Models\Role;
use App\Models\User;
use App\Models\WalletTopup;
use App\Services\MidtransService;
use App\Services\WalletService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminWalletReportTest extends TestCase
{
    use RefreshDatabase;

    private const SERVER_KEY = 'SB-Mid-server-test';

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.midtrans.server_key' => self::SERVER_KEY, 'services.wallet.max_balance' => 0]);
    }

    public function test_settlement_stores_payment_details_shown_in_topup_detail(): void
    {
        $topup = $this->topup(User::factory()->create(), 50000);

        app(MidtransService::class)->handleNotification($this->notification($topup, 'settlement', [
            'payment_type' => 'bank_transfer',
            'va_numbers' => [['bank' => 'bca', 'va_number' => '12345678901']],
        ]));

        Sanctum::actingAs($this->admin(), ['admin']);

        $this->getJson("/api/admin/wallet-topups/{$topup->id}")
            ->assertOk()
            ->assertJsonPath('data.status', 'paid')
            ->assertJsonPath('data.payment_method', 'Virtual Account BCA')
            ->assertJsonPath('data.balance_after', 50000)
            ->assertJsonFragment(['label' => 'Nomor Virtual Account', 'value' => '12345678901']);
    }

    public function test_topup_list_filters_running_topups_and_summarises_by_status(): void
    {
        $user = User::factory()->create(['name' => 'Budi']);
        $this->topup($user, 10000);
        $paid = $this->topup($user, 20000);
        app(MidtransService::class)->handleNotification($this->notification($paid, 'settlement', ['payment_type' => 'qris', 'issuer' => 'gopay']));

        Sanctum::actingAs($this->admin(), ['admin']);

        $this->getJson('/api/admin/wallet-topups?status=pending&search=budi')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.amount', 10000)
            ->assertJsonPath('meta.summary.pending.count', 1)
            ->assertJsonPath('meta.summary.paid.total', 20000);

        $this->getJson('/api/admin/wallet-topups?status=paid')
            ->assertJsonPath('data.0.payment_method', 'QRIS GoPay');
    }

    public function test_report_splits_income_and_expense_with_payment_method(): void
    {
        $user = User::factory()->create();
        $topup = $this->topup($user, 100000);
        app(MidtransService::class)->handleNotification($this->notification($topup, 'settlement', [
            'payment_type' => 'cstore', 'store' => 'indomaret', 'payment_code' => '998877',
        ]));
        $admin = $this->admin();
        app(WalletService::class)->adjust($user->fresh(), -30000, 'Koreksi', $admin);

        Sanctum::actingAs($admin, ['admin']);

        $res = $this->getJson('/api/admin/wallet-report?date_from='.now('Asia/Jakarta')->toDateString())
            ->assertOk()
            ->assertJsonPath('data.total_balance', 70000)
            ->assertJsonPath('data.period.opening_balance', 0)
            ->assertJsonPath('data.period.total_in', 100000)
            ->assertJsonPath('data.period.total_out', 30000)
            ->assertJsonPath('data.period.closing_balance', 70000)
            ->assertJsonPath('data.income_by_method.0.method', 'Gerai Retail Indomaret');

        $this->assertSame(['topup' => 100000], collect($res->json('data.income_by_type'))->pluck('total', 'type')->all());
        $this->assertSame(['adjustment' => 30000], collect($res->json('data.expense_by_type'))->pluck('total', 'type')->all());

        $this->getJson('/api/admin/wallet-report?direction=in')
            ->assertJsonCount(1, 'data.transactions')
            ->assertJsonPath('data.transactions.0.payment_method', 'Gerai Retail Indomaret');
    }

    private function topup(User $user, float $amount): WalletTopup
    {
        return WalletTopup::create([
            'topup_number' => WalletTopup::NUMBER_PREFIX.uniqid(),
            'user_id' => $user->id,
            'amount' => $amount,
        ]);
    }

    private function notification(WalletTopup $topup, string $status, array $extra): array
    {
        $payload = [
            'order_id' => $topup->topup_number,
            'status_code' => '200',
            'gross_amount' => number_format((float) $topup->amount, 2, '.', ''),
            'transaction_status' => $status,
            'transaction_id' => 'trx-'.uniqid(),
            ...$extra,
        ];
        $payload['signature_key'] = hash('sha512', $payload['order_id'].$payload['status_code'].$payload['gross_amount'].self::SERVER_KEY);

        return $payload;
    }

    private function admin(): AdminUser
    {
        return AdminUser::create([
            'name' => 'Admin',
            'email' => 'admin@example.com',
            'password' => 'secret123',
            'is_active' => true,
            'role_id' => Role::create(['name' => 'Super Admin', 'slug' => 'super-admin', 'is_system' => true])->id,
        ]);
    }
}
