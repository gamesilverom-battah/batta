import 'package:flutter/material.dart';

import 'avatars.dart';
import 'cards.dart';
import 'coins.dart';
import 'friends.dart';
import 'i18n.dart';
import 'menus.dart';
import 'net.dart';
import 'progress.dart';
import 'sounds.dart';
import 'store.dart' show MenuChip;
import 'wallet.dart';

String _left(Duration d) => d.inHours >= 24 ? trf('يتجدد بعد {0} يوم', [d.inDays]) : trf('يتجدد بعد {0} ساعة', [d.inHours]);

/// التحديات: يومية وأسبوعية، كل وحدة لها شريط تقدم وجايزة غوازي تنستلم
class ChallengesPage extends StatefulWidget {
  final VoidCallback onBack;
  const ChallengesPage({super.key, required this.onBack});

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  final _balanceKey = GlobalKey();
  final Map<String, GlobalKey> _cardKeys = {};
  bool _flying = false;

  /// استلام الجايزة: العملات تطير من التحدي لـ«غوازيك»، والرصيد يزيد أول ما توصل
  void _claim(Challenge c) {
    if (_flying || !Progress.instance.done(c) || Progress.instance.isClaimed(c)) return;
    _flying = true;
    flyCoins(context, from: _cardKeys[c.id]!, to: _balanceKey, onLand: () => Progress.instance.claim(c), onDone: () => _flying = false);
  }

  Widget _card(BuildContext context, Challenge c) {
    final p = Progress.instance;
    final got = p.progress(c), done = p.done(c), claimed = p.isClaimed(c);
    return Container(
      key: _cardKeys.putIfAbsent(c.id, GlobalKey.new),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1C1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: done && !claimed ? const Color(0xFFFFE08A) : Colors.white, width: done && !claimed ? 3 : 2),
      ),
      child: Row(children: [
        Bob(
          phase: c.id.hashCode % 10 / 10,
          lift: 2,
          child: Icon(claimed ? Icons.check_circle : (c.weekly ? Icons.emoji_events : Icons.flag), size: 30, color: claimed ? KoutColors.madmoon : const Color(0xFFFFE08A)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.title, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: got / c.goal, minHeight: 9, backgroundColor: const Color(0xFF3A3C40), color: done ? KoutColors.madmoon : const Color(0xFFFFE08A)),
                ),
              ),
              const SizedBox(width: 8),
              Text('$got / ${c.goal}', style: const TextStyle(fontSize: 13, color: Color(0xFFCCCCCC))),
            ]),
          ]),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 92,
          child: claimed
              ? Text(tr('استلمتها'), textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: KoutColors.madmoon, fontWeight: FontWeight.w700))
              : Pressable(child: FilledButton(
                  onPressed: done ? () => _claim(c) : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFE08A),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    minimumSize: const Size(88, 36),
                    textStyle: const TextStyle(fontFamily: 'ElMessiri', fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [const GhawaziIcon(size: 16), const SizedBox(width: 4), Text('${c.reward}')]),
                    if (done) Text(tr('استلم'), style: TextStyle(fontSize: 11, height: 1.1)),
                  ]),
                )),
        ),
      ]),
    );
  }

  Widget _section(String title, String note, List<Widget> cards) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Row(children: [
            Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: KoutColors.ink)),
            const Spacer(),
            Text(note, style: const TextStyle(fontSize: 13, color: KoutColors.ink)),
          ]),
        ),
        ...cards,
      ]);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([Progress.instance, Wallet.instance]),
        builder: (context, _) {
          final now = DateTime.now();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(children: [
                    Expanded(child: BackRow(title: tr('التحديات'), onBack: widget.onBack)),
                    MenuChip(key: _balanceKey, child: GhawaziAmount(Wallet.instance.balance, label: true)),
                  ]),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(tr('تنحسب من المباريات أونلاين'), style: TextStyle(fontSize: 13, color: KoutColors.ink)),
                ),
                Expanded(
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
                    _section(tr('تحديات اليوم'), _left(Progress.untilTomorrow(now)), [for (final c in dailyChallenges) _card(context, c)]),
                    _section(tr('تحديات الأسبوع'), _left(Progress.untilNextWeek(now)), [for (final c in weeklyChallenges) _card(context, c)]),
                  ]),
                ),
              ]),
            ),
          );
        },
      );
}

/// «تاريخك»: إحصائيات اللاعب من كل مبارياته
class HistoryPage extends StatelessWidget {
  final VoidCallback onBack;
  const HistoryPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Progress.instance,
        builder: (context, _) {
          final p = Progress.instance;
          int pct(int part, int all) => all == 0 ? 0 : (part * 100 / all).round();
          final matches = p.value('matches'), bought = p.value('bought');
          final rate = pct(p.value('wins'), matches);
          const good = Color(0xFF6FD68A), bad = Color(0xFFFF7A7A), gold = Color(0xFFFFE08A), blue = Color(0xFF8EC5FF);
          String title(String key) => historyStats.firstWhere((s) => s.key == key).title;

          // رقم واحد داخل قسم
          Widget stat(String label, String value, {Color color = Colors.white}) => Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: BoxDecoration(color: const Color(0xFF2A2C31), borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 24, height: 1.1, fontWeight: FontWeight.w800, color: color))),
                  const SizedBox(height: 2),
                  Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFFCCCCCC))),
                ]),
              );
          Widget of(String k, {Color color = Colors.white}) => stat(title(k), '${p.value(k)}', color: color);

          // قسم: أيقونة وعنوان، وتحته أرقامه
          Widget section(IconData icon, String name, List<Widget> stats) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: BoxDecoration(color: const Color(0xFF1B1C1F), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white, width: 2)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Bob(phase: name.hashCode % 10 / 10, lift: 2, child: Icon(icon, size: 24, color: gold)),
                    const SizedBox(width: 8),
                    Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                  const SizedBox(height: 8),
                  // 4 بالسطر لو فيه مكان، وإلا 2، وكلهم بنفس العرض
                  LayoutBuilder(builder: (_, box) {
                    final cols = box.maxWidth >= 440 ? 4 : 2;
                    final w = (box.maxWidth - 8 * (cols - 1)) / cols;
                    return Wrap(spacing: 8, runSpacing: 8, children: [for (final s in stats) SizedBox(width: w, child: s)]);
                  }),
                ]),
              );

          // فوق: دائرة نسبة الفوز، وجنبها المباريات والفوز والخسارة
          final hero = Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF1B1C1F), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white, width: 2)),
            child: Row(children: [
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(fit: StackFit.expand, children: [
                  CircularProgressIndicator(value: rate / 100, strokeWidth: 9, backgroundColor: bad.withValues(alpha: matches == 0 ? 0.25 : 0.8), color: good),
                  Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('$rate%', style: const TextStyle(fontSize: 24, height: 1.1, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text(tr('نسبة الفوز'), style: TextStyle(fontSize: 11, color: Color(0xFFCCCCCC))),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Row(children: [
                  for (final (k, color) in [('matches', Colors.white), ('wins', good), ('losses', bad)])
                    Expanded(
                      child: Column(children: [
                        FittedBox(fit: BoxFit.scaleDown, child: Text('${p.value(k)}', style: TextStyle(fontSize: 30, height: 1.1, fontWeight: FontWeight.w800, color: color))),
                        Text(title(k), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFFCCCCCC))),
                      ]),
                    ),
                ]),
              ),
            ]),
          );

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(children: [
                Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: BackRow(title: tr('تاريخك'), onBack: onBack)),
                Expanded(
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), children: [
                    hero,
                    section(Icons.shopping_bag, tr('الشراء'), [
                      of('bought'),
                      of('boughtMade', color: good),
                      of('boughtFailed', color: bad),
                      stat(tr('نسبة الوصول'), '${pct(p.value('boughtMade'), bought)}%', color: blue),
                    ]),
                    section(Icons.local_fire_department, tr('الباون والمزايدات الكبيرة'), [
                      of('bawanMade', color: good),
                      of('bawanFailed', color: bad),
                      of('bawanBroken', color: good),
                      of('bigBidMade', color: good),
                    ]),
                    section(Icons.style, tr('الجولات والنقاط'), [
                      of('rounds'),
                      stat(tr('نقاط فريقك'), '${p.value('points')}'),
                      of('jokerPenalty', color: bad),
                      stat(title('ghawaziWon'), '${p.value('ghawaziWon')}', color: gold),
                    ]),
                  ]),
                ),
              ]),
            ),
          );
        },
      );
}

/// بروفايل اللاعب بالقائمة الرئيسية جنب الشعار: شخصيته، اسمه، ومستواه وشريط للمستوى الجاي
class ProfileCard extends StatelessWidget {
  final String name;
  final String? char;
  final double height; // نفس طول الشعار
  final VoidCallback onTap;
  const ProfileCard({super.key, required this.name, required this.char, required this.height, required this.onTap});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Progress.instance,
        builder: (_, _) {
          final p = Progress.instance;
          final avatar = height * 0.46;
          return Pressable(child: GestureDetector(
            onTap: withTap(onTap),
            child: Container(
              height: height,
              constraints: BoxConstraints(minWidth: height * 1.05, maxWidth: height * 1.5),
              padding: EdgeInsets.fromLTRB(height * 0.08, height * 0.16, height * 0.08, height * 0.06),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1C1F),
                borderRadius: BorderRadius.circular(height * 0.18),
                border: Border.all(color: const Color(0xFF111111), width: 3),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 4))],
              ),
              // المحتوى يصغر لو ما كفى (جوالات صغيرة أو خط كبير)
              child: FittedBox(fit: BoxFit.scaleDown, child: Column(mainAxisSize: MainAxisSize.min, children: [
                // الشخصية ورقم المستوى على طرفها
                Stack(clipBehavior: Clip.none, children: [
                  CharacterAvatar(charId: char, size: avatar, ring: KoutColors.teamBlue, background: KoutColors.teamBlue, blink: true),
                  PositionedDirectional(
                    bottom: -4,
                    end: -8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: height * 0.05, vertical: 1),
                      decoration: BoxDecoration(color: const Color(0xFFFFE08A), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF111111), width: 2)),
                      child: Text('${p.level}', style: TextStyle(fontSize: height * 0.11, height: 1.2, fontWeight: FontWeight.w800, color: Colors.black)),
                    ),
                  ),
                ]),
                SizedBox(height: height * 0.05),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: height * 1.3),
                  child: Text(name.isEmpty ? tr('لاعب') : name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: height * 0.13, height: 1.1, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
                SizedBox(height: height * 0.02),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(trf('المستوى {0}', [p.level]), style: TextStyle(fontSize: height * 0.085, height: 1.1, color: const Color(0xFFFFE08A))),
                  SizedBox(height: height * 0.02),
                  SizedBox(
                    width: height * 0.9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: p.levelProgress, minHeight: height * 0.04, backgroundColor: const Color(0xFF3A3C40), color: const Color(0xFFFFE08A)),
                    ),
                  ),
                ]),
              ])),
            ),
          ));
        },
      );
}

/// بروفايل لاعب باللعب (بالضغط على شخصيته): شخصيته، اسمه، مستواه، وإنجازاته. والبوت يقول إنه بوت
void showPlayerProfile(BuildContext context, GameClient client, int seat) {
  final info = client.seatInfo(seat);
  if (info == null) return;
  showDialog(context: context, builder: (_) => _PlayerProfileDialog(client: client, seat: seat, info: info));
}

class _PlayerProfileDialog extends StatelessWidget {
  final GameClient client;
  final int seat;
  final Map info;
  const _PlayerProfileDialog({required this.client, required this.seat, required this.info});

  @override
  Widget build(BuildContext context) {
    final me = seat == client.mySeat;
    final bot = info['bot'] == true;
    // بروفايلي من جهازي (أحدث)، والباقين من السيرفر
    final Map p = me ? Progress.instance.publicProfile() : (info['profile'] as Map? ?? const {});
    int v(String k) => (p[k] as num?)?.toInt() ?? 0;
    final matches = v('matches');
    final rate = matches == 0 ? 0 : (v('wins') * 100 / matches).round();
    final team = KoutColors.team(seat % 2);
    final fc = info['fc'] as String?;
    final canAdd = !me && !bot && fc != null && !Friends.instance.list.any((f) => f.code == fc);
    Widget stat(String label, String value, Color color) => Container(
          width: 96,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFF2A2C31), borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFFCCCCCC))),
          ]),
        );
    return Dialog(
      backgroundColor: const Color(0xFF1B1C1F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Colors.white, width: 2)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(clipBehavior: Clip.none, children: [
              CharacterAvatar(charId: info['char'] as String?, size: 90, ring: team, background: team, blink: true),
              if (!bot)
                PositionedDirectional(
                  bottom: -4,
                  end: -10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFFFFE08A), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF111111), width: 2)),
                    child: Text('${v('level') == 0 ? 1 : v('level')}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black)),
                  ),
                ),
            ]),
            const SizedBox(height: 8),
            Text('${info['name']}', style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w800)),
            if (bot)
              Padding(padding: EdgeInsets.only(top: 6), child: Text(tr('بوت يلعب مكان لاعب'), style: TextStyle(fontSize: 14, color: Color(0xFFAAAAAA))))
            else ...[
              Text(trf('المستوى {0}', [v('level') == 0 ? 1 : v('level')]), style: const TextStyle(fontSize: 14, color: Color(0xFFFFE08A))),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                stat(tr('مباريات'), '$matches', Colors.white),
                stat(tr('فاز'), '${v('wins')}', const Color(0xFF6FD68A)),
                stat(tr('نسبة الفوز'), '$rate%', const Color(0xFF8EC5FF)),
                stat(tr('وصل فيها'), '${v('boughtMade')}', const Color(0xFF6FD68A)),
                stat(tr('جاب باون'), '${v('bawanMade')}', const Color(0xFFFFE08A)),
                stat(tr('قلب باون'), '${v('bawanBroken')}', const Color(0xFF6FD68A)),
              ]),
              if (canAdd) ...[
                const SizedBox(height: 12),
                Pressable(child: OutlinedButton.icon(
                  onPressed: withTap(() {
                    Friends.instance.add(fc, name: info['name'] as String?, char: info['char'] as String?);
                    Navigator.pop(context);
                  }),
                  icon: const Icon(Icons.person_add_alt_1, size: 20),
                  label: Text(tr('أضفه لأصدقائك')),
                )),
              ],
            ],
            const SizedBox(height: 6),
            TextButton(onPressed: withTap(() => Navigator.pop(context)), child: Text(tr('رجوع'), style: TextStyle(color: Color(0xFFAAAAAA)))),
          ]),
        ),
      ),
    );
  }
}
