import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class RecipeMedia {
  static Future<String?> pick() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 75,
    );
    if (picked == null) return null;
    if (await picked.length() > 5 * 1024 * 1024) {
      throw StateError('Ảnh cần nhỏ hơn 5 MB.');
    }
    final root = await getApplicationDocumentsDirectory();
    final saved = await File(
      picked.path,
    ).copy('${root.path}/${const Uuid().v4()}.jpg');
    return saved.path;
  }
}
