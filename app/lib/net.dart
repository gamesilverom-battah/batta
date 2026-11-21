import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'i18n.dart';
import 'friends.dart';
import 'progress.dart';
import 'wallet.dart';

/// إشارة (نوع أو أكثر، أو جوكر "J") أرسلها لاعب. تظهر للجميع ثانية ونص.
class SuitSignal {
  final int seat;
  final List<String> suits;
  final DateTime at = DateTime.now();
  SuitSignal(this.seat, this.suits);
}

const signalDuration = Duration(milliseconds: 1500);

/// الاتصال بالسيرفر وحالة الغرفة واللعبة.
class GameClient extends ChangeNotifier {
  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  String serverUrl = '';
  String name = '';
  String? char; // الشخصية اللي اختارها اللاعب (تنحفظ وتنرسل مع كل دخول)
  String? code;
  String? token;
  bool connected = false;
  bool _wantConnection = false;

  Map<String, dynamic>? room; // معلومات اللوبي
  Map<String, dynamic>? view; // حالة اللعبة الخاصة بهذا اللاعب
  final Map<int, SuitSignal> signals = {};
  // صاحب الجوكر الكبير أرسل إشارة الجوكر: ما تطلع فوقه، وورقته الجاية ينزل عليها كف
  final Set<int> slapPending = {};
  String? error;
  bool kicked = false;

  DateTime? deadline; // متى يخلص وقت اللاعب اللي عليه الدور

  // الأنميشن ما تتأثر بالاتصال:
  // 1) حركتي (رمي ورقة، مزايدة، حكم، باون) تبين على طول بدون ما تنتظر رد السيرفر
  // 2) لو وصلت حالات ورا بعض (النت علّق وفك)، كل وحدة تنتظر أنميشن اللي قبلها يخلص
  Map<String, dynamic>? _serverView; // آخر حالة من السيرفر (نرجع لها لو رفض حركتي)
  final List<({Map<String, dynamic> view, DateTime at})> _pending = [];
  DateTime _holdUntil = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _pendingTimer;

  int get mySeat => (room?['you'] as int?) ?? 0;
  bool get isHost => room?['isHost'] == true;
  bool get started => room?['started'] == true;
  bool get searching => room?['search'] == true;
  DateTime? searchEnds; // متى يخلص البحث وتكمّل البوتات
  int get mode => (room?['mode'] as int?) ?? 6;
  List get seats => (room?['seats'] as List?) ?? const [];

  Map? seatInfo(int seat) => seat < seats.length ? seats[seat] as Map? : null;

  String seatName(int seat) {
    final s = seatInfo(seat);
    return s == null ? tr('فاضي') : s['name'] as String;
  }

  /// الثواني الباقية للاعب اللي عليه الدور
  double? get secondsLeft {
    final d = deadline;
    if (d == null) return null;
    final ms = d.difference(DateTime.now()).inMilliseconds;
    return ms < 0 ? 0 : ms / 1000;
  }

  bool intro = true; // أنميشن الشعار عند الفتح

  Future<void> setIntro(bool on) async {
    intro = on;
    final p = await SharedPreferences.getInstance();
    await p.setBool('intro', on);
  }

  Future<void> loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    name = p.getString('name') ?? '';
    final saved = p.getString('activeGame');
    _saved = saved == null ? null : jsonDecode(saved) as Map<String, dynamic>;
    char = p.getString('char');
    // شخصية مقفلة (ما انشرت): ما تنستخدم
    if (char != null && !Wallet.instance.owns('char', char!)) char = null;
    // أنميشن الشعار دايماً يطلع (انشال إعداده)
    intro = true;
    nameChangesUsed = p.getInt('nameChanges') ?? 0;
    // السيرفر دايماً سيرفر اللعبة (انشال إعداده، فرابط قديم محفوظ ما يعلّق اللاعب)
    serverUrl = defaultServerUrl();
    await p.remove('server');
    await p.remove('serverCustom');
  }

  static String defaultServerUrl() {
    // يمكن تحديده وقت البناء: --dart-define=SERVER_URL=ws://192.168.0.100:8080
    const fromBuild = String.fromEnvironment('SERVER_URL');
    if (fromBuild.isNotEmpty) return fromBuild;
    if (kIsWeb) {
      // نفس عنوان الصفحة: يشتغل محلياً وعبر رابط https (wss)
      final base = Uri.base;
      if (base.host.isEmpty) return 'ws://localhost:8080';
      final scheme = base.scheme == 'https' ? 'wss' : 'ws';
      return '$scheme://${base.host}${base.hasPort ? ':${base.port}' : ''}';
    }
    if (defaultTargetPlatform == TargetPlatform.android) return 'ws://10.0.2.2:8080'; // محاكي أندرويد
    return 'ws://localhost:8080';
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('name', name);
    if (serverUrl.isEmpty || serverUrl == defaultServerUrl()) {
      await p.remove('serverCustom');
    } else {
      await p.setString('serverCustom', serverUrl);
    }
    if (code != null && token != null) {
      await p.setString('room', code!);
      await p.setString('token', token!);
    }
  }

  /// أطول اسم (حروف وأرقام ومسافات ورموز)، نفس السيرفر
  static const nameMax = 10;

  /// اسمه أطول من المسموح (من النسخ القديمة): لازم يغيّره، وما ينحسب من المرات المجانية
  bool get nameTooLong => name.characters.length > nameMax;

  /// تغيير الاسم: أول مرة (شاشة الاسم) مجاني، وبعدها مرتين مجاناً، والباقي بـ 1$ (قريباً مع الشراء الحقيقي)
  static const freeNameChanges = 2;
  int nameChangesUsed = 0;
  int get freeNameChangesLeft => (freeNameChanges - nameChangesUsed).clamp(0, freeNameChanges);

  /// تغيير اسم (من الإعدادات أو التفضيلات): يحسب من التغييرات المجانية. يرجّع false إذا خلصت
  Future<bool> changeName(String value) async {
    final v = value.trim();
    if (v.isEmpty || v == name) return false;
    if (freeNameChangesLeft <= 0) return false;
    nameChangesUsed++;
    final p = await SharedPreferences.getInstance();
    await p.setInt('nameChanges', nameChangesUsed);
    await saveName(v);
    return true;
  }

  /// اسم اللاعب (مثل الحساب): ينكتب أول مرة وينحفظ
  Future<void> saveName(String value) async {
    name = value.trim();
    startFriends();
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString('name', name);
  }

  /// اتصال الأصدقاء (الحضور): يبدأ أول ما يكون عندنا اسم
  void startFriends() => Friends.instance.start(url: serverUrl, name: name, char: char);

  // ---------- الرجوع للدور ----------
  // الدور الشغّال (أونلاين أو غرفة مخصصة) ينحفظ: لو فصل النت أو انقفلت اللعبة يقدر يرجع له
  Map<String, dynamic>? _saved;
  Map<String, dynamic>? rejoinOffer; // السيرفر قال مقعده له: نسأله «ترجع للدور؟»
  Map<String, dynamic>? subOffer; // دور شغّال ناقصه لاعب (وهو يدوّر): «تدخل؟»
  String? notice; // رسالة تطلع له (مثلاً دخل لاعب مكانه)
  /// تنبيه بالطاولة: لاعب فصل (والبوت مكانه)، رجع، أو دخل بديل مكانه. يطلع 4 ثواني
  ({String text, DateTime at})? seatNote;
  Map<String, dynamic>? _lastSearch; // آخر بحث (لو رفض البديل يرجع يدوّر)
  bool _checking = false;

  bool get hasSavedGame => _saved != null;

  /// دور شغّال وأنا فيه (مو تدريب، وما خلص)
  bool get inRunningGame => started && room?['practice'] != true && view != null && view!['phase'] != 'matchEnd';

  Future<void> _saveGame() async {
    final p = await SharedPreferences.getInstance();
    if (_saved == null) {
      await p.remove('activeGame');
    } else {
      await p.setString('activeGame', jsonEncode(_saved));
    }
  }

  /// فتح اللعبة (أو رجع للقائمة) وعنده دور محفوظ: نسأل السيرفر إذا مقعده لسه له
  void checkRejoin() {
    final s = _saved;
    if (s == null || _checking || rejoinOffer != null || room != null) return;
    _checking = true;
    _open(() => _send({'t': 'rejoinCheck', 'code': s['code'], 'token': s['token']}));
  }

  /// «ارجع»: نفس المقعد والمبلغ
  void acceptRejoin() {
    final s = _saved;
    rejoinOffer = null;
    if (s == null) return notifyListeners();
    code = s['code'] as String;
    token = s['token'] as String;
    matchFromSearch = s['search'] == true;
    Wallet.instance.resume(code!, s['stake'] as int?);
    _savePrefs();
    _send({'t': 'join', 'code': code, 'token': token, 'name': name, 'inGame': true, 'fc': Friends.instance.myCode, 'profile': Progress.instance.publicProfile()});
    notifyListeners();
  }

  /// «لا»: يخسر الرهان على طول، والبوت يكمل مكانه لين يجي بديل
  void declineRejoin() {
    final s = _saved;
    rejoinOffer = null;
    if (s != null) _send({'t': 'forfeit', 'code': s['code'], 'token': s['token']});
    _lostGame();
    Future.delayed(const Duration(milliseconds: 300), _close);
    notifyListeners();
  }

  /// الدور اللي كان فيه راح عليه (رفض، أو دخل بديل، أو خلص وهو مو موجود): خسارة
  void _lostGame() {
    final s = _saved;
    if (s == null) return;
    _saved = null;
    _saveGame();
    Wallet.instance.onLeave();
    Progress.instance.recordForfeit(online: s['search'] == true);
  }

  void _close() {
    if (room != null) return; // دخل شي ثاني بنفس الاتصال
    _wantConnection = false;
    _sub?.cancel();
    _ch?.sink.close();
    _ch = null;
    connected = false;
    connecting = false;
    notifyListeners();
  }

  /// البديل: «ادخل» مكان اللاعب اللي فصل
  void acceptSub() {
    final o = subOffer;
    subOffer = null;
    if (o == null) return notifyListeners();
    matchFromSearch = true;
    _send({'t': 'subAccept', 'code': o['code'], 'seat': o['seat'], 'name': name, 'char': ?char});
    notifyListeners();
  }

  /// البديل: «لا»، يكمل بحثه
  void declineSub() {
    final o = subOffer;
    subOffer = null;
    if (o != null) _send({'t': 'subDecline', 'code': o['code'], 'seat': o['seat']});
    _searchAgain();
    notifyListeners();
  }

  // العرض جاه قبل ما يدخل البحث: يرجع يدوّر عادي
  void _searchAgain() {
    final s = _lastSearch;
    if (room == null && s != null) _send({...s, 'noSub': true});
  }

  void clearNotice() {
    notice = null;
    notifyListeners();
  }

  /// اللعبة انفتحت من رابط غرفة (…/?room=1234): تدخل هالغرفة بس
  String? linkRoom;

  /// رابط الغرفة الحالية للمشاركة: نفس عنوان السيرفر (https)، ويفتح الغرفة بس
  String get roomLink {
    final u = Uri.parse(serverUrl);
    return Uri(scheme: u.scheme == 'wss' ? 'https' : 'http', host: u.host, port: u.hasPort ? u.port : null, queryParameters: {'room': code ?? ''}).toString();
  }

  /// المباراة جاية من «ابحث» (أونلاين)؟ الخبرة والتحديات والمتصدرين منها بس، مو من الغرفة المخصصة ولا التدريب
  bool matchFromSearch = false;

  Future<void> createRoom() async {
    matchFromSearch = false;
    Wallet.instance.roomStake = null;
    await _savePrefs();
    _open(() => _send({'t': 'create', 'name': name, 'char': ?char, 'fc': Friends.instance.myCode, 'profile': Progress.instance.publicProfile()}));
  }

  /// بحث عن لاعبين: mode 6 أو 4، و score هدف المباراة 54 أو 34
  /// «مع إشارة ميدان» (true) أو «بدون إشارة» (false): للبحث والتدريب
  bool signalsOn = true;

  /// الغرفة الحالية فيها إشارات؟
  bool get roomSignals => room?['signals'] != false;

  Future<void> search(int mode, int score) async {
    matchFromSearch = true;
    Wallet.instance.enterSearch();
    await _savePrefs();
    final msg = {'t': 'search', 'mode': mode, 'score': score, 'signals': signalsOn, 'name': name, 'char': ?char, 'fc': Friends.instance.myCode, 'profile': Progress.instance.publicProfile()};
    _lastSearch = msg;
    _open(() => _send(msg));
  }

  /// تدريب مع البوتات بدون وقت
  Future<void> practice(int mode) async {
    matchFromSearch = false;
    Wallet.instance.roomStake = null;
    await _savePrefs();
    _open(() => _send({'t': 'practice', 'mode': mode, 'signals': signalsOn, 'name': name, 'char': ?char, 'fc': Friends.instance.myCode, 'profile': Progress.instance.publicProfile()}));
  }

  Future<void> joinRoom(String roomCode) async {
    matchFromSearch = false;
    Wallet.instance.roomStake = null;
    await _savePrefs();
    final p = await SharedPreferences.getInstance();
    // لو نفس الغرفة اللي كنا فيها، نرجع لمقعدنا
    final savedToken = p.getString('room') == roomCode ? p.getString('token') : null;
    _open(() => _send({'t': 'join', 'code': roomCode, 'name': name, 'token': ?savedToken, 'char': ?char, 'fc': Friends.instance.myCode, 'profile': Progress.instance.publicProfile()}));
  }

  /// يحاول يتصل لين دقيقة ونص: سيرفر Render المجاني ينام إذا ما أحد يلعب، ويحتاج 30-60 ثانية يصحى
  static const _connectTries = 30;
  bool connecting = false;

  void _open(void Function() onOpen, {int attempt = 0}) {
    _wantConnection = true;
    error = null;
    kicked = false;
    connecting = true;
    _sub?.cancel();
    _ch?.sink.close();
    final WebSocketChannel ch;
    try {
      ch = WebSocketChannel.connect(Uri.parse(serverUrl));
    } catch (e) {
      connecting = false;
      error = tr('رابط السيرفر غير صحيح');
      notifyListeners();
      return;
    }
    _ch = ch;
    notifyListeners();
    ch.ready.timeout(const Duration(seconds: 15)).then((_) {
      if (_ch != ch) return;
      connected = true;
      connecting = false;
      onOpen();
      notifyListeners();
    }).catchError((_) {
      if (_ch != ch || !_wantConnection) return;
      // بالدور: يحاول لين يرجع النت (البوت يلعب مكانه وقتها)
      if (attempt + 1 < _connectTries || (code != null && token != null && _saved != null)) {
        // نعيد المحاولة: كل محاولة تصحّي السيرفر لين يرد
        Future.delayed(const Duration(seconds: 3), () {
          if (_wantConnection && !connected && _ch == ch) _open(onOpen, attempt: attempt + 1);
        });
      } else {
        connecting = false;
        error = tr('ما قدرت أتصل بالسيرفر، تأكد من الإنترنت وحاول مرة ثانية');
        notifyListeners();
      }
    });
    _sub = ch.stream.listen(_onMessage, onDone: () { if (_ch == ch) _onDone(); }, onError: (_) { if (_ch == ch) _onDone(); });
  }

  void _onDone() {
    connected = false;
    notifyListeners();
    if (_wantConnection && code != null && token != null) {
      // إعادة الاتصال تلقائياً لنفس المقعد
      Future.delayed(const Duration(seconds: 2), () {
        if (!_wantConnection || connected) return;
        _open(() => _send({'t': 'join', 'code': code, 'token': token, 'name': name, 'inGame': _saved != null, 'fc': Friends.instance.myCode, 'profile': Progress.instance.publicProfile()}));
      });
    }
  }

  void _onMessage(dynamic raw) {
    final m = jsonDecode(raw as String) as Map<String, dynamic>;
    switch (m['t']) {
      case 'joined':
        code = m['code'] as String;
        token = m['token'] as String;
        _savePrefs();
      case 'room':
        room = m;
        // الغرفة المخصصة بالغوازي: نفس نظام الأونلاين (ينخصم مع بداية المباراة، والفايز ياخذه وفوقه 70%)،
        // واللي غوازيه ما تكفي ما يقدر يدخل (وإذا المضيف رفع المبلغ فوق رصيده يطلع)
        final stake = m['stake'] as int?;
        if (stake != null && !matchFromSearch) {
          Wallet.instance.roomStake = stake;
          if (m['started'] != true && Wallet.instance.balance < stake) {
            leave();
            error = trf('غوازيك ما تكفي لهالغرفة (الدخول {0})', [stake]);
            notifyListeners();
            return;
          }
        }
        if (m['started'] != true) {
          view = null;
          _resetPending();
        }
        final searchMs = m['searchMsLeft'] as int?;
        searchEnds = searchMs == null ? null : DateTime.now().add(Duration(milliseconds: searchMs));
      case 'state':
        _pending.add((view: m['view'] as Map<String, dynamic>, at: DateTime.now()));
        _drain();
        return;
      case 'signal':
        final seat = m['seat'] as int;
        var incoming = (m['suits'] as List).cast<String>();
        if (m['big'] == true) {
          slapPending.add(seat);
          incoming = incoming.where((s) => s != 'J').toList();
          if (incoming.isEmpty) break;
        }
        // إذا اللاعب ضغط أكثر من نوع ورا بعض، تظهر كلها مع بعض ويتجدد الوقت
        final shown = signals[seat]?.suits ?? const <String>[];
        final sig = SuitSignal(seat, [...shown, ...incoming.where((s) => !shown.contains(s))]);
        signals[seat] = sig;
        Future.delayed(signalDuration, () {
          if (signals[sig.seat] == sig) {
            signals.remove(sig.seat);
            notifyListeners();
          }
        });
      case 'error':
        error = m['msg'] as String;
        // السيرفر رفض حركتي: نرجع للحالة الصحيحة
        if (_serverView != null) view = _serverView;
      case 'kicked':
        kicked = true;
        leave();
      case 'rejoinInfo':
        _checking = false;
        if (m['ok'] == true) {
          rejoinOffer = m;
        } else {
          // الدور خلص وهو مو موجود، أو دخل لاعب مكانه
          if (_saved != null) notice = tr('الدور اللي طلعت منه خلص أو انلغى أو دخل لاعب مكانك، وانحسبت لك خسارة');
          _lostGame();
          _close();
        }
      case 'seatLost':
        // رجع النت ومقعده راح
        final had = _saved != null || view != null;
        _lostGame();
        leave();
        if (had) notice = m['cancelled'] == true ? tr('الدور انلغى لأن كل اللاعبين فصلوا، وانحسبت لك خسارة') : tr('دخل لاعب مكانك بالدور، وانحسبت لك خسارة');
      case 'subOffer':
        subOffer = m;
      case 'seatEvent':
        final who = m['name'] as String? ?? '';
        final text = switch (m['kind']) {
          'gone' => trf('{0} فصل، والبوت يلعب مكانه', [who]),
          'back' => trf('{0} رجع للدور', [who]),
          _ => trf('{0} دخل مكان {1}', [who, m['old'] ?? '']),
        };
        final note = (text: text, at: DateTime.now());
        seatNote = note;
        Future.delayed(const Duration(seconds: 4), () {
          if (seatNote == note) {
            seatNote = null;
            notifyListeners();
          }
        });
      case 'subGone':
        subOffer = null;
        _searchAgain();
      case 'forfeited':
        break;
    }
    notifyListeners();
  }

  void _send(Map<String, dynamic> msg) => _ch?.sink.add(jsonEncode(msg));

  /// الحالات اللي وصلت تنطبق بالترتيب، وكل وحدة تنتظر لين يخلص أنميشن اللي قبلها
  void _drain() {
    _pendingTimer?.cancel();
    while (_pending.isNotEmpty) {
      final wait = _holdUntil.difference(DateTime.now());
      if (wait > Duration.zero) {
        _pendingTimer = Timer(wait, _drain);
        return;
      }
      final next = _pending.removeAt(0);
      _applyState(next.view, next.at);
    }
  }

  void _resetPending() {
    _pending.clear();
    _pendingTimer?.cancel();
    _holdUntil = DateTime.fromMillisecondsSinceEpoch(0);
    _serverView = null;
  }

  void _applyState(Map<String, dynamic> v, DateTime receivedAt) {
    final before = _serverView;
    _serverView = v;
    view = v;
    // الوقت من لحظة وصول الرسالة، مو من لحظة تطبيقها
    final ms = v['turnMsLeft'] as int?;
    deadline = ms == null ? null : receivedAt.add(Duration(milliseconds: ms));
    _holdUntil = DateTime.now().add(Duration(milliseconds: _animMs(before, v)));
    // الإحصائيات قبل المحفظة (المحفظة تنسى المبلغ بعد نهاية المباراة)
    Progress.instance.onState(code: code, view: v, mySeat: mySeat, online: Wallet.instance.roomStake != null && matchFromSearch);
    Wallet.instance.onState(code: code, phase: v['phase'] as String?, winner: v['winner'] as int?, myTeam: mySeat % 2);
    // الدور الشغّال ينحفظ (عشان لو فصل يرجع له)، ولما يخلص ينشال
    final running = room?['practice'] != true && v['phase'] != 'matchEnd';
    if (running && (_saved == null || _saved!['code'] != code)) {
      _saved = {'code': code, 'token': token, 'search': matchFromSearch, 'stake': Wallet.instance.roomStake};
      _saveGame();
    } else if (!running && _saved != null) {
      _saved = null;
      _saveGame();
    }
    notifyListeners();
  }

  /// كم ياخذ أنميشن التغيير من الحالة اللي قبل لهذي (توزيع، لمّ لمّة، طيران ورقة)
  static int _animMs(Map<String, dynamic>? a, Map<String, dynamic> b) {
    if (a == null) return 0;
    if (b['round'] != a['round'] && b['phase'] == 'bidding' && (b['bids'] as List).isEmpty) return 2650;
    if (b['round'] == a['round'] && (b['trickNo'] as int) > (a['trickNo'] as int)) return 2250;
    if (b['round'] == a['round'] && (b['trick'] as List).length > (a['trick'] as List).length) return 240;
    return 0;
  }

  /// حركتي تبين على طول: نعدّل الحالة عندنا لين يرد السيرفر بالحالة الصحيحة
  void _optimistic(Map<String, dynamic> Function(Map<String, dynamic> v) change) {
    final v = view;
    if (v == null) return;
    view = change(Map.of(v));
    deadline = null;
    notifyListeners();
  }


  void clearError() {
    error = null;
    notifyListeners();
  }

  // أوامر اللوبي
  void sit(int seat) => _send({'t': 'sit', 'seat': seat});
  Future<void> chooseChar(String id) async {
    char = id;
    startFriends();
    if (room != null) _send({'t': 'char', 'char': id});
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString('char', id);
  }
  void addBots() => _send({'t': 'addBots'});
  void kick(int seat) => _send({'t': 'kick', 'seat': seat});
  void start() => _send({'t': 'start'});
  void setMode(int mode) => _send({'t': 'mode', 'mode': mode});
  void setSignals(bool on) => _send({'t': 'signals', 'on': on});
  void setRoomStake(int value) => _send({'t': 'stake', 'value': value});
  void rematch() => _send({'t': 'rematch'});

  // أوامر اللعب
  void bid(Object value) {
    _send({'t': 'bid', 'value': value});
    if (!((view?['legalBids'] as List?)?.contains(value) ?? false)) return;
    _optimistic((v) => v
      ..['bids'] = [...v['bids'] as List, {'seat': mySeat, 'bid': value}]
      ..['legalBids'] = const []
      ..['turn'] = -1);
  }

  void chooseTrump(String suit) {
    _send({'t': 'trump', 'suit': suit});
    final v = view;
    if (v == null || v['phase'] != 'trump' || v['buyer'] != mySeat) return;
    _optimistic((v) => v
      ..['trump'] = suit
      ..['phase'] = 'playing'
      ..['legalCards'] = const []
      ..['turn'] = (mySeat + 1) % (v['players'] as int)); // أول واحد على يمين الشاري يبدأ
  }

  void play(String card) {
    _send({'t': 'play', 'card': card});
    final v = view;
    if (v == null || v['phase'] != 'playing' || v['turn'] != mySeat || !(v['legalCards'] as List).contains(card)) return;
    _optimistic((v) => v
      ..['hand'] = [for (final h in v['hand'] as List) if (h != card) h]
      ..['trick'] = [...v['trick'] as List, {'seat': mySeat, 'card': card}]
      ..['legalCards'] = const []
      // الدور للي بعدي، إلا إذا خلصت اللمّة (الفايز يعرفه السيرفر)
      ..['turn'] = (v['trick'] as List).length + 1 < (v['players'] as int) ? (mySeat + 1) % (v['players'] as int) : -1);
  }

  void answerBawan(bool accept) {
    _send({'t': 'bawan', 'accept': accept});
    _optimistic((v) => v..['bawanOffer'] = false);
  }
  void signal(List<String> suits) => _send({'t': 'signal', 'suits': suits});

  void leave() {
    // طلع من دور شغّال: البوت يلعب مكانه، ويقدر يرجع (القائمة تسأله)
    final keep = inRunningGame && _saved != null;
    Wallet.instance.onLeave(keepStake: keep);
    if (!keep && _saved != null && !started) {
      _saved = null;
      _saveGame();
    }
    _wantConnection = false;
    _sub?.cancel();
    _ch?.sink.close();
    _ch = null;
    connected = false;
    connecting = false;
    room = null;
    view = null;
    _resetPending();
    code = null;
    token = null;
    notifyListeners();
  }
}
