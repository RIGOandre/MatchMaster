import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pasta de fontes do SDK do Flutter em uso.
String? _materialFontsDir() {
  final String? flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final List<String> candidates = <String>[
    if (flutterRoot != null) '$flutterRoot/bin/cache/artifacts/material_fonts',
    '/opt/sdk/flutter/bin/cache/artifacts/material_fonts',
  ];
  for (final String dir in candidates) {
    if (Directory(dir).existsSync()) return dir;
  }
  return null;
}

/// Carrega Roboto e os ícones do Material.
///
/// Sem isso as capturas saem com os retângulos da fonte de teste no lugar do
/// texto, e não dá para avaliar tipografia nem detectar texto estourando.
Future<void> loadRealFonts() async {
  final String? dir = _materialFontsDir();
  if (dir == null) return;

  Future<void> load(String family, List<String> files) async {
    final FontLoader loader = FontLoader(family);
    for (final String file in files) {
      final File f = File('$dir/$file');
      if (!f.existsSync()) continue;
      loader.addFont(
        f.readAsBytes().then(
              (Uint8List bytes) => ByteData.view(bytes.buffer),
            ),
      );
    }
    await loader.load();
  }

  await load('Roboto', <String>[
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
  ]);
  await load('MaterialIcons', <String>['MaterialIcons-Regular.otf']);
}
