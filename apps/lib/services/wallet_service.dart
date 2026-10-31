import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
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

  /// [claimBonus] right after a rewarded ad: AdMob confirms the view to the
  /// backend a few seconds after the ad closes, and until then the claim is
  /// answered with 409, so keep retrying for a while.
  Future<int> claimBonusAfterAd() async {
    const attempts = 8;
    for (var i = 1; ; i++) {
      try {
        return await claimBonus();
      } on DioException catch (e) {
        final error = e.error;
        final pending = error is ApiException && error.statusCode == 409;
        if (!pending || i == attempts) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 2500));
      }
    }
  }

  /// Debug builds only: Google's sample ads never call the backend, so this
  /// records the view instead (the backend refuses it in production).
  Future<void> recordTestAdView() => _apiClient.dio.post('/wallet/bonus/test-ad-view');

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
