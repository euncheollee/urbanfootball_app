import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const _updateHideKey = 'update_hide_until';

class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.system_update, size: 42),
            const SizedBox(height: 16),

            const Text(
              '새로운 버전이 나왔어요',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),

            const Text(
              '업데이트하고 더 나은 환경에서\n서비스를 이용하세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _goToStore,
                child: const Text('업데이트 하기'),
              ),
            ),
            const SizedBox(height: 8),

            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final hideUntil = DateTime.now().add(const Duration(days: 7));
                await prefs.setInt(
                  _updateHideKey,
                  hideUntil.millisecondsSinceEpoch,
                );
                Navigator.pop(context);
              },
              child: const Text('나중에'),
            ),
          ],
        ),
      ),
    );
  }

  void _goToStore() async {
    const androidUrl = 'https://play.google.com/store/apps/details?id=패키지명';
    const iosUrl = 'https://apps.apple.com/app/id앱아이디';

    final uri = Uri.parse(Platform.isIOS ? iosUrl : androidUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
