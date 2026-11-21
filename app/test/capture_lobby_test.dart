// معاينة الغرفة المخصصة (بدون سحب) ونافذة الدعوة: flutter test test/capture_lobby_test.dart -> build/preview_lobby_*.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kout/friends.dart';
import 'package:kout/main.dart';
import 'package:kout/net.dart';
import 'package:kout/sounds.dart';

class _Client extends GameClient {}

/// الدخول بالرابط بدون سيرفر
class _LinkClient extends GameClient {
  int joins = 0;
  @override
  Future<void> joinRoom(String roomCode) async => joins++;
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
  testWidgets('lobby fits one screen, invite sheet', (tester) async {
    Sfx.muted = true;
    await tester.runAsync(() async {
      final f = FontLoader('ElMessiri')..addFont(rootBundle.load('assets/fonts/ElMessiri-Bold.ttf'));
      await f.load();
      final icons = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if (icons.existsSync()) await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())))).load();
    });
    addTearDown(tester.view.reset);
    Friends.instance.debugSet([Friend('P3RT8A', 'خالد', 'khusaib'), Friend('Z9MN4B', 'عبدالله', 'aslam'), Friend('H2WE6C', 'فهد', null)],
        {'P3RT8A': FriendStatus.online, 'Z9MN4B': FriendStatus.room}, code: 'B4TT3H');
    for (final (size, name, mode) in const [(Size(390, 844), 'portrait', 6), (Size(844, 390), 'landscape', 6), (Size(844, 390), 'landscape4', 4), (Size(360, 640), 'small', 6)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final c = _Client()
        ..name = 'مهند'
        ..connected = true
        ..intro = false
        ..code = '4821'
        ..serverUrl = 'wss://104-194-132-78.sslip.io'
        ..room = {
          't': 'room', 'code': '4821', 'mode': mode, 'started': false, 'you': 0, 'isHost': true, 'stake': 112, 'stakes': [112, 280],
          'seats': [
            {'name': 'مهند', 'bot': false, 'connected': true, 'char': 'aslam'},
            {'name': 'سالم', 'bot': false, 'connected': true, 'char': 'wadamtih', 'fc': 'K7Q2XM'},
            {'name': 'خصيب', 'bot': true, 'connected': true, 'char': 'khusaib'},
            ...List.filled(mode - 3, null),
          ],
        };
      await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: KoutApp(key: ValueKey(name), client: c)));
      await tester.pump(const Duration(milliseconds: 400));
      final err = tester.takeException(); // ما فيه تجاوز (overflow)

      expect(err, isNull);
      await _shot(tester, 'build/preview_lobby_$name.png');
      if (name == 'portrait' || name == 'landscape') {
        await tester.tap(find.text('دعوة').first);
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(find.text('انسخ الرابط'), findsOneWidget);
        expect(find.text('https://104-194-132-78.sslip.io?room=4821'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _shot(tester, 'build/preview_lobby_${name}_invite.png');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }
  });

  testWidgets('room link: opens only the room (name first), then back to the room or download the app', (tester) async {
    Sfx.muted = true;
    await tester.runAsync(() async {
      final f = FontLoader('ElMessiri')..addFont(rootBundle.load('assets/fonts/ElMessiri-Bold.ttf'));
      await f.load();
      final icons = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if (icons.existsSync()) await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())))).load();
    });
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final c = _LinkClient()
      ..name = ''
      ..intro = false
      ..linkRoom = '4821';
    await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: KoutApp(client: c)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('دعوة لغرفة 4821'), findsOneWidget);
    expect(find.text('6 لاعبين'), findsNothing); // ما فيه قوائم اللعبة
    await _shot(tester, 'build/preview_link_name.png');
    // دخل وطلع: يرجع للغرفة أو يحمّل التطبيق
    c.name = 'سالم';
    await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: KoutApp(key: const ValueKey('again'), client: c)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.joins, 1); // عنده اسم: دخل الغرفة على طول
    expect(find.text('حمّل التطبيق'), findsOneWidget);
    await _shot(tester, 'build/preview_link_left.png');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('search screen without countdown', (tester) async {
    Sfx.muted = true;
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final c = _Client()
      ..name = 'مهند'
      ..connected = true
      ..intro = false
      ..searchEnds = DateTime.now().add(const Duration(seconds: 75))
      ..room = {
        't': 'room', 'code': '7777', 'mode': 6, 'started': false, 'search': true, 'winScore': 54, 'you': 0,
        'seats': [{'name': 'مهند', 'bot': false, 'connected': true, 'char': 'aslam'}, {'name': 'سالم', 'bot': false, 'connected': true, 'char': 'wadamtih'}, null, null, null, null],
      };
    await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: KoutApp(key: const ValueKey('search'), client: c)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('1:1'), findsNothing); // ما فيه وقت
    await _shot(tester, 'build/preview_search.png');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
