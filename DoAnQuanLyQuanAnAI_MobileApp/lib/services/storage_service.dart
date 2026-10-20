import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doanquanlyquananai_mobileapp/core/network/api_response.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/error_handler.dart';

/// Dịch vụ chọn ảnh từ thiết bị (Thư viện / Camera) và tải thẳng lên Supabase Storage
class StorageService {
  static const String bucketName = 'restaurant-images';

  final SupabaseClient _db = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  /// Chọn ảnh từ Thư viện hoặc Camera và upload lên bucket `restaurant-images`
  /// Trả về Public URL của ảnh trên Supabase Storage (hoặc null nếu người dùng hủy chọn).
  Future<ApiResult<String?>> pickAndUploadImage({
    ImageSource source = ImageSource.gallery,
    String folder = 'menu',
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        // Người dùng đóng hộp thoại chọn ảnh
        return ApiResult.success(null);
      }

      final bytes = await pickedFile.readAsBytes();
      final ext = _extractExtension(pickedFile.name);
      final contentType = _mimeTypeFromExtension(ext);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = '$folder/$fileName';

      await _db.storage.from(bucketName).uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );

      final publicUrl = _db.storage.from(bucketName).getPublicUrl(storagePath);
      return ApiResult.success(publicUrl);
    } catch (e) {
      return ApiResult.failure(
        'Lỗi tải ảnh lên Supabase Storage (Hãy đảm bảo đã tạo bucket "$bucketName"): ${ErrorHandler.formatError(e)}',
      );
    }
  }

  String _extractExtension(String name) {
    final parts = name.split('.');
    if (parts.length > 1) {
      final ext = parts.last.toLowerCase();
      if (['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) {
        return ext;
      }
    }
    return 'jpg';
  }

  String _mimeTypeFromExtension(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }
}
