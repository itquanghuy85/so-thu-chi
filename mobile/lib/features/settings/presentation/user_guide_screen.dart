import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/screen_neutrals.dart';
import '../../../core/theme/section_accents.dart';
import '../../../core/theme/visual_style_provider.dart';
import '../../../shared/widgets/section_app_bar.dart';

class _GuideSection {
  final IconData icon;
  final AppSection accentSection;
  final String title;
  final List<String> steps;

  const _GuideSection({required this.icon, required this.accentSection, required this.title, required this.steps});
}

const _sections = <_GuideSection>[
  _GuideSection(
    icon: Icons.login,
    accentSection: AppSection.dashboard,
    title: 'Bắt đầu: Đăng nhập & Không gian làm việc',
    steps: [
      'Đăng nhập bằng email/mật khẩu hoặc bấm "Đăng nhập với Google" để vào nhanh.',
      'Lần đầu vào app, tạo "Không gian làm việc": chọn Cửa hàng (bán hàng, kho, nhân viên) hoặc Gia đình (thu chi sinh hoạt).',
      'Có mã mời từ người khác? Bấm "Có mã mời? Tham gia không gian có sẵn" ở màn chọn không gian làm việc.',
      'Muốn đổi qua không gian làm việc khác: Cài đặt → Đổi không gian làm việc.',
      'Mỗi không gian làm việc có túi tiền, giao dịch, danh mục, khách hàng... hoàn toàn riêng biệt.',
    ],
  ),
  _GuideSection(
    icon: Icons.dashboard_outlined,
    accentSection: AppSection.dashboard,
    title: 'Tổng quan (Dashboard)',
    steps: [
      'Xem tổng tài sản, biến động so với hôm qua — bấm biểu tượng mắt để ẩn/hiện số tiền.',
      'Chạm vào tên/ảnh đại diện ở góc trên bên trái để mở Trang cá nhân.',
      'Bấm biểu tượng bánh răng để vào Cài đặt.',
      '4 nút nhanh: Thu, Chi, Chuyển, Kiểm kê — dùng để tạo giao dịch hoặc đối chiếu túi tiền ngay lập tức.',
      'Nút "Nói" (biểu tượng micro): đọc giao dịch bằng giọng nói, ví dụ "thu năm trăm nghìn tiền mặt bán hàng" — app tự điền form để bạn xác nhận trước khi lưu.',
      '"Giao dịch gần đây": bấm vào bất kỳ dòng nào để xem chi tiết đầy đủ.',
      'Nếu có ngân sách sắp vượt hạn mức, một banner cảnh báo sẽ hiện ngay trên Dashboard.',
    ],
  ),
  _GuideSection(
    icon: Icons.receipt_long_outlined,
    accentSection: AppSection.transactions,
    title: 'Giao dịch',
    steps: [
      'Bấm nút "+" (góc dưới phải) để mở form tạo giao dịch — có 4 tab: Thu, Chi, Chuyển tiền, Công nợ.',
      'Thu/Chi: chọn danh mục bằng lưới icon màu, chọn túi tiền, nhập số tiền (tự hiện "X đồng" bằng chữ), ghi chú tuỳ chọn.',
      'Thu hàng có giá vốn: nhập thêm "Giá vốn hàng bán" để app tự tính lãi/lỗ ngay trên từng giao dịch.',
      'Chuyển tiền: chọn túi nguồn và túi đích.',
      'Công nợ có 2 tab con: "Bán thiếu" (khách nợ thêm) và "Trả nợ" (khách trả bớt/hết — có nút "Trả hết" điền nhanh đúng số còn nợ).',
      'Lọc danh sách theo thời gian (Hôm nay/Tuần/Tháng) và theo loại (Thu/Chi/Chuyển) ở đầu trang.',
      'Bấm vào một giao dịch để xem chi tiết đầy đủ: túi tiền, danh mục, ghi chú, người tạo, thời gian.',
      'Trong màn chi tiết: "Sửa giao dịch" (sửa lại thông tin), "Hủy giao dịch" (đánh dấu huỷ, vẫn giữ lại lịch sử), "Xoá vĩnh viễn" (xoá hẳn khỏi hệ thống, không khôi phục được).',
      'Bấm biểu tượng tải xuống ở góc trên để xuất danh sách giao dịch (theo bộ lọc đang chọn) ra file Excel.',
    ],
  ),
  _GuideSection(
    icon: Icons.account_balance_wallet_outlined,
    accentSection: AppSection.vaults,
    title: 'Túi tiền',
    steps: [
      'Xem tổng số dư và danh sách từng túi (tiền mặt, ngân hàng, ví điện tử...).',
      'Bấm "+" để tạo túi mới, có thể nhập số dư ban đầu.',
      'Bấm vào một túi để xem biến động 14 ngày gần nhất và toàn bộ lịch sử giao dịch của túi đó.',
      '"Kiểm kê túi này": đối chiếu số tiền thực tế đếm được với sổ sách — app tự tạo bút toán điều chỉnh nếu lệch.',
      'Xoá túi tiền (icon thùng rác trong màn chi tiết túi): chỉ xoá được nếu túi đó chưa từng phát sinh giao dịch nào.',
    ],
  ),
  _GuideSection(
    icon: Icons.people_outline,
    accentSection: AppSection.debt,
    title: 'Công nợ',
    steps: [
      'Xem danh sách khách hàng kèm số nợ hiện tại; lọc Tất cả / Đang nợ / Quá hạn; tìm kiếm theo tên hoặc SĐT (gõ không dấu vẫn tìm được).',
      'Bấm "+ Thêm khách" để thêm khách hàng mới.',
      'Bấm vào một khách hàng để xem tổng nợ, tổng đã mua, tổng đã trả, và toàn bộ lịch sử — có 2 nút nhanh "Tạo đơn bán thiếu" và "Ghi nhận trả nợ".',
      'Xoá khách hàng (icon thùng rác trong màn chi tiết khách hàng): chỉ xoá được khi khách đã hết nợ (số dư = 0).',
      'Bấm biểu tượng tải xuống để xuất danh sách khách hàng ra Excel.',
    ],
  ),
  _GuideSection(
    icon: Icons.pie_chart_outline,
    accentSection: AppSection.reports,
    title: 'Báo cáo',
    steps: [
      '4 thẻ tổng quan: Dòng tiền, Lợi nhuận, Tổng tài sản, Công nợ — bấm vào để xem chi tiết từng loại.',
      '"Dòng tiền": biểu đồ thu/chi theo Tuần/Tháng/Năm hoặc chọn khoảng ngày tuỳ ý, kèm bảng phân tích theo danh mục.',
      '"Lợi nhuận": biểu đồ lãi/lỗ theo từng ngày (hoặc tháng nếu xem khoảng dài), có bảng số liệu đầy đủ.',
      '"Lợi nhuận" ở đây = Thu − Chi (chưa trừ giá vốn hàng bán riêng, xem "Lãi" trên từng giao dịch để biết lãi thực theo giá vốn).',
      'Bấm biểu tượng tải xuống để xuất báo cáo tổng hợp tháng hiện tại ra Excel.',
    ],
  ),
  _GuideSection(
    icon: Icons.pie_chart_rounded,
    accentSection: AppSection.budget,
    title: 'Ngân sách',
    steps: [
      'Cài đặt → Tuỳ chỉnh → Ngân sách.',
      'Đặt hạn mức chi tiêu theo danh mục cụ thể, hoặc để trống danh mục để đặt hạn mức tổng cho cả tháng.',
      'Hạn mức luôn tính theo tháng hiện tại; sửa hạn mức có hiệu lực ngay, không cần tạo lại từng tháng.',
      'Khi chi tiêu vượt 80% hạn mức, một banner cảnh báo hiện trên Dashboard và app gửi thông báo đẩy.',
    ],
  ),
  _GuideSection(
    icon: Icons.repeat_rounded,
    accentSection: AppSection.recurring,
    title: 'Giao dịch định kỳ',
    steps: [
      'Cài đặt → Tuỳ chỉnh → Giao dịch định kỳ.',
      'Tạo mẫu giao dịch lặp lại (tiền điện, tiền nhà, lương nhân viên...) theo chu kỳ Ngày/Tuần/Tháng.',
      'App tự tạo giao dịch thật khi đến hạn mỗi lần mở Dashboard — không cần bấm tạo thủ công.',
      'Có thể tạm dừng hoặc xoá một giao dịch định kỳ bất cứ lúc nào.',
    ],
  ),
  _GuideSection(
    icon: Icons.badge_outlined,
    accentSection: AppSection.shift,
    title: 'Ca làm việc',
    steps: [
      'Cài đặt → Tuỳ chỉnh → Ca làm việc — dành cho shop có thu ngân theo ca.',
      '"Mở ca": chốt số dư tiền mặt đầu ca.',
      '"Kết thúc ca": chốt lại số dư cuối ca, app tự tính tổng thu/chi phát sinh trong ca đó.',
      'Xem lại lịch sử các ca đã đóng để đối chiếu.',
    ],
  ),
  _GuideSection(
    icon: Icons.fact_check_outlined,
    accentSection: AppSection.dailyClosing,
    title: 'Chốt sổ cuối ngày',
    steps: [
      'Cài đặt → Tuỳ chỉnh → Chốt sổ cuối ngày.',
      'Nhập số dư thực tế đếm được của từng túi tiền — app so sánh ngay với số dư sổ sách và báo chênh lệch.',
      'Mỗi ngày chỉ chốt được một lần; xem lại lịch sử chốt sổ các ngày trước trong cùng màn hình.',
    ],
  ),
  _GuideSection(
    icon: Icons.category_outlined,
    accentSection: AppSection.category,
    title: 'Danh mục thu/chi',
    steps: [
      'Cài đặt → Tuỳ chỉnh → Danh mục thu/chi.',
      'App có sẵn danh mục mặc định (Bán hàng, Nhập hàng, Lương...); có thể thêm mới hoặc đổi tên.',
      'Không xoá được danh mục đã có giao dịch sử dụng — để giữ đúng lịch sử.',
    ],
  ),
  _GuideSection(
    icon: Icons.mic_none_outlined,
    accentSection: AppSection.dashboard,
    title: 'Nhập liệu bằng giọng nói',
    steps: [
      'Bấm nút "Nói" trên Dashboard, cho phép quyền micro nếu được hỏi.',
      'Nói rõ loại giao dịch, số tiền, và túi/danh mục nếu có thể — ví dụ "chi hai trăm nghìn tiền điện".',
      'App sẽ điền sẵn một form giao dịch từ lời nói — luôn kiểm tra lại và bấm Lưu, app không tự lưu khi chưa xác nhận.',
      'Nếu nói không rõ hoặc câu quá phức tạp, chỉnh sửa trực tiếp trên form trước khi lưu.',
    ],
  ),
  _GuideSection(
    icon: Icons.backup_outlined,
    accentSection: AppSection.settings,
    title: 'Sao lưu & khôi phục',
    steps: [
      'Cài đặt → Tuỳ chỉnh → Sao lưu & khôi phục.',
      '"Sao lưu ngay": xuất toàn bộ túi tiền, danh mục, khách hàng, giao dịch ra một file .json, lưu vào thư mục Tải xuống và mở hộp thoại chia sẻ để gửi lên Drive/Zalo/email giữ làm bản sao dự phòng.',
      '"Chọn file & khôi phục": chọn lại một file backup đã lưu trước đó — dữ liệu sẽ được tạo thành một không gian làm việc HOÀN TOÀN MỚI, không ghi đè lên dữ liệu hiện tại.',
      'Ngân sách và giao dịch định kỳ chưa được sao lưu/khôi phục — cần tạo lại thủ công nếu cần sau khi khôi phục.',
    ],
  ),
  _GuideSection(
    icon: Icons.fingerprint,
    accentSection: AppSection.security,
    title: 'Bảo mật',
    steps: [
      'Cài đặt → Bảo mật → PIN / Vân tay: đặt mã PIN 6 số để khoá app; nếu máy hỗ trợ, có thể bật mở khoá nhanh bằng vân tay/khuôn mặt.',
      'App tự khoá lại nếu rời ứng dụng quá 5 phút hoặc khi mở lại sau khi tắt hẳn.',
      '"Lịch sử chỉnh sửa": xem nhật ký ai đã sửa/huỷ giao dịch nào, khi nào — giúp minh bạch khi có nhiều người dùng chung không gian làm việc.',
      '"Xoá tài khoản" (trong Bảo mật hoặc Trang cá nhân): xoá vĩnh viễn tài khoản và dữ liệu. Nếu đang sở hữu không gian làm việc có người khác, cần chuyển quyền hoặc xoá hết thành viên trước.',
    ],
  ),
  _GuideSection(
    icon: Icons.account_circle_outlined,
    accentSection: AppSection.settings,
    title: 'Trang cá nhân',
    steps: [
      'Mở bằng cách chạm vào tên/ảnh đại diện trên Dashboard, hoặc chạm vào thẻ thông tin ở đầu trang Cài đặt.',
      'Chạm vào biểu tượng máy ảnh trên ảnh đại diện để đổi ảnh (chọn từ thư viện ảnh).',
      'Sửa Họ tên, Số điện thoại rồi bấm "Lưu thay đổi". Email dùng để đăng nhập nên không đổi được ở đây.',
      '"Đổi mật khẩu": cần nhập đúng mật khẩu hiện tại trước khi đặt mật khẩu mới.',
      '"Xoá tài khoản": xem mục Bảo mật ở trên.',
    ],
  ),
  _GuideSection(
    icon: Icons.palette_outlined,
    accentSection: AppSection.settings,
    title: 'Giao diện & Thành tích',
    steps: [
      'Cài đặt → chọn 1 trong 3 giao diện: Cổ điển (gọn gàng), Tối (nền tối, chuyên nghiệp), hoặc Game Leon (vui nhộn, có linh vật Leon).',
      'Bấm huy hiệu "Lv.N" trên Dashboard để xem cấp độ, nhiệm vụ tuần, và các huy hiệu thành tích đã đạt được.',
      'Ghi giao dịch, kiểm kê khớp sổ, mời thành viên... đều cộng điểm kinh nghiệm (XP) để lên cấp.',
    ],
  ),
  _GuideSection(
    icon: Icons.group_add_outlined,
    accentSection: AppSection.member,
    title: 'Thành viên & phân quyền',
    steps: [
      'Cài đặt → Không gian làm việc → Thành viên.',
      'Xem/sao chép/tạo lại mã mời để chia sẻ cho người khác tham gia không gian làm việc.',
      'Chủ sở hữu (Owner) có thể đổi vai trò từng thành viên: Quản lý, Thu ngân, Thành viên — hoặc xoá thành viên khỏi không gian.',
      'Thu ngân chỉ thấy và thao tác được trên túi tiền được gán riêng cho mình.',
    ],
  ),
];

/// "Hướng dẫn sử dụng" (Cài đặt → Trợ giúp) — hướng dẫn từng tính năng thật
/// sự có trong app, theo đúng thứ tự người dùng thường gặp trong menu.
class UserGuideScreen extends ConsumerWidget {
  const UserGuideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(visualStyleProvider);
    final n = neutralsFor(style);
    final accent = sectionAccent(AppSection.settings, style);

    return Scaffold(
      backgroundColor: n.tint(accent),
      appBar: SectionAppBar(title: 'Hướng dẫn sử dụng', style: style),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _sections.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final section = _sections[index];
          final sectionColor = sectionAccent(section.accentSection, style);
          return Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Container(
              decoration: n.cardDecoration(radius: 14),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                leading: CircleAvatar(radius: 18, backgroundColor: sectionColor.withValues(alpha: 0.12), child: Icon(section.icon, size: 18, color: sectionColor)),
                title: Text(section.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: n.textPrimary)),
                iconColor: sectionColor,
                collapsedIconColor: n.textSecondary,
                childrenPadding: const EdgeInsets.fromLTRB(20, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final step in section.steps)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(width: 5, height: 5, decoration: BoxDecoration(color: sectionColor, shape: BoxShape.circle)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(step, style: TextStyle(fontSize: 13, color: n.textPrimary, height: 1.45))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
