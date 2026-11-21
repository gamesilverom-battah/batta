import 'package:flutter/material.dart';

import 'cards.dart';
import 'i18n.dart';
import 'invite.dart';
import 'main.dart' show AppLogo, MenuPanel, showErrors;
import 'menus.dart';
import 'net.dart';
import 'sounds.dart';

/// اللي فتح رابط غرفة (…/?room=1234): يدخل هالغرفة بس، وما يشوف باقي اللعبة (القوائم والمتجر).
/// أول مرة يكتب اسمه، وبعدها يدخل على طول. لما يطلع من الغرفة: يرجع لها، أو يحمّل التطبيق.
class RoomLinkScreen extends StatefulWidget {
  final GameClient client;
  const RoomLinkScreen({super.key, required this.client});

  @override
  State<RoomLinkScreen> createState() => _RoomLinkScreenState();
}

class _RoomLinkScreenState extends State<RoomLinkScreen> {
  late final _name = TextEditingController(text: widget.client.name);
  bool _tried = false; // دخلنا الغرفة مرة (فلو رجعنا هني يعني طلعنا منها)

  GameClient get c => widget.client;
  String get _code => c.linkRoom!;

  @override
  void initState() {
    super.initState();
    // عنده اسم: يدخل الغرفة على طول
    if (c.name.trim().isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _join());
  }

  void _join() {
    if (_name.text.trim().isEmpty) {
      c.error = tr('اكتب اسمك');
      setState(() {});
      return;
    }
    if (_name.text.trim() != c.name) c.saveName(_name.text);
    _tried = true;
    c.joinRoom(_code);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    showErrors(context, c);
    final firstTime = !_tried && c.name.trim().isEmpty;
    return Scaffold(
      body: Stack(fit: StackFit.expand, children: [
        const MenuBackdrop(),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Center(child: AppLogo(size: 110)),
                  const SizedBox(height: 14),
                  Text(trf('دعوة لغرفة {0}', [_code]), textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: KoutColors.ink)),
                  const SizedBox(height: 10),
                  if (c.connecting)
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: KoutColors.ink)),
                      const SizedBox(width: 8),
                      Text(tr('جاري الدخول للغرفة...'), style: const TextStyle(fontSize: 14, color: KoutColors.ink)),
                    ])
                  else if (firstTime) ...[
                    MenuPanel(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                      child: TextField(
                        controller: _name,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, color: Colors.white),
                        decoration: InputDecoration(labelText: tr('اسمك'), counterText: '', isDense: true),
                        maxLength: GameClient.nameMax,
                        onSubmitted: (_) => _join(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Pressable(child: FilledButton(
                      onPressed: withTap(_join),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: Text(tr('ادخل الغرفة'), style: const TextStyle(fontSize: 20)),
                    )),
                  ] else ...[
                    // طلع من الغرفة (أو ما قدر يدخل): يرجع لها، أو يحمّل التطبيق عشان يلعب كل شي
                    Pressable(child: FilledButton(
                      onPressed: withTap(_join),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: Text(tr('ارجع للغرفة'), style: const TextStyle(fontSize: 20)),
                    )),
                    const SizedBox(height: 10),
                    Pressable(child: OutlinedButton.icon(
                      onPressed: withTap(() => Invite.open(Uri.base.resolve('/batta.apk').toString())),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
                      icon: const Icon(Icons.download),
                      label: Text(tr('حمّل التطبيق'), style: const TextStyle(fontSize: 18)),
                    )),
                    const SizedBox(height: 6),
                    Text(tr('بالتطبيق تلعب أونلاين وتدرّب وتسوي غرفتك'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: KoutColors.ink)),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
