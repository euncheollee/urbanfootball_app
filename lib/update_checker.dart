import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _updateHideKey = 'update_hide_until';

Future<bool> shouldShowUpdatePopup() async {
  final prefs = await SharedPreferences.getInstance();

  // 1주일 숨김 체크
  final hideUntilMillis = prefs.getInt(_updateHideKey);
  if (hideUntilMillis != null &&
      DateTime.now().isBefore(
        DateTime.fromMillisecondsSinceEpoch(hideUntilMillis),
      )) {
    return false;
  }

  // 현재 앱 버전
  final info = await PackageInfo.fromPlatform();
  final currentVersion = info.version;

  // 서버 최신 버전
  final res = await http.get(
    Uri.parse('https://urbanfootball.co.kr/app/version.json'),
  );
  if (res.statusCode != 200) return false;

  final latestVersion = jsonDecode(res.body)['latest_version'];

  return _isUpdateAvailable(currentVersion, latestVersion);
}

bool _isUpdateAvailable(String current, String latest) {
  final c = current.split('.').map(int.parse).toList();
  final l = latest.split('.').map(int.parse).toList();

  for (int i = 0; i < l.length; i++) {
    final cv = i < c.length ? c[i] : 0;
    final lv = l[i];
    if (cv < lv) return true;
    if (cv > lv) return false;
  }
  return false;
}
