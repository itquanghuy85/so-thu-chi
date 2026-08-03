import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/screen_neutrals.dart';
import '../../../core/theme/section_accents.dart';
import '../../../core/theme/visual_style_provider.dart';
import '../../../shared/widgets/section_app_bar.dart';

/// The app's real installed version (`1.2.3`) + build number (`45`), read
/// from the platform at runtime — never hardcoded, so it can't drift out of
/// sync with what actually shipped.
final appPackageInfoProvider = FutureProvider<PackageInfo>((ref) => PackageInfo.fromPlatform());

const _developerName = 'Quang Huy';
const _phoneDisplay = '0964.09.59.79';
const _phoneDigits = '0964095979';
const _storeName = 'Huluca store';
const _storeAddress = '101 Hùng Vương, Hiệp Phước, Nhơn Trạch, Đồng Nai';

/// "Giới thiệu nhà phát triển" (Cài đặt → Tuỳ chỉnh).
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  Future<void> _call(BuildContext context) => _launch(context, Uri(scheme: 'tel', path: _phoneDigits));

  Future<void> _openZalo(BuildContext context) => _launch(context, Uri.parse('https://zalo.me/$_phoneDigits'));

  Future<void> _openMap(BuildContext context) =>
      _launch(context, Uri.parse('https://maps.google.com/?q=${Uri.encodeComponent('$_storeName, $_storeAddress')}'));

  Future<void> _launch(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể mở ứng dụng này trên máy của bạn')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(visualStyleProvider);
    final n = neutralsFor(style);
    final accent = sectionAccent(AppSection.settings, style);

    return Scaffold(
      backgroundColor: n.tint(accent),
      appBar: SectionAppBar(title: 'Giới thiệu', style: style),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [accent, Color.lerp(accent, Colors.black, 0.25)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8))],
                  ),
                  child: const Icon(Icons.savings_outlined, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 14),
                Text('Sổ Thu Chi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: n.textPrimary)),
                const SizedBox(height: 4),
                Text('Ứng dụng quản lý dòng tiền cho chủ shop & gia đình', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: n.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: n.cardDecoration(radius: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nhà phát triển', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: n.textPrimary)),
                const SizedBox(height: 14),
                _InfoTile(icon: Icons.person_outline, accent: accent, neutrals: n, label: 'Tên', value: _developerName),
                const SizedBox(height: 10),
                _InfoTile(
                  icon: Icons.phone_outlined,
                  accent: accent,
                  neutrals: n,
                  label: 'Điện thoại / Zalo',
                  value: _phoneDisplay,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(tooltip: 'Gọi điện', icon: Icon(Icons.call_outlined, color: accent), onPressed: () => _call(context)),
                      IconButton(tooltip: 'Mở Zalo', icon: Icon(Icons.chat_bubble_outline, color: accent), onPressed: () => _openZalo(context)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: n.cardDecoration(radius: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cửa hàng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: n.textPrimary)),
                const SizedBox(height: 14),
                _InfoTile(icon: Icons.storefront_outlined, accent: accent, neutrals: n, label: 'Tên cửa hàng', value: _storeName),
                const SizedBox(height: 10),
                _InfoTile(
                  icon: Icons.location_on_outlined,
                  accent: accent,
                  neutrals: n,
                  label: 'Địa chỉ',
                  value: _storeAddress,
                  trailing: IconButton(tooltip: 'Mở bản đồ', icon: Icon(Icons.map_outlined, color: accent), onPressed: () => _openMap(context)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Consumer(
              builder: (context, ref, _) {
                final infoAsync = ref.watch(appPackageInfoProvider);
                final label = infoAsync.when(
                  data: (info) => 'Sổ Thu Chi • Phiên bản ${info.version} (build ${info.buildNumber})',
                  loading: () => 'Sổ Thu Chi',
                  error: (_, _) => 'Sổ Thu Chi',
                );
                return Text(label, style: TextStyle(color: n.textSecondary, fontSize: 11));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final ScreenNeutrals neutrals;
  final String label;
  final String value;
  final Widget? trailing;

  const _InfoTile({required this.icon, required this.accent, required this.neutrals, required this.label, required this.value, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(radius: 18, backgroundColor: accent.withValues(alpha: 0.12), child: Icon(icon, size: 18, color: accent)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11.5, color: neutrals.textSecondary)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: neutrals.textPrimary)),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
