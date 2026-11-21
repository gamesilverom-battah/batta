import 'package:flutter/material.dart';

import 'avatars.dart';
import 'cards.dart';
import 'i18n.dart';
import 'menus.dart';
import 'progress.dart';
import 'sounds.dart';

/// لاعب بالقائمة: اسمه وشخصيته والرقم اللي ينرتب عليه (خبرته باليوم أو بالأسبوع)
class LeaderEntry {
  final String name;
  final String? char;
  final int value;
  final bool me;
  const LeaderEntry(this.name, this.char, this.value, {this.me = false});
}

enum LeaderPeriod { day, week }

/// المتصدرين على مستوى السيرفر كامل، قائمة لليوم وقائمة للأسبوع.
/// الترتيب على نفس اللي يرفع المستوى: الخبرة من المباريات أونلاين (مباراة 20، فوز 30 زيادة، جولة 2، باون 50)،
/// فاللي يلعب ويفوز أكثر يطلع فوق. اليوم يتصفر كل يوم، والأسبوع كل أحد (مثل التحديات).
/// اللاعب يرسل xpDay و xpWeek (publicProfile) مع الدخول وبعد كل مباراة، والسيرفر يرد بالقائمتين (server/src/leaderboard.js).
/// `metric` هو اللي ينعرض جنب كل لاعب، ويتغير بسهولة لو تغير أساس الترتيب.
class Leaderboard extends ChangeNotifier {
  Leaderboard._();
  static final instance = Leaderboard._();

  String metric = 'خبرة'; // عنوان الرقم (يمر على tr وقت العرض)

  /// القائمة تتحدث كل 3 ساعات (12، 3، 6، 9...): السيرفر يحسبها بهالأوقات بس، مو مع كل مباراة
  static const refreshEvery = Duration(hours: 3);
  static DateTime nextRefresh(DateTime now) {
    final slot = (now.hour ~/ refreshEvery.inHours + 1) * refreshEvery.inHours;
    return DateTime(now.year, now.month, now.day, slot);
  }
  final Map<LeaderPeriod, List<LeaderEntry>> lists = {LeaderPeriod.day: const [], LeaderPeriod.week: const []};
  final Map<LeaderPeriod, int?> myRank = {}; // ترتيبي أنا لو مو من اللي بالقائمة

  List<LeaderEntry> of(LeaderPeriod p) => lists[p] ?? const [];

  /// من السيرفر: {day: [...], week: [...], me: {day: 3, week: null}}
  void fromServer(Map<String, dynamic> m) {
    final me = (m['me'] as Map?) ?? const {};
    for (final p in LeaderPeriod.values) {
      final rank = me[p.name] as int?;
      lists[p] = [
        for (final (i, e) in ((m[p.name] as List?) ?? const []).cast<Map>().indexed)
          LeaderEntry(e['name'] as String? ?? '', e['char'] as String?, (e['value'] as num?)?.toInt() ?? 0, me: rank == i + 1),
      ];
      myRank[p] = rank;
    }
    notifyListeners();
  }

  void debugSet(LeaderPeriod p, List<LeaderEntry> list, {int? myRank}) {
    lists[p] = list;
    this.myRank[p] = myRank;
    notifyListeners();
  }
}

const _medals = [Color(0xFFFFD24A), Color(0xFFD9DDE3), Color(0xFFE09A5B)]; // ذهبي، فضي، برونزي

/// رقم المركز بدائرة: الثلاثة الأوائل بلون ميدالية
class _RankBadge extends StatelessWidget {
  final int rank;
  final double size;
  const _RankBadge(this.rank, {this.size = 22});

  @override
  Widget build(BuildContext context) {
    final medal = rank <= 3 ? _medals[rank - 1] : null;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: medal ?? const Color(0xFF2A2C31),
        border: Border.all(color: medal == null ? const Color(0xFF8A8D92) : Colors.black, width: 1.5),
      ),
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Text('$rank', style: TextStyle(fontSize: size * 0.55, height: 1, fontWeight: FontWeight.w800, color: medal == null ? Colors.white : Colors.black)),
        ),
      ),
    );
  }
}

/// خانة المتصدرين بالقائمة الرئيسية: الأول والثاني والثالث، والضغط يفتح القائمة كاملة
class LeaderboardBox extends StatelessWidget {
  final VoidCallback onTap;
  final double width;
  /// size: مربع بنفس مقاس الشعار (مكانه بالقائمة جنب بروفايل اللاعب)، وإلا خانة صغيرة بعرض width
  final double? size;
  const LeaderboardBox({super.key, required this.onTap, this.width = 132, this.size});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Leaderboard.instance,
        builder: (_, _) {
          final top = Leaderboard.instance.of(LeaderPeriod.day).take(3).toList(); // متصدرين اليوم
          Widget row(int i) {
            final e = i < top.length ? top[i] : null;
            return Padding(
              padding: EdgeInsets.only(top: size != null ? 9 : 3),
              child: Row(children: [
                _RankBadge(i + 1, size: 16),
                const SizedBox(width: 4),
                if (e?.char != null) ...[CharacterAvatar(charId: e!.char!, size: 15), const SizedBox(width: 3)],
                Expanded(
                  child: Text(e?.name ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'ElMessiri', fontSize: 10.5, height: 1.15, fontWeight: FontWeight.w700, color: e == null ? const Color(0xFF8A8D92) : Colors.white)),
                ),
                if (e != null) Text('${e.value}', style: const TextStyle(fontFamily: 'ElMessiri', fontSize: 10.5, height: 1.15, fontWeight: FontWeight.w800, color: Color(0xFFFFE08A))),
              ]),
            );
          }

          final content = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Bob(phase: 0.4, lift: 2, child: Icon(Icons.emoji_events, size: 15, color: Color(0xFFFFD24A))),
              const SizedBox(width: 4),
              Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(tr('متصدرين اليوم'), style: TextStyle(fontFamily: 'ElMessiri', fontSize: 11.5, height: 1.15, fontWeight: FontWeight.w700, color: Colors.white)))),
              Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left : Icons.chevron_right, size: 14, color: const Color(0xFFAAAAAA)),
            ]),
            for (var i = 0; i < 3; i++) row(i),
          ]);
          // مربع بمقاس الشعار وبنفس شكل بطاقة البروفايل (يتواكبون جنب بعض)
          final s = size;
          if (s != null) {
            return Pressable(child: GestureDetector(
              onTap: withTap(onTap),
              child: Container(
                width: s,
                height: s,
                padding: EdgeInsets.all(s * 0.08),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1C1F),
                  borderRadius: BorderRadius.circular(s * 0.18),
                  border: Border.all(color: const Color(0xFF111111), width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 4))],
                ),
                child: FittedBox(fit: BoxFit.contain, child: SizedBox(width: 108, child: content)),
              ),
            ));
          }
          return GestureDetector(
            onTap: withTap(onTap),
            child: Container(
              width: width,
              padding: const EdgeInsets.fromLTRB(7, 4, 7, 5),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: content,
            ),
          );
        },
      );
}

/// القائمة كاملة: كل اللاعبين على مستوى السيرفر بالترتيب
class LeaderboardPage extends StatefulWidget {
  final VoidCallback onBack;
  const LeaderboardPage({super.key, required this.onBack});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  var _period = LeaderPeriod.day;

  String _renews() {
    final now = DateTime.now();
    final left = _period == LeaderPeriod.day ? Progress.untilTomorrow(now) : Progress.untilNextWeek(now);
    return left.inHours >= 24 ? trf('يتجدد بعد {0} يوم', [(left.inHours / 24).ceil()]) : trf('يتجدد بعد {0} ساعة', [left.inHours + 1]);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Leaderboard.instance,
        builder: (context, _) {
          final lb = Leaderboard.instance;
          final list = lb.of(_period);
          final mine = lb.myRank[_period];

          Widget tab(LeaderPeriod p, String title) {
            final on = _period == p;
            return Expanded(
              child: GestureDetector(
                onTap: withTap(() => setState(() => _period = p)),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: on ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                  child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: on ? Colors.black : Colors.white)),
                ),
              ),
            );
          }

          final tabs = Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(13), border: Border.all(color: Colors.white, width: 2)),
            child: Row(children: [tab(LeaderPeriod.day, tr('اليوم')), const SizedBox(width: 3), tab(LeaderPeriod.week, tr('الأسبوع'))]),
          );
          final now = DateTime.now();
          final mins = Leaderboard.nextRefresh(now).difference(now).inMinutes + 1;
          final next = '${mins ~/ 60}:${(mins % 60).toString().padLeft(2, '0')}';
          final info = Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(children: [
              Text(tr('العب وفز أونلاين أكثر وتطلع فوق'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: KoutColors.ink)),
              FittedBox(fit: BoxFit.scaleDown, child: Text('${trf('تتحدث كل 3 ساعات، الجاي بعد {0}', [next])}  ·  ${_renews()}', style: const TextStyle(fontSize: 12, color: KoutColors.ink))),
            ]),
          );

          Widget row(int rank, LeaderEntry e) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: rank <= 3 ? 10 : 8),
                decoration: BoxDecoration(
                  color: e.me ? const Color(0xFF2A2410) : const Color(0xFF1B1C1F),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: e.me ? const Color(0xFFFFE08A) : (rank <= 3 ? _medals[rank - 1] : Colors.white24), width: rank <= 3 || e.me ? 2 : 1.5),
                ),
                child: Row(children: [
                  _RankBadge(rank, size: rank <= 3 ? 30 : 26),
                  const SizedBox(width: 10),
                  if (e.char != null) CharacterAvatar(charId: e.char!, size: rank <= 3 ? 38 : 32) else SizedBox(width: rank <= 3 ? 38 : 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(e.me ? trf('{0}{1}', [e.name, tr(' (أنت)')]) : e.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: rank <= 3 ? 18 : 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                    Text('${e.value}', style: TextStyle(fontSize: rank <= 3 ? 20 : 17, height: 1.1, fontWeight: FontWeight.w800, color: const Color(0xFFFFE08A))),
                    Text(tr(lb.metric), style: const TextStyle(fontSize: 11, height: 1.1, color: Color(0xFFAAAAAA))),
                  ]),
                ]),
              );

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(children: [
                Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: BackRow(title: tr('المتصدرين'), onBack: widget.onBack)),
                Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: Column(children: [tabs, info])),
                Expanded(
                  child: list.isEmpty
                      ? Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Bob(phase: 0.2, lift: 3, child: Icon(Icons.emoji_events, size: 64, color: Color(0xFFFFD24A))),
                            const SizedBox(height: 10),
                            Text(tr('القائمة فاضية للحين'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: KoutColors.ink)),
                            const SizedBox(height: 4),
                            Text(tr('العب أونلاين وكن أول واحد فيها'), style: const TextStyle(fontSize: 14, color: KoutColors.ink)),
                          ]),
                        )
                      : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), children: [
                          for (final (i, e) in list.indexed) row(i + 1, e),
                          if (mine != null && !list.any((e) => e.me)) ...[
                            const SizedBox(height: 4),
                            Center(child: Text(trf('ترتيبك {0}', [mine]), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: KoutColors.ink))),
                          ],
                        ]),
                ),
              ]),
            ),
          );
        },
      );
}
