import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matchmaster/core/theme/app_theme.dart';
import 'package:matchmaster/models/sport.dart';
import 'package:matchmaster/widgets/brand.dart';
import 'package:matchmaster/widgets/sport_glyph.dart';

import 'preview_fonts.dart';

Widget panel(ThemeData theme) {
  return Theme(
    data: theme,
    child: Builder(
      builder: (BuildContext context) => Container(
        color: theme.scaffoldBackgroundColor,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const BrandLockup(markSize: 56),
            const SizedBox(height: 28),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                BrandMark(size: 96),
                SizedBox(width: 16),
                BrandMark(size: 48),
                SizedBox(width: 16),
                BrandMark(size: 24),
                SizedBox(width: 16),
                BrandMark(size: 16),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: <Widget>[
                for (final Sport sport in Sport.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Column(
                      children: <Widget>[
                        SportGlyph(sport: sport, size: 72),
                        const SizedBox(height: 6),
                        Text(sport.label, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '40',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: AppColors.team1(theme.brightness),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'AD',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: AppColors.team2(theme.brightness),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('preview da marca', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Row(
          children: <Widget>[
            Expanded(child: panel(AppTheme.dark())),
            Expanded(child: panel(AppTheme.light())),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Row).first,
      matchesGoldenFile('../../docs/screenshots/brand.png'),
    );
  });
}
