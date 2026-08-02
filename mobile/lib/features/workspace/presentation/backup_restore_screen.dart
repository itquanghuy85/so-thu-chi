import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/theme/screen_neutrals.dart';
import '../../../core/theme/section_accents.dart';
import '../../../core/theme/visual_style_provider.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/widgets/section_app_bar.dart';
import '../data/backup_file_service.dart';
import '../data/workspace_repository.dart';

/// "Sao lưu & khôi phục" (Settings → Tuỳ chỉnh): exports the current
/// workspace's vaults/categories/customers/transactions to a JSON file
/// (same share-sheet pattern as Excel export — see `BackupService`'s doc
/// comment on the backend for exactly what's included/excluded), and
/// restores one back in as a brand-new workspace.
class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _exporting = false;
  bool _restoring = false;

  Future<void> _export() async {
    final workspace = ref.read(currentWorkspaceProvider);
    if (workspace == null || _exporting) return;
    setState(() => _exporting = true);
    try {
      final payload = await ref.read(workspaceRepositoryProvider).exportBackup(workspace.id);
      final dateSuffix = DateFormat('ddMMyyyy_HHmm').format(DateTime.now());
      final safeName = workspace.name.replaceAll(RegExp(r'[^\w\-]'), '_');
      final filename = 'SoThuChi_Backup_${safeName}_$dateSuffix.json';
      final savedAt = await saveBackupFile(payload, filename);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã lưu file sao lưu vào $savedAt'), duration: const Duration(seconds: 5)),
        );
      }
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể tạo file sao lưu';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _restore() async {
    if (_restoring) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final picked = result?.files.single;
    if (picked == null) return;

    Map<String, dynamic> payload;
    try {
      final bytes = picked.bytes ?? (picked.path != null ? await File(picked.path!).readAsBytes() : null);
      if (bytes == null) throw const FormatException();
      payload = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File không đúng định dạng backup')));
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Khôi phục backup?'),
        content: const Text(
          'Dữ liệu trong file sẽ được tạo thành một không gian làm việc MỚI (không ghi đè không gian hiện tại), '
          'với bạn là chủ sở hữu duy nhất. Ngân sách và giao dịch định kỳ không được khôi phục.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Khôi phục')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _restoring = true);
    try {
      final repository = ref.read(workspaceRepositoryProvider);
      final newWorkspaceId = await repository.restoreBackup(payload);
      final newWorkspace = await repository.getWorkspace(newWorkspaceId);
      await ref.read(workspaceNotifierProvider.notifier).selectWorkspace(newWorkspace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã khôi phục vào "${newWorkspace.name}"')));
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể khôi phục — file có thể bị hỏng hoặc không đúng định dạng';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = ref.watch(visualStyleProvider);
    final n = neutralsFor(style);
    final accent = sectionAccent(AppSection.settings, style);

    return Scaffold(
      backgroundColor: n.tint(accent),
      appBar: SectionAppBar(title: 'Sao lưu & khôi phục', style: style),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: n.cardDecoration(radius: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  CircleAvatar(backgroundColor: accent.withValues(alpha: 0.12), child: Icon(Icons.upload_outlined, color: accent)),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Sao lưu dữ liệu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: n.textPrimary))),
                ]),
                const SizedBox(height: 10),
                Text(
                  'Xuất túi tiền, danh mục, khách hàng và toàn bộ giao dịch của không gian làm việc hiện tại ra một file. '
                  'File được lưu vào Tải xuống và có thể gửi ngay qua Drive/Zalo/email để giữ bản sao trên "cloud" của riêng bạn.',
                  style: TextStyle(color: n.textSecondary, fontSize: 12.5),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: accent),
                    icon: _exporting
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.upload_outlined),
                    label: const Text('Sao lưu ngay'),
                    onPressed: _exporting ? null : _export,
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
                Row(children: [
                  CircleAvatar(backgroundColor: accent.withValues(alpha: 0.12), child: Icon(Icons.download_outlined, color: accent)),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Khôi phục từ file backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: n.textPrimary))),
                ]),
                const SizedBox(height: 10),
                Text(
                  'Chọn một file backup (.json) đã lưu trước đó. Dữ liệu sẽ được tạo thành một không gian làm việc mới — '
                  'không gian hiện tại của bạn không bị ảnh hưởng.',
                  style: TextStyle(color: n.textSecondary, fontSize: 12.5),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: _restoring
                        ? SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: accent))
                        : const Icon(Icons.download_outlined),
                    label: const Text('Chọn file & khôi phục'),
                    onPressed: _restoring ? null : _restore,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
