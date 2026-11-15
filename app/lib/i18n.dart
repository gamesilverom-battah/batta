import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'i18n_en.dart';

/// لغة اللعبة: العربية (الأصل) أو الإنجليزي. كل النصوص بالكود عربي، وtr ترجعها إنجليزي لو اللغة إنجليزي
class Lang extends ChangeNotifier {
  Lang._();
  static final instance = Lang._();

  bool en = false;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    en = p.getString('lang') == 'en';
  }

  Future<void> set(bool english) async {
    if (en == english) return;
    en = english;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString('lang', english ? 'en' : 'ar');
  }
}

/// نص ثابت: بالإنجليزي لو فيه ترجمة، وإلا مثل ما هو
String tr(String ar) => Lang.instance.en ? (enStrings[ar] ?? ar) : ar;

/// نص فيه أرقام أو أسماء: القالب فيه {0} {1}... والقيم تنحط مكانها
String trf(String template, List<Object?> args) {
  var s = Lang.instance.en ? (enStrings[template] ?? template) : template;
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}
