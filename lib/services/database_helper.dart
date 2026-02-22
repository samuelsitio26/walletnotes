import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import '../models/transaction.dart';
import '../models/task.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('walletnotes.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE transactions (
        id $idType,
        title $textType,
        amount $realType,
        type $textType,
        category $textType,
        date $textType,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id $idType,
        title $textType,
        description $textType,
        dueDate $textType,
        isCompleted $intType,
        priority $textType
      )
    ''');
  }

  // ===== TRANSACTION CRUD =====
  Future<int> insertTransaction(Transaction transaction) async {
    final db = await database;
    return await db.insert('transactions', transaction.toMap());
  }

  Future<List<Transaction>> getAllTransactions() async {
    final db = await database;
    final result = await db.query('transactions', orderBy: 'date DESC');
    return result.map((json) => Transaction.fromMap(json)).toList();
  }

  Future<int> updateTransaction(Transaction transaction) async {
    final db = await database;
    return db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // ===== TASK CRUD =====
  Future<int> insertTask(Task task) async {
    final db = await database;
    return await db.insert('tasks', task.toMap());
  }

  Future<List<Task>> getAllTasks() async {
    final db = await database;
    final result = await db.query('tasks', orderBy: 'dueDate ASC');
    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<int> updateTask(Task task) async {
    final db = await database;
    return db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // ===== SEARCH & FILTER =====

  /// Cari transaksi dengan filter kombinasi (query teks, tipe, kategori, rentang tanggal)
  Future<List<Transaction>> searchTransactions({
    String? query,
    String? type,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;

    final List<String> whereClauses = [];
    final List<dynamic> whereArgs = [];

    if (query != null && query.isNotEmpty) {
      whereClauses.add('(title LIKE ? OR category LIKE ? OR note LIKE ?)');
      whereArgs.addAll(['%$query%', '%$query%', '%$query%']);
    }

    if (type != null && type.isNotEmpty) {
      whereClauses.add('type = ?');
      whereArgs.add(type);
    }

    if (category != null && category.isNotEmpty) {
      whereClauses.add('category = ?');
      whereArgs.add(category);
    }

    if (startDate != null) {
      whereClauses.add('date >= ?');
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereClauses.add('date <= ?');
      whereArgs.add(
        endDate.copyWith(hour: 23, minute: 59, second: 59).toIso8601String(),
      );
    }

    final String? whereString = whereClauses.isNotEmpty
        ? whereClauses.join(' AND ')
        : null;

    final result = await db.query(
      'transactions',
      where: whereString,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'date DESC',
    );

    return result.map((json) => Transaction.fromMap(json)).toList();
  }

  /// Ambil total pengeluaran per kategori (untuk pie chart)
  Future<Map<String, double>> getExpenseByCategory({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;

    String whereClause = "type = 'expense'";
    if (startDate != null) {
      whereClause += " AND date >= '${startDate.toIso8601String()}'";
    }
    if (endDate != null) {
      whereClause +=
          " AND date <= '${endDate.copyWith(hour: 23, minute: 59, second: 59).toIso8601String()}'";
    }

    final result = await db.rawQuery('''
      SELECT category, SUM(amount) as total
      FROM transactions
      WHERE $whereClause
      GROUP BY category
      ORDER BY total DESC
    ''');

    final Map<String, double> categoryTotals = {};
    for (final row in result) {
      categoryTotals[row['category'] as String] = (row['total'] as num)
          .toDouble();
    }
    return categoryTotals;
  }

  /// Ambil statistik pemasukan & pengeluaran bulanan (n bulan terakhir)
  Future<List<Map<String, dynamic>>> getMonthlyStats(int months) async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT
        strftime('%Y-%m', date) as month,
        SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END) as income,
        SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) as expense
      FROM transactions
      WHERE date >= date('now', '-${months - 1} months', 'start of month')
      GROUP BY month
      ORDER BY month ASC
    ''');

    return result
        .map(
          (row) => {
            'month': row['month'] as String,
            'income': (row['income'] as num).toDouble(),
            'expense': (row['expense'] as num).toDouble(),
          },
        )
        .toList();
  }

  /// Ambil semua kategori pengeluaran yang pernah digunakan
  Future<List<String>> getUsedExpenseCategories() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT DISTINCT category FROM transactions WHERE type = 'expense' ORDER BY category ASC",
    );
    return result.map((row) => row['category'] as String).toList();
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}
