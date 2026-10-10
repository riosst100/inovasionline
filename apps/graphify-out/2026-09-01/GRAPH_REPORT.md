# Graph Report - inovasionline-apps-flutter  (2026-09-01)

## Corpus Check
- 100 files · ~56,046 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1318 nodes · 1954 edges · 86 communities (81 shown, 5 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 14 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `32f98d70`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Win32Window
- package:go_router/go_router.dart
- banner_carousel.dart
- product.dart
- auth_provider.dart
- chat_thread.dart
- post.dart
- AppDelegate
- home_screen.dart
- category_products_screen.dart
- product_tag_picker_sheet.dart
- theme.dart
- store_profile_screen.dart
- router.dart
- env.dart
- product_detail_screen.dart
- auth_service.dart
- flash_sale.dart
- wWinMain
- cart_screen.dart
- core_providers.dart
- manifest.json
- token_storage.dart
- category.dart
- List
- StatelessWidget
- Inovasi Online — Flutter App
- chat_thread_screen.dart
- address_picker.dart
- ../core/api/api_client.dart
- forgot_password_screen.dart
- formatters.dart
- MainActivity.kt
- widget_test.dart
- LaunchImage.imageset/README.md
- String?
- realtime_chat_service.dart
- register_screen.dart
- user_summary_card.dart
- api_client.dart
- catalog_service.dart
- post_providers.dart
- feedProvider
- region_service.dart
- product_card.dart
- banner.dart
- ConsumerState
- order.dart
- cart_providers.dart
- _PetalPatternPainter
- package:flutter/material.dart
- api_response.dart
- chat_message.dart
- package:flutter_riverpod/flutter_riverpod.dart
- create_post_screen.dart
- chat_screen.dart
- cart_service.dart
- checkout_screen.dart
- posts_screen.dart
- checkout_providers.dart
- checkout_service.dart
- order_detail_screen.dart
- payment_method.dart
- order_providers.dart
- order_list_screen.dart
- complete_address_screen.dart
- shipping_method.dart
- edit_profile_screen.dart
- authProvider
- post_comments_sheet.dart
- user.dart
- api_exception.dart
- package:cached_network_image/cached_network_image.dart
- _CheckoutScreenState
- home_providers.dart
- build
- chat_service.dart
- ConsumerWidget
- ../../widgets/skeleton.dart
- ApiClient
- _ProductDetailScreenState
- build

## God Nodes (most connected - your core abstractions)
1. `authProvider` - 37 edges
2. `Win32Window` - 22 edges
3. `ApiClient` - 14 edges
4. `feedProvider` - 13 edges
5. `MessageHandler` - 12 edges
6. `pendingWelcomeProvider` - 11 edges
7. `FlutterWindow` - 10 edges
8. `Create` - 10 edges
9. `WndProc` - 10 edges
10. `cartProvider` - 9 edges

## Surprising Connections (you probably didn't know these)
- `initState` --references--> `authProvider`  [EXTRACTED]
  lib/features/account/edit_profile_screen.dart → lib/providers/auth_provider.dart
- `_submit` --references--> `authProvider`  [EXTRACTED]
  lib/features/account/edit_profile_screen.dart → lib/providers/auth_provider.dart
- `build` --references--> `authProvider`  [EXTRACTED]
  lib/features/account/edit_profile_screen.dart → lib/providers/auth_provider.dart
- `_onRealtimeMessage` --references--> `authProvider`  [EXTRACTED]
  lib/features/chat/chat_thread_screen.dart → lib/providers/auth_provider.dart
- `build` --references--> `authProvider`  [EXTRACTED]
  lib/features/chat/chat_thread_screen.dart → lib/providers/auth_provider.dart

## Import Cycles
- None detected.

## Communities (86 total, 5 thin omitted)

### Community 0 - "Win32Window"
Cohesion: 0.06
Nodes (54): FlutterViewController, PluginRegistry, Point, RECT, Size, unique_ptr, RegisterPlugins(), DartProject (+46 more)

### Community 1 - "package:go_router/go_router.dart"
Cohesion: 0.18
Nodes (11): edit_profile_screen.dart, ../home/welcome_message.dart, createState, dispose, _emailController, _error, _formKey, _loading (+3 more)

### Community 2 - "banner_carousel.dart"
Cohesion: 0.05
Nodes (47): AnimationController, AppBanner get, double?, BannerCarousel, _BannerCarouselState, _BannerPreviewDialog, _BannerPreviewDialogState, banners (+39 more)

### Community 3 - "product.dart"
Cohesion: 0.06
Nodes (35): category, city, createdAt, deliveryAvailable, description, discountPercent, displayPrice, fromJson (+27 more)

### Community 4 - "auth_provider.dart"
Cohesion: 0.11
Nodes (18): core_providers.dart, AuthNotifier, AuthState, AuthStatus, copyWith, error, _errorMessage, login (+10 more)

### Community 5 - "chat_thread.dart"
Cohesion: 0.12
Nodes (16): avatarUrl, ChatOtherUser, ChatThread, fromJson, id, isDirectMessage, isGlobal, isOfficial (+8 more)

### Community 6 - "post.dart"
Cohesion: 0.05
Nodes (41): body, commentCount, copyWith, createdAt, displayPrice, fromJson, id, imageUrl (+33 more)

### Community 7 - "AppDelegate"
Cohesion: 0.11
Nodes (14): Any, Bool, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, FlutterSceneDelegate, AppDelegate (+6 more)

### Community 8 - "home_screen.dart"
Cohesion: 0.06
Nodes (31): dart:math, home_providers.dart, badgeIcon, badgeLabel, banner, bannerHeight, categories, child (+23 more)

### Community 9 - "category_products_screen.dart"
Cohesion: 0.13
Nodes (17): build, categoryName, CategoryProductsScreen, _CategoryProductsScreenState, createState, initState, _load, _loading (+9 more)

### Community 10 - "product_tag_picker_sheet.dart"
Cohesion: 0.07
Nodes (30): dart:async, build, createState, _debounce, dispose, initiallySelected, _loading, _onQueryChanged (+22 more)

### Community 11 - "theme.dart"
Cohesion: 0.12
Nodes (15): accent, AppColors, AppTheme, background, border, destructive, foreground, light (+7 more)

### Community 12 - "store_profile_screen.dart"
Cohesion: 0.06
Nodes (35): build, createState, initState, _load, _loading, _loadingMore, _loadMore, _meta (+27 more)

### Community 13 - "router.dart"
Cohesion: 0.10
Nodes (19): ../features/account/account_screen.dart, ../features/auth/complete_address_screen.dart, ../features/auth/forgot_password_screen.dart, ../features/auth/login_screen.dart, ../features/auth/register_screen.dart, ../features/cart/cart_screen.dart, ../features/categories/category_products_screen.dart, ../features/chat/chat_screen.dart (+11 more)

### Community 14 - "env.dart"
Cohesion: 0.18
Nodes (10): apiBaseUrl, appBaseUrl, Env, googleServerClientId, reverbAppKey, reverbHost, reverbPort, reverbScheme (+2 more)

### Community 15 - "product_detail_screen.dart"
Cohesion: 0.11
Nodes (18): Animation, ../cart/cart_providers.dart, _adding, _addToCart, _cartBeatController, _cartBeatScale, createState, dispose (+10 more)

### Community 16 - "auth_service.dart"
Cohesion: 0.14
Nodes (13): ../core/storage/token_storage.dart, dart:io, _apiClient, AuthService, currentUser, forgotPassword, login, loginWithGoogle (+5 more)

### Community 17 - "flash_sale.dart"
Cohesion: 0.12
Nodes (16): availableDates, date, endsAt, endTime, FlashSaleScheduleSlot, fromJson, id, isActive (+8 more)

### Community 18 - "wWinMain"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 19 - "cart_screen.dart"
Cohesion: 0.05
Nodes (46): cart_providers.dart, cartProvider, build, _CartItemTile, CartScreen, _CartScreenState, createState, group (+38 more)

### Community 20 - "core_providers.dart"
Cohesion: 0.11
Nodes (18): apiClientProvider, bannerServiceProvider, cartServiceProvider, checkoutServiceProvider, orderServiceProvider, tokenStorageProvider, ../services/auth_service.dart, ../services/banner_service.dart (+10 more)

### Community 21 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 22 - "token_storage.dart"
Cohesion: 0.20
Nodes (9): FlutterSecureStorage, clearToken, readToken, saveToken, _storage, _tokenKey, TokenStorage, package:flutter_secure_storage/flutter_secure_storage.dart (+1 more)

### Community 23 - "category.dart"
Cohesion: 0.18
Nodes (10): Category, copyWith, description, fromJson, icon, id, isActive, name (+2 more)

### Community 24 - "List"
Cohesion: 0.22
Nodes (8): _apiClient, products, search, SearchResult, SearchService, stores, suggestions, List

### Community 25 - "StatelessWidget"
Cohesion: 0.13
Nodes (15): _PaymentMethodPickerSheet, _PickerRow, _SectionCard, _ShippingMethodPickerSheet, _CategoryGrid, _HomeHeader, _HomeTopBackdrop, _ProductTile (+7 more)

### Community 26 - "Inovasi Online — Flutter App"
Cohesion: 0.25
Nodes (7): Architecture, Auth strategy, `.env`, Inovasi Online — Flutter App, Running, Scope (Phase 1), Setup

### Community 27 - "chat_thread_screen.dart"
Cohesion: 0.10
Nodes (23): build, canPost, ChatThreadScreen, _ChatThreadScreenState, _ChatThreadSkeleton, createState, dispose, _error (+15 more)

### Community 28 - "address_picker.dart"
Cohesion: 0.05
Nodes (43): EdgeInsets, code, fromJson, name, Region, regionServiceProvider, AddressPicker, _AddressPickerState (+35 more)

### Community 29 - "../core/api/api_client.dart"
Cohesion: 0.29
Nodes (6): ../core/api/api_client.dart, _apiClient, cancel, myOrders, orderDetail, OrderService

### Community 30 - "forgot_password_screen.dart"
Cohesion: 0.16
Nodes (13): FormState, build, createState, dispose, _emailController, ForgotPasswordScreen, _ForgotPasswordScreenState, _formKey (+5 more)

### Community 31 - "formatters.dart"
Cohesion: 0.33
Nodes (5): _currencyFormat, diff, formatCurrency, formatRelativeTime, package:intl/intl.dart

### Community 40 - "realtime_chat_service.dart"
Cohesion: 0.09
Nodes (22): dart:convert, _apiClient, _authorize, _channel, ChatMessageHandler, _connecting, _ensureConnected, _handlers (+14 more)

### Community 41 - "register_screen.dart"
Cohesion: 0.15
Nodes (12): _address, build, createState, dispose, _emailController, _error, _formKey, _loading (+4 more)

### Community 42 - "user_summary_card.dart"
Cohesion: 0.15
Nodes (12): IconData, build, _dummyLoyalty, icon, label, _LoyaltySummary, membershipLabel, points (+4 more)

### Community 43 - "api_client.dart"
Cohesion: 0.22
Nodes (8): api_exception.dart, ../config/env.dart, Dio, dio, _mapError, _tokenStorage, package:dio/dio.dart, ../storage/token_storage.dart

### Community 44 - "catalog_service.dart"
Cohesion: 0.15
Nodes (13): ../core/api/api_response.dart, Product, _apiClient, bestSellers, CatalogService, categories, flashSale, product (+5 more)

### Community 45 - "post_providers.dart"
Cohesion: 0.10
Nodes (21): copyWith, createPost, deletePost, error, _errorMessage, fallback, FeedNotifier, FeedState (+13 more)

### Community 46 - "feedProvider"
Cohesion: 0.20
Nodes (11): _submit, feedProvider, build, _confirmDelete, initState, _onScroll, _PostCard, _share (+3 more)

### Community 47 - "region_service.dart"
Cohesion: 0.25
Nodes (7): _apiClient, cities, districts, provinces, RegionService, villages, ../models/region.dart

### Community 48 - "product_card.dart"
Cohesion: 0.29
Nodes (6): ../core/utils/formatters.dart, build, onTap, product, ProductCard, VoidCallback

### Community 49 - "banner.dart"
Cohesion: 0.29
Nodes (6): AppBanner, fromJson, id, imageUrl, linkUrl, name

### Community 50 - "ConsumerState"
Cohesion: 0.21
Nodes (12): ConsumerState, ConsumerStatefulWidget, EditProfileScreen, _EditProfileScreenState, LoginScreen, RegisterScreen, PostCommentsSheet, _PostCommentsSheetState (+4 more)

### Community 51 - "order.dart"
Cohesion: 0.05
Nodes (42): at, by, createdAt, customerNotes, deliveryAddress, deliveryMethod, discountAmount, discountTotal (+34 more)

### Community 52 - "cart_providers.dart"
Cohesion: 0.13
Nodes (15): addItem, cart, CartNotifier, CartState, copyWith, error, _errorMessage, fallback (+7 more)

### Community 54 - "package:flutter/material.dart"
Cohesion: 0.14
Nodes (14): config/router.dart, ../config/theme.dart, build, navigationShell, build, InovasiOnlineApp, load, main (+6 more)

### Community 55 - "api_response.dart"
Cohesion: 0.17
Nodes (11): bool get, currentPage, data, fromJson, hasMore, lastPage, meta, PaginatedMeta (+3 more)

### Community 56 - "chat_message.dart"
Cohesion: 0.18
Nodes (10): DateTime?, body, ChatMessage, createdAt, fromJson, id, isOfficial, senderId (+2 more)

### Community 57 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.11
Nodes (17): ../features/chat/chat_thread_screen.dart, watch, name, type, WelcomeMessage, WelcomeType, build, ChatSellerButton (+9 more)

### Community 58 - "create_post_screen.dart"
Cohesion: 0.12
Nodes (17): _bodyController, build, _canSubmit, CreatePostScreen, _CreatePostScreenState, createState, dispose, _error (+9 more)

### Community 59 - "chat_screen.dart"
Cohesion: 0.14
Nodes (15): chat_providers.dart, chat_thread_screen.dart, chatGlobalPreviewProvider, chatThreadsProvider, build, _ChatListCard, _ChatThreadListView, emptyText (+7 more)

### Community 60 - "cart_service.dart"
Cohesion: 0.25
Nodes (7): addItem, _apiClient, cart, CartService, removeItem, updateQuantity, ../models/cart.dart

### Community 61 - "checkout_screen.dart"
Cohesion: 0.10
Nodes (20): checkout_providers.dart, _address, _addressDetailController, _canSubmit, child, createState, dispose, group (+12 more)

### Community 62 - "posts_screen.dart"
Cohesion: 0.13
Nodes (14): Color, create_post_screen.dart, color, createState, dispose, icon, label, media (+6 more)

### Community 63 - "checkout_providers.dart"
Cohesion: 0.15
Nodes (13): CheckoutNotifier, CheckoutState, copyWith, error, _errorMessage, fallback, order, _ref (+5 more)

### Community 64 - "checkout_service.dart"
Cohesion: 0.22
Nodes (8): _apiClient, checkout, CheckoutService, paymentMethods, shippingMethods, ../models/order.dart, ../models/payment_method.dart, ../models/shipping_method.dart

### Community 65 - "order_detail_screen.dart"
Cohesion: 0.15
Nodes (15): amount, bold, build, child, _confirmCancel, label, OrderDetailScreen, orderId (+7 more)

### Community 66 - "payment_method.dart"
Cohesion: 0.14
Nodes (13): accountHolderName, accountNumber, bankName, description, fromJson, id, instructions, isEnabled (+5 more)

### Community 67 - "order_providers.dart"
Cohesion: 0.18
Nodes (11): ../core/api/api_exception.dart, cancel, cancelling, error, _errorMessage, fallback, OrderCancelNotifier, OrderCancelState (+3 more)

### Community 68 - "order_list_screen.dart"
Cohesion: 0.18
Nodes (11): build, _color, _labels, order, OrderListScreen, _OrderTile, status, _StatusBadge (+3 more)

### Community 69 - "complete_address_screen.dart"
Cohesion: 0.22
Nodes (9): _address, build, CompleteAddressScreen, _CompleteAddressScreenState, createState, _error, _loading, AddressSelection (+1 more)

### Community 70 - "shipping_method.dart"
Cohesion: 0.10
Nodes (20): double get, baseFee, description, displayFee, estimatedDeliveryTime, freeShippingMinAmount, fromJson, id (+12 more)

### Community 71 - "edit_profile_screen.dart"
Cohesion: 0.11
Nodes (17): File?, build, createState, _croppedAvatar, dispose, _error, _formKey, initState (+9 more)

### Community 72 - "authProvider"
Cohesion: 0.24
Nodes (16): AccountScreen, build, _submit, _LoginScreenState, _submit, _submitGoogle, _RegisterScreenState, _submit (+8 more)

### Community 73 - "post_comments_sheet.dart"
Cohesion: 0.13
Nodes (15): build, comment, _comments, _CommentTile, _controller, createState, dispose, initState (+7 more)

### Community 74 - "user.dart"
Cohesion: 0.12
Nodes (15): avatarUrl, cityCode, districtCode, email, emailVerifiedAt, fromJson, hasAddress, id (+7 more)

### Community 75 - "api_exception.dart"
Cohesion: 0.20
Nodes (9): Exception, int?, ApiException, errors, firstErrorFor, message, statusCode, toString (+1 more)

### Community 76 - "package:cached_network_image/cached_network_image.dart"
Cohesion: 0.47
Nodes (5): build, storesProvider, StoresScreen, watch, package:cached_network_image/cached_network_image.dart

### Community 77 - "_CheckoutScreenState"
Cohesion: 0.22
Nodes (9): checkoutProvider, checkoutStorePaymentMethodsProvider, checkoutStoreShippingMethodsProvider, build, CheckoutScreen, _CheckoutScreenState, _pickPaymentMethod, _pickShippingMethod (+1 more)

### Community 78 - "home_providers.dart"
Cohesion: 0.25
Nodes (7): all, foodCategory, watch, FlashSaleSchedule, ../models/category.dart, ../models/flash_sale.dart, return

### Community 79 - "build"
Cohesion: 0.32
Nodes (8): bannersProvider, bestSellersProvider, rootCategoriesProvider, build, HomeScreen, _HomeScreenState, Route /flash-sale, Route /search

### Community 80 - "chat_service.dart"
Cohesion: 0.25
Nodes (7): _apiClient, ChatService, messages, sendMessage, startDirectMessage, threads, ../models/chat_thread.dart

### Community 81 - "ConsumerWidget"
Cohesion: 0.29
Nodes (7): ConsumerWidget, _StoreGroupCard, ChatScreen, _GuestGlobalPreviewView, _ThreadList, UserSummaryCard, MainShell

### Community 82 - "../../widgets/skeleton.dart"
Cohesion: 0.33
Nodes (6): ../home/home_providers.dart, build, FlashSaleScreen, flashSaleProvider, ../../widgets/product_grid.dart, ../../widgets/skeleton.dart

### Community 83 - "ApiClient"
Cohesion: 0.33
Nodes (5): ApiClient, _apiClient, banners, BannerService, ../models/banner.dart

### Community 84 - "_ProductDetailScreenState"
Cohesion: 0.40
Nodes (5): build, productDetailProvider, ProductDetailScreen, _ProductDetailScreenState, Route /cart

### Community 85 - "build"
Cohesion: 0.67
Nodes (3): build, Route /forgot-password, Route /register

## Knowledge Gaps
- **755 isolated node(s):** `XCTest`, `Env`, `apiBaseUrl`, `appBaseUrl`, `googleServerClientId` (+750 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `PaymentMethod` connect `payment_method.dart` to `order.dart`, `checkout_screen.dart`?**
  _High betweenness centrality (0.019) - this node is a cross-community bridge._
- **Why does `ApiClient` connect `ApiClient` to `checkout_service.dart`, `post.dart`, `realtime_chat_service.dart`, `api_client.dart`, `catalog_service.dart`, `region_service.dart`, `auth_service.dart`, `chat_service.dart`, `core_providers.dart`, `List`, `cart_service.dart`, `../core/api/api_client.dart`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._
- **What connects `XCTest`, `Env`, `apiBaseUrl` to the rest of the system?**
  _755 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Win32Window` be split into smaller, more focused modules?**
  _Cohesion score 0.05837173579109063 - nodes in this community are weakly interconnected._
- **Should `banner_carousel.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.04591836734693878 - nodes in this community are weakly interconnected._
- **Should `product.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.05555555555555555 - nodes in this community are weakly interconnected._
- **Should `auth_provider.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.1111111111111111 - nodes in this community are weakly interconnected._