import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../domain/app_failure.dart';
import '../domain/models.dart';

/// Owns a single client. Each request deadline includes reading the full body.
class RecipeApi {
  final Uri _base;
  final http.Client _client;
  final Duration timeout;
  RecipeApi({
    required String baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _base = Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/'),
       _client = client ?? http.Client() {
    if (!['http', 'https'].contains(_base.scheme) ||
        _base.host.isEmpty ||
        _base.hasQuery ||
        _base.hasFragment) {
      throw ArgumentError.value(
        baseUrl,
        'baseUrl',
        'Cần địa chỉ HTTP(S) hợp lệ.',
      );
    }
  }

  Future<List<Recipe>> getRecipes() async =>
      _list(await _request('GET', 'recipes'), _recipe);
  Future<Recipe?> getRecipe(String id) async {
    final response = await _request(
      'GET',
      'recipes/${Uri.encodeComponent(id)}',
      missing: true,
    );
    return response.statusCode == 404
        ? null
        : _parse(response, _recipe, expectedId: id);
  }

  Future<Recipe> createRecipe(Recipe value) async => _parse(
    await _request('POST', 'recipes', body: _remoteRecipe(value)),
    _recipe,
    expectedId: value.id,
  );
  Future<Recipe> updateRecipe(Recipe value) async => _parse(
    await _request(
      'PUT',
      'recipes/${Uri.encodeComponent(value.id)}',
      body: _remoteRecipe(value),
    ),
    _recipe,
    expectedId: value.id,
  );
  Future<void> deleteRecipe(String id) async {
    await _request('DELETE', 'recipes/${Uri.encodeComponent(id)}');
  }

  Future<List<Ingredient>> getIngredients() async =>
      _list(await _request('GET', 'ingredients'), _ingredient);
  Future<Ingredient?> getIngredient(String id) async {
    final response = await _request(
      'GET',
      'ingredients/${Uri.encodeComponent(id)}',
      missing: true,
    );
    return response.statusCode == 404
        ? null
        : _parse(response, _ingredient, expectedId: id);
  }

  Future<Ingredient> createIngredient(Ingredient value) async => _parse(
    await _request('POST', 'ingredients', body: value.toJson()),
    _ingredient,
    expectedId: value.id,
  );
  Future<Ingredient> updateIngredient(Ingredient value) async => _parse(
    await _request(
      'PUT',
      'ingredients/${Uri.encodeComponent(value.id)}',
      body: value.toJson(),
    ),
    _ingredient,
    expectedId: value.id,
  );
  void close() => _client.close();

  Json _remoteRecipe(Recipe value) => value.toJson()
    ..remove('favorite')
    ..['image'] = _httpImage(value.image) ? value.image : null;

  Future<http.Response> _request(
    String method,
    String endpoint, {
    Json? body,
    bool missing = false,
  }) async {
    try {
      final request = http.Request(method, _base.resolve(endpoint));
      request.headers['Accept'] = 'application/json';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json; charset=utf-8';
        request.body = jsonEncode(body);
      }
      final response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(timeout);
      if ((response.statusCode < 200 || response.statusCode >= 300) &&
          !(missing && response.statusCode == 404)) {
        throw AppFailure(
          'Máy chủ trả về lỗi ${response.statusCode}. Vui lòng thử lại.',
          kind: FailureKind.http,
          statusCode: response.statusCode,
        );
      }
      return response;
    } on AppFailure {
      rethrow;
    } on TimeoutException {
      throw AppFailure(
        method == 'GET'
            ? 'Kết nối quá thời gian chờ. Vui lòng thử lại.'
            : 'Chưa xác định máy chủ đã lưu thay đổi hay chưa. Hãy tải lại để kiểm tra trước khi thử lại.',
        kind: FailureKind.timeout,
      );
    } on http.ClientException {
      throw const AppFailure(
        'Không kết nối được máy chủ. Kiểm tra mạng và địa chỉ API.',
        kind: FailureKind.network,
      );
    } on SocketException {
      throw const AppFailure(
        'Không có kết nối mạng. Dữ liệu đã lưu vẫn dùng được.',
        kind: FailureKind.network,
      );
    }
  }

  T _decode<T>(http.Response response, T Function(dynamic) parse) {
    try {
      return parse(jsonDecode(utf8.decode(response.bodyBytes)));
    } catch (_) {
      throw const AppFailure(
        'Dữ liệu máy chủ không hợp lệ. Vui lòng thử tải lại.',
        kind: FailureKind.invalidData,
      );
    }
  }

  T _parse<T>(
    http.Response response,
    T Function(Json) parse, {
    String? expectedId,
  }) => _decode(response, (value) {
    final object = _map(value);
    if (expectedId != null && object['id'] != expectedId) {
      throw const FormatException();
    }
    return parse(object);
  });
  List<T> _list<T>(http.Response response, T Function(Json) parse) =>
      _decode(response, (value) {
        if (value is! List) {
          throw const FormatException();
        }
        final result = value.map((x) => parse(_map(x))).toList();
        final ids = value.map((x) => (x as Map)['id']).toSet();
        if (ids.length != result.length) {
          throw const FormatException();
        }
        return result;
      });
}

Json _map(dynamic value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException();
  }
  return value;
}

void _text(Json j, String key, {bool optional = false}) {
  if (optional && j[key] == null) {
    return;
  }
  if (j[key] is! String || (!optional && (j[key] as String).trim().isEmpty)) {
    throw const FormatException();
  }
}

void _num(
  Json j,
  String key, {
  bool optional = false,
  bool integer = false,
  bool positive = false,
}) {
  final value = j[key];
  if (optional && value == null) {
    return;
  }
  if (value is! num ||
      !value.isFinite ||
      value < 0 ||
      (positive && value <= 0) ||
      (integer && value is! int)) {
    throw const FormatException();
  }
}

bool _httpImage(String? image) {
  final uri = image == null ? null : Uri.tryParse(image);
  return uri != null &&
      ['http', 'https'].contains(uri.scheme) &&
      uri.host.isNotEmpty;
}

Recipe _recipe(Json j) {
  _text(j, 'id');
  _text(j, 'name');
  for (final key in ['description', 'category', 'image']) {
    _text(j, key, optional: true);
  }
  _num(j, 'minutes', integer: true);
  _num(j, 'servings', integer: true, positive: true);
  for (final key in ['vegetarian', 'sample', 'favorite']) {
    if (j[key] != null && j[key] is! bool) {
      throw const FormatException();
    }
  }
  if (j['items'] is! List ||
      j['steps'] is! List ||
      (j['steps'] as List).any((x) => x is! String)) {
    throw const FormatException();
  }
  for (final value in j['items']) {
    final item = _map(value);
    _text(item, 'ingredientId');
    _text(item, 'unit');
    _num(item, 'amount', optional: true);
  }
  return Recipe.fromJson({
    ...j,
    'favorite': false,
    'image': _httpImage(j['image'] as String?) ? j['image'] : null,
  });
}

Ingredient _ingredient(Json j) {
  _text(j, 'id');
  _text(j, 'name');
  _text(j, 'source', optional: true);
  _num(j, 'gramsPerPiece', optional: true, positive: true);
  if (j['per100g'] != null) {
    final nutrients = _map(j['per100g']);
    for (final key in ['kcal', 'protein', 'carbs', 'fat']) {
      _num(nutrients, key);
    }
  }
  return Ingredient.fromJson(j);
}
