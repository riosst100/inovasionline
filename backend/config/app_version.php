<?php

return [
    /*
     * Latest Android build info. Bump these whenever a new APK is published
     * to storage/app/public/releases/app-latest.apk.
     */
    'android' => [
        'version' => env('ANDROID_APP_VERSION', '1.0.0'),
        'build_number' => env('ANDROID_APP_BUILD_NUMBER', 1),
        'apk_path' => env('ANDROID_APP_APK_PATH', 'releases/app-latest.apk'),
        'release_notes' => env('ANDROID_APP_RELEASE_NOTES', ''),
        'force_update' => env('ANDROID_APP_FORCE_UPDATE', false),
        'min_supported_build_number' => env('ANDROID_APP_MIN_SUPPORTED_BUILD_NUMBER', 1),
    ],
];
