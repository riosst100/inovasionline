<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    'google' => [
        'client_id' => env('GOOGLE_CLIENT_ID'),
    ],

    'whatsapp_otp' => [
        'base_url' => env('WHATSAPP_OTP_BASE_URL', 'http://127.0.0.1:3100'),
        'api_key' => env('WHATSAPP_OTP_API_KEY'),
    ],

    'midtrans' => [
        'server_key' => env('MIDTRANS_SERVER_KEY'),
        'client_key' => env('MIDTRANS_CLIENT_KEY'),
        'is_production' => env('MIDTRANS_IS_PRODUCTION', false),
        'expiry_minutes' => (int) env('MIDTRANS_EXPIRY_MINUTES', 1440),
        'notification_url' => env('MIDTRANS_NOTIFICATION_URL'),
    ],

    // Closed-loop buyer balance ("Saldo"). Limits in rupiah; 0 disables the balance cap.
    'wallet' => [
        'topup_min' => (int) env('WALLET_TOPUP_MIN', 10000),
        'topup_max' => (int) env('WALLET_TOPUP_MAX', 2000000),
        'max_balance' => (int) env('WALLET_MAX_BALANCE', 2000000),
    ],

    'admob' => [
        // Lets debug builds (Google's sample ad units, which never send SSV
        // callbacks) claim rewards themselves. Ignored in production.
        'allow_unverified_rewards' => (bool) env('ADMOB_ALLOW_UNVERIFIED_REWARDS', false),
    ],

    'support' => [
        // Link opened by the "Hubungi Admin" button on the blocked-account screen.
        'contact_url' => env('SUPPORT_CONTACT_URL'),
    ],

    // Road route courier → buyer on the order tracking map (App\Services\DeliveryRouteService).
    // Free key at openrouteservice.org; empty = the app draws a straight line instead.
    'openrouteservice' => [
        'key' => env('OPENROUTESERVICE_API_KEY'),
    ],

    'potocandid' => [
        'base_url' => env('POTOCANDID_SERVICE_BASE_URL', 'http://127.0.0.1:3200'),
        'api_key' => env('POTOCANDID_SERVICE_API_KEY'),
    ],

];
