<?php

namespace Tests\Unit;

use App\Services\MidtransService;
use App\Services\OrderCancellationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MidtransSignatureTest extends TestCase
{
    // The server key is read from midtrans_settings (falling back to config when empty).
    use RefreshDatabase;

    public function test_validates_notification_signature(): void
    {
        config(['services.midtrans.server_key' => 'SB-Mid-server-test']);

        $service = new MidtransService(new OrderCancellationService);
        $payload = ['order_id' => 'ORD-1', 'status_code' => '200', 'gross_amount' => '10000.00'];
        $payload['signature_key'] = hash('sha512', 'ORD-1200'.'10000.00'.'SB-Mid-server-test');

        $this->assertTrue($service->isValidSignature($payload));

        $payload['gross_amount'] = '1.00';
        $this->assertFalse($service->isValidSignature($payload));
    }
}
