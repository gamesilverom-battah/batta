// معاينة رسايل «ترجع للدور؟» و«فيه دور شغّال ناقصه لاعب» و«اسمك طويل»: flutter test test/capture_rejoin_test.dart -> build/preview_rejoin_*.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kout/main.dart';
import 'package:kout/net.dart';
import 'package:kout/sounds.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// بدون سيرفر: نسجّل اللي ينرسل بس
class _Client extends GameClient {
  final sent = <String>[];
  @override
  void acceptRejoin() => sent.add('rejoin');
  @override
  void declineRejoin() => sent.add('forfeit');
}

Future<void> _shot(WidgetTester tester, String out) async {
  await tester.runAsync(() async {
    final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
    final img = await ro.toImage(pixelRatio: 1);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File(out).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('rejoin, substitute and long name prompts', (tester) async {
    Sfx.muted = true;
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      final f = FontLoader('ElMessiri')..addFont(rootBundle.load('assets/fonts/ElMessiri-Bold.ttf'));
      await f.load();
    });
    addTearDown(tester.view.reset);
    for (final (size, name) in const [(Size(390, 844), 'portrait'), (Size(844, 390), 'landscape')]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final c = _Client()..name = 'مهند';
      c.rejoinOffer = {'ok': true, 'code': '1234', 'mode': 6, 'winScore': 54, 'scores': [31, 18], 'team': 1};
      await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: KoutApp(key: ValueKey(name), client: c)));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('ترجع للدور؟'), findsOneWidget);
      await _shot(tester, 'build/preview_rejoin_${name}_back.png');
      await tester.tap(find.text('ارجع'));
      expect(c.sent, ['rejoin']);

      c.rejoinOffer = null;
      c.subOffer = {'code': '5678', 'seat': 2, 'mode': 4, 'winScore': 34, 'scores': [12, 20], 'team': 0};
      c.notifyListeners();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('فيه دور شغّال ناقصه لاعب'), findsOneWidget);
      await _shot(tester, 'build/preview_rejoin_${name}_sub.png');

      c.subOffer = null;
      c.notice = 'دخل لاعب مكانك بالدور، وانحسبت لك خسارة';
      c.notifyListeners();
      await tester.pump(const Duration(milliseconds: 100));
      await _shot(tester, 'build/preview_rejoin_${name}_lost.png');
      await tester.tap(find.text('تمام'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.notice, isNull);

      // اسم قديم أطول من 10
      c.name = 'محمد بن سالم الحارثي';
      c.notifyListeners();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('اسمك طويل'), findsOneWidget);
      await _shot(tester, 'build/preview_rejoin_${name}_name.png');
      await tester.enterText(find.byType(TextField).last, 'بو سالم');
      await tester.pump();
      await tester.tap(find.text('احفظ'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.name, 'بو سالم');
      expect(find.text('اسمك طويل'), findsNothing);
    }
  });
}
