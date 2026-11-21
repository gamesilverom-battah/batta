// المتصدرين بالقائمة الرئيسية وصفحتهم: flutter test test/capture_leaderboard_test.dart -> build/preview_lb_*.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kout/i18n.dart';
import 'package:kout/leaderboard.dart';
import 'package:kout/main.dart';
import 'package:kout/progress_pages.dart';
import 'package:kout/net.dart';
import 'package:kout/progress.dart';
import 'package:kout/sounds.dart';
import 'package:kout/wallet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends GameClient {}

Future<void> _shot(WidgetTester tester, String out) async {
  await tester.runAsync(() async {
    final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
    final img = await ro.toImage(pixelRatio: 1);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File(out).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 500));
}

// خبرة اليوم
const _sample = [
  LeaderEntry('بو سالم', 'khalfan', 378),
  LeaderEntry('ريم', 'aslam', 333),
  LeaderEntry('حمود', 'marhoon', 279),
  LeaderEntry('ناصر', 'wadamtih', 252),
  LeaderEntry('مهند', 'musabbah', 216, me: true),
  LeaderEntry('خالد', 'khusaib', 198),
  LeaderEntry('عبدالله', 'bodhirs', 171),
  LeaderEntry('فهد', 'fares', 153),
  LeaderEntry('سيف', 'medhat', 135),
  LeaderEntry('هلال', 'sulaiman', 108),
];

void main() {
  setUpAll(() async {
    Sfx.muted = true;
    SharedPreferences.setMockInitialValues({});
    final f = FontLoader('ElMessiri')..addFont(rootBundle.load('assets/fonts/ElMessiri-Bold.ttf'));
    await f.load();
    final sdk = Platform.environment['FLUTTER_ROOT'] ?? File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
    final icons = File('$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())))).load();
  });

  test('each level needs more XP than the one before', () {
    expect([for (var l = 1; l <= 6; l++) Progress.xpFor(l)], [0, 140, 310, 510, 740, 1010]);
    for (var l = 2; l < 30; l++) {
      expect(Progress.levelStep(l), greaterThan(Progress.levelStep(l - 1)));
    }
  });

  testWidgets('leaderboard box on the menu and the full page', (tester) async {
    addTearDown(tester.view.reset);
    addTearDown(() {
      Lang.instance.en = false;
      Leaderboard.instance.debugSet(LeaderPeriod.day, const []);
      Leaderboard.instance.debugSet(LeaderPeriod.week, const []);
    });
    for (final (size, name, en, data) in const [
      (Size(390, 844), 'portrait', false, true),
      (Size(844, 390), 'landscape', false, true),
      (Size(390, 844), 'portrait_empty', false, false),
      (Size(390, 844), 'portrait_en', true, true),
      (Size(360, 740), 'small', false, true),
    ]) {
      SharedPreferences.setMockInitialValues({});
      Lang.instance.en = en;
      await tester.runAsync(() => Wallet.instance.load());
      await tester.runAsync(() => Progress.instance.load());
      Wallet.instance.giftReady = name != 'small';
      Leaderboard.instance.debugSet(LeaderPeriod.day, data ? _sample : const []);
      Leaderboard.instance.debugSet(LeaderPeriod.week, data ? [for (final (i, e) in _sample.reversed.indexed) LeaderEntry(e.name, e.char, 2400 - i * 190, me: e.me)] : const []);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final c = _Client()..name = 'مهند';
      await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: KoutApp(key: ValueKey(name), client: c)));
      await tester.pump(const Duration(milliseconds: 400));
      await _shot(tester, 'build/preview_lb_${name}_menu.png');
      // الخانتين بنفس المقاس
      final gift = tester.getSize(find.text(en ? 'Daily gift' : 'هدية اليوم').evaluate().isEmpty ? find.text(en ? 'Next gift' : 'الهدية الجاية') : find.text(en ? 'Daily gift' : 'هدية اليوم'));
      expect(gift.height, greaterThan(0));
      await _tap(tester, find.text(en ? "Today's leaders" : 'متصدرين اليوم').first);
      await _shot(tester, 'build/preview_lb_${name}_page.png');
      await _tap(tester, find.text(en ? 'This week' : 'الأسبوع'));
      await _shot(tester, 'build/preview_lb_${name}_week.png');
      // البروفايل بالقائمة يفتح تاريخك
      if (name == 'portrait' || name == 'landscape') {
        await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: KoutApp(key: ValueKey('${name}_p'), client: c)));
        await tester.pump(const Duration(milliseconds: 400));
        await _tap(tester, find.byType(ProfileCard));
        expect(find.byType(HistoryPage), findsOneWidget);
        await _shot(tester, 'build/preview_lb_${name}_history.png');
      }
    }
  });
}
