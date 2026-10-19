import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models.dart';

class RecipeMedia {
  static Future<Recipe> upload(Recipe recipe, SupabaseClient client) async {
    final image = recipe.image;
    if (image == null ||
        image.startsWith('cloud:') ||
        image.startsWith('https://')) {
      return recipe;
    }
    final file = File(image);
    final bytes = await file.readAsBytes();
    if (bytes.length > 5242880) throw StateError('Ảnh cần nhỏ hơn 5 MB.');
    final path = '${client.auth.currentUser!.id}/${file.uri.pathSegments.last}';
    await client.storage
        .from('recipe-images')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        )
        .timeout(const Duration(seconds: 20));
    return recipe.copy(image: 'cloud:$path');
  }

  static Future<String> resolve(String reference, SupabaseClient client) async {
    final remote = reference.substring('cloud:'.length);
    final uid = client.auth.currentUser?.id;
    if (uid == null ||
        !remote.startsWith('$uid/') ||
        remote.split('/').length != 2 ||
        remote.contains('..')) {
      throw StateError('Không có quyền truy cập ảnh.');
    }
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/cloud/$uid');
    await directory.create(recursive: true);
    final file = File('${directory.path}/${remote.split('/').last}');
    if (await file.exists()) return file.path;
    final bytes = await client.storage
        .from('recipe-images')
        .download(remote)
        .timeout(const Duration(seconds: 15));
    if (client.auth.currentUser?.id != uid) {
      throw StateError('Phiên làm việc đã thay đổi.');
    }
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<void> clearAccount(String uid) async {
    if (!RegExp(r'^[0-9a-f-]{36}$').hasMatch(uid)) return;
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/cloud/$uid');
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
