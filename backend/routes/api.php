<?php

use App\Http\Controllers\Api\V1\Admin\BannerController as AdminBannerController;
use App\Http\Controllers\Api\V1\Admin\CategoryController as AdminCategoryController;
use App\Http\Controllers\Api\V1\Admin\FlashSaleSlotController as AdminFlashSaleSlotController;
use App\Http\Controllers\Api\V1\Admin\NotificationController as AdminNotificationController;
use App\Http\Controllers\Api\V1\Admin\OrderController as AdminOrderController;
use App\Http\Controllers\Api\V1\Admin\PaymentMethodController as AdminPaymentMethodController;
use App\Http\Controllers\Api\V1\Admin\PhotographerApplicationController as AdminPhotographerApplicationController;
use App\Http\Controllers\Api\V1\Admin\SellerApplicationController as AdminSellerApplicationController;
use App\Http\Controllers\Api\V1\Admin\ShippingMethodController as AdminShippingMethodController;
use App\Http\Controllers\Api\V1\Admin\ShippingRateTemplateController as AdminShippingRateTemplateController;
use App\Http\Controllers\Api\V1\Admin\ShippingRateTemplateRowController as AdminShippingRateTemplateRowController;
use App\Http\Controllers\Api\V1\Admin\UserController as AdminUserController;
use App\Http\Controllers\Api\V1\Admin\UserVerificationController as AdminUserVerificationController;
use App\Http\Controllers\Api\V1\AppVersionController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\BannerController;
use App\Http\Controllers\Api\V1\CartController;
use App\Http\Controllers\Api\V1\CategoryController;
use App\Http\Controllers\Api\V1\ChatController;
use App\Http\Controllers\Api\V1\CheckoutController;
use App\Http\Controllers\Api\V1\DeviceTokenController;
use App\Http\Controllers\Api\V1\FaceProfileController;
use App\Http\Controllers\Api\V1\FlashSaleSlotController;
use App\Http\Controllers\Api\V1\MatchedPhotoController;
use App\Http\Controllers\Api\V1\OrderController;
use App\Http\Controllers\Api\V1\Photographer\PhotoController as PhotographerPhotoController;
use App\Http\Controllers\Api\V1\Photographer\PhotoEventController as PhotographerPhotoEventController;
use App\Http\Controllers\Api\V1\PhotographerApplicationController;
use App\Http\Controllers\Api\V1\PhotoController;
use App\Http\Controllers\Api\V1\PhotoPurchaseController;
use App\Http\Controllers\Api\V1\PostController;
use App\Http\Controllers\Api\V1\PublicProductController;
use App\Http\Controllers\Api\V1\PublicStoreController;
use App\Http\Controllers\Api\V1\RegionController;
use App\Http\Controllers\Api\V1\SearchController;
use App\Http\Controllers\Api\V1\Seller\CategoryController as SellerCategoryController;
use App\Http\Controllers\Api\V1\Seller\OrderController as SellerOrderController;
use App\Http\Controllers\Api\V1\Seller\PaymentMethodController as SellerPaymentMethodController;
use App\Http\Controllers\Api\V1\Seller\ProductController as SellerProductController;
use App\Http\Controllers\Api\V1\Seller\PromotionController as SellerPromotionController;
use App\Http\Controllers\Api\V1\Seller\ShippingMethodController as SellerShippingMethodController;
use App\Http\Controllers\Api\V1\Seller\ShippingMethodRateController as SellerShippingMethodRateController;
use App\Http\Controllers\Api\V1\Seller\ShippingRateTemplateReadController as SellerShippingRateTemplateReadController;
use App\Http\Controllers\Api\V1\SellerApplicationController;
use App\Http\Controllers\Api\V1\UserVerificationController;
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
        });
    });

    Route::middleware('auth:sanctum')->group(function () {
        Route::prefix('seller-applications')->group(function () {
            Route::post('/', [SellerApplicationController::class, 'store']);
            Route::get('/me', [SellerApplicationController::class, 'show']);
        });

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

    Route::get('/app-version/latest', [AppVersionController::class, 'latest']);

    Route::prefix('products')->group(function () {
        Route::get('/flash-sale', [PublicProductController::class, 'flashSale']);
        Route::get('/best-sellers', [PublicProductController::class, 'bestSellers']);
        Route::get('/{product:slug}', [PublicProductController::class, 'show']);
    });

    Route::get('/stores', [PublicStoreController::class, 'index']);
    Route::get('/stores/{slug}', [PublicStoreController::class, 'show']);
    Route::get('/stores/{store}/payment-methods', [PublicStoreController::class, 'paymentMethods']);
    Route::get('/stores/{store}/shipping-methods', [PublicStoreController::class, 'shippingMethods']);

    Route::prefix('search')->group(function () {
        Route::get('/', [SearchController::class, 'index']);
        Route::get('/suggestions', [SearchController::class, 'suggestions']);
        Route::get('/popular', [SearchController::class, 'popular']);
        Route::post('/click', [SearchController::class, 'click']);
    });

    Route::prefix('regions')->group(function () {
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

        Route::middleware('auth:sanctum')->group(function () {
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

        Route::middleware('auth:sanctum')->group(function () {
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

    Route::prefix('cart')->middleware('auth:sanctum')->group(function () {
        Route::get('/', [CartController::class, 'index']);
        Route::post('/items', [CartController::class, 'store']);
        Route::patch('/items/{cartItem}', [CartController::class, 'update']);
        Route::delete('/items/{cartItem}', [CartController::class, 'destroy']);
    });

    Route::prefix('checkout')->middleware('auth:sanctum')->group(function () {
        Route::post('/', [CheckoutController::class, 'store']);
    });

    Route::prefix('orders')->middleware('auth:sanctum')->group(function () {
        Route::get('/', [OrderController::class, 'index']);
        Route::get('/{order}', [OrderController::class, 'show']);
        Route::post('/{order}/cancel', [OrderController::class, 'cancel']);
    });

    Route::prefix('seller')->middleware(['auth:sanctum', 'seller', 'store.owner'])->group(function () {
        Route::prefix('products')->group(function () {
            Route::get('/', [SellerProductController::class, 'index']);
            Route::post('/', [SellerProductController::class, 'store']);
            Route::get('/export', [SellerProductController::class, 'export']);
            Route::post('/import', [SellerProductController::class, 'import']);
            Route::get('/{product}', [SellerProductController::class, 'show']);
            Route::post('/{product}', [SellerProductController::class, 'update']);
        });

        Route::prefix('promotions')->group(function () {
            Route::get('/', [SellerPromotionController::class, 'index']);
            Route::post('/', [SellerPromotionController::class, 'store']);
        });

        Route::prefix('categories')->group(function () {
            Route::get('/', [SellerCategoryController::class, 'index']);
            Route::post('/', [SellerCategoryController::class, 'store']);
        });

        Route::prefix('payment-methods')->group(function () {
            Route::get('/', [SellerPaymentMethodController::class, 'index']);
            Route::post('/', [SellerPaymentMethodController::class, 'store']);
            Route::put('/{paymentMethod}', [SellerPaymentMethodController::class, 'update']);
            Route::delete('/{paymentMethod}', [SellerPaymentMethodController::class, 'destroy']);
        });

        Route::prefix('shipping-methods')->group(function () {
            Route::get('/', [SellerShippingMethodController::class, 'index']);
            Route::post('/', [SellerShippingMethodController::class, 'store']);
            Route::put('/{shippingMethod}', [SellerShippingMethodController::class, 'update']);
            Route::delete('/{shippingMethod}', [SellerShippingMethodController::class, 'destroy']);

            Route::prefix('{shippingMethod}/rates')->group(function () {
                Route::get('/', [SellerShippingMethodRateController::class, 'index']);
                Route::post('/', [SellerShippingMethodRateController::class, 'store']);
                Route::put('/{rate}', [SellerShippingMethodRateController::class, 'update']);
                Route::delete('/{rate}', [SellerShippingMethodRateController::class, 'destroy']);
                Route::get('/export', [SellerShippingMethodRateController::class, 'export']);
                Route::post('/import', [SellerShippingMethodRateController::class, 'import']);
                Route::post('/copy-template', [SellerShippingMethodRateController::class, 'copyFromTemplate']);
            });
        });

        Route::get('/shipping-rate-templates', [SellerShippingRateTemplateReadController::class, 'index']);

        Route::prefix('orders')->group(function () {
            Route::get('/', [SellerOrderController::class, 'index']);
            Route::get('/{order}', [SellerOrderController::class, 'show']);
            Route::post('/{order}/status', [SellerOrderController::class, 'updateStatus']);
            Route::post('/{order}/mark-paid', [SellerOrderController::class, 'markAsPaid']);
        });
    });

    Route::prefix('photographer')->middleware(['auth:sanctum', 'photographer'])->group(function () {
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
        Route::get('/users', [AdminUserController::class, 'index']);

        Route::prefix('seller-applications')->group(function () {
            Route::get('/', [AdminSellerApplicationController::class, 'index']);
            Route::post('/{sellerApplication}/approve', [AdminSellerApplicationController::class, 'approve']);
            Route::post('/{sellerApplication}/reject', [AdminSellerApplicationController::class, 'reject']);
        });

        Route::prefix('photographer-applications')->group(function () {
            Route::get('/', [AdminPhotographerApplicationController::class, 'index']);
            Route::post('/{photographerApplication}/approve', [AdminPhotographerApplicationController::class, 'approve']);
            Route::post('/{photographerApplication}/reject', [AdminPhotographerApplicationController::class, 'reject']);
        });

        Route::prefix('verifications')->group(function () {
            Route::get('/', [AdminUserVerificationController::class, 'index']);
            Route::post('/{userVerification}/approve', [AdminUserVerificationController::class, 'approve']);
            Route::post('/{userVerification}/reject', [AdminUserVerificationController::class, 'reject']);
        });

        Route::prefix('flash-sale-slots')->group(function () {
            Route::get('/', [AdminFlashSaleSlotController::class, 'index']);
            Route::post('/', [AdminFlashSaleSlotController::class, 'store']);
            Route::put('/{flashSaleSlot}', [AdminFlashSaleSlotController::class, 'update']);
            Route::delete('/{flashSaleSlot}', [AdminFlashSaleSlotController::class, 'destroy']);
        });

        Route::prefix('banners')->group(function () {
            Route::get('/', [AdminBannerController::class, 'index']);
            Route::post('/', [AdminBannerController::class, 'store']);
            Route::post('/reorder', [AdminBannerController::class, 'reorder']);
            Route::post('/{banner}', [AdminBannerController::class, 'update']);
            Route::delete('/{banner}', [AdminBannerController::class, 'destroy']);
        });

        Route::prefix('categories')->group(function () {
            Route::get('/', [AdminCategoryController::class, 'index']);
            Route::post('/', [AdminCategoryController::class, 'store']);
            Route::put('/{category}', [AdminCategoryController::class, 'update']);
            Route::post('/{category}/approve', [AdminCategoryController::class, 'approve']);
        });

        Route::post('/notifications/broadcast', [AdminNotificationController::class, 'broadcast']);

        Route::prefix('orders')->group(function () {
            Route::get('/', [AdminOrderController::class, 'index']);
            Route::get('/{order}', [AdminOrderController::class, 'show']);
        });

        Route::prefix('payment-methods')->group(function () {
            Route::get('/', [AdminPaymentMethodController::class, 'index']);
            Route::post('/{paymentMethod}/toggle', [AdminPaymentMethodController::class, 'toggle']);
        });

        Route::prefix('shipping-methods')->group(function () {
            Route::get('/', [AdminShippingMethodController::class, 'index']);
            Route::post('/{shippingMethod}/toggle', [AdminShippingMethodController::class, 'toggle']);
        });

        Route::prefix('shipping-rate-templates')->group(function () {
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
