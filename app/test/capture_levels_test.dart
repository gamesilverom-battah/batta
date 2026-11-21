// معاينة شارات المستوى (كل 10 مستويات شكل): flutter test test/capture_levels_test.dart -> build/preview_levels.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kout/level_badge.dart';

void main() {
  testWidgets('level badges', (tester) async {
    final f = FontLoader('ElMessiri')..addFont(rootBundle.load('assets/fonts/ElMessiri-Bold.ttf'));
    await f.load();
    tester.view.physicalSize = const Size(900, 520) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    const levels = [5, 14, 27, 33, 45, 55, 64, 70];
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'ElMessiri'),
      home: Material(child: RepaintBoundary(
        key: const ValueKey('shot'),
        child: Container(
          color: const Color(0xFF6B6F75),
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            for (final row in [levels.sublist(0, 4), levels.sublist(4)])
              Expanded(
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  for (final l in row)
                    Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      LevelBadge(level: l, size: 120),
                      const SizedBox(height: 18),
                      LevelBadge(level: l, size: 30),
                      const SizedBox(height: 10),
                      Text(LevelBadge.tierNames[LevelBadge.tierOf(l)], textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 16, color: Colors.white, decoration: TextDecoration.none)),
                    ]),
                ]),
              ),
          ]),
        ),
      ),
    )));
    await tester.pump();
    await tester.runAsync(() async {
      final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
      final img = await ro.toImage(pixelRatio: 2);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('build/preview_levels.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
