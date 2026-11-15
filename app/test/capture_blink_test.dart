// معاينة الرمش: كل شخصية ترمش بوقتها: flutter test test/capture_blink_test.dart -> build/preview_blink.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kout/avatars.dart';
import 'package:kout/cached_paint.dart';

void main() {
  testWidgets('characters blink at different times', (tester) async {
    tester.view.physicalSize = const Size(900, 220);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const ids = ['bodhirs', 'wadamtih', 'aslam', 'medhat', 'khusaib', 'fares'];
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('shot'),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          color: const Color(0xFFBDAE8D),
          alignment: Alignment.center,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            for (final id in ids) CharacterAvatar(charId: id, size: 120, ring: Colors.white, blink: true),
          ]),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    // نمشي 50ms 50ms: أول ما ترمش شخصية (يختفي وجهها الجاهز) نتأكد إن الباقين ما رمشوا معها
    var blinkFrames = 0, together = 0;
    var shot = false;
    for (var i = 0; i < 400; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      final cached = find.byType(CachedPaint).evaluate().length;
      final blinking = ids.length - cached;
      if (blinking > 0) blinkFrames++;
      if (blinking > 1) together++;
      if (blinking == 1 && !shot) {
        shot = true;
        await tester.runAsync(() async {
          final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
          final img = await ro.toImage(pixelRatio: 1);
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('build/preview_blink.png').writeAsBytesSync(png!.buffer.asUint8List());
        });
      }
    }
    expect(blinkFrames, greaterThan(0)); // رمشوا خلال 20 ثانية
    expect(together, 0); // ولا مرة رمشوا ثنين مع بعض
    expect(shot, true);
    debugPrint('blink frames: $blinkFrames, frames with 2+ blinking together: $together');
    await tester.pumpWidget(const SizedBox());
  });
}
