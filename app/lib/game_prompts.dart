import 'package:flutter/material.dart';

import 'cards.dart';
import 'i18n.dart';
import 'menus.dart';
import 'net.dart';
import 'sounds.dart';

/// الرسائل اللي تطلع فوق كل شي:
/// «ترجع للدور؟» (فصل عليه النت أو انقفلت اللعبة)، «فيه دور شغّال ناقصه لاعب، تدخل؟» (وهو يدوّر)،
/// «اسمك طويل» (لازم يغيّره)، ورسايل مثل «دخل لاعب مكانك»
class GamePrompts extends StatelessWidget {
  final GameClient client;
  const GamePrompts({super.key, required this.client});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: client,
        builder: (context, _) {
          final c = client;
          final Widget? card = c.rejoinOffer != null
              ? _rejoin(c, c.rejoinOffer!)
              : c.subOffer != null
                  ? _sub(c, c.subOffer!)
                  : c.notice != null
                      ? _notice(c)
                      : c.room == null && c.name.trim().isNotEmpty && c.nameTooLong
                          ? _LongName(client: c)
                          : null;
          if (card == null) return const SizedBox.shrink();
          // طبقة خاصة فيها (فوق الصفحات)، عشان خانة الكتابة تشتغل
          // (المفتاح يتغير مع الرسالة، عشان الطبقة تنبني من جديد)
          final id = c.rejoinOffer != null ? 'rejoin${c.rejoinOffer}' : c.subOffer != null ? 'sub${c.subOffer}' : c.notice != null ? 'notice${c.notice}' : 'name';
          return Overlay(key: ValueKey(id), initialEntries: [
            OverlayEntry(
              builder: (_) => Material(
                color: Colors.black54,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: card),
                  ),
                ),
              ),
            ),
          ]);
        },
      );

  // النتيجة من عنده: فريقك كذا والخصم كذا
  static Widget _score(Map m) {
    final scores = (m['scores'] as List?) ?? const [0, 0];
    final team = (m['team'] as int?) ?? 0;
    Widget side(String label, Object score, Color color) => Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.w700)),
          Text('$score', style: TextStyle(fontSize: 34, height: 1.1, color: color, fontWeight: FontWeight.w800)),
        ]);
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      side(tr('فريقك'), scores[team], KoutColors.team(team)),
      const SizedBox(width: 28),
      Text(trf('من {0}', [m['winScore'] ?? 54]), style: const TextStyle(fontSize: 15, color: Color(0xFFBBBBBB))),
      const SizedBox(width: 28),
      side(tr('الخصم'), scores[1 - team], KoutColors.team(1 - team)),
    ]);
  }

  Widget _rejoin(GameClient c, Map m) => _Card(
        title: tr('ترجع للدور؟'),
        body: tr('فصل عليك الدور وللحين شغّال، والبوت يلعب مكانك.'),
        middle: _score(m),
        warn: tr('إذا ما رجعت تخسر الرهان'),
        yes: tr('ارجع'),
        no: tr('لا'),
        onYes: c.acceptRejoin,
        onNo: c.declineRejoin,
      );

  Widget _sub(GameClient c, Map m) => _Card(
        title: tr('فيه دور شغّال ناقصه لاعب'),
        body: trf('دور {0} لاعبين، والنتيجة الحين:', [m['mode'] ?? 6]),
        middle: _score(m),
        yes: tr('ادخل'),
        no: tr('لا، كمّل بحث'),
        onYes: c.acceptSub,
        onNo: c.declineSub,
      );

  Widget _notice(GameClient c) => _Card(body: c.notice!, yes: tr('تمام'), onYes: c.clearNotice);
}

class _Card extends StatelessWidget {
  final String? title, warn, no;
  final String body, yes;
  final Widget? middle;
  final VoidCallback onYes;
  final VoidCallback? onNo;
  const _Card({this.title, required this.body, this.middle, this.warn, required this.yes, this.no, required this.onYes, this.onNo});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (title != null) Text(title!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
          if (title != null) const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: Colors.white)),
          if (middle != null) ...[const SizedBox(height: 12), middle!],
          if (warn != null) ...[
            const SizedBox(height: 12),
            Text(warn!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Color(0xFFFFC46B))),
          ],
          const SizedBox(height: 16),
          Row(children: [
            if (no != null) ...[
              Expanded(child: Pressable(child: OutlinedButton(onPressed: withTap(onNo!), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)), child: Text(no!)))),
              const SizedBox(width: 12),
            ],
            Expanded(child: Pressable(child: FilledButton(onPressed: withTap(onYes), style: FilledButton.styleFrom(minimumSize: const Size(0, 48)), child: Text(yes)))),
          ]),
        ]),
      );
}

/// الاسم أطول من 10: يكتب اسم جديد (ما ينحسب من مرات التغيير المجانية)
class _LongName extends StatefulWidget {
  final GameClient client;
  const _LongName({required this.client});

  @override
  State<_LongName> createState() => _LongNameState();
}

class _LongNameState extends State<_LongName> {
  late final _ctl = TextEditingController(text: widget.client.name.characters.take(GameClient.nameMax).toString());

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('اسمك طويل'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(trf('الاسم صار {0} حروف بالكثير (مع المسافات والأرقام والرموز). اكتب اسم جديد، وهالتغيير مجاني.', [GameClient.nameMax]),
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
          const SizedBox(height: 14),
          TextField(
            controller: _ctl,
            maxLength: GameClient.nameMax,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Pressable(child: FilledButton(
            onPressed: _ctl.text.trim().isEmpty ? null : withTap(() => widget.client.saveName(_ctl.text)),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            child: Text(tr('احفظ')),
          )),
        ]),
      );
}
