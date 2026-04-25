import 'package:flutter/widgets.dart';

bool isChineseLocale(BuildContext context) {
  return Localizations.localeOf(
    context,
  ).languageCode.toLowerCase().startsWith('zh');
}

String appText(BuildContext context, {required String zh, required String en}) {
  return isChineseLocale(context) ? zh : en;
}
