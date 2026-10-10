# Graph Report - inovasionline-apps-flutter  (2026-08-30)

## Corpus Check
- 82 files · ~60,051 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 916 nodes · 1308 edges · 61 communities (56 shown, 5 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 14 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Win32Window
- authProvider
- banner_carousel.dart
- product.dart
- auth_provider.dart
- chat_thread.dart
- home_providers.dart
- AppDelegate
- home_screen.dart
- category_products_screen.dart
- search_screen.dart
- theme.dart
- store_profile_screen.dart
- router.dart
- main.dart
- product_detail_screen.dart
- auth_service.dart
- flash_sale.dart
- wWinMain
- cart.dart
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
- user.dart
- register_screen.dart
- user_summary_card.dart
- api_client.dart
- catalog_service.dart
- chat_service.dart
- complete_address_screen.dart
- region_service.dart
- product_card.dart
- banner.dart
- package:flutter_riverpod/flutter_riverpod.dart
- cart_screen.dart
- cart_providers.dart
- _PetalPatternPainter
- package:flutter/material.dart
- api_response.dart
- chat_message.dart
- chat_seller_button.dart
- login_screen.dart
- chat_screen.dart
- ApiClient

## God Nodes (most connected - your core abstractions)
1. `Win32Window` - 22 edges
2. `authProvider` - 21 edges
3. `MessageHandler` - 12 edges
4. `pendingWelcomeProvider` - 11 edges
5. `ApiClient` - 10 edges
6. `FlutterWindow` - 10 edges
7. `Create` - 10 edges
8. `WndProc` - 10 edges
9. `build` - 9 edges
10. `MessageHandler` - 9 edges

## Surprising Connections (you probably didn't know these)
- `build` --references--> `authProvider`  [EXTRACTED]
  lib/features/chat/chat_thread_screen.dart → lib/providers/auth_provider.dart
- `build` --references--> `authProvider`  [EXTRACTED]
  lib/features/home/user_summary_card.dart → lib/providers/auth_provider.dart
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  windows/runner/main.cpp → windows/runner/utils.cpp
- `Win32Window::Win32Window()` --calls--> `Destroy`  [INFERRED]
  windows/runner/win32_window.cpp → windows/runner/win32_window.h
- `build` --references--> `cartProvider`  [EXTRACTED]
  lib/features/cart/cart_screen.dart → lib/features/cart/cart_providers.dart

## Import Cycles
- None detected.

## Communities (61 total, 5 thin omitted)

### Community 0 - "Win32Window"
Cohesion: 0.06
Nodes (54): FlutterViewController, PluginRegistry, Point, RECT, Size, unique_ptr, RegisterPlugins(), DartProject (+46 more)

### Community 1 - "authProvider"
Cohesion: 0.19
Nodes (20): ConsumerState, ConsumerStatefulWidget, AccountScreen, build, CompleteAddressScreen, _CompleteAddressScreenState, _submit, LoginScreen (+12 more)

### Community 2 - "banner_carousel.dart"
Cohesion: 0.05
Nodes (47): AnimationController, AppBanner get, double?, BannerCarousel, _BannerCarouselState, _BannerPreviewDialog, _BannerPreviewDialogState, banners (+39 more)

### Community 3 - "product.dart"
Cohesion: 0.04
Nodes (45): double get, Exception, int?, ApiException, errors, firstErrorFor, message, statusCode (+37 more)

### Community 4 - "auth_provider.dart"
Cohesion: 0.11
Nodes (19): ../core/api/api_exception.dart, core_providers.dart, AuthNotifier, AuthState, AuthStatus, copyWith, error, _errorMessage (+11 more)

### Community 5 - "chat_thread.dart"
Cohesion: 0.12
Nodes (16): avatarUrl, ChatOtherUser, ChatThread, fromJson, id, isDirectMessage, isGlobal, isOfficial (+8 more)

### Community 6 - "home_providers.dart"
Cohesion: 0.13
Nodes (19): build, FlashSaleScreen, all, bannersProvider, bestSellersProvider, flashSaleProvider, foodCategory, rootCategoriesProvider (+11 more)

### Community 7 - "AppDelegate"
Cohesion: 0.11
Nodes (14): Any, Bool, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, FlutterSceneDelegate, AppDelegate (+6 more)

### Community 8 - "home_screen.dart"
Cohesion: 0.06
Nodes (32): Color, dart:math, home_providers.dart, badgeIcon, badgeLabel, banner, bannerHeight, categories (+24 more)

### Community 9 - "category_products_screen.dart"
Cohesion: 0.13
Nodes (17): build, categoryName, CategoryProductsScreen, _CategoryProductsScreenState, createState, initState, _load, _loading (+9 more)

### Community 10 - "search_screen.dart"
Cohesion: 0.13
Nodes (16): dart:async, build, _controller, createState, _debounce, dispose, _loading, _onChanged (+8 more)

### Community 11 - "theme.dart"
Cohesion: 0.12
Nodes (15): accent, AppColors, AppTheme, background, border, destructive, foreground, light (+7 more)

### Community 12 - "store_profile_screen.dart"
Cohesion: 0.06
Nodes (33): build, createState, initState, _load, _loading, _loadingMore, _loadMore, _meta (+25 more)

### Community 13 - "router.dart"
Cohesion: 0.12
Nodes (16): ../features/account/account_screen.dart, ../features/auth/complete_address_screen.dart, ../features/auth/forgot_password_screen.dart, ../features/auth/login_screen.dart, ../features/auth/register_screen.dart, ../features/cart/cart_screen.dart, ../features/categories/category_products_screen.dart, ../features/chat/chat_screen.dart (+8 more)

### Community 14 - "main.dart"
Cohesion: 0.13
Nodes (13): config/router.dart, apiBaseUrl, appBaseUrl, Env, googleServerClientId, build, InovasiOnlineApp, load (+5 more)

### Community 15 - "product_detail_screen.dart"
Cohesion: 0.14
Nodes (16): ../cart/cart_providers.dart, _adding, _addToCart, _AddToCartBar, _AddToCartBarState, build, createState, _handleAddToCart (+8 more)

### Community 16 - "auth_service.dart"
Cohesion: 0.14
Nodes (13): ../core/storage/token_storage.dart, _apiClient, AuthService, currentUser, forgotPassword, login, loginWithGoogle, logout (+5 more)

### Community 17 - "flash_sale.dart"
Cohesion: 0.12
Nodes (16): availableDates, date, endsAt, endTime, FlashSaleScheduleSlot, fromJson, id, isActive (+8 more)

### Community 18 - "wWinMain"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 19 - "cart.dart"
Cohesion: 0.08
Nodes (23): CartStoreSummary, fromJson, grandTotal, id, isEmpty, itemCount, items, lineTotal (+15 more)

### Community 20 - "core_providers.dart"
Cohesion: 0.15
Nodes (12): apiClientProvider, bannerServiceProvider, cartServiceProvider, tokenStorageProvider, ../services/auth_service.dart, ../services/banner_service.dart, ../services/cart_service.dart, ../services/catalog_service.dart (+4 more)

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
Cohesion: 0.15
Nodes (13): _ChatThreadSkeleton, _MessageBubble, _CategoryGrid, _HomeHeader, _HomeTopBackdrop, _ProductTile, _ProductDetailBody, _ProductDetailSkeleton (+5 more)

### Community 26 - "Inovasi Online — Flutter App"
Cohesion: 0.25
Nodes (7): Architecture, Auth strategy, `.env`, Inovasi Online — Flutter App, Running, Scope (Phase 1), Setup

### Community 27 - "chat_thread_screen.dart"
Cohesion: 0.11
Nodes (19): build, canPost, createState, dispose, _error, initState, isMine, _load (+11 more)

### Community 28 - "address_picker.dart"
Cohesion: 0.05
Nodes (42): EdgeInsets, code, fromJson, name, Region, regionServiceProvider, AddressPicker, _AddressPickerState (+34 more)

### Community 29 - "../core/api/api_client.dart"
Cohesion: 0.33
Nodes (5): ../core/api/api_client.dart, _apiClient, banners, BannerService, ../models/banner.dart

### Community 30 - "forgot_password_screen.dart"
Cohesion: 0.18
Nodes (12): build, createState, dispose, _emailController, ForgotPasswordScreen, _ForgotPasswordScreenState, _formKey, _loading (+4 more)

### Community 31 - "formatters.dart"
Cohesion: 0.50
Nodes (3): _currencyFormat, formatCurrency, package:intl/intl.dart

### Community 40 - "user.dart"
Cohesion: 0.12
Nodes (15): avatarUrl, cityCode, districtCode, email, emailVerifiedAt, fromJson, hasAddress, id (+7 more)

### Community 41 - "register_screen.dart"
Cohesion: 0.15
Nodes (12): _address, build, createState, dispose, _emailController, _error, _formKey, _loading (+4 more)

### Community 42 - "user_summary_card.dart"
Cohesion: 0.17
Nodes (11): IconData, build, _dummyLoyalty, icon, label, _LoyaltySummary, membershipLabel, points (+3 more)

### Community 43 - "api_client.dart"
Cohesion: 0.22
Nodes (8): api_exception.dart, ../config/env.dart, Dio, dio, _mapError, _tokenStorage, package:dio/dio.dart, ../storage/token_storage.dart

### Community 44 - "catalog_service.dart"
Cohesion: 0.15
Nodes (12): Product, _apiClient, bestSellers, CatalogService, categories, flashSale, product, _apiClient (+4 more)

### Community 45 - "chat_service.dart"
Cohesion: 0.22
Nodes (8): ../core/api/api_response.dart, _apiClient, ChatService, messages, sendMessage, startDirectMessage, threads, ../models/chat_message.dart

### Community 46 - "complete_address_screen.dart"
Cohesion: 0.25
Nodes (7): _address, build, createState, _error, _loading, AddressSelection, ../../widgets/address_picker.dart

### Community 47 - "region_service.dart"
Cohesion: 0.25
Nodes (7): _apiClient, cities, districts, provinces, RegionService, villages, ../models/region.dart

### Community 48 - "product_card.dart"
Cohesion: 0.25
Nodes (7): ../core/utils/formatters.dart, build, onTap, product, ProductCard, package:cached_network_image/cached_network_image.dart, VoidCallback

### Community 49 - "banner.dart"
Cohesion: 0.29
Nodes (6): AppBanner, fromJson, id, imageUrl, linkUrl, name

### Community 50 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.33
Nodes (5): name, type, WelcomeMessage, WelcomeType, package:flutter_riverpod/flutter_riverpod.dart

### Community 51 - "cart_screen.dart"
Cohesion: 0.15
Nodes (16): cart_providers.dart, cartProvider, build, _CartItemTile, CartScreen, _CartScreenState, createState, group (+8 more)

### Community 52 - "cart_providers.dart"
Cohesion: 0.14
Nodes (14): addItem, cart, CartNotifier, CartState, copyWith, error, load, loading (+6 more)

### Community 54 - "package:flutter/material.dart"
Cohesion: 0.14
Nodes (14): ../config/theme.dart, ../home/home_providers.dart, ../home/welcome_message.dart, build, PostsScreen, build, MainShell, navigationShell (+6 more)

### Community 55 - "api_response.dart"
Cohesion: 0.17
Nodes (11): bool get, currentPage, data, fromJson, hasMore, lastPage, meta, PaginatedMeta (+3 more)

### Community 56 - "chat_message.dart"
Cohesion: 0.18
Nodes (10): DateTime, body, ChatMessage, createdAt, fromJson, id, isOfficial, senderId (+2 more)

### Community 57 - "chat_seller_button.dart"
Cohesion: 0.25
Nodes (8): ../features/chat/chat_thread_screen.dart, build, ChatSellerButton, _ChatSellerButtonState, createState, _loading, sellerName, sellerUserId

### Community 58 - "login_screen.dart"
Cohesion: 0.22
Nodes (8): FormState, createState, dispose, _emailController, _error, _formKey, _loading, _passwordController

### Community 59 - "chat_screen.dart"
Cohesion: 0.07
Nodes (34): chat_providers.dart, chat_thread_screen.dart, ConsumerWidget, build, _StoreGroupCard, chatGlobalPreviewProvider, chatThreadsProvider, watch (+26 more)

### Community 60 - "ApiClient"
Cohesion: 0.22
Nodes (8): ApiClient, addItem, _apiClient, cart, CartService, removeItem, updateQuantity, ../models/cart.dart

## Knowledge Gaps
- **486 isolated node(s):** `XCTest`, `Env`, `apiBaseUrl`, `appBaseUrl`, `googleServerClientId` (+481 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `User` connect `user.dart` to `auth_provider.dart`?**
  _High betweenness centrality (0.027) - this node is a cross-community bridge._
- **Why does `ApiClient` connect `ApiClient` to `api_client.dart`, `catalog_service.dart`, `chat_service.dart`, `region_service.dart`, `auth_service.dart`, `core_providers.dart`, `List`, `../core/api/api_client.dart`?**
  _High betweenness centrality (0.026) - this node is a cross-community bridge._
- **What connects `XCTest`, `Env`, `apiBaseUrl` to the rest of the system?**
  _486 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Win32Window` be split into smaller, more focused modules?**
  _Cohesion score 0.05837173579109063 - nodes in this community are weakly interconnected._
- **Should `banner_carousel.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.04591836734693878 - nodes in this community are weakly interconnected._
- **Should `product.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.0425531914893617 - nodes in this community are weakly interconnected._
- **Should `auth_provider.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.10526315789473684 - nodes in this community are weakly interconnected._