// اللغة الإنجليزية والإعدادات وبروفايل اللاعب: flutter test test/capture_en_test.dart -> build/preview_en_*.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kout/cards.dart';
import 'package:kout/i18n.dart';
import 'package:kout/i18n_en.dart';
import 'package:kout/main.dart';
import 'package:kout/net.dart';
import 'package:kout/progress.dart';
import 'package:kout/sounds.dart';
import 'package:kout/table.dart';
import 'package:kout/wallet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends GameClient {
  @override
  Future<void> search(int mode, int score) async {}
}

Future<void> _shot(WidgetTester tester, String out) async {
  await tester.runAsync(() async {
    final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
    final img = await ro.toImage(pixelRatio: 1);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File(out).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _back(WidgetTester tester) => _tap(tester, find.byIcon(Icons.arrow_back).first);

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

  test('every template keeps its {n} slots in English', () {
    final slot = RegExp(r'\{\d\}');
    enStrings.forEach((ar, en) {
      final a = slot.allMatches(ar).map((m) => m[0]).toSet();
      final e = slot.allMatches(en).map((m) => m[0]).toSet();
      expect(e, a, reason: ar);
    });
  });

  testWidgets('settings: Arabic, then switch to English and go through the menus', (tester) async {
    addTearDown(tester.view.reset);
    addTearDown(() => Lang.instance.en = false);
    for (final (size, name) in const [(Size(390, 844), 'portrait'), (Size(844, 390), 'landscape')]) {
      SharedPreferences.setMockInitialValues({});
      Lang.instance.en = false;
      await tester.runAsync(() => Wallet.instance.load());
      await tester.runAsync(() => Progress.instance.load());
      Progress.instance.stats.addAll({'matches': 24, 'wins': 15, 'losses': 9, 'rounds': 188, 'bought': 41, 'boughtMade': 30, 'boughtFailed': 11, 'bigBidMade': 6, 'bawanMade': 2, 'bawanFailed': 1, 'bawanBroken': 3, 'points': 612});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final c = _Client()..name = 'مهند';
      await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: KoutApp(key: ValueKey(name), client: c)));
      await tester.pump(const Duration(milliseconds: 400));
      // الإعدادات بالعربي
      await _tap(tester, find.byIcon(Icons.settings));
      await _shot(tester, 'build/preview_en_${name}_settings_ar.png');
      // تغيير الاسم
      await _tap(tester, find.text('تغيير الاسم').first);
      await _shot(tester, 'build/preview_en_${name}_rename.png');
      await _tap(tester, find.text('رجوع').last);
      // English
      await _tap(tester, find.text('English'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(Lang.instance.en, true);
      await _shot(tester, 'build/preview_en_${name}_settings.png');
      await tester.tapAt(const Offset(20, 20)); // يسكّر الإعدادات
      await tester.pump(const Duration(milliseconds: 500));
      await _shot(tester, 'build/preview_en_${name}_menu.png');
      expect(find.text('Play online'), findsWidgets);
      await _tap(tester, find.text('6 players'));
      await _shot(tester, 'build/preview_en_${name}_online.png');
      await _back(tester);
      await _tap(tester, find.text('Store'));
      await _shot(tester, 'build/preview_en_${name}_store.png');
      await _back(tester);
      await _tap(tester, find.text('Challenges'));
      await _shot(tester, 'build/preview_en_${name}_challenges.png');
      await _back(tester);
      await _tap(tester, find.text('Your history'));
      await _shot(tester, 'build/preview_en_${name}_history.png');
      await _back(tester);
      await _tap(tester, find.text('Practice'));
      await _tap(tester, find.text('Game rules'));
      await _shot(tester, 'build/preview_en_${name}_rules.png');
    }
  });

  testWidgets('table in English, and tapping a player opens their profile', (tester) async {
    addTearDown(tester.view.reset);
    addTearDown(() => Lang.instance.en = false);
    for (final (size, name, en) in const [(Size(390, 844), 'portrait', true), (Size(844, 390), 'landscape', true), (Size(390, 844), 'portrait_ar', false)]) {
      Lang.instance.en = en;
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      final c = _Client()
        ..connected = true
        ..room = {
          't': 'room', 'code': '1234', 'mode': 6, 'started': true, 'you': 0, 'isHost': true,
          'seats': [
            for (final (i, (n, ch)) in [('مهند', 'musabbah'), ('خصيب', 'khusaib'), ('مرهون', 'marhoon'), ('بو حمدان', 'buhamdan'), ('خلفان التفق', 'khalfan'), ('ود عمتيه', 'wadamtih')].indexed)
              {
                'name': n, 'bot': i > 1, 'connected': true, 'char': ch,
                if (i == 1) 'fc': 'K7Q2XM',
                if (i == 1) 'profile': {'level': 7, 'matches': 58, 'wins': 33, 'losses': 25, 'rounds': 420, 'bought': 90, 'boughtMade': 61, 'bigBidMade': 12, 'bawanMade': 3, 'bawanFailed': 1, 'bawanBroken': 2, 'points': 1490},
              },
          ],
        }
        ..view = {
          'seat': 0, 'players': 6, 'team': 0, 'phase': 'bidding', 'round': 2, 'scores': [12, 26], 'khabis': 3, 'turn': 0,
          'hand': ['H-14', 'H-7', 'C-13', 'C-3', 'D-11', 'D-10', 'D-8', 'S-9', 'JB'],
          'handCounts': [9, 9, 9, 9, 9, 9], 'bids': [{'seat': 4, 'bid': 'pass'}, {'seat': 5, 'bid': 7}], 'currentBid': 7, 'buyer': null, 'majbur': false, 'trump': null,
          'madmoon': false, 'bluePlayed': false, 'bawan': false, 'trick': [], 'trickNo': 0, 'tricksWon': [0, 0], 'greyPlayed': false,
          'lastTrick': null, 'lastRound': null, 'winner': null, 'winReason': null, 'legalBids': [8, 9, 'pass'], 'legalCards': [],
          'blueLoses': false, 'canSignal': false, 'canSignalJoker': false, 'hasJoker': true, 'bawanOffer': false, 'turnMsLeft': 8000, 'history': [], 'signals': true,
        };
      await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: KoutApp(key: ValueKey(name), client: c)));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.runAsync(() async {
        final ctx = tester.element(find.byType(KoutApp));
        for (final card in [...c.view!['hand'] as List, 'back']) {
          await precacheImage(cardImage(card), ctx);
        }
        await precacheImage(matImage, ctx);
      });
      await tester.pump(const Duration(milliseconds: 600));
      await tester.runAsync(() async {
        final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
        final img = await ro.toImage(pixelRatio: 2);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('build/preview_en_table_$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
      if (name == 'landscape') continue;
      // بروفايل خصيب
      await tester.tap(find.text('خصيب').first);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(en ? 'Level 7' : 'المستوى 7'), findsWidgets);
      await tester.runAsync(() async {
        final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
        final img = await ro.toImage(pixelRatio: 2);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('build/preview_en_profile_$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
      Navigator.of(tester.element(find.text('خصيب').last)).pop();
      await tester.pump(const Duration(milliseconds: 500));
    }
  });
}
