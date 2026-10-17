import '../core/api/api_client.dart';
import '../models/wallet.dart';

class WalletService {
  WalletService(this._apiClient);

  final ApiClient _apiClient;

  Future<WalletSummary> summary() async {
    final response = await _apiClient.dio.get('/wallet');
    return WalletSummary.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  /// Claims the one-time bonus and returns the (random) amount credited.
  Future<int> claimBonus() async {
    final response = await _apiClient.dio.post('/wallet/bonus/claim');
    final data = response.data['data'] as Map<String, dynamic>;
    return (data['claimed_amount'] as num?)?.toInt() ?? 0;
  }

  Future<List<WalletTransaction>> transactions({int perPage = 50}) async {
    final response = await _apiClient.dio.get(
      '/wallet/transactions',
      queryParameters: {'per_page': perPage},
    );
    return (response.data['data'] as List<dynamic>)
        .map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WalletTopup> createTopup(int amount) async {
    final response = await _apiClient.dio.post(
      '/wallet/topups',
      data: {'amount': amount},
    );
    return WalletTopup.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Asks the backend to re-check the top-up with Midtrans, then returns it.
  Future<WalletTopup> topupStatus(String topupId) async {
    final response = await _apiClient.dio.get('/wallet/topups/$topupId/status');
    return WalletTopup.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
