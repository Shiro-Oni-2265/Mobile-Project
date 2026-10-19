import 'dart:convert';
import 'dart:io';

import 'package:naugi/data/catalog.dart';

/// Run from app/: dart run tool/export_seed.dart [--check].
/// Runtime data is deliberately never touched by this exporter.
void main(List<String> args) {
  final seed = const JsonEncoder.withIndent('  ').convert({
    'recipes': sampleRecipes.map((recipe) => recipe.toJson()).toList(),
    'ingredients': baseIngredients
        .map((ingredient) => ingredient.toJson())
        .toList(),
  });
  final destination = File('../backend/seed.json');
  final example = File('../backend/db.json');
  final content = '$seed\n';
  if (args.contains('--check')) {
    for (final file in [destination, example]) {
      if (!file.existsSync() ||
          file.readAsStringSync().replaceAll('\r\n', '\n') != content) {
        stderr.writeln(
          '${file.path} differs from catalog.dart. Run dart run tool/export_seed.dart.',
        );
        exitCode = 1;
      }
    }
    return;
  }
  destination.writeAsStringSync(content);
  example.writeAsStringSync(content);
  stdout.writeln(
    'Exported ${sampleRecipes.length} recipes and ${baseIngredients.length} ingredients. Runtime database preserved.',
  );
}
