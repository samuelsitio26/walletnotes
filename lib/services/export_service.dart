import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';

class ExportService {
  static final _dateFormat = DateFormat('yyyy-MM-dd');
  static final _fileTimestamp = DateFormat('yyyyMMdd_HHmm');

  /// Export daftar transaksi ke file CSV lalu share
  static Future<void> exportTransactionsToCSV(
    List<Transaction> transactions,
  ) async {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('Tanggal,Judul,Tipe,Kategori,Jumlah (Rp),Catatan');

    for (final t in transactions) {
      final date = _dateFormat.format(t.date);
      final type = t.type == 'income' ? 'Pemasukan' : 'Pengeluaran';
      // Escape koma dalam string dengan tanda kutip
      final title = _escapeCSV(t.title);
      final category = _escapeCSV(t.category);
      final note = _escapeCSV(t.note ?? '');

      buffer.writeln(
        '$date,$title,$type,$category,${t.amount.toStringAsFixed(0)},$note',
      );
    }

    final dir = await getTemporaryDirectory();
    final fileName = 'walletnotes_${_fileTimestamp.format(DateTime.now())}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buffer.toString(), encoding: utf8);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv', name: fileName)],
        subject: 'WalletNotes - Export Transaksi',
        text:
            'Berikut data transaksi saya dari aplikasi WalletNotes.\nTotal: ${transactions.length} transaksi.',
      ),
    );
  }

  static String _escapeCSV(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
