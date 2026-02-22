import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  // 1 = bulan ini, 3 = 3 bulan, 6 = 6 bulan, 0 = semua
  int _selectedPeriod = 1;

  Map<String, double> _categoryExpenses = {};
  List<Map<String, dynamic>> _monthlyStats = [];
  bool _isLoading = true;
  int _touchedIndex = -1;

  double _totalIncome = 0;
  double _totalExpense = 0;

  final _currencyCompact = NumberFormat.compact(locale: 'id_ID');

  final List<Color> _pieColors = [
    const Color(0xFFE57373),
    const Color(0xFF64B5F6),
    const Color(0xFFFFB74D),
    const Color(0xFF81C784),
    const Color(0xFFBA68C8),
    const Color(0xFF4DD0E1),
    const Color(0xFFA1887F),
    const Color(0xFF90A4AE),
    const Color(0xFFF06292),
    const Color(0xFFAED581),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  DateTime? get _startDate {
    if (_selectedPeriod == 0) return null;
    final now = DateTime.now();
    if (_selectedPeriod == 1) return DateTime(now.year, now.month, 1);
    return DateTime(now.year, now.month - _selectedPeriod + 1, 1);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final cats = await DatabaseHelper.instance.getExpenseByCategory(
      startDate: _startDate,
    );

    final monthly = await DatabaseHelper.instance.getMonthlyStats(6);

    final transactions = await DatabaseHelper.instance.searchTransactions(
      startDate: _startDate,
    );

    double income = 0;
    double expense = 0;
    for (final t in transactions) {
      if (t.type == 'income') {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }

    setState(() {
      _categoryExpenses = cats;
      _monthlyStats = monthly;
      _totalIncome = income;
      _totalExpense = expense;
      _isLoading = false;
      _touchedIndex = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Statistik',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.green.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildPeriodSelector(),
                  const SizedBox(height: 16),
                  _buildSummaryCards(),
                  const SizedBox(height: 20),
                  if (_categoryExpenses.isNotEmpty) ...[
                    _buildSectionTitle(
                      'Pengeluaran per Kategori',
                      Icons.pie_chart,
                    ),
                    const SizedBox(height: 12),
                    _buildCategoryPieChart(),
                    const SizedBox(height: 20),
                    _buildCategoryLegend(),
                    const SizedBox(height: 24),
                  ],
                  if (_monthlyStats.isNotEmpty) ...[
                    _buildSectionTitle(
                      'Tren 6 Bulan Terakhir',
                      Icons.bar_chart,
                    ),
                    const SizedBox(height: 12),
                    _buildMonthlyBarChart(),
                    const SizedBox(height: 8),
                    _buildBarChartLegend(),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  // ─── Period Selector ────────────────────────────────────────────
  Widget _buildPeriodSelector() {
    final periods = [
      (1, 'Bulan Ini'),
      (3, '3 Bulan'),
      (6, '6 Bulan'),
      (0, 'Semua'),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: periods.map((p) {
          final isSelected = _selectedPeriod == p.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedPeriod = p.$1);
                _loadData();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.green.shade700
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  p.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Summary Cards ───────────────────────────────────────────────
  Widget _buildSummaryCards() {
    final balance = _totalIncome - _totalExpense;
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            'Pemasukan',
            _totalIncome,
            Colors.green,
            Icons.arrow_downward,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryCard(
            'Pengeluaran',
            _totalExpense,
            Colors.red,
            Icons.arrow_upward,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryCard(
            'Saldo',
            balance,
            balance >= 0 ? Colors.blue : Colors.orange,
            Icons.account_balance_wallet,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(String label, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
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
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            _currencyCompact.format(amount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ─── Section Title ────────────────────────────────────────────────
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.green.shade700, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ─── Pie Chart ────────────────────────────────────────────────────
  Widget _buildCategoryPieChart() {
    final entries = _categoryExpenses.entries.toList();
    final total = entries.fold(0.0, (sum, e) => sum + e.value);

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: PieChart(
        PieChartData(
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              setState(() {
                if (!event.isInterestedForInteractions ||
                    pieTouchResponse == null ||
                    pieTouchResponse.touchedSection == null) {
                  _touchedIndex = -1;
                  return;
                }
                _touchedIndex =
                    pieTouchResponse.touchedSection!.touchedSectionIndex;
              });
            },
          ),
          sectionsSpace: 2,
          centerSpaceRadius: 55,
          sections: entries.asMap().entries.map((entry) {
            final index = entry.key;
            final cat = entry.value;
            final isTouched = index == _touchedIndex;
            final pct = total > 0 ? (cat.value / total * 100) : 0.0;
            final color = _pieColors[index % _pieColors.length];

            return PieChartSectionData(
              value: cat.value,
              title: isTouched
                  ? '${pct.toStringAsFixed(1)}%'
                  : '${pct.toStringAsFixed(0)}%',
              color: color,
              radius: isTouched ? 65 : 52,
              titleStyle: TextStyle(
                fontSize: isTouched ? 14 : 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCategoryLegend() {
    final entries = _categoryExpenses.entries.toList();
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: entries.asMap().entries.map((entry) {
        final color = _pieColors[entry.key % _pieColors.length];
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${entry.value.key} (${_currencyCompact.format(entry.value.value)})',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        );
      }).toList(),
    );
  }

  // ─── Bar Chart ────────────────────────────────────────────────────
  Widget _buildMonthlyBarChart() {
    // Buat 6 bulan terakhir
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final dt = DateTime(now.year, now.month - 5 + i, 1);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
    });

    // Isi data dari monthly stats (fallback 0 jika bulan kosong)
    final statsMap = {for (final m in _monthlyStats) m['month'] as String: m};

    double maxY = 1000;
    final barGroups = months.asMap().entries.map((entry) {
      final stats = statsMap[entry.value];
      final income = stats != null ? (stats['income'] as double) : 0.0;
      final expense = stats != null ? (stats['expense'] as double) : 0.0;
      if (income > maxY) maxY = income;
      if (expense > maxY) maxY = expense;
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: income,
            color: Colors.green.shade400,
            width: 10,
            borderRadius: BorderRadius.circular(4),
          ),
          BarChartRodData(
            toY: expense,
            color: Colors.red.shade400,
            width: 10,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
        barsSpace: 4,
      );
    }).toList();

    final monthLabels = months.map((m) {
      final parts = m.split('-');
      final monthNames = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      return monthNames[int.parse(parts[1])];
    }).toList();

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY * 1.2,
          barGroups: barGroups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= monthLabels.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      monthLabels[idx],
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Text(
                    _currencyCompact.format(value),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBarChartLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendDot(Colors.green.shade400, 'Pemasukan'),
        const SizedBox(width: 20),
        _legendDot(Colors.red.shade400, 'Pengeluaran'),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
