import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import 'api_client.dart';

/// Abstraction for KYC document uploads.
/// Phase 1: API → local disk (`IFileStorage` / wwwroot).
/// Later: swap to a blob-backed client without changing wizard UI.
abstract class DocumentUploadClient {
  Future<Map<String, dynamic>?> upload({
    required String documentType,
    required String fileName,
    String? filePath,
    List<int>? bytes,
  });
}

class ApiDocumentUploadClient implements DocumentUploadClient {
  ApiDocumentUploadClient(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Map<String, dynamic>?> upload({
    required String documentType,
    required String fileName,
    String? filePath,
    List<int>? bytes,
  }) async {
    final MultipartFile part;
    if (bytes != null) {
      part = MultipartFile.fromBytes(bytes, filename: fileName);
    } else if (filePath != null && filePath.isNotEmpty) {
      part = await MultipartFile.fromFile(filePath, filename: fileName);
    } else {
      throw ApiException(message: 'ไม่พบไฟล์เอกสาร', statusCode: 400);
    }

    final formData = FormData.fromMap({
      'documentType': documentType,
      'file': part,
    });

    final response = await _apiClient.post(
      '${AppConstants.staffApiPrefix}/documents',
      data: formData,
    );

    final raw = response.data;
    if (raw is Map) {
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      final data = map['data'];
      if (data is Map) {
        return data.map((k, v) => MapEntry(k.toString(), v));
      }
      return map;
    }
    return null;
  }
}
