<?php

use App\Http\Controllers\Api\Admin\AdminAuthController;
use App\Http\Controllers\Api\Admin\AdminStaffController;
use App\Http\Controllers\Api\Admin\CustomerController;
use App\Http\Controllers\Api\Admin\DriverController;
use App\Http\Controllers\Api\Admin\DriverDeliveryController;
use App\Http\Controllers\Api\V1\Admin\BannerController as AdminBannerController;
use App\Http\Controllers\Api\V1\Admin\CodVerificationController as AdminCodVerificationController;
use App\Http\Controllers\Api\V1\CodVerificationController;
use App\Http\Controllers\Api\V1\Admin\CategoryController as AdminCategoryController;
use App\Http\Controllers\Api\V1\Admin\DashboardController as AdminDashboardController;
use App\Http\Controllers\Api\V1\Admin\DashboardOverviewController as AdminDashboardOverviewController;
use App\Http\Controllers\Api\V1\Admin\SalesReportController as AdminSalesReportController;
use App\Http\Controllers\Api\V1\Admin\DataTransferController as AdminDataTransferController;
use App\Http\Controllers\Api\V1\Admin\DeliveryHolidayController as AdminDeliveryHolidayController;
use App\Http\Controllers\Api\V1\Admin\DeliveryScheduleController as AdminDeliveryScheduleController;
use App\Http\Controllers\Api\V1\Admin\ProductAttributeController as AdminProductAttributeController;
use App\Http\Controllers\Api\V1\Admin\ProductController as AdminProductController;
use App\Http\Controllers\Api\V1\Admin\ProductStockController as AdminProductStockController;
use App\Http\Controllers\Api\V1\Admin\SearchSuggestionController as AdminSearchSuggestionController;
use App\Http\Controllers\Api\V1\Admin\FlashSaleController as AdminFlashSaleController;
use App\Http\Controllers\Api\V1\Admin\FlashSaleSlotController as AdminFlashSaleSlotController;
use App\Http\Controllers\Api\V1\Admin\NotificationController as AdminNotificationController;
use App\Http\Controllers\Api\V1\Admin\OrderController as AdminOrderController;
use App\Http\Controllers\Api\V1\Admin\PaymentMethodController as AdminPaymentMethodController;
use App\Http\Controllers\Api\V1\Admin\PhotographerApplicationController as AdminPhotographerApplicationController;
use App\Http\Controllers\Api\V1\Admin\RoleController as AdminRoleController;
use App\Http\Controllers\Api\V1\Admin\ServiceCityController as AdminServiceCityController;
use App\Http\Controllers\Api\V1\Admin\NavBadgeController as AdminNavBadgeController;
use App\Http\Controllers\Api\V1\Admin\LabelConfigController as AdminLabelConfigController;
use App\Http\Controllers\Api\V1\Admin\OrderSettingController as AdminOrderSettingController;
use App\Http\Controllers\Api\V1\Admin\AdChestController as AdminAdChestController;
use App\Http\Controllers\Api\V1\Admin\AdmobController as AdminAdmobController;
use App\Http\Controllers\Api\V1\Admin\AppUpdateController as AdminAppUpdateController;
use App\Http\Controllers\Api\V1\Admin\FreeShippingController as AdminFreeShippingController;
use App\Http\Controllers\Api\V1\Admin\WalletBonusController as AdminWalletBonusController;
use App\Http\Controllers\Api\V1\Admin\WalletController as AdminWalletController;
use App\Http\Controllers\Api\V1\Admin\WalletReportController as AdminWalletReportController;
use App\Http\Controllers\Api\V1\Admin\WalletTopupController as AdminWalletTopupController;
use App\Http\Controllers\Api\V1\Admin\ServiceFeeController as AdminServiceFeeController;
use App\Http\Controllers\Api\V1\Admin\MidtransSettingController as AdminMidtransSettingController;
use App\Http\Controllers\Api\V1\Admin\ShippingMethodController as AdminShippingMethodController;
use App\Http\Controllers\Api\V1\Admin\ShippingRateTemplateController as AdminShippingRateTemplateController;
use App\Http\Controllers\Api\V1\Admin\ShippingRateTemplateRowController as AdminShippingRateTemplateRowController;
use App\Http\Controllers\Api\V1\Admin\UserController as AdminUserController;
use App\Http\Controllers\Api\V1\Admin\UserVerificationController as AdminUserVerificationController;
use App\Http\Controllers\Api\V1\Admin\WarehouseController as AdminWarehouseController;
use App\Http\Controllers\Api\V1\Admin\SupplierController as AdminSupplierController;
use App\Http\Controllers\Api\V1\Admin\BrandController as AdminBrandController;
use App\Http\Controllers\Api\V1\Admin\CompanyTransactionController as AdminCompanyTransactionController;
use App\Http\Controllers\Api\V1\Admin\EmployeeController as AdminEmployeeController;
use App\Http\Controllers\Api\V1\Admin\FinanceController as AdminFinanceController;
use App\Http\Controllers\Api\V1\Admin\SupplierBillController as AdminSupplierBillController;
use App\Http\Controllers\Api\V1\AppPresenceController;
use App\Http\Controllers\Api\V1\UserContactController;
use App\Http\Controllers\Api\V1\AppVersionController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\BannerController;
use App\Http\Controllers\Api\V1\CartController;
use App\Http\Controllers\Api\V1\CategoryController;
use App\Http\Controllers\Api\V1\ChatController;
use App\Http\Controllers\Api\V1\CheckoutController;
use App\Http\Controllers\Api\V1\CheckoutOptionsController;
use App\Http\Controllers\Api\V1\DeviceTokenController;
use App\Http\Controllers\Api\V1\FaceProfileController;
use App\Http\Controllers\Api\V1\FlashSaleSlotController;
use App\Http\Controllers\Api\V1\MatchedPhotoController;
use App\Http\Controllers\Api\V1\NavBadgeController;
use App\Http\Controllers\Api\V1\AdmobConfigController;
use App\Http\Controllers\Api\V1\AdmobSsvController;
use App\Http\Controllers\Api\V1\WalletController;
use App\Http\Controllers\Api\V1\OrderController;
use App\Http\Controllers\Api\V1\PaymentController;
use App\Http\Controllers\Api\V1\Photographer\PhotoController as PhotographerPhotoController;
use App\Http\Controllers\Api\V1\Photographer\PhotoEventController as PhotographerPhotoEventController;
use App\Http\Controllers\Api\V1\PhotographerApplicationController;
use App\Http\Controllers\Api\V1\PhotoController;
use App\Http\Controllers\Api\V1\PhotoPurchaseController;
use App\Http\Controllers\Api\V1\PostController;
use App\Http\Controllers\Api\V1\PublicProductController;
use App\Http\Controllers\Api\V1\RegionController;
use App\Http\Controllers\Api\V1\SearchController;
use App\Http\Controllers\Api\V1\UserAddressController;
use App\Http\Controllers\Api\V1\UserVerificationController;
use App\Http\Middleware\EnsureDriver;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {

    Route::prefix('auth')->group(function () {
        Route::post('/register', [AuthController::class, 'register'])
            ->middleware('throttle:6,1');
        Route::post('/login', [AuthController::class, 'login'])
            ->middleware('throttle:6,1');
        Route::post('/google', [AuthController::class, 'google'])
            ->middleware('throttle:6,1');
        Route::post('/forgot-password', [AuthController::class, 'forgotPassword'])
            ->middleware('throttle:6,1');
        Route::post('/reset-password', [AuthController::class, 'resetPassword'])
            ->middleware('throttle:6,1');
        Route::post('/send-phone-otp', [AuthController::class, 'sendPhoneOtp'])
            ->middleware('throttle:3,1');
        Route::post('/verify-phone-otp', [AuthController::class, 'verifyPhoneOtp'])
            ->middleware('throttle:6,1');

        Route::middleware('auth:sanctum')->group(function () {
            Route::post('/logout', [AuthController::class, 'logout']);
            Route::get('/user', [AuthController::class, 'user']);
            Route::put('/user', [AuthController::class, 'updateProfile']);
            Route::post('/user', [AuthController::class, 'updateProfile']);
            Route::put('/user/address', [AuthController::class, 'updateAddress']);
            Route::post('/user/address/from-location', [AuthController::class, 'setAddressFromLocation'])
                ->middleware('throttle:6,1');
            Route::get('/user/addresses', [UserAddressController::class, 'index']);
            Route::post('/user/addresses', [UserAddressController::class, 'store']);
            Route::put('/user/addresses/{address}', [UserAddressController::class, 'update']);
            Route::delete('/user/addresses/{address}', [UserAddressController::class, 'destroy']);
        });
    });

    Route::middleware(['auth:sanctum', 'not.blocked'])->group(function () {
        Route::prefix('potocandid')->group(function () {
            Route::post('/face-profile', [FaceProfileController::class, 'store']);
            Route::get('/face-profile', [FaceProfileController::class, 'show']);

            Route::get('/photos', [PhotoController::class, 'index']);
            Route::get('/photos/{photo}', [PhotoController::class, 'show']);

            Route::get('/matched-photos', [MatchedPhotoController::class, 'index']);

            Route::get('/purchases', [PhotoPurchaseController::class, 'index']);
            Route::post('/purchases', [PhotoPurchaseController::class, 'store']);

            Route::prefix('photographer-applications')->group(function () {
                Route::post('/', [PhotographerApplicationController::class, 'store']);
                Route::get('/me', [PhotographerApplicationController::class, 'show']);
            });
        });

        Route::prefix('verifications')->group(function () {
            Route::post('/', [UserVerificationController::class, 'store']);
            Route::get('/me', [UserVerificationController::class, 'show']);
        });

        Route::prefix('device-tokens')->group(function () {
            Route::post('/', [DeviceTokenController::class, 'store']);
            Route::delete('/', [DeviceTokenController::class, 'destroy']);
        });
    });

    Route::get('/categories', [CategoryController::class, 'index']);
    Route::get('/categories/{slug}', [CategoryController::class, 'show']);

    Route::get('/app-version', [AppVersionController::class, 'show']);

    Route::prefix('products')->group(function () {
        Route::get('/flash-sale', [PublicProductController::class, 'flashSale']);
        Route::get('/best-sellers', [PublicProductController::class, 'bestSellers']);
        Route::get('/{product:slug}', [PublicProductController::class, 'show']);
    });

    Route::get('/payment-methods', [CheckoutOptionsController::class, 'paymentMethods']);
    Route::get('/shipping-methods', [CheckoutOptionsController::class, 'shippingMethods']);
    Route::get('/delivery-schedules', [CheckoutOptionsController::class, 'deliverySchedules']);
    Route::get('/service-fee', [CheckoutOptionsController::class, 'serviceFee']);
    Route::get('/free-shipping', [CheckoutOptionsController::class, 'freeShipping']);
    Route::get('/nav-badge', [NavBadgeController::class, 'show']);
    Route::post('/app/heartbeat', [AppPresenceController::class, 'heartbeat'])->middleware('throttle:30,1');
    Route::post('/contacts/sync', [UserContactController::class, 'sync'])->middleware('throttle:30,1');
    Route::get('/admob-config', [AdmobConfigController::class, 'show']);
    Route::get('/admob/ssv', AdmobSsvController::class)->name('admob.ssv')->middleware('throttle:120,1');

    Route::prefix('search')->group(function () {
        Route::get('/', [SearchController::class, 'index']);
        Route::get('/suggestions', [SearchController::class, 'suggestions']);
        Route::get('/popular', [SearchController::class, 'popular']);
        Route::post('/click', [SearchController::class, 'click']);
    });

    Route::prefix('regions')->group(function () {
        Route::get('/nearest', [RegionController::class, 'nearest'])->middleware('throttle:20,1');
        Route::get('/provinces', [RegionController::class, 'provinces']);
        Route::get('/provinces/{provinceCode}/cities', [RegionController::class, 'cities']);
        Route::get('/cities/{cityCode}/districts', [RegionController::class, 'districts']);
        Route::get('/districts/{districtCode}/villages', [RegionController::class, 'villages']);
    });

    Route::get('/flash-sale-slots', [FlashSaleSlotController::class, 'index']);

    Route::get('/banners', [BannerController::class, 'index']);

    Route::prefix('posts')->group(function () {
        Route::get('/', [PostController::class, 'index']);
        Route::get('/{post}/comments', [PostController::class, 'comments']);

        Route::middleware(['auth:sanctum', 'not.blocked', 'feature.ban:posts'])->group(function () {
            Route::post('/', [PostController::class, 'store']);
            Route::post('/{post}/share', [PostController::class, 'share']);
            Route::delete('/{post}', [PostController::class, 'destroy']);
            Route::post('/{post}/like', [PostController::class, 'toggleLike']);
            Route::post('/{post}/comments', [PostController::class, 'storeComment']);
            Route::delete('/comments/{comment}', [PostController::class, 'destroyComment']);
        });
    });

    Route::prefix('chat')->group(function () {
        Route::get('/global-preview', [ChatController::class, 'globalPreview']);

        Route::middleware(['auth:sanctum', 'not.blocked', 'feature.ban:chat'])->group(function () {
            Route::get('/threads', [ChatController::class, 'index']);
            Route::get('/threads/{thread}', [ChatController::class, 'show']);
            Route::get('/threads/{thread}/messages', [ChatController::class, 'messages']);
            Route::post('/threads/{thread}/messages', [ChatController::class, 'sendMessage']);
            Route::get('/threads/{thread}/participants', [ChatController::class, 'participants']);
            Route::post('/threads/{thread}/read', [ChatController::class, 'markAsRead']);
            Route::post('/threads/{thread}/favorite', [ChatController::class, 'toggleFavorite']);
            Route::post('/users/{user}/dm', [ChatController::class, 'startDirectMessage']);
        });
    });

    Route::prefix('cart')->middleware(['auth:sanctum', 'not.blocked', 'feature.ban:purchase'])->group(function () {
        Route::get('/', [CartController::class, 'index']);
        Route::post('/items', [CartController::class, 'store']);
        Route::patch('/items/{cartItem}', [CartController::class, 'update']);
        Route::delete('/items/{cartItem}', [CartController::class, 'destroy']);
    });

    Route::prefix('checkout')->middleware(['auth:sanctum', 'not.blocked', 'feature.ban:purchase'])->group(function () {
        Route::post('/', [CheckoutController::class, 'store']);
        // One-time face check shared by COD and Paylater; /cod-verification is the older alias.
        Route::get('/face-verification', [CodVerificationController::class, 'show']);
        Route::post('/face-verification', [CodVerificationController::class, 'store'])->middleware('throttle:10,1');
        Route::get('/cod-verification', [CodVerificationController::class, 'show']);
        Route::post('/cod-verification', [CodVerificationController::class, 'store'])->middleware('throttle:10,1');
    });

    Route::prefix('orders')->middleware(['auth:sanctum', 'not.blocked'])->group(function () {
        Route::get('/', [OrderController::class, 'index']);
        Route::get('/{order}', [OrderController::class, 'show']);
        Route::post('/{order}/cancel', [OrderController::class, 'cancel']);
        Route::post('/{order}/cancel-hold', [OrderController::class, 'holdCancel']);
        Route::post('/{order}/cancel-decline', [OrderController::class, 'declineCancel']);
        Route::post('/{order}/pay', [PaymentController::class, 'pay'])->middleware('feature.ban:purchase');
        Route::get('/{order}/payment-status', [PaymentController::class, 'status']);
    });

    Route::prefix('wallet')->middleware(['auth:sanctum', 'not.blocked'])->group(function () {
        Route::get('/', [WalletController::class, 'show']);
        Route::get('/transactions', [WalletController::class, 'transactions']);
        // Retried every couple of seconds while AdMob's reward callback is pending.
        Route::post('/bonus/claim', [WalletController::class, 'claimBonus'])->middleware('throttle:20,1');
        Route::post('/bonus/test-ad-view', [WalletController::class, 'testAdView'])->middleware('throttle:10,1');
        // Opening is retried every couple of seconds while AdMob's reward callback is pending.
        Route::get('/chest', [WalletController::class, 'chest'])->middleware('throttle:60,1');
        Route::post('/chest/open', [WalletController::class, 'openChest'])->middleware('throttle:20,1');
        Route::post('/topups', [WalletController::class, 'topup'])->middleware('throttle:10,1');
        Route::get('/topups/{topup}/status', [WalletController::class, 'topupStatus']);
    });

    Route::post('/payments/midtrans/notification', [PaymentController::class, 'notification']);

    Route::prefix('photographer')->middleware(['auth:sanctum', 'not.blocked', 'photographer'])->group(function () {
        Route::prefix('events')->group(function () {
            Route::get('/', [PhotographerPhotoEventController::class, 'index']);
            Route::post('/', [PhotographerPhotoEventController::class, 'store']);
            Route::post('/{event}', [PhotographerPhotoEventController::class, 'update']);
            Route::delete('/{event}', [PhotographerPhotoEventController::class, 'destroy']);
        });

        Route::prefix('photos')->group(function () {
            Route::get('/', [PhotographerPhotoController::class, 'index']);
            Route::post('/', [PhotographerPhotoController::class, 'store']);
            Route::delete('/{photo}', [PhotographerPhotoController::class, 'destroy']);
        });
    });

    Route::prefix('admin')->middleware(['auth:sanctum', 'admin'])->group(function () {
        Route::prefix('users')->middleware('menu:users')->group(function () {
            Route::get('/', [AdminUserController::class, 'index']);
            Route::post('/', [AdminUserController::class, 'store']);
            Route::get('/{user}', [AdminUserController::class, 'show']);
            Route::put('/{user}', [AdminUserController::class, 'update']);
            Route::delete('/{user}', [AdminUserController::class, 'destroy']);
        });

        Route::prefix('roles')->middleware('menu:roles,users')->group(function () {
            Route::get('/permissions', [AdminRoleController::class, 'availablePermissions']);
            Route::get('/', [AdminRoleController::class, 'index']);
            Route::post('/', [AdminRoleController::class, 'store']);
            Route::get('/{role}', [AdminRoleController::class, 'show']);
            Route::put('/{role}', [AdminRoleController::class, 'update']);
            Route::delete('/{role}', [AdminRoleController::class, 'destroy']);
        });

        Route::prefix('photographer-applications')->middleware('menu:customers')->group(function () {
            Route::get('/', [AdminPhotographerApplicationController::class, 'index']);
            Route::post('/{photographerApplication}/approve', [AdminPhotographerApplicationController::class, 'approve']);
            Route::post('/{photographerApplication}/reject', [AdminPhotographerApplicationController::class, 'reject']);
        });

        Route::prefix('verifications')->middleware('menu:customers')->group(function () {
            Route::get('/', [AdminUserVerificationController::class, 'index']);
            Route::post('/{userVerification}/approve', [AdminUserVerificationController::class, 'approve']);
            Route::post('/{userVerification}/reject', [AdminUserVerificationController::class, 'reject']);
        });

        Route::prefix('flash-sale-slots')->middleware('menu:flash_sales')->group(function () {
            Route::get('/', [AdminFlashSaleSlotController::class, 'index']);
            Route::post('/', [AdminFlashSaleSlotController::class, 'store']);
            Route::put('/{flashSaleSlot}', [AdminFlashSaleSlotController::class, 'update']);
            Route::delete('/{flashSaleSlot}', [AdminFlashSaleSlotController::class, 'destroy']);
        });

        Route::prefix('banners')->middleware('menu:banners')->group(function () {
            Route::get('/', [AdminBannerController::class, 'index']);
            Route::post('/', [AdminBannerController::class, 'store']);
            Route::post('/reorder', [AdminBannerController::class, 'reorder']);
            Route::post('/{banner}/toggle', [AdminBannerController::class, 'toggleActive']);
            Route::match(['post', 'put', 'patch'], '/{banner}', [AdminBannerController::class, 'update']);
            Route::delete('/{banner}', [AdminBannerController::class, 'destroy']);
        });

        Route::prefix('categories')->middleware('menu:categories,products')->group(function () {
            Route::get('/', [AdminCategoryController::class, 'index']);
            Route::post('/', [AdminCategoryController::class, 'store']);
            Route::post('/reorder', [AdminCategoryController::class, 'reorder']);
            Route::put('/{category}', [AdminCategoryController::class, 'update']);
            Route::post('/{category}/approve', [AdminCategoryController::class, 'approve']);
            Route::post('/{category}/toggle', [AdminCategoryController::class, 'toggle']);
            Route::delete('/{category}', [AdminCategoryController::class, 'destroy']);
        });

        Route::post('/notifications/broadcast', [AdminNotificationController::class, 'broadcast'])->middleware('menu:notifications.broadcast');

        Route::prefix('orders')->middleware('menu:orders')->group(function () {
            Route::get('/', [AdminOrderController::class, 'index']);
            Route::get('/counts', [AdminOrderController::class, 'counts']);
            Route::get('/{order}', [AdminOrderController::class, 'show']);
        });

        Route::prefix('payment-methods')->middleware('menu:free_shipping')->group(function () {
            Route::get('/', [AdminPaymentMethodController::class, 'index']);
            Route::post('/{paymentMethod}/toggle', [AdminPaymentMethodController::class, 'toggle']);
        });

        Route::prefix('shipping-methods')->middleware('menu:shipping_methods,free_shipping,orders')->group(function () {
            Route::get('/', [AdminShippingMethodController::class, 'index']);
            Route::post('/{shippingMethod}/toggle', [AdminShippingMethodController::class, 'toggle']);
        });

        Route::prefix('shipping-rate-templates')->middleware('menu:shipping_methods')->group(function () {
            Route::get('/', [AdminShippingRateTemplateController::class, 'index']);
            Route::post('/', [AdminShippingRateTemplateController::class, 'store']);
            Route::put('/{template}', [AdminShippingRateTemplateController::class, 'update']);
            Route::delete('/{template}', [AdminShippingRateTemplateController::class, 'destroy']);

            Route::prefix('{template}/rows')->group(function () {
                Route::get('/', [AdminShippingRateTemplateRowController::class, 'index']);
                Route::post('/', [AdminShippingRateTemplateRowController::class, 'store']);
                Route::put('/{row}', [AdminShippingRateTemplateRowController::class, 'update']);
                Route::delete('/{row}', [AdminShippingRateTemplateRowController::class, 'destroy']);
                Route::get('/export', [AdminShippingRateTemplateRowController::class, 'export']);
                Route::post('/import', [AdminShippingRateTemplateRowController::class, 'import']);
            });
        });
    });

});

/*
|--------------------------------------------------------------------------
| Dedicated Admin API Endpoints (/api/admin/*)
|--------------------------------------------------------------------------
| Completely separated from customer/client marketplace API (/api/v1/*).
*/
Route::prefix('admin')->group(function () {

    // Public Admin Auth
    Route::prefix('auth')->group(function () {
        Route::post('/login', [AdminAuthController::class, 'login']);
    });

    // Protected Admin Endpoints
    Route::middleware(['auth:sanctum', 'admin.auth'])->group(function () {

        Route::prefix('auth')->group(function () {
            Route::get('/me', [AdminAuthController::class, 'me']);
            Route::post('/logout', [AdminAuthController::class, 'logout']);
            Route::put('/password', [AdminAuthController::class, 'changePassword']);
            Route::post('/avatar', [AdminAuthController::class, 'updateAvatar']);
            Route::delete('/avatar', [AdminAuthController::class, 'deleteAvatar']);
            Route::get('/sessions', [AdminAuthController::class, 'sessions']);
            Route::delete('/sessions', [AdminAuthController::class, 'revokeOtherSessions']);
            Route::delete('/sessions/{id}', [AdminAuthController::class, 'revokeSession']);
        });

        // Staff / Admin Users Management (admin_users table)
        Route::prefix('staff')->middleware('menu:users')->group(function () {
            Route::get('/', [AdminStaffController::class, 'index']);
            Route::post('/', [AdminStaffController::class, 'store']);
            Route::get('/{adminUser}', [AdminStaffController::class, 'show']);
            Route::put('/{adminUser}', [AdminStaffController::class, 'update']);
            Route::delete('/{adminUser}', [AdminStaffController::class, 'destroy']);
        });

        // Dedicated Driver Management (/api/admin/drivers/*)
        Route::prefix('drivers')->middleware('menu:drivers')->group(function () {
            Route::get('/', [DriverController::class, 'index']);
            Route::post('/', [DriverController::class, 'store']);
            Route::get('/{driver}', [DriverController::class, 'show']);
            Route::put('/{driver}', [DriverController::class, 'update']);
            Route::patch('/{driver}/status', [DriverController::class, 'setStatus']);
            Route::delete('/{driver}', [DriverController::class, 'destroy']);
            Route::get('/{driver}/orders', [DriverController::class, 'orders']);
        });

        // Driver app: scan a parcel's QR, then confirm pickup (shipped) or handover (delivered) with a photo.
        Route::prefix('driver')->middleware(EnsureDriver::class)->group(function () {
            Route::get('/orders', [DriverDeliveryController::class, 'index']);
            Route::post('/scan', [DriverDeliveryController::class, 'scan']);
            Route::post('/orders/{order}/ship', [DriverDeliveryController::class, 'ship']);
            Route::post('/orders/{order}/deliver', [DriverDeliveryController::class, 'deliver']);
        });

        // Role & Permissions Management
        Route::prefix('roles')->middleware('menu:roles,users')->group(function () {
            Route::get('/permissions', [AdminRoleController::class, 'availablePermissions']);
            Route::get('/', [AdminRoleController::class, 'index']);
            Route::post('/', [AdminRoleController::class, 'store']);
            Route::get('/{role}', [AdminRoleController::class, 'show']);
            Route::put('/{role}', [AdminRoleController::class, 'update']);
            Route::delete('/{role}', [AdminRoleController::class, 'destroy']);
        });

        // Customer Listing (users table)
        Route::prefix('customers')->middleware('menu:customers')->group(function () {
            Route::get('/', [CustomerController::class, 'index']);
            Route::post('/', [CustomerController::class, 'store']);
            Route::get('/{user}', [CustomerController::class, 'show']);
            Route::post('/{user}/block', [CustomerController::class, 'block']);
            Route::post('/{user}/unblock', [CustomerController::class, 'unblock']);
            Route::post('/{user}/ban', [CustomerController::class, 'ban']);
            Route::post('/{user}/unban', [CustomerController::class, 'unban']);
            Route::post('/{user}/revoke-verification', [CustomerController::class, 'revokeVerification']);
            Route::delete('/{user}/sessions/{session}', [CustomerController::class, 'revokeSession']);
        });

        // Operational Marketplace Management
        Route::prefix('banners')->middleware('menu:banners')->group(function () {
            Route::get('/', [AdminBannerController::class, 'index']);
            Route::post('/', [AdminBannerController::class, 'store']);
            Route::post('/reorder', [AdminBannerController::class, 'reorder']);
            Route::post('/{banner}/toggle', [AdminBannerController::class, 'toggleActive']);
            Route::match(['post', 'put', 'patch'], '/{banner}', [AdminBannerController::class, 'update']);
            Route::delete('/{banner}', [AdminBannerController::class, 'destroy']);
        });

        Route::prefix('categories')->middleware('menu:categories,products')->group(function () {
            Route::get('/', [AdminCategoryController::class, 'index']);
            Route::post('/', [AdminCategoryController::class, 'store']);
            Route::post('/reorder', [AdminCategoryController::class, 'reorder']);
            Route::post('/{category}/toggle', [AdminCategoryController::class, 'toggle']);
            Route::put('/{category}', [AdminCategoryController::class, 'update']);
            Route::post('/{category}', [AdminCategoryController::class, 'update']);
            Route::delete('/{category}', [AdminCategoryController::class, 'destroy']);
        });

        // Queued CSV/XLSX import & export (categories, products, ...)
        Route::prefix('data-transfers')->group(function () {
            Route::get('/', [AdminDataTransferController::class, 'index']);
            Route::get('/template', [AdminDataTransferController::class, 'template']);
            Route::post('/export', [AdminDataTransferController::class, 'export']);
            Route::post('/import', [AdminDataTransferController::class, 'import'])->middleware('throttle:20,1');
            Route::get('/{dataTransfer}', [AdminDataTransferController::class, 'show']);
            Route::get('/{dataTransfer}/download', [AdminDataTransferController::class, 'download']);
            Route::delete('/{dataTransfer}', [AdminDataTransferController::class, 'destroy']);
        });

        Route::prefix('search-suggestions')->middleware('menu:search_suggestions')->group(function () {
            Route::get('/', [AdminSearchSuggestionController::class, 'index']);
            Route::post('/', [AdminSearchSuggestionController::class, 'store']);
            Route::delete('/{searchLog}', [AdminSearchSuggestionController::class, 'destroy']);
        });

        Route::prefix('product-attributes')->middleware('menu:attributes')->group(function () {
            Route::get('/', [AdminProductAttributeController::class, 'index']);
            Route::post('/', [AdminProductAttributeController::class, 'store']);
            Route::put('/{productAttribute}', [AdminProductAttributeController::class, 'update']);
            Route::delete('/{productAttribute}', [AdminProductAttributeController::class, 'destroy']);
        });

        Route::prefix('employees')->middleware('menu:employees,cashflow')->group(function () {
            Route::get('/', [AdminEmployeeController::class, 'index']);
            Route::post('/', [AdminEmployeeController::class, 'store']);
            Route::put('/{employee}', [AdminEmployeeController::class, 'update']);
            Route::delete('/{employee}', [AdminEmployeeController::class, 'destroy']);
        });

        // Master Data
        Route::prefix('suppliers')->middleware('menu:suppliers,products,purchases')->group(function () {
            Route::get('/', [AdminSupplierController::class, 'index']);
            Route::post('/', [AdminSupplierController::class, 'store']);
            Route::put('/{supplier}', [AdminSupplierController::class, 'update']);
            Route::delete('/{supplier}', [AdminSupplierController::class, 'destroy']);
        });

        Route::prefix('brands')->middleware('menu:brands,products')->group(function () {
            Route::get('/', [AdminBrandController::class, 'index']);
            Route::post('/', [AdminBrandController::class, 'store']);
            Route::put('/{brand}', [AdminBrandController::class, 'update']);
            Route::delete('/{brand}', [AdminBrandController::class, 'destroy']);
        });

        Route::prefix('warehouses')->middleware('menu:warehouses,products,product_stocks')->group(function () {
            Route::get('/', [AdminWarehouseController::class, 'index']);
            Route::post('/', [AdminWarehouseController::class, 'store']);
            Route::get('/{warehouse}', [AdminWarehouseController::class, 'show']);
            Route::put('/{warehouse}', [AdminWarehouseController::class, 'update']);
            Route::delete('/{warehouse}', [AdminWarehouseController::class, 'destroy']);
        });

        Route::prefix('shipping-methods')->middleware('menu:shipping_methods,free_shipping,orders')->group(function () {
            Route::get('/', [AdminShippingMethodController::class, 'index']);
            Route::post('/', [AdminShippingMethodController::class, 'store']);
            Route::put('/{shippingMethod}', [AdminShippingMethodController::class, 'update']);
            Route::delete('/{shippingMethod}', [AdminShippingMethodController::class, 'destroy']);
            Route::post('/{shippingMethod}/toggle', [AdminShippingMethodController::class, 'toggle']);
        });

        Route::prefix('delivery-holidays')->middleware('menu:delivery_schedules')->group(function () {
            Route::get('/', [AdminDeliveryHolidayController::class, 'index']);
            Route::post('/', [AdminDeliveryHolidayController::class, 'store']);
            Route::put('/{deliveryHoliday}', [AdminDeliveryHolidayController::class, 'update']);
            Route::delete('/{deliveryHoliday}', [AdminDeliveryHolidayController::class, 'destroy']);
        });

        Route::prefix('delivery-schedules')->middleware('menu:delivery_schedules')->group(function () {
            Route::get('/', [AdminDeliveryScheduleController::class, 'index']);
            Route::post('/', [AdminDeliveryScheduleController::class, 'store']);
            Route::put('/{deliverySchedule}', [AdminDeliveryScheduleController::class, 'update']);
            Route::delete('/{deliverySchedule}', [AdminDeliveryScheduleController::class, 'destroy']);
        });

        Route::get('service-cities', [AdminServiceCityController::class, 'index'])->middleware('menu:service_cities');
        Route::put('service-cities', [AdminServiceCityController::class, 'update'])->middleware('menu:service_cities');

        Route::get('service-fee', [AdminServiceFeeController::class, 'show'])->middleware('menu:service_fee');
        Route::put('service-fee', [AdminServiceFeeController::class, 'update'])->middleware('menu:service_fee');

        Route::get('midtrans-settings', [AdminMidtransSettingController::class, 'show'])->middleware('menu:payment_gateway');
        Route::put('midtrans-settings', [AdminMidtransSettingController::class, 'update'])->middleware('menu:payment_gateway');

        Route::get('free-shipping', [AdminFreeShippingController::class, 'show'])->middleware('menu:free_shipping');
        Route::put('free-shipping', [AdminFreeShippingController::class, 'update'])->middleware('menu:free_shipping');

        Route::get('wallet-bonus', [AdminWalletBonusController::class, 'show'])->middleware('menu:wallet_bonus');
        Route::put('wallet-bonus', [AdminWalletBonusController::class, 'update'])->middleware('menu:wallet_bonus');

        Route::prefix('wallets')->middleware('menu:wallets')->group(function () {
            Route::get('/', [AdminWalletController::class, 'index']);
            Route::get('/{user}', [AdminWalletController::class, 'show']);
            Route::post('/{user}/adjust', [AdminWalletController::class, 'adjust']);
        });

        Route::get('wallet-topups', [AdminWalletTopupController::class, 'index'])->middleware('menu:wallet_topups');
        Route::get('wallet-topups/{topup}', [AdminWalletTopupController::class, 'show'])->middleware('menu:wallet_topups');
        Route::get('wallet-report', [AdminWalletReportController::class, 'index'])->middleware('menu:wallet_report');

        Route::get('cod-verifications', [AdminCodVerificationController::class, 'index'])->middleware('menu:cod_verifications');
        Route::post('cod-verifications/{codVerification}/revoke', [AdminCodVerificationController::class, 'revoke'])->middleware('menu:cod_verifications');

        Route::get('dashboard', [AdminDashboardController::class, 'index'])->middleware('menu:dashboard');
        Route::get('dashboard/overview', [AdminDashboardOverviewController::class, 'index'])->middleware('menu:dashboard');
        Route::get('sales-report', [AdminSalesReportController::class, 'index'])->middleware('menu:dashboard');

        // Keuangan
        Route::get('finance/report', [AdminFinanceController::class, 'report'])->middleware('menu:finance_report');
        Route::get('finance/profit', [AdminFinanceController::class, 'profit'])->middleware('menu:finance_report');
        Route::prefix('company-transactions')->middleware('menu:cashflow')->group(function () {
            Route::get('/', [AdminCompanyTransactionController::class, 'index']);
            Route::post('/', [AdminCompanyTransactionController::class, 'store']);
            Route::put('/{companyTransaction}', [AdminCompanyTransactionController::class, 'update']);
            Route::delete('/{companyTransaction}', [AdminCompanyTransactionController::class, 'destroy']);
        });
        Route::prefix('supplier-bills')->middleware('menu:purchases')->group(function () {
            Route::get('/', [AdminSupplierBillController::class, 'index']);
            Route::post('/', [AdminSupplierBillController::class, 'store']);
            Route::put('/{supplierBill}', [AdminSupplierBillController::class, 'update']);
            Route::delete('/{supplierBill}', [AdminSupplierBillController::class, 'destroy']);
            Route::post('/{supplierBill}/pay', [AdminSupplierBillController::class, 'pay']);
            Route::post('/{supplierBill}/unpay', [AdminSupplierBillController::class, 'unpay']);
        });

        Route::get('nav-badge', [AdminNavBadgeController::class, 'show'])->middleware('menu:nav_badge');
        Route::put('nav-badge', [AdminNavBadgeController::class, 'update'])->middleware('menu:nav_badge');

        Route::get('app-update', [AdminAppUpdateController::class, 'show'])->middleware('menu:app_update');
        Route::put('app-update', [AdminAppUpdateController::class, 'update'])->middleware('menu:app_update');

        Route::get('label-configs', [AdminLabelConfigController::class, 'index'])->middleware('menu:order_statuses,orders');
        Route::put('label-configs', [AdminLabelConfigController::class, 'update'])->middleware('menu:order_statuses,orders');

        Route::get('order-settings', [AdminOrderSettingController::class, 'show'])->middleware('menu:order_cancellation');
        Route::put('order-settings', [AdminOrderSettingController::class, 'update'])->middleware('menu:order_cancellation');

        Route::get('ad-chest', [AdminAdChestController::class, 'show'])->middleware('menu:reward_chest');
        Route::put('ad-chest', [AdminAdChestController::class, 'update'])->middleware('menu:reward_chest');

        Route::get('admob', [AdminAdmobController::class, 'show'])->middleware('menu:admob');
        Route::put('admob', [AdminAdmobController::class, 'update'])->middleware('menu:admob');

        Route::prefix('flash-sales')->middleware('menu:flash_sales')->group(function () {
            Route::get('/', [AdminFlashSaleController::class, 'index']);
            Route::post('/', [AdminFlashSaleController::class, 'store']);
            Route::get('/{flashSale}', [AdminFlashSaleController::class, 'show']);
            Route::put('/{flashSale}', [AdminFlashSaleController::class, 'update']);
            Route::post('/{flashSale}/toggle', [AdminFlashSaleController::class, 'toggle']);
            Route::delete('/{flashSale}', [AdminFlashSaleController::class, 'destroy']);
        });

        Route::get('product-stocks', [AdminProductStockController::class, 'index'])->middleware('menu:product_stocks');
        Route::put('product-stocks/{product}', [AdminProductStockController::class, 'update'])->middleware('menu:product_stocks');

        Route::get('products', [AdminProductController::class, 'index'])->middleware('menu:products,flash_sales');
        Route::post('products', [AdminProductController::class, 'store'])->middleware('menu:products,flash_sales');
        Route::post('products/bulk-status', [AdminProductController::class, 'bulkUpdateStatus'])->middleware('menu:products,flash_sales');
        Route::post('products/bulk-delete', [AdminProductController::class, 'bulkDestroy'])->middleware('menu:products,flash_sales');
        Route::post('products/{product}/images', [AdminProductController::class, 'storeImages'])->middleware('menu:products,flash_sales');
        Route::post('products/{product}/images/{image}/primary', [AdminProductController::class, 'setPrimaryImage'])->middleware('menu:products,flash_sales');
        Route::delete('products/{product}/images/{image}', [AdminProductController::class, 'destroyImage'])->middleware('menu:products,flash_sales');
        Route::get('products/{product}',[AdminProductController::class, 'show'])->middleware('menu:products,flash_sales');
        Route::delete('products/{product}',[AdminProductController::class, 'destroy'])->middleware('menu:products,flash_sales');
        Route::put('products/{product}',[AdminProductController::class, 'update'])->middleware('menu:products,flash_sales');
        Route::patch('products/{product}/status', [AdminProductController::class, 'updateStatus'])->middleware('menu:products,flash_sales');

        Route::prefix('orders')->middleware('menu:orders')->group(function () {
            Route::get('/', [AdminOrderController::class, 'index']);
            Route::get('/counts', [AdminOrderController::class, 'counts']);
            Route::get('/instant', [AdminOrderController::class, 'instant']);
            Route::get('/scheduled', [AdminOrderController::class, 'scheduled']);
            Route::get('/{order}', [AdminOrderController::class, 'show']);
            Route::patch('/{order}/status', [AdminOrderController::class, 'updateStatus']);
            Route::put('/{order}/packages', [AdminOrderController::class, 'updatePackages']);
        });

        Route::prefix('flash-sale-slots')->middleware('menu:flash_sales')->group(function () {
            Route::get('/', [AdminFlashSaleSlotController::class, 'index']);
            Route::post('/', [AdminFlashSaleSlotController::class, 'store']);
            Route::put('/{flashSaleSlot}', [AdminFlashSaleSlotController::class, 'update']);
            Route::delete('/{flashSaleSlot}', [AdminFlashSaleSlotController::class, 'destroy']);
        });

        Route::post('/notifications/broadcast', [AdminNotificationController::class, 'broadcast'])->middleware('menu:notifications.broadcast');
    });
});
