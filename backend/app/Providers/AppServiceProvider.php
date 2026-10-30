<?php

namespace App\Providers;

use App\Events\AdminDataChanged;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->singleton(\App\Services\NotificationService::class, function ($app) {
            try {
                $messaging = $app->make(\Kreait\Firebase\Contract\Messaging::class);
                return new \App\Services\NotificationService($messaging);
            } catch (\Throwable) {
                return new \App\Services\NotificationService(null);
            }
        });

        $this->app->scoped(\App\Services\FlashSalePricing::class);
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // Live admin panel (dashboard, instant-order alerts, menu badges): signal which data changed.
        $topics = [
            \App\Models\Order::class => AdminDataChanged::ORDERS,
            \App\Models\WalletTopup::class => AdminDataChanged::DASHBOARD,
            \App\Models\User::class => AdminDataChanged::DASHBOARD,
            \App\Models\SupplierBill::class => AdminDataChanged::DASHBOARD,
            \App\Models\CompanyTransaction::class => AdminDataChanged::DASHBOARD,
            \App\Models\Product::class => AdminDataChanged::DASHBOARD,
            \App\Models\Promotion::class => AdminDataChanged::DASHBOARD,
            \App\Models\Employee::class => AdminDataChanged::DASHBOARD,
        ];
        foreach ($topics as $model => $topic) {
            $model::saved(fn () => AdminDataChanged::signal($topic));
            $model::deleted(fn () => AdminDataChanged::signal($topic));
        }

        // Data the mobile app keeps on the phone: bump its version when the source models change.
        \App\Support\AppCache::listen();
    }
}
