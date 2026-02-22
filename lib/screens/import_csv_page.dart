import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/database_helper.dart';

class ImportCsvPage extends StatefulWidget {
  const ImportCsvPage({super.key});

  @override
  State<ImportCsvPage> createState() => _ImportCsvPageState();
}

class _ImportCsvPageState extends State<ImportCsvPage> {
  List<List<dynamic>> _csvRows = [];
  List<Transaction> _previewTransactions = [];
  bool _isLoading = false;
  bool _isParsed = false;
  String _errorMsg = '';
  int _importedCount = 0;

  // Mapping kolom: index dalam CSV
  int _colDate = 0;
  int _colTitle = 1;
  int _colAmount = 2;
  int _colType = 3; // "income"/"expense" atau "debit"/"kredit"
  final int _colCategory = -1; // -1 = tidak ada, gunakan default
  String _defaultCategory = 'Lainnya';

  final _categories = [
    'Makanan',
    'Transportasi',
    'Belanja',
    'Tagihan',
    'Hiburan',
    'Kesehatan',
    'Pendidikan',
    'Gaji',
    'Bonus',
    'Investasi',
    'Lainnya',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Import CSV Bank',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.teal.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard(),
          const SizedBox(height: 16),
          _buildPickFileButton(),
          if (_errorMsg.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildError(),
          ],
          if (_isParsed && !_isLoading) ...[
            const SizedBox(height: 20),
            _buildColumnMapper(),
            const SizedBox(height: 16),
            _buildPreviewTable(),
            const SizedBox(height: 20),
            _buildImportButton(),
          ],
          if (_importedCount > 0) ...[
            const SizedBox(height: 16),
            _buildSuccessCard(),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ─── Info Card ────────────────────────────────────────────────────
  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.teal.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Format CSV yang didukung',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Ekspor riwayat transaksi dari internet banking ke format CSV\n'
            '• Kolom minimal: Tanggal, Keterangan, Jumlah, Tipe\n'
            '• Baris pertama dapat berupa header (akan dilewati)\n'
            '• Format tanggal: YYYY-MM-DD atau DD/MM/YYYY\n'
            '• Tipe: income/pemasukan/kredit atau expense/pengeluaran/debit',
            style: TextStyle(
              color: Colors.teal.shade800,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickFileButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _pickFile,
      icon: const Icon(Icons.upload_file),
      label: Text(_isParsed ? 'Ganti File CSV' : 'Pilih File CSV'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMsg,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Column Mapper ────────────────────────────────────────────────
  Widget _buildColumnMapper() {
    final colCount = _csvRows.isNotEmpty ? _csvRows[0].length : 4;
    final colOptions = List.generate(colCount, (i) => i);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Petakan Kolom CSV',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          _colDropdown(
            'Kolom Tanggal',
            _colDate,
            colOptions,
            (v) => setState(() {
              _colDate = v!;
              _regeneratePreview();
            }),
          ),
          _colDropdown(
            'Kolom Keterangan/Judul',
            _colTitle,
            colOptions,
            (v) => setState(() {
              _colTitle = v!;
              _regeneratePreview();
            }),
          ),
          _colDropdown(
            'Kolom Jumlah',
            _colAmount,
            colOptions,
            (v) => setState(() {
              _colAmount = v!;
              _regeneratePreview();
            }),
          ),
          _colDropdown(
            'Kolom Tipe (income/expense)',
            _colType,
            colOptions,
            (v) => setState(() {
              _colType = v!;
              _regeneratePreview();
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Kategori Default: ', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _defaultCategory,
                  isExpanded: true,
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _defaultCategory = v!;
                    _regeneratePreview();
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _colDropdown(
    String label,
    int current,
    List<int> options,
    void Function(int?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: current,
            items: options
                .map(
                  (i) =>
                      DropdownMenuItem(value: i, child: Text('Kolom ${i + 1}')),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // ─── Preview Table ────────────────────────────────────────────────
  Widget _buildPreviewTable() {
    if (_previewTransactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('Tidak ada data yang bisa diparsing')),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              'Preview (${_previewTransactions.length} akan diimport)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DataTable(
              columnSpacing: 12,
              headingRowColor: WidgetStateProperty.all(Colors.teal.shade50),
              columns: const [
                DataColumn(label: Text('Tanggal')),
                DataColumn(label: Text('Judul')),
                DataColumn(label: Text('Tipe')),
                DataColumn(label: Text('Jumlah')),
              ],
              rows: _previewTransactions.take(10).map((t) {
                final isIncome = t.type == 'income';
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        DateFormat('dd/MM/yy').format(t.date),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    DataCell(
                      Text(
                        t.title.length > 20
                            ? '${t.title.substring(0, 20)}…'
                            : t.title,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (isIncome ? Colors.green : Colors.red)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isIncome ? 'Masuk' : 'Keluar',
                          style: TextStyle(
                            fontSize: 11,
                            color: isIncome ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        'Rp ${t.amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isIncome
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          if (_previewTransactions.length > 10)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '... dan ${_previewTransactions.length - 10} baris lainnya',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImportButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _importData,
      icon: const Icon(Icons.save_alt),
      label: Text('Import ${_previewTransactions.length} Transaksi'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSuccessCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700),
          const SizedBox(width: 12),
          Text(
            '$_importedCount transaksi berhasil diimport!',
            style: TextStyle(
              color: Colors.green.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Logic ────────────────────────────────────────────────────────
  Future<void> _pickFile() async {
    setState(() {
      _errorMsg = '';
      _isLoading = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final file = File(result.files.single.path!);
      final content = await file.readAsString();

      // Coba parse dengan berbagai delimiter
      List<List<dynamic>> rows = [];
      for (final eol in ['\n', '\r\n', '\r']) {
        try {
          rows = const CsvToListConverter(eol: '\n').convert(content, eol: eol);
          if (rows.length > 1) break;
        } catch (_) {}
      }

      if (rows.length < 2) {
        setState(() {
          _errorMsg = 'File CSV tidak valid atau terlalu sedikit baris data.';
          _isLoading = false;
        });
        return;
      }

      // Cek apakah baris pertama adalah header
      final firstRow = rows[0];
      bool hasHeader = firstRow.any((cell) {
        final s = cell.toString().toLowerCase();
        return [
          'tanggal',
          'date',
          'keterangan',
          'description',
          'jumlah',
          'amount',
        ].contains(s);
      });

      setState(() {
        _csvRows = hasHeader ? rows.skip(1).toList() : rows;
        _isParsed = true;
        _isLoading = false;
        _importedCount = 0;
      });

      _regeneratePreview();
    } catch (e) {
      setState(() {
        _errorMsg = 'Gagal membaca file: $e';
        _isLoading = false;
      });
    }
  }

  void _regeneratePreview() {
    final parsed = <Transaction>[];
    for (final row in _csvRows) {
      try {
        if (row.length <= _colDate ||
            row.length <= _colTitle ||
            row.length <= _colAmount) {
          continue;
        }

        final dateStr = row[_colDate].toString().trim();
        final title = row[_colTitle].toString().trim();
        final amountStr = row[_colAmount]
            .toString()
            .replaceAll(RegExp(r'[Rp\s\.]'), '')
            .replaceAll(',', '.');
        final typeStr = _colType < row.length
            ? row[_colType].toString().trim().toLowerCase()
            : 'expense';

        if (title.isEmpty || amountStr.isEmpty) continue;

        final amount = double.tryParse(amountStr);
        if (amount == null || amount <= 0) continue;

        final date = _parseDate(dateStr);
        if (date == null) continue;

        String type = 'expense';
        if ([
          'income',
          'pemasukan',
          'kredit',
          'cr',
          'masuk',
        ].contains(typeStr)) {
          type = 'income';
        }

        final category = _colCategory >= 0 && _colCategory < row.length
            ? row[_colCategory].toString().trim()
            : _defaultCategory;

        parsed.add(
          Transaction(
            title: title,
            amount: amount,
            type: type,
            category: category,
            date: date,
          ),
        );
      } catch (_) {
        // skip baris yang gagal parse
      }
    }

    setState(() => _previewTransactions = parsed);
  }

  DateTime? _parseDate(String value) {
    final formats = [
      DateFormat('yyyy-MM-dd'),
      DateFormat('dd/MM/yyyy'),
      DateFormat('dd-MM-yyyy'),
      DateFormat('MM/dd/yyyy'),
      DateFormat('d/M/yyyy'),
      DateFormat('yyyy/MM/dd'),
    ];
    for (final fmt in formats) {
      try {
        return fmt.parseStrict(value);
      } catch (_) {}
    }
    return null;
  }

  Future<void> _importData() async {
    if (_previewTransactions.isEmpty) return;

    setState(() => _isLoading = true);

    int count = 0;
    for (final t in _previewTransactions) {
      await DatabaseHelper.instance.insertTransaction(t);
      count++;
    }

    setState(() {
      _importedCount = count;
      _isLoading = false;
      _isParsed = false;
      _csvRows = [];
      _previewTransactions = [];
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count transaksi berhasil diimport!'),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }
}
