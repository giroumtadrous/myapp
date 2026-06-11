import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePhotoStorageService {
  ProfilePhotoStorageService._();

  static final ProfilePhotoStorageService instance =
      ProfilePhotoStorageService._();

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<XFile?> pickImage(ImageSource source) {
    return _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
    );
  }

  Future<String> uploadProfilePhoto({
    required XFile image,
    required String userId,
    required String pathPrefix,
  }) async {
    final extension = _extensionForPath(image.path, image.name);
    final contentType = _contentTypeForExtension(extension);
    final objectPath =
        '$pathPrefix/$userId/profile_photo_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ref = _storage.ref(objectPath);
    final metadata = SettableMetadata(contentType: contentType);

    if (kIsWeb) {
      final bytes = await image.readAsBytes();
      await ref.putData(bytes, metadata);
    } else {
      await ref.putFile(File(image.path), metadata);
    }

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
