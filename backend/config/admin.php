<?php

return [

    // Admin login session lifetime (days). Cookie and token expire together.
    'session_days' => (int) env('ADMIN_SESSION_DAYS', 365),

    // Cookie domain, e.g. ".example.com" to share across admin/api subdomains.
    'cookie_domain' => env('ADMIN_COOKIE_DOMAIN'),

    // Use "none" only if admin frontend and API are on different sites (requires HTTPS).
    'cookie_same_site' => env('ADMIN_COOKIE_SAMESITE', 'lax'),

];
