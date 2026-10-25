part of '../main.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  static const String _databaseName = 'chefim.db';
  static const int _databaseVersion = 4;
  static const String _usersTable = 'users';
  static const String _productsTable = 'products';
  static const String _shoppingTable = 'shopping_items';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final directory = await getDatabasesPath();
    final databasePath = p.join(directory, _databaseName);

    return openDatabase(
      databasePath,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createUsersTable(db);
        await _createProductsTable(db);
        await _createShoppingTable(db);
        await _createOwnershipIndexes(db);
        await _seedInitialData(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // A tabela de usuários precisa existir antes das colunas com chave
        // estrangeira adicionadas na versão 4.
        if (oldVersion < 4) {
          await _createUsersTable(db);
        }
        if (oldVersion < 2) {
          await _upgradeToVersion2(db);
        }
        if (oldVersion < 3) {
          await _upgradeToVersion3(db);
        }
        if (oldVersion < 4) {
          await _upgradeToVersion4(db);
        }
      },
    );
  }

  Future<void> _createUsersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_usersTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL COLLATE NOCASE UNIQUE,
        password_hash TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createProductsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_productsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER REFERENCES $_usersTable(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        expiry_date INTEGER NOT NULL,
        quantity REAL NOT NULL DEFAULT 1,
        unit TEXT NOT NULL DEFAULT 'unidade',
        calories INTEGER
      )
    ''');
  }

  Future<void> _createShoppingTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_shoppingTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER REFERENCES $_usersTable(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 1,
        unit TEXT NOT NULL DEFAULT 'unidade',
        checked INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _createOwnershipIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_user_id '
      'ON $_productsTable(user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_shopping_user_id '
      'ON $_shoppingTable(user_id)',
    );
  }

  Future<void> _seedInitialData(Database db) async {
    await db.insert(_productsTable, {
      'user_id': null,
      'name': 'Leite',
      'expiry_date': DateUtils.dateOnly(
        DateTime.now().add(const Duration(days: 5)),
      ).millisecondsSinceEpoch,
      'quantity': 1.0,
      'unit': 'L',
    });

    await _seedShoppingList(db);
  }

  Future<void> _upgradeToVersion2(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info($_productsTable)');
    final columnNames = columns.map((column) => column['name']).toSet();

    if (!columnNames.contains('quantity')) {
      await db.execute(
        'ALTER TABLE $_productsTable '
        'ADD COLUMN quantity REAL NOT NULL DEFAULT 1',
      );
    }

    if (!columnNames.contains('unit')) {
      await db.execute(
        "ALTER TABLE $_productsTable "
        "ADD COLUMN unit TEXT NOT NULL DEFAULT 'unidade'",
      );
    }

    if (!columnNames.contains('calories')) {
      await db.execute(
        'ALTER TABLE $_productsTable ADD COLUMN calories INTEGER',
      );
    }

    await _createShoppingTable(db);

    await db.update(
      _productsTable,
      {'quantity': 1.0, 'unit': 'L', 'calories': 650},
      where: 'LOWER(name) = ? AND calories IS NULL',
      whereArgs: ['leite'],
    );

    await _seedShoppingList(db);
  }

  Future<void> _seedShoppingList(Database db) async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM $_shoppingTable',
    );
    final total = (result.first['total'] as num?)?.toInt() ?? 0;

    if (total > 0) return;

    final batch = db.batch();
    batch.insert(_shoppingTable, {
      'user_id': null,
      'name': 'Banana',
      'quantity': 6.0,
      'unit': 'unidade',
      'checked': 0,
    });
    batch.insert(_shoppingTable, {
      'user_id': null,
      'name': 'Ovos',
      'quantity': 12.0,
      'unit': 'unidade',
      'checked': 1,
    });
    batch.insert(_shoppingTable, {
      'user_id': null,
      'name': 'Café',
      'quantity': 1.0,
      'unit': 'pacote',
      'checked': 0,
    });
    await batch.commit(noResult: true);
  }

  Future<void> _upgradeToVersion3(Database db) async {
    await db.update(
      _productsTable,
      {'unit': 'unidade'},
      where: 'LOWER(unit) = ?',
      whereArgs: ['unidades'],
    );

    await db.update(
      _shoppingTable,
      {'unit': 'unidade'},
      where: 'LOWER(unit) = ?',
      whereArgs: ['unidades'],
    );
  }

  Future<void> _upgradeToVersion4(Database db) async {
    final productColumns = await db.rawQuery(
      'PRAGMA table_info($_productsTable)',
    );
    final productColumnNames = productColumns
        .map((column) => column['name'])
        .toSet();

    if (!productColumnNames.contains('user_id')) {
      await db.execute(
        'ALTER TABLE $_productsTable '
        'ADD COLUMN user_id INTEGER '
        'REFERENCES $_usersTable(id) ON DELETE CASCADE',
      );
    }

    final shoppingColumns = await db.rawQuery(
      'PRAGMA table_info($_shoppingTable)',
    );
    final shoppingColumnNames = shoppingColumns
        .map((column) => column['name'])
        .toSet();

    if (!shoppingColumnNames.contains('user_id')) {
      await db.execute(
        'ALTER TABLE $_shoppingTable '
        'ADD COLUMN user_id INTEGER '
        'REFERENCES $_usersTable(id) ON DELETE CASCADE',
      );
    }

    await _createOwnershipIndexes(db);
  }

  String _ownerWhere(int? userId) {
    return userId == null ? 'user_id IS NULL' : 'user_id = ?';
  }

  List<Object?>? _ownerWhereArgs(int? userId) {
    return userId == null ? null : <Object?>[userId];
  }

  Future<AppUser> createUser({
    required String name,
    required String email,
    required String passwordHash,
  }) async {
    final db = await database;
    final user = AppUser(
      name: name.trim(),
      email: email.trim().toLowerCase(),
      passwordHash: passwordHash,
      createdAt: DateTime.now(),
    );

    return db.transaction((transaction) async {
      final values = user.toMap()..remove('id');
      final id = await transaction.insert(
        _usersTable,
        values,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      final result = await transaction.rawQuery(
        'SELECT COUNT(*) AS total FROM $_usersTable',
      );
      final totalUsers = (result.first['total'] as num?)?.toInt() ?? 0;

      // A primeira conta recebe os dados criados antes desta atualização.
      if (totalUsers == 1) {
        await transaction.update(_productsTable, {
          'user_id': id,
        }, where: 'user_id IS NULL');
        await transaction.update(_shoppingTable, {
          'user_id': id,
        }, where: 'user_id IS NULL');
      }

      return AppUser(
        id: id,
        name: user.name,
        email: user.email,
        passwordHash: user.passwordHash,
        createdAt: user.createdAt,
      );
    });
  }

  Future<AppUser?> getUserById(int id) async {
    final db = await database;
    final records = await db.query(
      _usersTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return records.isEmpty ? null : AppUser.fromMap(records.first);
  }

  Future<AppUser?> getUserByEmail(String email) async {
    final db = await database;
    final records = await db.query(
      _usersTable,
      where: 'email = ? COLLATE NOCASE',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );

    return records.isEmpty ? null : AppUser.fromMap(records.first);
  }

  Future<bool> emailExists(String email) async {
    final user = await getUserByEmail(email);
    return user != null;
  }

  Future<List<Product>> getProducts({required int? userId}) async {
    final db = await database;

    final records = await db.query(
      _productsTable,
      where: _ownerWhere(userId),
      whereArgs: _ownerWhereArgs(userId),
      orderBy: 'expiry_date ASC, name COLLATE NOCASE ASC',
    );

    return records.map(Product.fromMap).toList();
  }

  Future<Product> insertProduct(Product product) async {
    final db = await database;
    final values = product.toMap()..remove('id');
    final id = await db.insert(_productsTable, values);

    return product.copyWith(id: id);
  }

  Future<int> updateProduct(Product product) async {
    if (product.id == null) {
      throw StateError('Não é possível editar um produto sem identificador.');
    }

    final db = await database;
    final values = product.toMap()..remove('id');

    return db.update(
      _productsTable,
      values,
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return db.delete(_productsTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ShoppingItem>> getShoppingItems({required int? userId}) async {
    final db = await database;
    final records = await db.query(
      _shoppingTable,
      where: _ownerWhere(userId),
      whereArgs: _ownerWhereArgs(userId),
      orderBy: 'checked ASC, name COLLATE NOCASE ASC',
    );

    return records.map(ShoppingItem.fromMap).toList();
  }

  Future<ShoppingItem> insertShoppingItem(ShoppingItem item) async {
    final db = await database;
    final values = item.toMap()..remove('id');
    final id = await db.insert(_shoppingTable, values);

    return item.copyWith(id: id);
  }

  Future<int> updateShoppingItem(ShoppingItem item) async {
    if (item.id == null) {
      throw StateError(
        'Não é possível editar um item de compras sem identificador.',
      );
    }

    final db = await database;
    final values = item.toMap()..remove('id');

    return db.update(
      _shoppingTable,
      values,
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteShoppingItem(int id) async {
    final db = await database;
    return db.delete(_shoppingTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> clearShoppingItems({required int? userId}) async {
    final db = await database;
    return db.delete(
      _shoppingTable,
      where: _ownerWhere(userId),
      whereArgs: _ownerWhereArgs(userId),
    );
  }
}
