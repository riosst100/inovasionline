import '../core/utils/formatters.dart';
import 'order.dart';

class DashboardStats {
  const DashboardStats({
    required this.activeOrders,
    required this.ordersByStatus,
    required this.ordersToday,
    required this.revenueToday,
    required this.usersOnline,
    required this.usersActiveToday,
    required this.usersRegistered,
    required this.usersRegisteredToday,
    required this.installsTotal,
    required this.installsToday,
    required this.checkingOut,
    required this.cartsWithItems,
    required this.addedToCartToday,
    required this.awaitingPayment,
    required this.bestSellers,
    required this.mostViewed,
    required this.bestSellerDays,
    required this.onlineMinutes,
  });

  final int activeOrders;
  final Map<OrderStatus, int> ordersByStatus;
  final int ordersToday;
  final double revenueToday;
  final int usersOnline;
  final int usersActiveToday;
  final int usersRegistered;
  final int usersRegisteredToday;
  final int installsTotal;
  final int installsToday;
  final int checkingOut;
  final int cartsWithItems;
  final int addedToCartToday;
  final int awaitingPayment;
  final List<DashboardProduct> bestSellers;
  final List<DashboardProduct> mostViewed;
  final int bestSellerDays;
  final int onlineMinutes;

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    final orders = json['orders'] as Map<String, dynamic>;
    final users = json['users'] as Map<String, dynamic>;
    final installs = json['installs'] as Map<String, dynamic>;
    final funnel = json['funnel'] as Map<String, dynamic>;
    final byStatus = orders['by_status'] as Map<String, dynamic>;

    List<DashboardProduct> products(String key) =>
        (json[key] as List<dynamic>).map((e) => DashboardProduct.fromJson(e as Map<String, dynamic>)).toList();

    return DashboardStats(
      activeOrders: _int(orders['active']),
      ordersByStatus: {for (final s in OrderStatus.values) s: _int(byStatus[s.name])},
      ordersToday: _int(orders['today']),
      revenueToday: parseNum(orders['revenue_today']),
      usersOnline: _int(users['online']),
      usersActiveToday: _int(users['active_today']),
      usersRegistered: _int(users['registered']),
      usersRegisteredToday: _int(users['registered_today']),
      installsTotal: _int(installs['total']),
      installsToday: _int(installs['today']),
      checkingOut: _int(funnel['checking_out']),
      cartsWithItems: _int(funnel['carts_with_items']),
      addedToCartToday: _int(funnel['added_to_cart_today']),
      awaitingPayment: _int(funnel['awaiting_payment']),
      bestSellers: products('best_sellers'),
      mostViewed: products('most_viewed'),
      bestSellerDays: _int(json['best_seller_days']),
      onlineMinutes: _int(json['online_minutes']),
    );
  }
}

class DashboardProduct {
  const DashboardProduct({
    required this.id,
    required this.name,
    this.imageUrl,
    this.sold = 0,
    this.revenue = 0,
    this.views = 0,
  });

  final String id;
  final String name;
  final String? imageUrl;
  final int sold;
  final double revenue;
  final int views;

  factory DashboardProduct.fromJson(Map<String, dynamic> json) => DashboardProduct(
    id: json['id'].toString(),
    name: json['name']?.toString() ?? '-',
    imageUrl: json['image_url'] as String?,
    sold: _int(json['sold']),
    revenue: parseNum(json['revenue']),
    views: _int(json['views']),
  );
}

int _int(Object? value) => parseNum(value).toInt();
