import 'package:flutter/material.dart';

import 'i18n.dart';
import 'cards.dart';
import 'menus.dart';

/// قوانين اللعب (من التدريب): قوة الأوراق والقوانين الرئيسية بالفصحى.
/// القوانين مطابقة لمحرك اللعبة (server/src/engine.js)
class RulesPage extends StatelessWidget {
  final VoidCallback onBack;
  const RulesPage({super.key, required this.onBack});

  static List<(IconData, String, List<String>)> get _rules => [
    (Icons.groups, tr('اللاعبون والأوراق'), [
      tr('يلعب ستة لاعبين أو أربعة في فريقين، ويجلس أعضاء الفريق بالتناوب.'),
      tr('يأخذ كل لاعب تسع أوراق. وفي لعبة الأربعة تُحذف الأوراق الصغيرة فيبقى ستٌّ وثلاثون ورقة.'),
    ]),
    (Icons.record_voice_over, tr('المزايدة'), [
      tr('تبدأ المزايدة من اللاعب الذي على يمين الموزّع، ويزايد كل لاعب مرة واحدة: 6 أو 7 أو 8 أو 9، أو يقول «طاف».'),
      tr('يجب أن تكون كل مزايدة أعلى من التي قبلها، ومن يزايد أعلى رقم يصبح «الشاري».'),
      tr('إذا لم يزايد أحد أُجبر الموزّع على 6، وتُسمّى «6 مجبور».'),
      tr('في طور «بدون إشارة» تبدأ المزايدة من 5، ويكون المجبور «5 مجبور».'),
    ]),
    (Icons.style, tr('الحكم واللعب'), [
      tr('يختار الشاري نوع «الحكم»، ثم يبدأ اللعب من اللاعب الذي على يمينه.'),
      tr('يجب على كل لاعب أن يلعب من نوع الورقة الأولى إن كان يملك منه، فإن لم يملك لعب أي ورقة.'),
      tr('تفوز باللمّة أعلى ورقة جوكر، فإن لم يُلعب جوكر فأعلى ورقة حكم، فإن لم يُلعب حكم فازت أعلى ورقة من نوع الورقة الأولى. ويبدأ الفائز اللمّة التالية.'),
      tr('الجوكران ورقتان خاصتان لا تتبعان أي نوع، ويجوز لعبهما بدل أي نوع.'),
      tr('إذا كانت المزايدة 8 وجب افتتاح اللمّة الأولى بورقة حكم لمن يملكها.'),
    ]),
    (Icons.warning_amber, tr('الجوكران'), [
      tr('لا يجوز الافتتاح بالجوكر الكبير. فإن لم يبقَ مع اللاعب غيره وكان الافتتاح عليه خسر فريقه المباراة.'),
      tr('من لعب الجوكر الكبير قبل نزول الجوكر الصغير خسر فريقه المباراة، إلا الشاري إذا كان يملك الجوكرين معاً («مضمون»).'),
      tr('يجب أن ينزل الجوكر الصغير خلال اللمّات الثلاث الأولى، وإلا أخذ الفريق الآخر 15 نقطة.'),
    ]),
    (Icons.calculate, tr('النقاط'), [
      tr('إذا جمع فريق الشاري عدد اللمّات الذي زايد عليه أخذ نقاطاً بقدر مزايدته.'),
      tr('وإذا عجز عن ذلك أخذ الفريق الآخر ضعف المزايدة.'),
      tr('في «6 مجبور» تكون النقاط ستاً فقط، فوزاً أو خسارة.'),
    ]),
    (Icons.local_fire_department, tr('الباون'), [
      tr('إذا أخذ فريق الشاري كل اللمّات ولم يبقَ له إلا لمّة واحدة ليبلغ مزايدته، خُيّر الشاري في إعلان «الباون».'),
      tr('الباون أن يأخذ الفريق اللمّات التسع كلها: فإن نجح فاز بالمباراة، وإن خسر لمّة واحدة فاز الفريق الآخر بالمباراة.'),
      tr('المزايدة بـ 9 باونٌ من بداية الجولة، ولا باون في «6 مجبور».'),
    ]),
    (Icons.emoji_events, tr('الفوز'), [
      tr('يفوز بالمباراة أول فريق يبلغ 54 نقطة في «الدور الكامل»، أو 34 نقطة في «الدور السريع».'),
    ]),
  ];

  // قوة الأوراق من الأقوى: الجوكر الكبير، الصغير، الآص، الشايب، البنت، الولد، 10 ... 2
  static const _order = ['JB', 'JG', 'S-14', 'S-13', 'S-12', 'S-11', 'S-10', 'S-9', 'S-8', 'S-7', 'S-6', 'S-5', 'S-4', 'S-3', 'S-2'];

  Widget _panel({required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(color: const Color(0xFF1B1C1F), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white, width: 2)),
        child: child,
      );

  Widget _title(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Icon(icon, size: 22, color: const Color(0xFFFFE08A)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
      );

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: BackRow(title: tr('قوانين اللعب'), onBack: onBack)),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), children: [
                _panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _title(Icons.trending_up, tr('قوة الأوراق')),
                    Text(tr('من الأقوى إلى الأضعف، والترتيب نفسه في كل الأنواع:'), style: TextStyle(fontSize: 14, color: Color(0xFFCCCCCC))),
                    const SizedBox(height: 10),
                    LayoutBuilder(builder: (_, box) {
                      // الأوراق بصفين لو الشاشة ضيقة
                      final perRow = box.maxWidth >= 600 ? _order.length : 8;
                      final w = (box.maxWidth - 4 * (perRow - 1)) / perRow;
                      return Directionality(
                        textDirection: TextDirection.rtl,
                        child: Wrap(spacing: 4, runSpacing: 8, children: [for (final c in _order) PlayingCard(c, width: w, shadow: false)]),
                      );
                    }),
                    const SizedBox(height: 8),
                    Text(tr('الجوكر الكبير هو الأقوى ثم الجوكر الصغير، وهما ورقتان خاصتان تغلبان كل الأوراق، حتى الحكم. وأي ورقة حكم تغلب أي ورقة من نوع آخر.'),
                        style: TextStyle(fontSize: 14, height: 1.5, color: Colors.white)),
                  ]),
                ),
                for (final (icon, title, lines) in _rules)
                  _panel(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _title(icon, title),
                      for (final l in lines)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Padding(padding: EdgeInsets.only(top: 8, left: 8), child: CircleAvatar(radius: 3, backgroundColor: Color(0xFFFFE08A))),
                            Expanded(child: Text(l, style: const TextStyle(fontSize: 15, height: 1.55, color: Colors.white))),
                          ]),
                        ),
                    ]),
                  ),
              ]),
            ),
          ]),
        ),
      );
}
