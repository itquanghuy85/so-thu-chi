import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/debt/domain/customer.dart';
import '../../features/reports/domain/cashflow_report.dart';
import '../../features/transaction/domain/transaction.dart';
import '../../features/transaction/presentation/transaction_display.dart';

final _dateFormat = DateFormat('HH:mm dd/MM/yyyy', 'vi_VN');

/// Matches `MainActivity.kt`'s `saveToDownloads` — saves into the public
/// "Tải xuống" folder via MediaStore so the file is actually findable in
/// any file manager, instead of the app-private directory used previously.
const _downloadsChannel = MethodChannel('com.moneyflow.mobile/downloads');
const _xlsxMimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// Generates a `.xlsx` workbook for one of the app's exportable datasets
/// (Giao dịch / Công nợ / Báo cáo) and opens the OS share sheet so the user
/// can save it or hand it straight to a bookkeeper (Zalo, email, Drive,
/// ...). Values are written as real Excel numbers (not formatted strings)
/// so the file is actually usable for further calculation, not just a
/// printout.
class ExcelExportService {
  const ExcelExportService();

  Future<String> exportTransactions({
    required List<Transaction> transactions,
    required String periodLabel,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];
    sheet.appendRow([
      TextCellValue('Ngày giờ'),
      TextCellValue('Loại'),
      TextCellValue('Số tiền'),
      TextCellValue('Túi/Danh mục'),
      TextCellValue('Ghi chú'),
      TextCellValue('Trạng thái'),
    ]);
    for (final t in transactions) {
      sheet.appendRow([
        TextCellValue(_dateFormat.format(t.createdAt)),
        TextCellValue(transactionTypeLabel(t.type)),
        IntCellValue(t.amount.toInt() * (t.type == TransactionType.expense || t.type == TransactionType.debtIncrease ? -1 : 1)),
        TextCellValue(transactionDescription(t)),
        TextCellValue(t.note ?? ''),
        TextCellValue(t.isVoided ? 'Đã hủy' : (t.pending ? 'Chờ đồng bộ' : 'Hoàn tất')),
      ]);
    }
    _autoFitColumns(sheet, columnCount: 6);
    return _saveAndShare(excel, 'GiaoDich_${_safeFileSuffix(periodLabel)}.xlsx');
  }

  Future<String> exportCustomers({required List<Customer> customers}) async {
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];
    sheet.appendRow([
      TextCellValue('Tên khách hàng'),
      TextCellValue('Số điện thoại'),
      TextCellValue('Số dư nợ'),
      TextCellValue('Ngày tạo'),
    ]);
    for (final c in customers) {
      sheet.appendRow([
        TextCellValue(c.name),
        TextCellValue(c.phone ?? ''),
        IntCellValue(c.debtBalance.toInt()),
        TextCellValue(c.createdAt != null ? DateFormat('dd/MM/yyyy', 'vi_VN').format(c.createdAt!) : ''),
      ]);
    }
    _autoFitColumns(sheet, columnCount: 4);
    return _saveAndShare(excel, 'CongNo_${_safeFileSuffix(DateFormat('dd-MM-yyyy').format(DateTime.now()))}.xlsx');
  }

  Future<String> exportSummaryReport({
    required CashflowReport report,
    required num totalAssets,
    required num totalDebt,
    required String periodLabel,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];
    sheet.appendRow([TextCellValue('Báo cáo tổng hợp — $periodLabel')]);
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('Chỉ tiêu'), TextCellValue('Số tiền (đ)')]);
    final rows = <(String, num)>[
      ('Tổng thu', report.totalIncome),
      if (report.totalCost > 0) ('Giá vốn hàng bán', report.totalCost),
      ('Tổng chi', report.totalExpense),
      ('Lợi nhuận', report.grossProfit),
      ('Dòng tiền thuần', report.netCashflow),
      ('Tổng tài sản', totalAssets),
      ('Công nợ phải thu', totalDebt),
    ];
    for (final (label, value) in rows) {
      sheet.appendRow([TextCellValue(label), IntCellValue(value.toInt())]);
    }
    _autoFitColumns(sheet, columnCount: 2);
    return _saveAndShare(excel, 'BaoCao_${_safeFileSuffix(periodLabel)}.xlsx');
  }

  void _autoFitColumns(Sheet sheet, {required int columnCount}) {
    for (var i = 0; i < columnCount; i++) {
      sheet.setColumnAutoFit(i);
    }
  }

  String _safeFileSuffix(String label) => _stripDiacritics(label).replaceAll(RegExp(r'[^\w\-]'), '_');

  static String _stripDiacritics(String input) {
    const from = 'àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ'
        'ÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬÈÉẺẼẸÊỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴĐ';
    const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'
        'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
    final buffer = StringBuffer();
    for (final ch in input.split('')) {
      final idx = from.indexOf(ch);
      buffer.write(idx == -1 ? ch : to[idx]);
    }
    return buffer.toString();
  }

  /// Saves into the public "Tải xuống" (Downloads) folder via MediaStore
  /// (`MainActivity.kt`'s `saveToDownloads`) so the file is actually
  /// findable afterward in any file manager or the Files app — the
  /// previous location (`Android/data/<package>/files/`, app-private
  /// external storage) technically worked but isn't reasonably browsable by
  /// a normal user, which was the original complaint this replaces. Also
  /// writes a temp copy for the OS share sheet, so "send straight to
  /// Zalo/email" still works alongside the Downloads save. Falls back to
  /// the old app-private-directory approach if the native call fails (non-
  /// Android platform, or a very old Android version without the legacy
  /// storage permission) rather than the export failing outright. Returns
  /// where the file landed so the caller can tell the user.
  Future<String> _saveAndShare(Excel excel, String filename) async {
    final bytes = excel.encode();
    if (bytes == null) throw StateError('Không thể tạo file Excel');

    String savedLocation;
    if (Platform.isAndroid) {
      try {
        final result = await _downloadsChannel.invokeMethod<String>('saveToDownloads', {
          'fileName': filename,
          'mimeType': _xlsxMimeType,
          'bytes': Uint8List.fromList(bytes),
        });
        savedLocation = result ?? 'Tải xuống/$filename';
      } catch (_) {
        savedLocation = await _saveToAppDirectory(bytes, filename);
      }
    } else {
      savedLocation = await _saveToAppDirectory(bytes, filename);
    }

    final tempDir = await getTemporaryDirectory();
    final shareFile = File('${tempDir.path}/$filename');
    await shareFile.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(shareFile.path)], text: 'Sổ Thu Chi — $filename');

    return savedLocation;
  }

  Future<String> _saveToAppDirectory(List<int> bytes, String filename) async {
    Directory dir;
    try {
      dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    } catch (_) {
      dir = await getTemporaryDirectory();
    }
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

final excelExportService = ExcelExportService();
