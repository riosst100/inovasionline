import '../core/api/api_client.dart';

class PhoneContact {
  const PhoneContact({required this.name, required this.phone});

  final String? name;
  final String phone;

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};
}

class ContactService {
  ContactService(this._apiClient);

  final ApiClient _apiClient;

  /// The backend accepts at most this many contacts per request.
  static const _chunkSize = 500;

  /// Uploads the phone book in chunks. An empty list only links contacts
  /// already uploaded from this install to the signed-in user.
  Future<void> sync(String installId, List<PhoneContact> contacts) async {
    if (contacts.isEmpty) {
      await _post(installId, const []);
      return;
    }
    for (var i = 0; i < contacts.length; i += _chunkSize) {
      final end = i + _chunkSize < contacts.length ? i + _chunkSize : contacts.length;
      await _post(installId, contacts.sublist(i, end));
    }
  }

  Future<void> _post(String installId, List<PhoneContact> contacts) async {
    await _apiClient.dio.post(
      '/contacts/sync',
      data: {
        'install_id': installId,
        'contacts': contacts.map((c) => c.toJson()).toList(),
      },
    );
  }
}
