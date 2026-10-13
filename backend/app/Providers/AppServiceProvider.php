<?php

namespace App\Providers;

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
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        //
    }
}
