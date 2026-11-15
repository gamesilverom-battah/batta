import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'i18n.dart';
import 'avatars.dart';
import 'cards.dart';
import 'coins.dart';
import 'friends.dart';
import 'fullscreen.dart';
import 'intro.dart';
import 'invite.dart';
import 'menus.dart';
import 'net.dart';
import 'progress.dart';
import 'progress_pages.dart';
import 'rules_page.dart';
import 'sounds.dart';
import 'store.dart';
import 'table.dart';
import 'wallet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final client = GameClient();
  await Wallet.instance.load();
  await Progress.instance.load();
  await Friends.instance.load();
  await client.loadPrefs();
  client.startFriends(); // الأصدقاء: مين متصل، والدعوات (إذا فيه اسم)
  await Sfx.loadSettings();
  await Lang.instance.load();
  runApp(KoutApp(client: client, intro: client.intro));
}

/// خط المسيري الغامق لكل نصوص اللعبة
const appFont = 'ElMessiri';

/// رقم النسخة يطلع تحت الشاشة الرئيسية (نفس version في pubspec.yaml)
const appVersion = '1.0.22';

class KoutApp extends StatefulWidget {
  final GameClient client;
  final bool intro; // أنميشن الشعار عند فتح اللعبة
  const KoutApp({super.key, required this.client, this.intro = false});

  @override
  State<KoutApp> createState() => _KoutAppState();
}

class _KoutAppState extends State<KoutApp> {
  late bool _intro = widget.intro;
  GameClient get client => widget.client;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: KoutColors.accent,
      brightness: Brightness.dark,
      surface: KoutColors.surface,
    ).copyWith(primary: Colors.white, onPrimary: Colors.black, secondary: KoutColors.accent);
    final base = ThemeData.dark().textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white, fontFamily: appFont);
    return MaterialApp(
      title: tr('بتّه'),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        fontFamily: appFont,
        scaffoldBackgroundColor: KoutColors.bg,
        textTheme: base,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2C30),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white, width: 2)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white, width: 2.5)),
          labelStyle: const TextStyle(color: Color(0xFFBBBBBB)),
          counterStyle: const TextStyle(color: Color(0xFF999999)),
        ),
        // الزر الأساسي أبيض بكتابة سودا، والثانوي أسود بإطار أبيض
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            disabledBackgroundColor: const Color(0xFF9A9DA2),
            disabledForegroundColor: const Color(0xFF3A3A3A),
            textStyle: const TextStyle(fontFamily: appFont, fontWeight: FontWeight.w700, fontSize: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white, width: 2)),
            elevation: 3,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFF111111),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontFamily: appFont, fontWeight: FontWeight.w700, fontSize: 17),
            side: const BorderSide(color: Colors.white, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      // كل الكلام أكبر شوي عشان يكون أوضح
      builder: (context, child) => PhoneFrame(
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.15)),
          // اللغة: العربي من اليمين والإنجليزي من اليسار، وتتغير على طول من الإعدادات
          child: ListenableBuilder(
            listenable: Lang.instance,
            builder: (context, _) => Directionality(
              textDirection: Lang.instance.en ? TextDirection.ltr : TextDirection.rtl,
              child: Stack(fit: StackFit.expand, children: [
                KeyedSubtree(key: ValueKey(Lang.instance.en), child: child!),
                if (_intro) LogoIntro(onDone: () => setState(() => _intro = false)),
              ]),
            ),
          ),
        ),
      ),
      home: ListenableBuilder(
        listenable: client,
        builder: (context, _) {
          final (id, screen) = client.room == null
              ? ('home', HomeScreen(client: client))
              : client.searching
                  ? ('search', SearchScreen(client: client))
                  : !client.started
                      ? ('lobby', LobbyScreen(client: client))
                      : ('table', TableScreen(client: client) as Widget);
          return PageSwitcher(id: id, child: screen);
        },
      ),
    );
  }
}

/// بالمتصفح على الكمبيوتر: اللعبة تنرسم بمقاس شاشة جوال بالضبط (844×390 عرضي أو 390×844 طولي حسب النافذة)،
/// وبعدها تتكبّر على قد النافذة بالنص، عشان تطلع نفس التطبيق بدل ما تتمدد على عرض الشاشة كلها.
/// متصفح الجوال والتطبيق ياخذون الشاشة كاملة مثل قبل.
class PhoneFrame extends StatelessWidget {
  final Widget child;
  const PhoneFrame({super.key, required this.child});

  static const long = 844.0, short = 390.0; // مقاس جوال (آيفون 13/14)
  /// للاختبارات: تشغيل الإطار خارج المتصفح
  static bool? force;

  static bool get _on =>
      force ?? (kIsWeb && defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS);

  @override
  Widget build(BuildContext context) {
    if (!_on) return child;
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final wide = size.width > size.height;
    final phone = wide ? const Size(long, short) : const Size(short, long);
    // أكبر تكبير يدخل بالنافذة
    final scale = min(size.width / phone.width, size.height / phone.height);
    return ColoredBox(
      color: const Color(0xFF0E0F11),
      child: Center(
        child: SizedBox(
          width: phone.width * scale,
          height: phone.height * scale,
          child: ClipRect(
            child: FittedBox(
              child: SizedBox.fromSize(
                size: phone,
                child: MediaQuery(
                  data: mq.copyWith(size: phone, padding: EdgeInsets.zero, viewPadding: EdgeInsets.zero, viewInsets: EdgeInsets.zero),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showErrors(BuildContext context, GameClient client) {
  final err = client.error;
  if (err == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(tr(err), style: const TextStyle(color: Colors.black, fontFamily: appFont, fontSize: 19)),
      backgroundColor: Colors.white,
      duration: const Duration(seconds: 2),
    ));
    client.clearError();
  });
}

/// خلفية القوائم: كروم مثل الشعار، مع خط لمعة فوق
class ChromeBackground extends StatelessWidget {
  final Widget child;
  const ChromeBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(gradient: KoutColors.chrome()),
        child: Stack(children: [
          Positioned(
            top: 4,
            left: 40,
            right: 40,
            height: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: const LinearGradient(colors: [Color(0x00FFFFFF), Color(0xB3FFFFFF), Color(0x00FFFFFF)]),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ]),
      );
}

/// لوحة سودا بإطار أبيض (القوائم)
class MenuPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const MenuPanel({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: child,
      );
}

/// الشعار بزوايا دائرية وظل، وفريم أسود مثل فريم الخيارات الرئيسية
class AppLogo extends StatelessWidget {
  final double size;
  final double? frame; // سماكة الفريم (الافتراضي بنفس نسبة فريم الخيارات: 5 من 180)
  const AppLogo({super.key, required this.size, this.frame});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.22),
          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: size * 0.12, offset: Offset(0, size * 0.04))],
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.22),
          border: Border.all(color: const Color(0xFF111111), width: frame ?? size * 5 / 180),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.22),
          child: Image.asset('assets/images/logo.png', fit: BoxFit.cover, filterQuality: FilterQuality.medium),
        ),
      );
}

class HomeScreen extends StatefulWidget {
  final GameClient client;
  const HomeScreen({super.key, required this.client});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final _name = TextEditingController(text: widget.client.name);
  final _code = TextEditingController();
  // أول مرة باللعبة (ما فيه اسم): شاشة الاسم بعد الشعار، وبعدها القائمة
  late _Page _page = widget.client.name.trim().isEmpty ? _Page.account : _Page.menu;
  int _mode = 6;
  int _score = 54;
  int _stakeLevel = 0; // أي مبلغ من مستويات نوع الدور (0 الأصغر)
  String? _storeFocus; // غرض نفتح عليه المتجر (من التفضيلات)
  // أماكن الرصيد والهدية وخيارات الدخول: العملات تطير بينها
  // (تتجدد مع كل صفحة: وقت الانتقال الصفحة القديمة والجديدة يكونون مع بعض)
  var _balanceKey = GlobalKey(), _giftKey = GlobalKey(), _adKey = GlobalKey(), _stakeBalanceKey = GlobalKey();
  var _searchKey = GlobalKey();
  _Page? _keysPage;
  bool _coinsFlying = false;

  /// هدية اليوم: العملات تطير من الخانة للرصيد، والرصيد يزيد أول ما توصل
  void _claimGift() {
    if (_coinsFlying || !Wallet.instance.giftReady) return;
    _coinsFlying = true;
    flyCoins(context, from: _giftKey, to: _balanceKey, onLand: Wallet.instance.claimGift, onDone: () => _coinsFlying = false);
  }

  /// مشاهدة إعلان: لو كمّله، العملات تطير من خانة الإعلان لـ«غوازيك»
  Future<void> _watchAd() async {
    if (_coinsFlying || Wallet.instance.adsLeft() <= 0) return;
    if (!await showAd(context) || !mounted) return;
    _coinsFlying = true;
    flyCoins(context, from: _adKey, to: _balanceKey, onLand: Wallet.instance.claimAd, onDone: () => _coinsFlying = false);
  }

  /// دخول جيم بغوازي: العملات تطير من الرصيد على الخيار، وبعدها يبدأ البحث
  void _enterStake(int stake) {
    if (_coinsFlying) return;
    Wallet.instance.setStake(stake);
    if (!Wallet.instance.canEnter()) return _search(_mode, _score, stake);
    _coinsFlying = true;
    flyCoins(context, from: _stakeBalanceKey, to: _searchKey, onDone: () {
      _coinsFlying = false;
      if (mounted) _search(_mode, _score, stake);
    });
  }

  void _openStore([String? item]) => setState(() {
        _storeFocus = item;
        _page = _Page.store;
      });

  @override
  void initState() {
    super.initState();
    // نجهّز الورق والأصوات من الشاشة الرئيسية، عشان ما تتأخر أول مرة تظهر باللعب
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Sfx.muted || !mounted) return;
      precacheImage(matImage, context);
      precacheCards(context);
      Sfx.preload();
    });
  }

  bool _apply() {
    final c = widget.client;
    if (c.name.trim().isEmpty) {
      c.error = tr('اكتب اسمك');
      setState(() {});
      return false;
    }
    return true;
  }

  // بعد عدد اللاعبين: نختار مع إشارة ميدان أو بدون، وبعدها نكمل (أونلاين: كم نقطة، تدريب: يبدأ على طول)
  bool _practiceFlow = false;

  void _choosePlayers(int mode) => setState(() {
        _mode = mode;
        _practiceFlow = false;
        _page = _Page.online;
      });

  void _practice(int mode) => setState(() {
        _mode = mode;
        _practiceFlow = true;
        _page = _Page.signals;
      });

  void _chooseSignals(bool on) {
    widget.client.signalsOn = on;
    if (_practiceFlow) {
      widget.client.practice(_mode);
    } else {
      setState(() => _page = _Page.online);
    }
  }

  // مع إشارة ميدان أو بدون: بكل الأطوار (أونلاين والتدريب، والغرفة المخصصة من داخلها)
  Widget _signalsPage(GameClient c, BoxConstraints box) {
    final w = min(min((box.maxWidth - 60) / 2, (box.maxHeight - 90) / cardRatio), 240.0);
    final suit = _practiceFlow ? 'H' : (_mode == 6 ? 'S' : 'D');
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: w * 2 + 16),
          child: BackRow(title: _practiceFlow ? trf('تدريب {0} لاعبين', [_mode]) : trf('{0} لاعبين', [_mode]), onBack: () => setState(() => _page = _practiceFlow ? _Page.practice : _Page.menu)),
        ),
        if (c.connecting) _connecting(),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          MenuCard(width: w, suit: suit, icon: Icons.back_hand, title: tr('مع إشارة ميدان'), subtitle: tr('الإشارات مسموحة'), onTap: c.connecting ? null : () => _chooseSignals(true)),
          const SizedBox(width: 16),
          MenuCard(width: w, suit: suit, icon: Icons.do_not_touch, title: tr('بدون إشارة'), subtitle: tr('ما فيه إشارات باللعب'), onTap: c.connecting ? null : () => _chooseSignals(false)),
        ]),
      ]),
    );
  }

  void _search(int mode, int score, int stake) {
    if (!_apply()) return;
    Wallet.instance.setStake(stake);
    if (!Wallet.instance.canEnter()) {
      widget.client.error = tr('غوازيك ما تكفي، اختر مبلغ أصغر أو تدرّب مع البوتات');
      setState(() {});
      return;
    }
    widget.client.search(mode, score);
  }

  // شاشة الاسم أول مرة: الشعار كبير، واسمك، وزر الدخول
  Widget _account(GameClient c, BoxConstraints box) {
    final logo = min(box.maxHeight * 0.32, 150.0);
    void enter() {
      if (_name.text.trim().isEmpty) {
        c.error = tr('اكتب اسمك');
        setState(() {});
        return;
      }
      c.saveName(_name.text);
      setState(() => _page = _Page.menu);
    }

    return Stack(fit: StackFit.expand, children: [
      const MenuBackdrop(),
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(child: AppLogo(size: logo)),
              const SizedBox(height: 14),
              Text(tr('هلا والله! موه اسمك؟'), textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: KoutColors.ink)),
              const SizedBox(height: 10),
              MenuPanel(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: TextField(
                  controller: _name,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, color: Colors.white),
                  decoration: InputDecoration(labelText: tr('اسمك'), counterText: '', isDense: true),
                  maxLength: 20,
                  onSubmitted: (_) => enter(),
                ),
              ),
              const SizedBox(height: 12),
              Pressable(child: FilledButton(
                onPressed: withTap(enter),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(tr('يلا ندخل'), style: TextStyle(fontSize: 20)),
              )),
              const SizedBox(height: 6),
              Text(tr('تقدر تغيّر اسمك بعدين مرتين مجاناً، وبعدها كل تغيير بـ 1\$'), textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: KoutColors.ink)),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _connecting() => Padding(
        // السيرفر المجاني ينام إذا ما أحد يلعب، ويصحى خلال دقيقة
        padding: EdgeInsets.only(top: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: KoutColors.ink)),
          SizedBox(width: 8),
          Flexible(child: Text(tr('جاري الاتصال بالسيرفر... (أول مرة تاخذ لين دقيقة)'), style: TextStyle(fontSize: 13, color: KoutColors.ink))),
        ]),
      );

  // الخيارات الأربعة على شكل ورق، والمتجر والتفضيلات أزرار صغيرة على الجنبين
  Widget _menu(GameClient c, BoxConstraints box) {
    final wide = box.maxWidth > box.maxHeight;
    final logo = wide ? min(box.maxHeight * 0.3, 120.0) : min(box.maxHeight * 0.18, 150.0);
    final free = box.maxHeight - logo - 90;
    final w = min(wide ? min((box.maxWidth - 72) / 4, free / cardRatio) : min((box.maxWidth - 40) / 2, (free - 12) / 2 / cardRatio), 240.0) * (wide ? 0.72 : 0.62);
    final cards = [
      MenuCard(width: w, suit: 'S', ring: 6, title: tr('6 لاعبين'), subtitle: tr('العب أونلاين'), onTap: () => _choosePlayers(6)),
      MenuCard(width: w, suit: 'D', ring: 4, title: tr('4 لاعبين'), subtitle: tr('العب أونلاين'), onTap: () => _choosePlayers(4)),
      MenuCard(width: w, suit: 'C', icon: Icons.vpn_key, title: tr('غرفة مخصصة'), subtitle: tr('ولّف ربعك بكود الغرفة'), onTap: () => setState(() => _page = _Page.custom)),
      MenuCard(width: w, suit: 'H', icon: Icons.school, title: tr('تدريب'), subtitle: tr('تمرّن مع البوتات بدون وقت'), onTap: () => setState(() => _page = _Page.practice)),
    ];
    return Stack(fit: StackFit.expand, children: [
      const MenuBackdrop(),
      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      // الشعار وجنبه بروفايل اللاعب (شخصيته واسمه ومستواه)، الاثنين مع بعض بالنص
      Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
        AppLogo(size: logo, frame: 5 * w / 180), // نفس سماكة فريم الخيارات
        SizedBox(width: logo * 0.12),
        ProfileCard(name: c.name, char: c.char, height: logo, onTap: () => setState(() => _page = _Page.prefs)),
      ]),
      if (c.connecting) _connecting(),
      SizedBox(height: wide ? 10 : 18),
      if (wide)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final card in cards) Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: card)])
      else ...[
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [cards[0], const SizedBox(width: 12), cards[1]]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [cards[2], const SizedBox(width: 12), cards[3]]),
      ],
      const SizedBox(height: 8),
      Text(trf('نسخة {0}', [appVersion]), textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF4A4D52))),
      ]),
      // تحت يمين: المتجر والتفضيلات. تحت يسار: التحديات وتاريخك
      PositionedDirectional(
        start: 10,
        bottom: 8,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SideButton(icon: Icons.shopping_cart, label: tr('المتجر'), phase: 0, onTap: () => _openStore()),
          const SizedBox(width: 10),
          SideButton(icon: Icons.palette, label: tr('التفضيلات'), phase: 0.25, onTap: () => setState(() => _page = _Page.prefs)),
        ]),
      ),
      PositionedDirectional(
        end: 10,
        bottom: 8,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          ListenableBuilder(
            listenable: Progress.instance,
            builder: (_, _) => SideButton(icon: Icons.flag, label: tr('التحديات'), phase: 0.5, dot: Progress.instance.anyToClaim, onTap: () => setState(() => _page = _Page.challenges)),
          ),
          const SizedBox(width: 10),
          SideButton(icon: Icons.military_tech, label: tr('تاريخك'), phase: 0.75, onTap: () => setState(() => _page = _Page.history)),
        ]),
      ),
      // رصيد الغوازي، وتحته خانة هدية اليوم
      PositionedDirectional(
        top: 10,
        start: 8,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ListenableBuilder(listenable: Wallet.instance, builder: (_, _) => MenuChip(key: _balanceKey, child: GhawaziAmount(Wallet.instance.balance, label: true))),
          const SizedBox(height: 6),
          GiftBox(key: _giftKey, onTap: _claimGift),
          const SizedBox(height: 6),
          AdBox(key: _adKey, onTap: _watchAd),
        ]),
      ),
      // فوق على اليسار: الإعدادات بالزاوية، وجنبها الأصدقاء وملء الشاشة
      PositionedDirectional(
        top: 8,
        end: 8,
        child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
          if (Fullscreen.supported) ...[_fullscreenButton(), const SizedBox(width: 8)],
          FriendsButton(onTap: () => setState(() => _page = _Page.friends)),
          const SizedBox(width: 8),
          Pressable(child: OutlinedButton(
            onPressed: withTap(() => showSettings(context, c)),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(8), minimumSize: const Size(44, 44)),
            child: const Icon(Icons.settings, size: 22),
          )),
        ]),
      ),
    ]);
  }

  Widget _fullscreenButton() => ValueListenableBuilder<bool>(
            valueListenable: Fullscreen.on,
            builder: (context, full, _) => Tooltip(
              message: full ? tr('خروج من ملء الشاشة') : tr('ملء الشاشة'),
              child: Pressable(child: OutlinedButton(
                onPressed: withTap(Fullscreen.toggle),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(8), minimumSize: const Size(44, 44)),
                child: Icon(full ? Icons.fullscreen_exit : Icons.fullscreen, size: 24),
              )),
            ),
          );

  // أونلاين: كل الأطوار بصفحة وحدة (نوع الدور، الإشارات، المبلغ)، واللاعب يحدد اللي يبيه وبعدها «ابحث»
  Widget _onlinePage(GameClient c, BoxConstraints box) {
    final wallet = Wallet.instance;
    final wide = box.maxWidth > box.maxHeight;
    final levels = stakeLevels[_score]!;
    final stake = levels[_stakeLevel.clamp(0, levels.length - 1)];
    final win = (stake * (1 + Wallet.winBonus)).round();

    Widget section(String title, List<Widget> tiles) => Padding(
          padding: EdgeInsets.only(bottom: wide ? 8 : 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: KoutColors.ink))),
            Row(children: [for (final (i, t) in tiles.indexed) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: t)]]),
          ]),
        );

    final options = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      section(tr('نوع الدور'), [
        for (final (score, title, icon) in [(54, tr('دور كامل'), Icons.emoji_events), (34, tr('دور على السريع'), Icons.bolt)])
          OptionTile(
            selected: _score == score,
            icon: Icon(icon, size: 26, color: KoutColors.ink),
            title: title,
            subtitle: trf('من {0} نقطة', [score]),
            onTap: () => setState(() => _score = score),
          ),
      ]),
      section(tr('الإشارات'), [
        OptionTile(selected: c.signalsOn, icon: const Icon(Icons.back_hand, size: 24, color: KoutColors.ink), title: tr('مع إشارة ميدان'), subtitle: tr('الإشارات مسموحة'), onTap: () => setState(() => c.signalsOn = true)),
        OptionTile(selected: !c.signalsOn, icon: const Icon(Icons.do_not_touch, size: 24, color: KoutColors.ink), title: tr('بدون إشارة'), subtitle: tr('ما فيه إشارات'), onTap: () => setState(() => c.signalsOn = false)),
      ]),
      section(tr('الدخول'), [
        for (final (i, s) in levels.indexed)
          OptionTile(
            selected: _stakeLevel == i,
            enabled: wallet.balance >= s,
            icon: const GhawaziIcon(size: 26),
            title: '$s',
            subtitle: trf('تفوز {0}', [(s * (1 + Wallet.winBonus)).round()]),
            onTap: () => setState(() => _stakeLevel = i),
          ),
      ]),
    ]);

    // زر البحث: كبير، والعملات تطير له لما يدخل
    final search = Pressable(child: GestureDetector(
      key: _searchKey,
      onTap: c.connecting ? null : withTap(() => _enterStake(stake)),
      child: Container(
        width: wide ? 170 : double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: wide ? 20 : 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE08A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF111111), width: 4),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 5))],
        ),
        child: Flex(
          direction: wide ? Axis.vertical : Axis.horizontal,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Bob(phase: 0.2, lift: 2.5, child: Icon(Icons.search, size: wide ? 48 : 34, color: Colors.black)),
            SizedBox(width: wide ? 0 : 10, height: wide ? 6 : 0),
            // يصغر لو ما كفى عرض الزر
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(tr('ابحث'), style: TextStyle(fontSize: wide ? 26 : 24, fontWeight: FontWeight.w800, color: Colors.black)),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const GhawaziIcon(size: 15),
                const SizedBox(width: 4),
                Text(trf('{0}  ·  تفوز {1}', [stake, win]), style: const TextStyle(fontSize: 13, color: Color(0xFF3A2C05), fontWeight: FontWeight.w700)),
              ]),
            ]))),
          ],
        ),
      ),
    ));

    final header = Row(children: [
      Expanded(child: BackRow(title: trf('{0} لاعبين', [_mode]), onBack: () => setState(() => _page = _Page.menu))),
      ListenableBuilder(listenable: wallet, builder: (_, _) => MenuChip(key: _stakeBalanceKey, child: GhawaziAmount(wallet.balance, size: 16, label: true))),
    ]);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: wide ? 780 : 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(children: [
            header,
            if (c.connecting) _connecting(),
            const SizedBox(height: 10),
            Expanded(
              child: wide
                  // البحث على اليمين، والخيارات جنبه
                  ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      search,
                      const SizedBox(width: 16),
                      Expanded(child: SingleChildScrollView(child: options)),
                    ])
                  : Column(children: [
                      Expanded(child: SingleChildScrollView(child: options)),
                      const SizedBox(height: 10),
                      search,
                    ]),
            ),
          ]),
        ),
      ),
    );
  }

  // التدريب: 6 أو 4 لاعبين مع البوتات، وقوانين اللعب
  Widget _trainingPage(GameClient c, BoxConstraints box) {
    // بالطولي: التدريبين فوق والقوانين تحت. بالعرضي: الثلاثة بصف
    final tall = box.maxHeight > box.maxWidth;
    final w = tall
        ? min(min((box.maxWidth - 60) / 2, (box.maxHeight - 120) / 2 / cardRatio), 240.0)
        : min(min((box.maxWidth - 64) / 3, (box.maxHeight - 90) / cardRatio), 240.0);
    final off = c.connecting;
    final rules = MenuCard(width: w, suit: 'H', icon: Icons.menu_book, title: tr('قوانين اللعب'), subtitle: tr('قوة الأوراق والقوانين'), onTap: () => setState(() => _page = _Page.rules));
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: tall ? w * 2 + 16 : w * 3 + 32),
          child: BackRow(title: tr('تدريب'), onBack: () => setState(() => _page = _Page.menu)),
        ),
        if (c.connecting) _connecting(),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final (i, mode) in const [(0, 6), (1, 4)]) ...[
            if (i > 0) const SizedBox(width: 16),
            MenuCard(width: w, suit: 'H', ring: mode, title: trf('{0} لاعبين', [mode]), subtitle: tr('مع البوتات بدون وقت'), onTap: off ? null : () => _practice(mode)),
          ],
          if (!tall) ...[const SizedBox(width: 16), rules],
        ]),
        if (tall) ...[const SizedBox(height: 16), rules],
      ]),
    );
  }

  // الغرفة المخصصة: سوّ غرفة، أو ادخل بكود
  Widget _custom(GameClient c) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              BackRow(title: tr('غرفة مخصصة'), onBack: () => setState(() => _page = _Page.menu)),
              const SizedBox(height: 10),
              if (c.connecting) _connecting(),
              Pressable(child: FilledButton(
                onPressed: c.connecting ? null : withTap(() { if (_apply()) c.createRoom(); }),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(tr('سوّ غرفة جديدة'), style: TextStyle(fontSize: 19)),
              )),
              const SizedBox(height: 12),
              MenuPanel(
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, color: Colors.white, letterSpacing: 4),
                      decoration: InputDecoration(labelText: tr('كود الغرفة')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Pressable(child: OutlinedButton(
                    onPressed: c.connecting ? null : withTap(() { if (_apply() && _code.text.trim().isNotEmpty) c.joinRoom(_code.text.trim()); }),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 22)),
                    child: Text(tr('ادخل')),
                  )),
                ]),
              ),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    showErrors(context, c);
    if (_keysPage != _page) {
      _keysPage = _page;
      _balanceKey = GlobalKey();
      _giftKey = GlobalKey();
      _adKey = GlobalKey();
      _stakeBalanceKey = GlobalKey();
      _searchKey = GlobalKey();
    }
    return Scaffold(
      body: ChromeBackground(
        child: SafeArea(
          child: Stack(fit: StackFit.expand, children: [
          PageSwitcher(
            id: _page,
            child: LayoutBuilder(builder: (context, box) => switch (_page) {
                  _Page.account => _account(c, box),
                  _Page.menu => _menu(c, box),
                  _Page.signals => _signalsPage(c, box),
                  _Page.practice => _trainingPage(c, box),
                  _Page.friends => FriendsPage(onBack: () => setState(() => _page = _Page.menu)),
                  _Page.rules => RulesPage(onBack: () => setState(() => _page = _Page.practice)),
                  _Page.custom => _custom(c),
                  _Page.online => _onlinePage(c, box),
                  _Page.store => StorePage(focus: _storeFocus, onBack: () => setState(() => _page = _storeFocus == null ? _Page.menu : _Page.prefs)),
                  _Page.challenges => ChallengesPage(onBack: () => setState(() => _page = _Page.menu)),
                  _Page.history => HistoryPage(onBack: () => setState(() => _page = _Page.menu)),
                  _Page.prefs => PrefsPage(
                      client: c,
                      onBack: () => setState(() => _page = _Page.menu),
                      onStore: (item) => _openStore(item),
                    ),
                }),
          ),
          // دعوة من صديق لغرفته: تطلع فوق أي صفحة
          InviteBanner(onJoin: (code) => c.joinRoom(code)),
          ]),
        ),
      ),
    );
  }
}

enum _Page { account, menu, online, practice, custom, store, prefs, challenges, history, rules, friends, signals }

class LobbyScreen extends StatelessWidget {
  final GameClient client;
  const LobbyScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    final c = client;
    showErrors(context, c);
    final full = c.seats.every((s) => s != null);
    final waiting = c.seats.where((s) => s == null).length;

    // فريق: عنوانه، ومقاعده تتقاسم المكان الموجود (بدون سحب)
    Widget team(int t) => Expanded(
          child: Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(color: KoutColors.team(t), borderRadius: BorderRadius.circular(8)),
              child: Text(trf('الفريق {0}', [KoutColors.teamName(t)]),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t == 0 ? Colors.white : Colors.black, fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: LayoutBuilder(builder: (_, box) {
                final rows = c.mode ~/ 2;
                final h = ((box.maxHeight - 6 * (rows - 1)) / rows).clamp(26.0, 84.0);
                return Column(children: [
                  for (var seat = t, i = 0; seat < c.mode; seat += 2, i++) ...[
                    if (i > 0) const SizedBox(height: 6),
                    _SeatTile(client: c, seat: seat, height: h),
                  ],
                ]);
              }),
            ),
          ]),
        );

    // فوق: رجوع، والعنوان، وزر الدعوة
    final bar = Row(children: [
      Pressable(child: OutlinedButton(
        onPressed: withTap(c.leave),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(8), minimumSize: const Size(44, 44)),
        child: const Icon(Icons.arrow_back, size: 20),
      )),
      const SizedBox(width: 10),
      Expanded(child: Text(tr('الغرفة'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: KoutColors.ink))),
    ]);

    // الكود: سطر واحد، وبضغطة ينسخ
    final codeChip = Pressable(child: GestureDetector(
      onTap: withTap(() => _copy(context, c.code ?? '', tr('نسخت الكود'))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white, width: 2)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(tr('الكود'), style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 13)),
          const SizedBox(width: 8),
          Text(c.code ?? '', style: const TextStyle(fontSize: 26, height: 1.1, fontWeight: FontWeight.w700, letterSpacing: 6, color: Colors.white)),
          const SizedBox(width: 6),
          const Icon(Icons.copy, size: 18, color: Color(0xFFBBBBBB)),
        ]),
      ),
    ));

    // عدد اللاعبين: المضيف يختار (المحدد أبيض)
    Widget modeButton(int m) {
      final on = c.mode == m;
      return Pressable(child: GestureDetector(
        onTap: withTap(c.isHost && !on ? () => c.setMode(m) : null),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
          color: on ? Colors.white : const Color(0xFF111111),
          child: Text(trf('{0} لاعبين', [m]), textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: on ? Colors.black : Colors.white)),
        ),
      ));
    }

    final mode = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white, width: 2)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [modeButton(6), modeButton(4)]),
    );
    Widget signalButton(bool value, String label) {
      final on = c.roomSignals == value;
      return Pressable(child: GestureDetector(
        onTap: withTap(c.isHost && !on ? () => c.setSignals(value) : null),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          color: on ? Colors.white : const Color(0xFF111111),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: on ? Colors.black : Colors.white)),
        ),
      ));
    }

    final signalsToggle = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white, width: 2)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [signalButton(true, tr('مع إشارة')), signalButton(false, tr('بدون إشارة'))]),
    );

    // تحت: عبّي بالبوتات، وابدأ
    final actions = c.isHost
        ? Row(children: [
            if (!full) ...[
              Expanded(
                child: Pressable(child: OutlinedButton.icon(
                  onPressed: withTap(c.addBots),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  icon: const Icon(Icons.smart_toy),
                  label: FittedBox(child: Text(tr('عبّي الفاضي ببوتات'), style: TextStyle(fontSize: 15))),
                )),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Pressable(child: FilledButton(
                onPressed: withTap(full ? c.start : null),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
                child: FittedBox(child: Text(full ? tr('ابدأ اللعب') : trf('بانتظار {0} لاعبين', [waiting]))),
              )),
            ),
          ])
        : Text(tr('بانتظار المضيف يبدأ اللعبة...'), textAlign: TextAlign.center, style: TextStyle(color: KoutColors.ink, fontSize: 16));

    return Scaffold(
      body: ChromeBackground(
        child: SafeArea(
          child: LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth > 600;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 760 : 520),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(children: [
                    // بالعرضي: الكود وعدد اللاعبين بنفس سطر العنوان، وبالطولي تحته
                    if (wide)
                      Row(children: [
                        Expanded(child: bar),
                        const SizedBox(width: 10),
                        // يصغر لو ما كفى المكان
                        Flexible(flex: 3, child: FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [codeChip, const SizedBox(width: 10), mode, const SizedBox(width: 10), signalsToggle]))),
                      ])
                    else ...[
                      bar,
                      const SizedBox(height: 10),
                      Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, runSpacing: 8, children: [codeChip, mode, signalsToggle]),
                    ],
                    if (c.mode == 4)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(tr('36 ورقة: بدون 2-6 كلفس وهاس، وبدون 2-5 سبيت وديمن'), textAlign: TextAlign.center, style: TextStyle(color: KoutColors.ink, fontSize: 12)),
                      ),
                    const SizedBox(height: 10),
                    // المقاعد بالنص، وإذا فيه مكان زايد (الطولي) ورق يتخلط تحتها لين يكتمل العدد
                    Expanded(
                      child: LayoutBuilder(builder: (_, area) {
                        final rows = c.mode ~/ 2;
                        final need = 32 + rows * 84.0 + 6 * (rows - 1);
                        final seatsH = min(area.maxHeight, need);
                        final shuffle = !full && area.maxHeight - seatsH >= 120;
                        return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          SizedBox(height: seatsH, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [team(0), const SizedBox(width: 10), team(1)])),
                          if (shuffle) const Padding(padding: EdgeInsets.only(top: 24), child: CardShuffle(cardWidth: 34)),
                        ]);
                      }),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: wide ? 4 : 6),
                      child: Text(tr('المقعد الفاضي: «دعوة» لربعك، أو الكرسي تنتقل له. ومقعدك تختار شخصيتك'), textAlign: TextAlign.center, style: TextStyle(color: KoutColors.ink, fontSize: 12)),
                    ),
                    actions,
                    if (!c.connected)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(tr('انقطع الاتصال، جاري إعادة الاتصال...'), textAlign: TextAlign.center, style: TextStyle(color: KoutColors.lose)),
                      ),
                  ]),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

void _copy(BuildContext context, String text, String done) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(done, style: const TextStyle(color: Colors.black, fontFamily: appFont, fontSize: 18)),
    backgroundColor: Colors.white,
    duration: const Duration(seconds: 2),
  ));
}

/// دعوة الربع: بالكود بس (بدون رابط، عشان عنوان السيرفر ما ينعرف)
void showInvite(BuildContext context, GameClient c) {
  final code = c.code ?? '';
  final text = trf('تعال العب معاي بتّه! ادخل «غرفة مخصصة» وحط الكود {0}', [code]);
  Widget option(IconData icon, String label, Color color, VoidCallback onTap) => Expanded(
        child: Pressable(child: GestureDetector(
          onTap: withTap(onTap),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.white)),
          ]),
        )),
      );
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1B1C1F),
    isScrollControlled: true, // بالعرضي ياخذ الطول اللي يحتاجه (الافتراضي 9/16 من الشاشة وما يكفي)
    constraints: const BoxConstraints(maxWidth: 560),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        // بالعرضي لو طالت (أصدقاء كثير) تنسحب
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(tr('دعوة'), style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(tr('ربعك يدخلون «غرفة مخصصة» ويحطون هالكود'), textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFFBBBBBB))),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFF2A2C31), borderRadius: BorderRadius.circular(12)),
            child: Text(code, style: const TextStyle(fontSize: 34, height: 1.15, fontWeight: FontWeight.w700, letterSpacing: 10, color: Color(0xFFFFE08A))),
          ),
          const SizedBox(height: 12),
          // أصدقائي المتصلين: الدعوة توصلهم على طول
          FriendsToInvite(roomCode: code),
          const SizedBox(height: 12),
          Row(children: [
            if (Invite.canShare) option(Icons.ios_share, tr('شارك'), const Color(0xFF3A6FD8), () => Invite.share(text)),
            if (Invite.canOpen) option(Icons.chat, tr('واتساب'), const Color(0xFF25A244), () => Invite.open('https://wa.me/?text=${Uri.encodeComponent(text)}')),
            option(Icons.content_copy, tr('انسخ الدعوة'), const Color(0xFF555960), () {
              Navigator.pop(ctx);
              _copy(context, text, tr('نسخت الدعوة'));
            }),
          ]),
        ])),
      ),
    ),
  );
}

/// اختيار الشخصية: كل الشخصيات بأسمائها، واللي ماخذها لاعب ثاني باهتة وما تنضغط
/// (اللي مع بوت تنفع، والبوت ياخذ غيرها)
void showCharacterPicker(BuildContext context, GameClient c) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1B1C1F),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (ctx) => ListenableBuilder(
      listenable: c,
      builder: (ctx, _) {
        // من القائمة الرئيسية ما فيه غرفة بعد
        final inRoom = c.room != null;
        final mine = inRoom ? (c.seats[c.mySeat]?['char'] as String?) : c.char;
        final team = KoutColors.team(inRoom ? c.mySeat % 2 : 0);
        final byPlayer = {
          for (var i = 0; i < c.seats.length; i++)
            if (i != c.mySeat && c.seats[i] != null && c.seats[i]!['bot'] != true) c.seats[i]!['char'] as String?: true,
        };
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(tr('اختر شخصيتك'), style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 14, children: [
                    for (final e in characterNames.entries)
                      Opacity(
                        opacity: byPlayer.containsKey(e.key) ? 0.35 : 1,
                        child: Pressable(child: GestureDetector(
                          onTap: byPlayer.containsKey(e.key)
                              ? null
                              : !Wallet.instance.owns('char', e.key)
                                  ? () {
                                      Sfx.tap();
                                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                        content: Text(trf('{0} مقفلة، تنشرى من المتجر', [e.value]), style: const TextStyle(color: Colors.black, fontFamily: appFont, fontSize: 18)),
                                        backgroundColor: Colors.white,
                                        duration: const Duration(seconds: 2),
                                      ));
                                    }
                                  : () {
                                      Sfx.tap();
                                      c.chooseChar(e.key);
                                      Navigator.pop(ctx);
                                    },
                          child: SizedBox(
                            width: 104,
                            child: Column(children: [
                              const SizedBox(height: 18), // الراس يطلع فوق الإطار
                              Stack(clipBehavior: Clip.none, children: [
                                CharacterAvatar(charId: e.key, size: 70, ring: e.key == mine ? Colors.white : team, background: team),
                                if (!Wallet.instance.owns('char', e.key))
                                  Positioned(
                                    bottom: -4,
                                    left: 0,
                                    right: 0,
                                    child: Center(child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFFE08A))),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        const Icon(Icons.lock, size: 12, color: Color(0xFFFFE08A)),
                                        const SizedBox(width: 3),
                                        Text('${lockedChars[e.key]}', style: const TextStyle(fontSize: 11, color: Color(0xFFFFE08A), fontWeight: FontWeight.w700)),
                                      ]),
                                    )),
                                  ),
                              ]),
                              const SizedBox(height: 4),
                              Text(e.value,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, color: e.key == mine ? Colors.white : const Color(0xFFCCCCCC), fontWeight: e.key == mine ? FontWeight.w700 : FontWeight.w400)),
                            ]),
                          ),
                        )),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              Pressable(child: OutlinedButton.icon(
                onPressed: withTap(() => Navigator.pop(ctx)),
                icon: const Icon(Icons.arrow_back, size: 20),
                label: Text(tr('رجوع')),
              )),
            ]),
          ),
        );
      },
    ),
  );
}

class _SeatTile extends StatelessWidget {
  final GameClient client;
  final int seat;
  final double height;
  const _SeatTile({required this.client, required this.seat, this.height = 60});

  @override
  Widget build(BuildContext context) {
    final s = client.seats[seat];
    final me = seat == client.mySeat;
    final canMove = s == null || s['bot'] == true;
    final teamColor = KoutColors.team(seat % 2);
    final av = max(18.0, min(44.0, (height - 6) * 0.75));
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        // مقعدك بإطار لون فريقك
        border: Border.all(color: me ? teamColor : Colors.white, width: me ? 3 : 2),
        borderRadius: BorderRadius.circular(11),
        boxShadow: me ? [BoxShadow(color: teamColor.withValues(alpha: 0.5), blurRadius: 8)] : null,
      ),
      child: Pressable(child: InkWell(
        // المقعد الفاضي: دعوة لربعك (والانتقال له من زر الكرسي)
        onTap: withTap(me ? () => showCharacterPicker(context, client) : (s == null ? () => showInvite(context, client) : (canMove ? () => client.sit(seat) : null))),
        // الإطار من ضمن الارتفاع
        child: SizedBox(
          height: height - (me ? 6 : 4),
          child: Row(children: [
            const SizedBox(width: 7),
            if (s == null)
              Container(
                width: av,
                height: av,
                decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFFE08A), border: Border.all(color: teamColor, width: 2)),
                child: Icon(Icons.person_add_alt_1, color: Colors.black, size: av / 2),
              )
            else
              CharacterAvatar(charId: s['char'] as String?, size: av, ring: teamColor, background: teamColor),
            const SizedBox(width: 7),
            Expanded(
              child: s == null
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(tr('دعوة'), style: TextStyle(fontSize: 14, color: Color(0xFFFFE08A), fontWeight: FontWeight.w700)),
                    )
                  : Text(trf('{0}{1}', [s['name'], me ? tr(' (أنت)') : '']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: Colors.white)),
            ),
            // زر صغير: انتقل لهالمقعد
            if (s == null)
              Pressable(child: Tooltip(
                message: tr('انتقل لهالمقعد'),
                child: InkResponse(
                  onTap: withTap(() => client.sit(seat)),
                  radius: 18,
                  child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Icon(Icons.event_seat, size: 20, color: Color(0xFFBBBBBB))),
                ),
              )),
            if (s != null && s['bot'] == true) const Icon(Icons.smart_toy, size: 17, color: Color(0xFFBBBBBB)),
            // لاعب حقيقي مو من أصدقائي: زر أضفه
            if (s != null && !me && s['fc'] is String && !Friends.instance.list.any((f) => f.code == s['fc']))
              Pressable(child: Tooltip(
                message: tr('أضفه لأصدقائك'),
                child: InkResponse(
                radius: 16,
                onTap: withTap(() {
                  final err = Friends.instance.add(s['fc'] as String, name: s['name'] as String?, char: s['char'] as String?);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(err ?? trf('انضاف {0} لأصدقائك', [s['name']]), style: const TextStyle(color: Colors.black, fontFamily: appFont, fontSize: 18)),
                    backgroundColor: Colors.white,
                    duration: const Duration(seconds: 2),
                  ));
                  (context as Element).markNeedsBuild();
                }),
                child: const Padding(padding: EdgeInsets.symmetric(horizontal: 5, vertical: 6), child: Icon(Icons.person_add_alt_1, size: 18, color: Color(0xFFFFE08A))),
                ),
              )),
            if (client.isHost && s != null && !me)
              Pressable(child: Tooltip(
                message: tr('طرد'),
                child: InkResponse(
                  radius: 16,
                  onTap: withTap(() => client.kick(seat)),
                  child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Icon(Icons.close, size: 16, color: Colors.white)),
                ),
              )),
            const SizedBox(width: 4),
          ]),
)        ),
      ),
    );
  }
}
