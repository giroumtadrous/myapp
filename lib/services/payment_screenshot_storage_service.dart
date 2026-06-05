import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Uploads InstaPay payment proof images to Firebase Storage.
class PaymentScreenshotStorageService {
  PaymentScreenshotStorageService._();

  static final PaymentScreenshotStorageService instance =
      PaymentScreenshotStorageService._();

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<XFile?> pickFromGallery() {
    return _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2048,
    );
  }

  Future<XFile?> pickFromCamera() {
    return _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 2048,
    );
  }

  Future<String> uploadPaymentScreenshot({
    required XFile image,
    required String userId,
    required String sessionId,
  }) async {
    final extension = _extensionForPath(image.path, image.name);
    final contentType = _contentTypeForExtension(extension);
    final objectPath =
        'payment_screenshots/$userId/${sessionId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ref = _storage.ref(objectPath);
    final metadata = SettableMetadata(contentType: contentType);

    final bytes = await image.readAsBytes();
    await ref.putData(bytes, metadata);

    return ref.getDownloadURL();
  }

  String _extensionForPath(String path, String name) {
    final source = name.isNotEmpty ? name : path;
    final dotIndex = source.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == source.length - 1) {
      return 'jpg';
    }
    final ext = source.substring(dotIndex + 1).toLowerCase();
    if (ext == 'jpeg' || ext == 'jpg' || ext == 'png' || ext == 'webp') {
      return ext == 'jpeg' ? 'jpg' : ext;
    }
    return 'jpg';
  }

  String _contentTypeForExtension(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
