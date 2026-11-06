part of '../main.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  static const String _databaseName = 'chefim.db';

  static const int _databaseVersion = 6;

  static const String _usersTable = 'users';

  static const String _productsTable = 'products';

  static const String _shoppingTable = 'shopping_items';

  Database? _database;

  Future<Database> get database async {
    final currentDatabase = _database;

    if (currentDatabase != null) {
      return currentDatabase;
    }

    final openedDatabase = await _openDatabase();

    _database = openedDatabase;

    return openedDatabase;
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
        await _createBarcodeIndex(db);
        await _seedInitialData(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        /*
         * A tabela de usuários deve existir antes
         * das colunas com chave estrangeira
         * adicionadas na versão 4.
         */
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

        if (oldVersion < 5) {
          await _upgradeToVersion5(db);
        }

        if (oldVersion < 6) {
          await _upgradeToVersion6(db);
        }

        /*
         * A criação com IF NOT EXISTS garante
         * que os índices estejam presentes,
         * mesmo depois de uma reconstrução
         * da tabela.
         */
        await _createOwnershipIndexes(db);
        await _createBarcodeIndex(db);
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
      CREATE TABLE IF NOT EXISTS $_productsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        user_id INTEGER
          REFERENCES $_usersTable(id)
          ON DELETE CASCADE,

        name TEXT NOT NULL,
        expiry_date INTEGER,

        quantity REAL NOT NULL DEFAULT 1,
        unit TEXT NOT NULL DEFAULT 'unidade',

        calories INTEGER,

        barcode TEXT,
        brand TEXT,

        image_url TEXT,

        ingredients TEXT,
        allergens TEXT,
        serving_size TEXT,

        energy_kcal_100g REAL,
        carbohydrates_100g REAL,
        proteins_100g REAL,
        fat_100g REAL,
        saturated_fat_100g REAL,
        sugars_100g REAL,
        fiber_100g REAL,
        sodium_100g REAL,

        data_source TEXT
      )
    ''');
  }

  Future<void> _createShoppingTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_shoppingTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        user_id INTEGER
          REFERENCES $_usersTable(id)
          ON DELETE CASCADE,

        name TEXT NOT NULL,

        quantity REAL NOT NULL DEFAULT 1,
        unit TEXT NOT NULL DEFAULT 'unidade',

        checked INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _createOwnershipIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS '
      'idx_products_user_id '
      'ON $_productsTable(user_id)',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS '
      'idx_shopping_user_id '
      'ON $_shoppingTable(user_id)',
    );
  }

  Future<void> _createBarcodeIndex(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS '
      'idx_products_owner_barcode '
      'ON $_productsTable(user_id, barcode)',
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

  Future<void> _seedShoppingList(Database db) async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total '
      'FROM $_shoppingTable',
    );

    final total = (result.first['total'] as num?)?.toInt() ?? 0;

    if (total > 0) {
      return;
    }

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

  Future<void> _upgradeToVersion2(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info($_productsTable)');

    final columnNames = columns.map((column) => column['name']).toSet();

    if (!columnNames.contains('quantity')) {
      await db.execute(
        'ALTER TABLE $_productsTable '
        'ADD COLUMN quantity '
        'REAL NOT NULL DEFAULT 1',
      );
    }

    if (!columnNames.contains('unit')) {
      await db.execute(
        'ALTER TABLE $_productsTable '
        "ADD COLUMN unit "
        "TEXT NOT NULL DEFAULT 'unidade'",
      );
    }

    if (!columnNames.contains('calories')) {
      await db.execute(
        'ALTER TABLE $_productsTable '
        'ADD COLUMN calories INTEGER',
      );
    }

    await _createShoppingTable(db);

    await db.update(
      _productsTable,
      {'quantity': 1.0, 'unit': 'L', 'calories': 650},
      where:
          'LOWER(name) = ? '
          'AND calories IS NULL',
      whereArgs: ['leite'],
    );

    await _seedShoppingList(db);
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
        'REFERENCES $_usersTable(id) '
        'ON DELETE CASCADE',
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
        'REFERENCES $_usersTable(id) '
        'ON DELETE CASCADE',
      );
    }

    await _createOwnershipIndexes(db);
  }

  Future<void> _upgradeToVersion5(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info($_productsTable)');

    final columnNames = columns.map((column) => column['name']).toSet();

    final additions = <String, String>{
      'barcode': 'TEXT',
      'brand': 'TEXT',
      'image_url': 'TEXT',
      'ingredients': 'TEXT',
      'allergens': 'TEXT',
      'serving_size': 'TEXT',
      'energy_kcal_100g': 'REAL',
      'carbohydrates_100g': 'REAL',
      'proteins_100g': 'REAL',
      'fat_100g': 'REAL',
      'saturated_fat_100g': 'REAL',
      'sugars_100g': 'REAL',
      'fiber_100g': 'REAL',
      'sodium_100g': 'REAL',
      'data_source': 'TEXT',
    };

    for (final entry in additions.entries) {
      if (!columnNames.contains(entry.key)) {
        await db.execute(
          'ALTER TABLE $_productsTable '
          'ADD COLUMN ${entry.key} '
          '${entry.value}',
        );
      }
    }

    await _createBarcodeIndex(db);
  }

  Future<void> _upgradeToVersion6(Database db) async {
    const temporaryProductsTable = 'products_v6';

    /*
     * O SQLite não permite retirar diretamente
     * o NOT NULL de uma coluna.
     *
     * A tabela precisa ser reconstruída para que
     * expiry_date aceite null.
     *
     * A antiga coluna price_cents não é copiada,
     * pois o Chefim não utiliza mais controle
     * de preço.
     */

    await db.execute(
      'DROP TABLE IF EXISTS '
      '$temporaryProductsTable',
    );

    await db.execute('''
      CREATE TABLE $temporaryProductsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        user_id INTEGER
          REFERENCES $_usersTable(id)
          ON DELETE CASCADE,

        name TEXT NOT NULL,
        expiry_date INTEGER,

        quantity REAL NOT NULL DEFAULT 1,
        unit TEXT NOT NULL DEFAULT 'unidade',

        calories INTEGER,

        barcode TEXT,
        brand TEXT,
        image_url TEXT,

        ingredients TEXT,
        allergens TEXT,
        serving_size TEXT,

        energy_kcal_100g REAL,
        carbohydrates_100g REAL,
        proteins_100g REAL,
        fat_100g REAL,
        saturated_fat_100g REAL,
        sugars_100g REAL,
        fiber_100g REAL,
        sodium_100g REAL,

        data_source TEXT
      )
    ''');

    await db.execute('''
      INSERT INTO $temporaryProductsTable (
        id,
        user_id,
        name,
        expiry_date,
        quantity,
        unit,
        calories,
        barcode,
        brand,
        image_url,
        ingredients,
        allergens,
        serving_size,
        energy_kcal_100g,
        carbohydrates_100g,
        proteins_100g,
        fat_100g,
        saturated_fat_100g,
        sugars_100g,
        fiber_100g,
        sodium_100g,
        data_source
      )
      SELECT
        id,
        user_id,
        name,
        expiry_date,
        quantity,
        unit,
        calories,
        barcode,
        brand,
        image_url,
        ingredients,
        allergens,
        serving_size,
        energy_kcal_100g,
        carbohydrates_100g,
        proteins_100g,
        fat_100g,
        saturated_fat_100g,
        sugars_100g,
        fiber_100g,
        sodium_100g,
        data_source
      FROM $_productsTable
    ''');

    await db.execute('DROP TABLE $_productsTable');

    await db.execute(
      'ALTER TABLE $temporaryProductsTable '
      'RENAME TO $_productsTable',
    );

    await _createOwnershipIndexes(db);
    await _createBarcodeIndex(db);
  }

  String _ownerWhere(int? userId) {
    if (userId == null) {
      return 'user_id IS NULL';
    }

    return 'user_id = ?';
  }

  List<Object?>? _ownerWhereArgs(int? userId) {
    if (userId == null) {
      return null;
    }

    return <Object?>[userId];
  }

  void _validateProduct(Product product) {
    if (product.name.trim().isEmpty) {
      throw ArgumentError.value(
        product.name,
        'name',
        'O nome do produto não pode '
            'ficar vazio.',
      );
    }

    if (!product.quantity.isFinite || product.quantity <= 0) {
      throw ArgumentError.value(
        product.quantity,
        'quantity',
        'A quantidade deve ser maior '
            'que zero.',
      );
    }
  }

  void _validateShoppingItem(ShoppingItem item) {
    if (item.name.trim().isEmpty) {
      throw ArgumentError.value(
        item.name,
        'name',
        'O nome do item não pode '
            'ficar vazio.',
      );
    }

    if (!item.quantity.isFinite || item.quantity <= 0) {
      throw ArgumentError.value(
        item.quantity,
        'quantity',
        'A quantidade deve ser maior '
            'que zero.',
      );
    }
  }

  Future<AppUser> createUser({
    required String name,
    required String email,
    required String passwordHash,
  }) async {
    final normalizedName = name.trim();
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'O nome não pode ficar vazio.');
    }

    if (normalizedEmail.isEmpty) {
      throw ArgumentError.value(
        email,
        'email',
        'O e-mail não pode ficar vazio.',
      );
    }

    if (passwordHash.trim().isEmpty) {
      throw ArgumentError.value(
        passwordHash,
        'passwordHash',
        'A senha criptografada não pode '
            'ficar vazia.',
      );
    }

    final db = await database;

    final user = AppUser(
      name: normalizedName,
      email: normalizedEmail,
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
        'SELECT COUNT(*) AS total '
        'FROM $_usersTable',
      );

      final totalUsers = (result.first['total'] as num?)?.toInt() ?? 0;

      /*
         * A primeira conta recebe os dados
         * criados antes da implementação
         * do sistema de usuários.
         */
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

    if (records.isEmpty) {
      return null;
    }

    return AppUser.fromMap(records.first);
  }

  Future<AppUser?> getUserByEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty) {
      return null;
    }

    final db = await database;

    final records = await db.query(
      _usersTable,
      where: 'email = ? COLLATE NOCASE',
      whereArgs: [normalizedEmail],
      limit: 1,
    );

    if (records.isEmpty) {
      return null;
    }

    return AppUser.fromMap(records.first);
  }

  Future<bool> emailExists(String email) async {
    final user = await getUserByEmail(email);

    return user != null;
  }

  Future<void> updateUserPassword({
    required int userId,
    required String passwordHash,
  }) async {
    if (passwordHash.trim().isEmpty) {
      throw ArgumentError.value(
        passwordHash,
        'passwordHash',
        'A senha criptografada não pode '
            'ficar vazia.',
      );
    }

    final db = await database;

    final updatedRows = await db.update(
      _usersTable,
      {'password_hash': passwordHash},
      where: 'id = ?',
      whereArgs: [userId],
    );

    if (updatedRows != 1) {
      throw StateError(
        'Não foi possível localizar a '
        'conta para atualizar.',
      );
    }
  }

  Future<void> deleteUser(int userId) async {
    final db = await database;

    await db.transaction((transaction) async {
      /*
         * As exclusões explícitas garantem a
         * remoção mesmo em bancos antigos nos
         * quais a chave estrangeira possa não
         * ter sido criada corretamente.
         */
      await transaction.delete(
        _productsTable,
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      await transaction.delete(
        _shoppingTable,
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      final deletedRows = await transaction.delete(
        _usersTable,
        where: 'id = ?',
        whereArgs: [userId],
      );

      if (deletedRows != 1) {
        throw StateError(
          'Não foi possível localizar a '
          'conta para excluir.',
        );
      }
    });
  }

  Future<List<Product>> getProducts({required int? userId}) async {
    final db = await database;

    final records = await db.query(
      _productsTable,
      where: _ownerWhere(userId),
      whereArgs: _ownerWhereArgs(userId),
      orderBy:
          'expiry_date IS NULL ASC, '
          'expiry_date ASC, '
          'name COLLATE NOCASE ASC',
    );

    return records.map(Product.fromMap).toList();
  }

  Future<Product?> getProductById(int id) async {
    final db = await database;

    final records = await db.query(
      _productsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (records.isEmpty) {
      return null;
    }

    return Product.fromMap(records.first);
  }

  Future<Product?> getProductByBarcode({
    required int? userId,
    required String barcode,
  }) async {
    final normalizedBarcode = barcode.trim();

    if (normalizedBarcode.isEmpty) {
      return null;
    }

    final db = await database;

    final ownerArgs = _ownerWhereArgs(userId) ?? <Object?>[];

    final records = await db.query(
      _productsTable,
      where:
          '${_ownerWhere(userId)} '
          'AND barcode = ?',
      whereArgs: [...ownerArgs, normalizedBarcode],
      limit: 1,
    );

    if (records.isEmpty) {
      return null;
    }

    return Product.fromMap(records.first);
  }

  Future<Product> createProduct(Product product) {
    return insertProduct(product);
  }

  Future<Product> insertProduct(Product product) async {
    _validateProduct(product);

    final db = await database;

    final normalizedProduct = product.copyWith(
      name: product.name.trim(),
      barcode: product.barcode?.trim().isEmpty == true
          ? null
          : product.barcode?.trim(),
      brand: product.brand?.trim().isEmpty == true
          ? null
          : product.brand?.trim(),
      imageUrl: product.imageLocation,
    );

    final values = normalizedProduct.toMap()..remove('id');

    final id = await db.insert(
      _productsTable,
      values,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    return normalizedProduct.copyWith(id: id);
  }

  Future<int> updateProduct(Product product) async {
    final id = product.id;

    if (id == null) {
      throw StateError(
        'Não é possível editar um '
        'produto sem identificador.',
      );
    }

    _validateProduct(product);

    final db = await database;

    final values = product.toMap()..remove('id');

    final updatedRows = await db.update(
      _productsTable,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (updatedRows != 1) {
      throw StateError(
        'Não foi possível localizar o '
        'produto para atualizar.',
      );
    }

    return updatedRows;
  }

  /// Incrementa o estoque de forma atômica.
  Future<Product> updateQuantity({
    required Product product,
    required double amountToAdd,
  }) async {
    final id = product.id;

    if (id == null) {
      throw StateError(
        'O produto precisa estar salvo '
        'antes da atualização.',
      );
    }

    if (!amountToAdd.isFinite || amountToAdd <= 0) {
      throw ArgumentError.value(
        amountToAdd,
        'amountToAdd',
        'A quantidade deve ser maior '
            'que zero.',
      );
    }

    final db = await database;

    return db.transaction((transaction) async {
      final updatedRows = await transaction.rawUpdate(
        'UPDATE $_productsTable '
        'SET quantity = quantity + ? '
        'WHERE id = ?',
        [amountToAdd, id],
      );

      if (updatedRows != 1) {
        throw StateError(
          'Não foi possível atualizar o '
          'estoque do produto.',
        );
      }

      final records = await transaction.query(
        _productsTable,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (records.isEmpty) {
        throw StateError(
          'O produto atualizado não foi '
          'encontrado.',
        );
      }

      return Product.fromMap(records.first);
    });
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
      orderBy:
          'checked ASC, '
          'name COLLATE NOCASE ASC',
    );

    return records.map(ShoppingItem.fromMap).toList();
  }

  Future<ShoppingItem> insertShoppingItem(ShoppingItem item) async {
    _validateShoppingItem(item);

    final db = await database;

    final normalizedItem = item.copyWith(
      name: item.name.trim(),
      unit: item.unit.trim().isEmpty ? 'unidade' : item.unit.trim(),
    );

    final values = normalizedItem.toMap()..remove('id');

    final id = await db.insert(
      _shoppingTable,
      values,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    return normalizedItem.copyWith(id: id);
  }

  Future<int> updateShoppingItem(ShoppingItem item) async {
    final id = item.id;

    if (id == null) {
      throw StateError(
        'Não é possível editar um item '
        'de compras sem identificador.',
      );
    }

    _validateShoppingItem(item);

    final db = await database;

    final values = item.toMap()..remove('id');

    final updatedRows = await db.update(
      _shoppingTable,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (updatedRows != 1) {
      throw StateError(
        'Não foi possível localizar o '
        'item para atualizar.',
      );
    }

    return updatedRows;
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

  Future<void> close() async {
    final currentDatabase = _database;

    if (currentDatabase == null) {
      return;
    }

    await currentDatabase.close();
    _database = null;
  }
}
