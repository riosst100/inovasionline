import '../core/api/api_client.dart';
import '../models/bank_account.dart';

class BankAccountService {
  BankAccountService(this._api);

  final ApiClient _api;

  Future<List<BankAccount>> list() async {
    final res = await _api.dio.get('/admin/bank-accounts');
    return (res.data['data'] as List).map((e) => BankAccount.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<BankAccount> save(BankAccountInput input, {String? id}) async {
    final res = id == null
        ? await _api.dio.post('/admin/bank-accounts', data: input.toJson())
        : await _api.dio.put('/admin/bank-accounts/$id', data: input.toJson());
    return BankAccount.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<BankAccount> toggle(String id) async {
    final res = await _api.dio.post('/admin/bank-accounts/$id/toggle');
    return BankAccount.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _api.dio.delete('/admin/bank-accounts/$id');
}

