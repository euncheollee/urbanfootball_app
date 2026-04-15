import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const _updateHideKey = 'update_hide_until';
const Color pointColor = Color(0xFF2FCD30);

class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🔥 아이콘
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: pointColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.system_update_alt_rounded,
                size: 30,
                color: pointColor,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              '새로운 버전이 나왔어요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 12),

            const Text(
              '더 나은 기능과 안정성을 위해\n최신 버전으로 업데이트해주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 26),

            // 🔥 업데이트 버튼
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: pointColor,
                  foregroundColor: Colors.white, // 글씨색
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _goToStore,
                child: const Text(
                  '업데이트 하기',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // 🔥 나중에 버튼
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: pointColor, // 글씨색
              ),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final hideUntil = DateTime.now().add(const Duration(days: 7));
                await prefs.setInt(
                  _updateHideKey,
                  hideUntil.millisecondsSinceEpoch,
                );
                Navigator.pop(context);
              },
              child: const Text(
                '나중에',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToStore() async {
    const androidUrl =
        'https://play.google.com/store/apps/details?id=com.urbanfootball.android';
    const iosUrl = 'https://apps.apple.com/app/com.urbanfootball.app';

    final uri = Uri.parse(Platform.isIOS ? iosUrl : androidUrl);

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
