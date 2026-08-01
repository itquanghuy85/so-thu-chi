import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import 'onboarding_notifier.dart';

class _OnboardingSlide {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _OnboardingSlide({required this.icon, required this.color, required this.title, required this.description});
}

const _slides = [
  _OnboardingSlide(
    icon: Icons.savings_rounded,
    color: AppColors.primary,
    title: 'Chào mừng đến với Sổ Thu Chi!',
    description: 'Quản lý thu chi cho shop hay gia đình bạn, đơn giản và rõ ràng — không cần biết kế toán.',
  ),
  _OnboardingSlide(
    icon: Icons.swap_horiz_rounded,
    color: AppColors.transfer,
    title: 'Ghi sổ chỉ trong vài giây',
    description: 'Bấm Thu, Chi hoặc Chuyển tiền ngay trên màn hình chính — chọn túi tiền, nhập số tiền, xong!',
  ),
  _OnboardingSlide(
    icon: Icons.mic_none_rounded,
    color: AppColors.debt,
    title: 'Hoặc chỉ cần... nói ra',
    description: 'Bấm nút "Nói" và đọc ví dụ "thu 500 nghìn tiền mặt bán hàng" — app sẽ tự điền sẵn cho bạn kiểm tra trước khi lưu.',
  ),
  _OnboardingSlide(
    icon: Icons.emoji_events_rounded,
    color: Color(0xFFE0A020),
    title: 'Vui hơn cùng Leon',
    description: 'Ghi sổ đều đặn để lên cấp, hoàn thành nhiệm vụ tuần và mở khoá huy chương. Thử đổi sang giao diện "Game Leon" trong Cài đặt!',
  ),
  _OnboardingSlide(
    icon: Icons.cloud_off_rounded,
    color: AppColors.income,
    title: 'Mất mạng vẫn ghi sổ được',
    description: 'Không có Internet? App vẫn cho bạn xem dữ liệu đã lưu và ghi giao dịch mới — tự động đồng bộ khi có mạng trở lại.',
  ),
];

/// First-launch intro tour, shown once (per device) right after
/// login/register succeeds and before the workspace picker — see the
/// redirect in app.dart. Dismissing (skip or finishing the last slide)
/// persists via [onboardingProvider] so it never shows again on this
/// device.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() => ref.read(onboardingProvider.notifier).markSeen();

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _slides.length - 1;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Bỏ qua', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(color: slide.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                          child: Icon(slide.icon, size: 64, color: slide.color),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index ? _slides[_index].color : AppColors.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _slides[_index].color),
                  onPressed: isLast
                      ? _finish
                      : () => _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                  child: Text(isLast ? 'Bắt đầu ngay' : 'Tiếp theo'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
