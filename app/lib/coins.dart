import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'menus.dart' show Bob, Pressable;
import 'i18n.dart';
import 'sounds.dart';
import 'wallet.dart';

/// عدد العملات اللي تطير (صوت العملات مسوّى على نفس العدد: tools/gen-coins.js)
const coinCount = 10;

/// عملات غوازي تطير من مكان لمكان (من الهدية للرصيد، أو من الرصيد للجيم) مع صوت العملات.
/// onLand: أول ما توصل أول عملة (نحدّث الرصيد وقتها عشان الرقم يعدّ مع وصولها)
void flyCoins(BuildContext context, {required GlobalKey from, required GlobalKey to, int count = coinCount, VoidCallback? onLand, VoidCallback? onDone}) {
  final overlay = Overlay.maybeOf(context);
  final box = overlay?.context.findRenderObject() as RenderBox?;
  Rect? rectOf(GlobalKey k) {
    final b = k.currentContext?.findRenderObject() as RenderBox?;
    if (b == null || box == null || !b.hasSize) return null;
    return b.localToGlobal(Offset.zero, ancestor: box) & b.size;
  }

  final a = rectOf(from), b = rectOf(to);
  if (overlay == null || a == null || b == null) {
    onLand?.call();
    onDone?.call();
    return;
  }
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _CoinFlight(
      from: a.center,
      to: b.center,
      count: count,
      onLand: onLand,
      onDone: () {
        entry.remove();
        onDone?.call();
      },
    ),
  );
  overlay.insert(entry);
}

class _CoinFlight extends StatefulWidget {
  final Offset from, to;
  final int count;
  final VoidCallback? onLand;
  final VoidCallback onDone;
  const _CoinFlight({required this.from, required this.to, required this.count, required this.onLand, required this.onDone});

  @override
  State<_CoinFlight> createState() => _CoinFlightState();
}

class _CoinFlightState extends State<_CoinFlight> with SingleTickerProviderStateMixin {
  // الطيران كله 1.6 ثانية: كل عملة تطير 40% منه (640ms)، والعملات ورا بعض بالتساوي لين آخر الوقت.
  // بفرق 103ms بين العملات (10 عملات)، وصوت العملات نفس الإيقاع: كل رنّة لحظة ما توصل عملة
  static const _ms = 1600, _fly = 0.4;
  late final double _gap = (1 - _fly - 0.02) / max(1, widget.count - 1);
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(milliseconds: _ms));
  final _rnd = Random(3);
  late final List<Offset> _spread = [for (var i = 0; i < widget.count; i++) Offset(_rnd.nextDouble() * 36 - 18, _rnd.nextDouble() * 20 - 10)];
  bool _landed = false;

  @override
  void initState() {
    super.initState();
    _t.addListener(() {
      if (!_landed && _t.value >= _fly) {
        _landed = true;
        Sfx.coins(); // الصوت يبدأ مع وصول أول عملة
        widget.onLand?.call();
      }
    });
    _t.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _t,
          builder: (_, _) {
            final d = widget.to - widget.from;
            // قوس لفوق بين النقطتين
            // (ما يطلع برا الشاشة من فوق)
            final lift = -min(min(140.0, 60 + d.distance * 0.25), max(0.0, min(widget.from.dy, widget.to.dy) - 14));
            return Stack(children: [
              for (var i = 0; i < widget.count; i++)
                Builder(builder: (_) {
                  final p = ((_t.value - i * _gap) / _fly).clamp(0.0, 1.0);
                  if (p <= 0 || p >= 1) return const SizedBox.shrink();
                  final e = Curves.easeInOut.transform(p);
                  // تنتشر شوي أول ما تطلع، وتتجمع لما توصل
                  final spread = _spread[i] * sin(p * pi);
                  final pos = widget.from + d * e + Offset(0, lift * 4 * e * (1 - e)) + spread;
                  final size = 26.0 * (1 - 0.25 * e);
                  return Positioned(
                    left: pos.dx - size / 2,
                    top: pos.dy - size / 2,
                    child: Transform.rotate(angle: p * pi * 2 * (i.isEven ? 1 : -1), child: GhawaziIcon(size: size)),
                  );
                }),
            ]);
          },
        ),
      );
}

String _after(Duration d) => d.inHours >= 1 ? trf('بعد {0} ساعة', [d.inHours]) : trf('بعد {0} دقيقة', [max(1, d.inMinutes)]);

/// مقاس خانتي هدية اليوم و«شاهد إعلان» (نفس الشي للثنتين، وصغار عشان ما يزاحمون الشعار)
const double sideBoxWidth = 104, sideBoxHeight = 34;

/// خانة هدية اليوم تحت الرصيد: تلمع وتنط لين يضغطها اللاعب، وبعدها تقول متى الجاية (24 ساعة من استلامه).
/// كل 30 ثانية وهي ظاهرة تحدّث الوقت الباقي، وتفتح الهدية لو خلص
class GiftBox extends StatefulWidget {
  final VoidCallback onTap;
  const GiftBox({super.key, required this.onTap});

  @override
  State<GiftBox> createState() => _GiftBoxState();
}

class _GiftBoxState extends State<GiftBox> {
  late final Timer _clock = Timer.periodic(const Duration(seconds: 30), (_) {
    Wallet.instance.checkGift();
    if (mounted) setState(() {});
  });

  @override
  void initState() {
    super.initState();
    _clock;
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Wallet.instance,
        builder: (_, _) {
          final ready = Wallet.instance.giftReady;
          final when = _after(Wallet.instance.untilNextGift());
          return GestureDetector(
            onTap: ready ? widget.onTap : null,
            child: Container(
              width: sideBoxWidth,
              height: sideBoxHeight,
              padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
              decoration: BoxDecoration(
                color: ready ? const Color(0xFF2A1F05) : const Color(0xFF111111),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ready ? const Color(0xFFFFD65A) : const Color(0xFF8A8D92), width: 2),
                boxShadow: ready ? const [BoxShadow(color: Color(0x99FFD65A), blurRadius: 12)] : null,
              ),
              child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Row(mainAxisSize: MainAxisSize.min, children: [
                Bob(phase: 0.1, lift: ready ? 3 : 0, child: Icon(Icons.card_giftcard, size: 16, color: ready ? const Color(0xFFFFD65A) : const Color(0xFF8A8D92))),
                const SizedBox(width: 6),
                Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ready ? tr('هدية اليوم') : tr('الهدية الجاية'), style: TextStyle(fontFamily: 'ElMessiri', fontSize: 10.5, height: 1.15, fontWeight: FontWeight.w700, color: ready ? Colors.white : const Color(0xFFAAAAAA))),
                  ready
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          GhawaziIcon(size: 10),
                          SizedBox(width: 3),
                          Text(trf('+{0} استلمها', [Wallet.dailyGift]), style: TextStyle(fontFamily: 'ElMessiri', fontSize: 9.5, height: 1.15, color: Color(0xFFFFD65A))),
                        ])
                      : Text(when, style: const TextStyle(fontFamily: 'ElMessiri', fontSize: 9.5, height: 1.15, color: Color(0xFFAAAAAA))),
                ]),
              ])),
            ),
          );
        },
      );
}

/// خانة «شاهد إعلان» تحت الهدية: إعلان كامل = غوازي (${Wallet.adReward})، لين ${Wallet.adsPerDay} إعلانات بكل 24 ساعة
class AdBox extends StatelessWidget {
  final VoidCallback onTap;
  const AdBox({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Wallet.instance,
        builder: (_, _) {
          final w = Wallet.instance;
          final left = w.adsLeft();
          final ready = left > 0;
          return GestureDetector(
            onTap: ready ? onTap : null,
            child: Container(
              width: sideBoxWidth,
              height: sideBoxHeight,
              padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ready ? Colors.white : const Color(0xFF8A8D92), width: 2),
              ),
              child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Row(mainAxisSize: MainAxisSize.min, children: [
                Bob(phase: 0.6, lift: ready ? 2.5 : 0, child: Icon(Icons.smart_display, size: 16, color: ready ? Colors.white : const Color(0xFF8A8D92))),
                const SizedBox(width: 6),
                Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('شاهد إعلان'), style: TextStyle(fontFamily: 'ElMessiri', fontSize: 10.5, height: 1.15, fontWeight: FontWeight.w700, color: ready ? Colors.white : const Color(0xFFAAAAAA))),
                  ready
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          const GhawaziIcon(size: 10),
                          const SizedBox(width: 3),
                          Text(trf('+{0}  (باقي {1})', [Wallet.adReward, left]), style: const TextStyle(fontFamily: 'ElMessiri', fontSize: 9.5, height: 1.15, color: Color(0xFFFFE08A))),
                        ])
                      : Text(_after(w.untilNextAd()), style: const TextStyle(fontFamily: 'ElMessiri', fontSize: 9.5, height: 1.15, color: Color(0xFFAAAAAA))),
                ]),
              ])),
            ),
          );
        },
      );
}

/// شاشة الإعلان. الحين إعلان تجريبي (عدّاد) لين نربط شبكة إعلانات حقيقية مع نشر التطبيق بالمتاجر (مثل AdMob).
/// يرجّع true إذا خلص الإعلان كامل (الجايزة بس لما يكمل)
Future<bool> showAd(BuildContext context, {int seconds = 15}) async {
  final done = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AdDialog(seconds: seconds),
  );
  return done == true;
}

class _AdDialog extends StatefulWidget {
  final int seconds;
  const _AdDialog({required this.seconds});

  @override
  State<_AdDialog> createState() => _AdDialogState();
}

class _AdDialogState extends State<_AdDialog> {
  late int _left = widget.seconds;
  late final Timer _timer = Timer.periodic(const Duration(seconds: 1), (t) {
    if (!mounted) return;
    setState(() => _left--);
    if (_left <= 0) t.cancel();
  });

  @override
  void initState() {
    super.initState();
    _timer;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: const Color(0xFF1B1C1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white, width: 2)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text(tr('إعلان'), style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(_left > 0 ? '$_left' : '', style: const TextStyle(fontSize: 18, color: Color(0xFFFFE08A), fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 12),
            Container(
              height: 150,
              width: 280,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFF2A2C31), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.smart_display, size: 64, color: Color(0xFF8A8D92)),
            ),
            const SizedBox(height: 12),
            if (_left > 0)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(trf('كمّل الإعلان وتاخذ {0}', [Wallet.adReward]), style: const TextStyle(fontSize: 14, color: Color(0xFFCCCCCC))),
                const SizedBox(width: 4),
                const GhawaziIcon(size: 16),
              ])
            else
              Pressable(child: FilledButton(
                onPressed: withTap(() => Navigator.pop(context, true)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [const GhawaziIcon(size: 18), const SizedBox(width: 6), Text(trf('استلم {0}', [Wallet.adReward]), style: const TextStyle(fontSize: 17))]),
              )),
            const SizedBox(height: 6),
            TextButton(
              onPressed: withTap(() => Navigator.pop(context, false)),
              child: Text(_left > 0 ? tr('سكّر (بدون جايزة)') : tr('سكّر'), style: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))),
            ),
          ]),
        ),
      );
}
