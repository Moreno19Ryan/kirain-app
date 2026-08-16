// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kirain_database.dart';

// ignore_for_file: type=lint
class $LocalOutboxItemsTable extends LocalOutboxItems
    with TableInfo<$LocalOutboxItemsTable, LocalOutboxItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalOutboxItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _goalIdMeta = const VerificationMeta('goalId');
  @override
  late final GeneratedColumn<String> goalId = GeneratedColumn<String>(
    'goal_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transactionDateMeta = const VerificationMeta(
    'transactionDate',
  );
  @override
  late final GeneratedColumn<String> transactionDate = GeneratedColumn<String>(
    'transaction_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expenseTypeMeta = const VerificationMeta(
    'expenseType',
  );
  @override
  late final GeneratedColumn<String> expenseType = GeneratedColumn<String>(
    'expense_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<OutboxSyncStatus, String>
  syncStatus =
      GeneratedColumn<String>(
        'sync_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<OutboxSyncStatus>(
        $LocalOutboxItemsTable.$convertersyncStatus,
      );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lockedAtMeta = const VerificationMeta(
    'lockedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lockedAt = GeneratedColumn<DateTime>(
    'locked_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    categoryId,
    goalId,
    amount,
    note,
    transactionDate,
    createdAt,
    expenseType,
    syncStatus,
    retryCount,
    lastAttemptAt,
    errorMessage,
    lockedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_outbox_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalOutboxItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('goal_id')) {
      context.handle(
        _goalIdMeta,
        goalId.isAcceptableOrUnknown(data['goal_id']!, _goalIdMeta),
      );
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('transaction_date')) {
      context.handle(
        _transactionDateMeta,
        transactionDate.isAcceptableOrUnknown(
          data['transaction_date']!,
          _transactionDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionDateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('expense_type')) {
      context.handle(
        _expenseTypeMeta,
        expenseType.isAcceptableOrUnknown(
          data['expense_type']!,
          _expenseTypeMeta,
        ),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('locked_at')) {
      context.handle(
        _lockedAtMeta,
        lockedAt.isAcceptableOrUnknown(data['locked_at']!, _lockedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalOutboxItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalOutboxItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      goalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_id'],
      ),
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      transactionDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_date'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      expenseType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expense_type'],
      ),
      syncStatus: $LocalOutboxItemsTable.$convertersyncStatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}sync_status'],
        )!,
      ),
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      lockedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}locked_at'],
      ),
    );
  }

  @override
  $LocalOutboxItemsTable createAlias(String alias) {
    return $LocalOutboxItemsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<OutboxSyncStatus, String, String>
  $convertersyncStatus = const EnumNameConverter<OutboxSyncStatus>(
    OutboxSyncStatus.values,
  );
}

class LocalOutboxItem extends DataClass implements Insertable<LocalOutboxItem> {
  final String id;
  final String userId;

  /// Exactly one of [categoryId] / [goalId] is set, matching
  /// TransactionRepository's addTransaction (category) vs
  /// addSavingsContribution (goal) split.
  final String? categoryId;
  final String? goalId;

  /// Exact whole Rupiah — the smallest currency unit KIRAIN's domain model
  /// actually uses today (Catat's amount field is `decimal: false`; there's
  /// no sen/cents concept anywhere in the app). Stored as an integer, not
  /// REAL/double, so this durable local copy of a financial amount can't
  /// drift from what the user typed through binary floating-point rounding.
  /// Supabase's `numeric(14,2)` column stays authoritative once synced —
  /// this is a delivery buffer, not the ledger of record — but that's not a
  /// reason to be inexact here.
  final int amount;
  final String? note;

  /// ISO date string ('yyyy-MM-dd'), matching core/utils/format.dart's
  /// isoDate() — transaction_date is a DATE server-side, not a timestamp, so
  /// storing it as plain text sidesteps DateTimeColumn's timezone-aware
  /// unix-timestamp semantics for a value that was never a timestamp.
  final String transactionDate;

  /// Captured locally at enqueue time. Supabase's `created_at default now()`
  /// only applies once the row actually reaches the server — history
  /// ordering needs a real creation instant before that happens.
  final DateTime createdAt;

  /// 'wajib' / 'keinginan' / null — [ExpenseType.name], null for savings
  /// contributions and income rows. Same convention TransactionRepository's
  /// own inserts already use.
  final String? expenseType;
  final OutboxSyncStatus syncStatus;
  final int retryCount;
  final DateTime? lastAttemptAt;
  final String? errorMessage;

  /// The sync lease: non-null only while [syncStatus] is SYNCING, set to the
  /// claim time by SyncWorker's conditional claim UPDATE. Null again the
  /// moment a row leaves SYNCING (success = row deleted; retryable/permanent
  /// failure = explicitly cleared) — so "has a lease" and "is SYNCING" stay
  /// equivalent, which is what makes staleness ("SYNCING for longer than the
  /// configured threshold") a simple `lockedAt` age check rather than needing
  /// a separately-tracked expiry.
  final DateTime? lockedAt;
  const LocalOutboxItem({
    required this.id,
    required this.userId,
    this.categoryId,
    this.goalId,
    required this.amount,
    this.note,
    required this.transactionDate,
    required this.createdAt,
    this.expenseType,
    required this.syncStatus,
    required this.retryCount,
    this.lastAttemptAt,
    this.errorMessage,
    this.lockedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || goalId != null) {
      map['goal_id'] = Variable<String>(goalId);
    }
    map['amount'] = Variable<int>(amount);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['transaction_date'] = Variable<String>(transactionDate);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || expenseType != null) {
      map['expense_type'] = Variable<String>(expenseType);
    }
    {
      map['sync_status'] = Variable<String>(
        $LocalOutboxItemsTable.$convertersyncStatus.toSql(syncStatus),
      );
    }
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    if (!nullToAbsent || lockedAt != null) {
      map['locked_at'] = Variable<DateTime>(lockedAt);
    }
    return map;
  }

  LocalOutboxItemsCompanion toCompanion(bool nullToAbsent) {
    return LocalOutboxItemsCompanion(
      id: Value(id),
      userId: Value(userId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      goalId: goalId == null && nullToAbsent
          ? const Value.absent()
          : Value(goalId),
      amount: Value(amount),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      transactionDate: Value(transactionDate),
      createdAt: Value(createdAt),
      expenseType: expenseType == null && nullToAbsent
          ? const Value.absent()
          : Value(expenseType),
      syncStatus: Value(syncStatus),
      retryCount: Value(retryCount),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      lockedAt: lockedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lockedAt),
    );
  }

  factory LocalOutboxItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalOutboxItem(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      goalId: serializer.fromJson<String?>(json['goalId']),
      amount: serializer.fromJson<int>(json['amount']),
      note: serializer.fromJson<String?>(json['note']),
      transactionDate: serializer.fromJson<String>(json['transactionDate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      expenseType: serializer.fromJson<String?>(json['expenseType']),
      syncStatus: $LocalOutboxItemsTable.$convertersyncStatus.fromJson(
        serializer.fromJson<String>(json['syncStatus']),
      ),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      lockedAt: serializer.fromJson<DateTime?>(json['lockedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'categoryId': serializer.toJson<String?>(categoryId),
      'goalId': serializer.toJson<String?>(goalId),
      'amount': serializer.toJson<int>(amount),
      'note': serializer.toJson<String?>(note),
      'transactionDate': serializer.toJson<String>(transactionDate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'expenseType': serializer.toJson<String?>(expenseType),
      'syncStatus': serializer.toJson<String>(
        $LocalOutboxItemsTable.$convertersyncStatus.toJson(syncStatus),
      ),
      'retryCount': serializer.toJson<int>(retryCount),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'lockedAt': serializer.toJson<DateTime?>(lockedAt),
    };
  }

  LocalOutboxItem copyWith({
    String? id,
    String? userId,
    Value<String?> categoryId = const Value.absent(),
    Value<String?> goalId = const Value.absent(),
    int? amount,
    Value<String?> note = const Value.absent(),
    String? transactionDate,
    DateTime? createdAt,
    Value<String?> expenseType = const Value.absent(),
    OutboxSyncStatus? syncStatus,
    int? retryCount,
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    Value<DateTime?> lockedAt = const Value.absent(),
  }) => LocalOutboxItem(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    goalId: goalId.present ? goalId.value : this.goalId,
    amount: amount ?? this.amount,
    note: note.present ? note.value : this.note,
    transactionDate: transactionDate ?? this.transactionDate,
    createdAt: createdAt ?? this.createdAt,
    expenseType: expenseType.present ? expenseType.value : this.expenseType,
    syncStatus: syncStatus ?? this.syncStatus,
    retryCount: retryCount ?? this.retryCount,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    lockedAt: lockedAt.present ? lockedAt.value : this.lockedAt,
  );
  LocalOutboxItem copyWithCompanion(LocalOutboxItemsCompanion data) {
    return LocalOutboxItem(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      goalId: data.goalId.present ? data.goalId.value : this.goalId,
      amount: data.amount.present ? data.amount.value : this.amount,
      note: data.note.present ? data.note.value : this.note,
      transactionDate: data.transactionDate.present
          ? data.transactionDate.value
          : this.transactionDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      expenseType: data.expenseType.present
          ? data.expenseType.value
          : this.expenseType,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      lockedAt: data.lockedAt.present ? data.lockedAt.value : this.lockedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalOutboxItem(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('categoryId: $categoryId, ')
          ..write('goalId: $goalId, ')
          ..write('amount: $amount, ')
          ..write('note: $note, ')
          ..write('transactionDate: $transactionDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('expenseType: $expenseType, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('lockedAt: $lockedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    categoryId,
    goalId,
    amount,
    note,
    transactionDate,
    createdAt,
    expenseType,
    syncStatus,
    retryCount,
    lastAttemptAt,
    errorMessage,
    lockedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalOutboxItem &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.categoryId == this.categoryId &&
          other.goalId == this.goalId &&
          other.amount == this.amount &&
          other.note == this.note &&
          other.transactionDate == this.transactionDate &&
          other.createdAt == this.createdAt &&
          other.expenseType == this.expenseType &&
          other.syncStatus == this.syncStatus &&
          other.retryCount == this.retryCount &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.errorMessage == this.errorMessage &&
          other.lockedAt == this.lockedAt);
}

class LocalOutboxItemsCompanion extends UpdateCompanion<LocalOutboxItem> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String?> categoryId;
  final Value<String?> goalId;
  final Value<int> amount;
  final Value<String?> note;
  final Value<String> transactionDate;
  final Value<DateTime> createdAt;
  final Value<String?> expenseType;
  final Value<OutboxSyncStatus> syncStatus;
  final Value<int> retryCount;
  final Value<DateTime?> lastAttemptAt;
  final Value<String?> errorMessage;
  final Value<DateTime?> lockedAt;
  final Value<int> rowid;
  const LocalOutboxItemsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.goalId = const Value.absent(),
    this.amount = const Value.absent(),
    this.note = const Value.absent(),
    this.transactionDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.expenseType = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.lockedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalOutboxItemsCompanion.insert({
    required String id,
    required String userId,
    this.categoryId = const Value.absent(),
    this.goalId = const Value.absent(),
    required int amount,
    this.note = const Value.absent(),
    required String transactionDate,
    required DateTime createdAt,
    this.expenseType = const Value.absent(),
    required OutboxSyncStatus syncStatus,
    this.retryCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.lockedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       amount = Value(amount),
       transactionDate = Value(transactionDate),
       createdAt = Value(createdAt),
       syncStatus = Value(syncStatus);
  static Insertable<LocalOutboxItem> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? categoryId,
    Expression<String>? goalId,
    Expression<int>? amount,
    Expression<String>? note,
    Expression<String>? transactionDate,
    Expression<DateTime>? createdAt,
    Expression<String>? expenseType,
    Expression<String>? syncStatus,
    Expression<int>? retryCount,
    Expression<DateTime>? lastAttemptAt,
    Expression<String>? errorMessage,
    Expression<DateTime>? lockedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (categoryId != null) 'category_id': categoryId,
      if (goalId != null) 'goal_id': goalId,
      if (amount != null) 'amount': amount,
      if (note != null) 'note': note,
      if (transactionDate != null) 'transaction_date': transactionDate,
      if (createdAt != null) 'created_at': createdAt,
      if (expenseType != null) 'expense_type': expenseType,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (errorMessage != null) 'error_message': errorMessage,
      if (lockedAt != null) 'locked_at': lockedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalOutboxItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String?>? categoryId,
    Value<String?>? goalId,
    Value<int>? amount,
    Value<String?>? note,
    Value<String>? transactionDate,
    Value<DateTime>? createdAt,
    Value<String?>? expenseType,
    Value<OutboxSyncStatus>? syncStatus,
    Value<int>? retryCount,
    Value<DateTime?>? lastAttemptAt,
    Value<String?>? errorMessage,
    Value<DateTime?>? lockedAt,
    Value<int>? rowid,
  }) {
    return LocalOutboxItemsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      goalId: goalId ?? this.goalId,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      transactionDate: transactionDate ?? this.transactionDate,
      createdAt: createdAt ?? this.createdAt,
      expenseType: expenseType ?? this.expenseType,
      syncStatus: syncStatus ?? this.syncStatus,
      retryCount: retryCount ?? this.retryCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      errorMessage: errorMessage ?? this.errorMessage,
      lockedAt: lockedAt ?? this.lockedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (goalId.present) {
      map['goal_id'] = Variable<String>(goalId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (transactionDate.present) {
      map['transaction_date'] = Variable<String>(transactionDate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (expenseType.present) {
      map['expense_type'] = Variable<String>(expenseType.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(
        $LocalOutboxItemsTable.$convertersyncStatus.toSql(syncStatus.value),
      );
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (lockedAt.present) {
      map['locked_at'] = Variable<DateTime>(lockedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalOutboxItemsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('categoryId: $categoryId, ')
          ..write('goalId: $goalId, ')
          ..write('amount: $amount, ')
          ..write('note: $note, ')
          ..write('transactionDate: $transactionDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('expenseType: $expenseType, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('lockedAt: $lockedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalTransactionsTable extends LocalTransactions
    with TableInfo<$LocalTransactionsTable, LocalTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _goalIdMeta = const VerificationMeta('goalId');
  @override
  late final GeneratedColumn<String> goalId = GeneratedColumn<String>(
    'goal_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transactionDateMeta = const VerificationMeta(
    'transactionDate',
  );
  @override
  late final GeneratedColumn<String> transactionDate = GeneratedColumn<String>(
    'transaction_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expenseTypeMeta = const VerificationMeta(
    'expenseType',
  );
  @override
  late final GeneratedColumn<String> expenseType = GeneratedColumn<String>(
    'expense_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    categoryId,
    goalId,
    amount,
    note,
    transactionDate,
    createdAt,
    expenseType,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalTransaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('goal_id')) {
      context.handle(
        _goalIdMeta,
        goalId.isAcceptableOrUnknown(data['goal_id']!, _goalIdMeta),
      );
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('transaction_date')) {
      context.handle(
        _transactionDateMeta,
        transactionDate.isAcceptableOrUnknown(
          data['transaction_date']!,
          _transactionDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionDateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('expense_type')) {
      context.handle(
        _expenseTypeMeta,
        expenseType.isAcceptableOrUnknown(
          data['expense_type']!,
          _expenseTypeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalTransaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      goalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_id'],
      ),
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      transactionDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_date'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      expenseType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expense_type'],
      ),
    );
  }

  @override
  $LocalTransactionsTable createAlias(String alias) {
    return $LocalTransactionsTable(attachedDatabase, alias);
  }
}

class LocalTransaction extends DataClass
    implements Insertable<LocalTransaction> {
  final String id;
  final String userId;

  /// Exactly one of [categoryId] / [goalId] is set — same invariant as
  /// [LocalOutboxItems], enforced the same two ways (OutboxDraft's
  /// constructor, backstopped by the CHECK constraint below).
  final String? categoryId;
  final String? goalId;

  /// Exact whole Rupiah — see [LocalOutboxItems.amount] for why int, not
  /// num/double.
  final int amount;
  final String? note;

  /// ISO date string ('yyyy-MM-dd'), matching [LocalOutboxItems.transactionDate].
  final String transactionDate;
  final DateTime createdAt;

  /// 'wajib' / 'keinginan' / null — matches [LocalOutboxItems.expenseType].
  final String? expenseType;
  const LocalTransaction({
    required this.id,
    required this.userId,
    this.categoryId,
    this.goalId,
    required this.amount,
    this.note,
    required this.transactionDate,
    required this.createdAt,
    this.expenseType,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || goalId != null) {
      map['goal_id'] = Variable<String>(goalId);
    }
    map['amount'] = Variable<int>(amount);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['transaction_date'] = Variable<String>(transactionDate);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || expenseType != null) {
      map['expense_type'] = Variable<String>(expenseType);
    }
    return map;
  }

  LocalTransactionsCompanion toCompanion(bool nullToAbsent) {
    return LocalTransactionsCompanion(
      id: Value(id),
      userId: Value(userId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      goalId: goalId == null && nullToAbsent
          ? const Value.absent()
          : Value(goalId),
      amount: Value(amount),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      transactionDate: Value(transactionDate),
      createdAt: Value(createdAt),
      expenseType: expenseType == null && nullToAbsent
          ? const Value.absent()
          : Value(expenseType),
    );
  }

  factory LocalTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalTransaction(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      goalId: serializer.fromJson<String?>(json['goalId']),
      amount: serializer.fromJson<int>(json['amount']),
      note: serializer.fromJson<String?>(json['note']),
      transactionDate: serializer.fromJson<String>(json['transactionDate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      expenseType: serializer.fromJson<String?>(json['expenseType']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'categoryId': serializer.toJson<String?>(categoryId),
      'goalId': serializer.toJson<String?>(goalId),
      'amount': serializer.toJson<int>(amount),
      'note': serializer.toJson<String?>(note),
      'transactionDate': serializer.toJson<String>(transactionDate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'expenseType': serializer.toJson<String?>(expenseType),
    };
  }

  LocalTransaction copyWith({
    String? id,
    String? userId,
    Value<String?> categoryId = const Value.absent(),
    Value<String?> goalId = const Value.absent(),
    int? amount,
    Value<String?> note = const Value.absent(),
    String? transactionDate,
    DateTime? createdAt,
    Value<String?> expenseType = const Value.absent(),
  }) => LocalTransaction(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    goalId: goalId.present ? goalId.value : this.goalId,
    amount: amount ?? this.amount,
    note: note.present ? note.value : this.note,
    transactionDate: transactionDate ?? this.transactionDate,
    createdAt: createdAt ?? this.createdAt,
    expenseType: expenseType.present ? expenseType.value : this.expenseType,
  );
  LocalTransaction copyWithCompanion(LocalTransactionsCompanion data) {
    return LocalTransaction(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      goalId: data.goalId.present ? data.goalId.value : this.goalId,
      amount: data.amount.present ? data.amount.value : this.amount,
      note: data.note.present ? data.note.value : this.note,
      transactionDate: data.transactionDate.present
          ? data.transactionDate.value
          : this.transactionDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      expenseType: data.expenseType.present
          ? data.expenseType.value
          : this.expenseType,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalTransaction(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('categoryId: $categoryId, ')
          ..write('goalId: $goalId, ')
          ..write('amount: $amount, ')
          ..write('note: $note, ')
          ..write('transactionDate: $transactionDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('expenseType: $expenseType')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    categoryId,
    goalId,
    amount,
    note,
    transactionDate,
    createdAt,
    expenseType,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalTransaction &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.categoryId == this.categoryId &&
          other.goalId == this.goalId &&
          other.amount == this.amount &&
          other.note == this.note &&
          other.transactionDate == this.transactionDate &&
          other.createdAt == this.createdAt &&
          other.expenseType == this.expenseType);
}

class LocalTransactionsCompanion extends UpdateCompanion<LocalTransaction> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String?> categoryId;
  final Value<String?> goalId;
  final Value<int> amount;
  final Value<String?> note;
  final Value<String> transactionDate;
  final Value<DateTime> createdAt;
  final Value<String?> expenseType;
  final Value<int> rowid;
  const LocalTransactionsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.goalId = const Value.absent(),
    this.amount = const Value.absent(),
    this.note = const Value.absent(),
    this.transactionDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.expenseType = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalTransactionsCompanion.insert({
    required String id,
    required String userId,
    this.categoryId = const Value.absent(),
    this.goalId = const Value.absent(),
    required int amount,
    this.note = const Value.absent(),
    required String transactionDate,
    required DateTime createdAt,
    this.expenseType = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       amount = Value(amount),
       transactionDate = Value(transactionDate),
       createdAt = Value(createdAt);
  static Insertable<LocalTransaction> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? categoryId,
    Expression<String>? goalId,
    Expression<int>? amount,
    Expression<String>? note,
    Expression<String>? transactionDate,
    Expression<DateTime>? createdAt,
    Expression<String>? expenseType,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (categoryId != null) 'category_id': categoryId,
      if (goalId != null) 'goal_id': goalId,
      if (amount != null) 'amount': amount,
      if (note != null) 'note': note,
      if (transactionDate != null) 'transaction_date': transactionDate,
      if (createdAt != null) 'created_at': createdAt,
      if (expenseType != null) 'expense_type': expenseType,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalTransactionsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String?>? categoryId,
    Value<String?>? goalId,
    Value<int>? amount,
    Value<String?>? note,
    Value<String>? transactionDate,
    Value<DateTime>? createdAt,
    Value<String?>? expenseType,
    Value<int>? rowid,
  }) {
    return LocalTransactionsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      goalId: goalId ?? this.goalId,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      transactionDate: transactionDate ?? this.transactionDate,
      createdAt: createdAt ?? this.createdAt,
      expenseType: expenseType ?? this.expenseType,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (goalId.present) {
      map['goal_id'] = Variable<String>(goalId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (transactionDate.present) {
      map['transaction_date'] = Variable<String>(transactionDate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (expenseType.present) {
      map['expense_type'] = Variable<String>(expenseType.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('categoryId: $categoryId, ')
          ..write('goalId: $goalId, ')
          ..write('amount: $amount, ')
          ..write('note: $note, ')
          ..write('transactionDate: $transactionDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('expenseType: $expenseType, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$KirainDatabase extends GeneratedDatabase {
  _$KirainDatabase(QueryExecutor e) : super(e);
  $KirainDatabaseManager get managers => $KirainDatabaseManager(this);
  late final $LocalOutboxItemsTable localOutboxItems = $LocalOutboxItemsTable(
    this,
  );
  late final $LocalTransactionsTable localTransactions =
      $LocalTransactionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localOutboxItems,
    localTransactions,
  ];
}

typedef $$LocalOutboxItemsTableCreateCompanionBuilder =
    LocalOutboxItemsCompanion Function({
      required String id,
      required String userId,
      Value<String?> categoryId,
      Value<String?> goalId,
      required int amount,
      Value<String?> note,
      required String transactionDate,
      required DateTime createdAt,
      Value<String?> expenseType,
      required OutboxSyncStatus syncStatus,
      Value<int> retryCount,
      Value<DateTime?> lastAttemptAt,
      Value<String?> errorMessage,
      Value<DateTime?> lockedAt,
      Value<int> rowid,
    });
typedef $$LocalOutboxItemsTableUpdateCompanionBuilder =
    LocalOutboxItemsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String?> categoryId,
      Value<String?> goalId,
      Value<int> amount,
      Value<String?> note,
      Value<String> transactionDate,
      Value<DateTime> createdAt,
      Value<String?> expenseType,
      Value<OutboxSyncStatus> syncStatus,
      Value<int> retryCount,
      Value<DateTime?> lastAttemptAt,
      Value<String?> errorMessage,
      Value<DateTime?> lockedAt,
      Value<int> rowid,
    });

class $$LocalOutboxItemsTableFilterComposer
    extends Composer<_$KirainDatabase, $LocalOutboxItemsTable> {
  $$LocalOutboxItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get goalId => $composableBuilder(
    column: $table.goalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transactionDate => $composableBuilder(
    column: $table.transactionDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expenseType => $composableBuilder(
    column: $table.expenseType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<OutboxSyncStatus, OutboxSyncStatus, String>
  get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lockedAt => $composableBuilder(
    column: $table.lockedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalOutboxItemsTableOrderingComposer
    extends Composer<_$KirainDatabase, $LocalOutboxItemsTable> {
  $$LocalOutboxItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goalId => $composableBuilder(
    column: $table.goalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transactionDate => $composableBuilder(
    column: $table.transactionDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expenseType => $composableBuilder(
    column: $table.expenseType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lockedAt => $composableBuilder(
    column: $table.lockedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalOutboxItemsTableAnnotationComposer
    extends Composer<_$KirainDatabase, $LocalOutboxItemsTable> {
  $$LocalOutboxItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get goalId =>
      $composableBuilder(column: $table.goalId, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get transactionDate => $composableBuilder(
    column: $table.transactionDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get expenseType => $composableBuilder(
    column: $table.expenseType,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<OutboxSyncStatus, String> get syncStatus =>
      $composableBuilder(
        column: $table.syncStatus,
        builder: (column) => column,
      );

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lockedAt =>
      $composableBuilder(column: $table.lockedAt, builder: (column) => column);
}

class $$LocalOutboxItemsTableTableManager
    extends
        RootTableManager<
          _$KirainDatabase,
          $LocalOutboxItemsTable,
          LocalOutboxItem,
          $$LocalOutboxItemsTableFilterComposer,
          $$LocalOutboxItemsTableOrderingComposer,
          $$LocalOutboxItemsTableAnnotationComposer,
          $$LocalOutboxItemsTableCreateCompanionBuilder,
          $$LocalOutboxItemsTableUpdateCompanionBuilder,
          (
            LocalOutboxItem,
            BaseReferences<
              _$KirainDatabase,
              $LocalOutboxItemsTable,
              LocalOutboxItem
            >,
          ),
          LocalOutboxItem,
          PrefetchHooks Function()
        > {
  $$LocalOutboxItemsTableTableManager(
    _$KirainDatabase db,
    $LocalOutboxItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalOutboxItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalOutboxItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalOutboxItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> goalId = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> transactionDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> expenseType = const Value.absent(),
                Value<OutboxSyncStatus> syncStatus = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime?> lockedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalOutboxItemsCompanion(
                id: id,
                userId: userId,
                categoryId: categoryId,
                goalId: goalId,
                amount: amount,
                note: note,
                transactionDate: transactionDate,
                createdAt: createdAt,
                expenseType: expenseType,
                syncStatus: syncStatus,
                retryCount: retryCount,
                lastAttemptAt: lastAttemptAt,
                errorMessage: errorMessage,
                lockedAt: lockedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                Value<String?> categoryId = const Value.absent(),
                Value<String?> goalId = const Value.absent(),
                required int amount,
                Value<String?> note = const Value.absent(),
                required String transactionDate,
                required DateTime createdAt,
                Value<String?> expenseType = const Value.absent(),
                required OutboxSyncStatus syncStatus,
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime?> lockedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalOutboxItemsCompanion.insert(
                id: id,
                userId: userId,
                categoryId: categoryId,
                goalId: goalId,
                amount: amount,
                note: note,
                transactionDate: transactionDate,
                createdAt: createdAt,
                expenseType: expenseType,
                syncStatus: syncStatus,
                retryCount: retryCount,
                lastAttemptAt: lastAttemptAt,
                errorMessage: errorMessage,
                lockedAt: lockedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalOutboxItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$KirainDatabase,
      $LocalOutboxItemsTable,
      LocalOutboxItem,
      $$LocalOutboxItemsTableFilterComposer,
      $$LocalOutboxItemsTableOrderingComposer,
      $$LocalOutboxItemsTableAnnotationComposer,
      $$LocalOutboxItemsTableCreateCompanionBuilder,
      $$LocalOutboxItemsTableUpdateCompanionBuilder,
      (
        LocalOutboxItem,
        BaseReferences<
          _$KirainDatabase,
          $LocalOutboxItemsTable,
          LocalOutboxItem
        >,
      ),
      LocalOutboxItem,
      PrefetchHooks Function()
    >;
typedef $$LocalTransactionsTableCreateCompanionBuilder =
    LocalTransactionsCompanion Function({
      required String id,
      required String userId,
      Value<String?> categoryId,
      Value<String?> goalId,
      required int amount,
      Value<String?> note,
      required String transactionDate,
      required DateTime createdAt,
      Value<String?> expenseType,
      Value<int> rowid,
    });
typedef $$LocalTransactionsTableUpdateCompanionBuilder =
    LocalTransactionsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String?> categoryId,
      Value<String?> goalId,
      Value<int> amount,
      Value<String?> note,
      Value<String> transactionDate,
      Value<DateTime> createdAt,
      Value<String?> expenseType,
      Value<int> rowid,
    });

class $$LocalTransactionsTableFilterComposer
    extends Composer<_$KirainDatabase, $LocalTransactionsTable> {
  $$LocalTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get goalId => $composableBuilder(
    column: $table.goalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transactionDate => $composableBuilder(
    column: $table.transactionDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expenseType => $composableBuilder(
    column: $table.expenseType,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalTransactionsTableOrderingComposer
    extends Composer<_$KirainDatabase, $LocalTransactionsTable> {
  $$LocalTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goalId => $composableBuilder(
    column: $table.goalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transactionDate => $composableBuilder(
    column: $table.transactionDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expenseType => $composableBuilder(
    column: $table.expenseType,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalTransactionsTableAnnotationComposer
    extends Composer<_$KirainDatabase, $LocalTransactionsTable> {
  $$LocalTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get goalId =>
      $composableBuilder(column: $table.goalId, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get transactionDate => $composableBuilder(
    column: $table.transactionDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get expenseType => $composableBuilder(
    column: $table.expenseType,
    builder: (column) => column,
  );
}

class $$LocalTransactionsTableTableManager
    extends
        RootTableManager<
          _$KirainDatabase,
          $LocalTransactionsTable,
          LocalTransaction,
          $$LocalTransactionsTableFilterComposer,
          $$LocalTransactionsTableOrderingComposer,
          $$LocalTransactionsTableAnnotationComposer,
          $$LocalTransactionsTableCreateCompanionBuilder,
          $$LocalTransactionsTableUpdateCompanionBuilder,
          (
            LocalTransaction,
            BaseReferences<
              _$KirainDatabase,
              $LocalTransactionsTable,
              LocalTransaction
            >,
          ),
          LocalTransaction,
          PrefetchHooks Function()
        > {
  $$LocalTransactionsTableTableManager(
    _$KirainDatabase db,
    $LocalTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalTransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalTransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> goalId = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> transactionDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> expenseType = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalTransactionsCompanion(
                id: id,
                userId: userId,
                categoryId: categoryId,
                goalId: goalId,
                amount: amount,
                note: note,
                transactionDate: transactionDate,
                createdAt: createdAt,
                expenseType: expenseType,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                Value<String?> categoryId = const Value.absent(),
                Value<String?> goalId = const Value.absent(),
                required int amount,
                Value<String?> note = const Value.absent(),
                required String transactionDate,
                required DateTime createdAt,
                Value<String?> expenseType = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalTransactionsCompanion.insert(
                id: id,
                userId: userId,
                categoryId: categoryId,
                goalId: goalId,
                amount: amount,
                note: note,
                transactionDate: transactionDate,
                createdAt: createdAt,
                expenseType: expenseType,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$KirainDatabase,
      $LocalTransactionsTable,
      LocalTransaction,
      $$LocalTransactionsTableFilterComposer,
      $$LocalTransactionsTableOrderingComposer,
      $$LocalTransactionsTableAnnotationComposer,
      $$LocalTransactionsTableCreateCompanionBuilder,
      $$LocalTransactionsTableUpdateCompanionBuilder,
      (
        LocalTransaction,
        BaseReferences<
          _$KirainDatabase,
          $LocalTransactionsTable,
          LocalTransaction
        >,
      ),
      LocalTransaction,
      PrefetchHooks Function()
    >;

class $KirainDatabaseManager {
  final _$KirainDatabase _db;
  $KirainDatabaseManager(this._db);
  $$LocalOutboxItemsTableTableManager get localOutboxItems =>
      $$LocalOutboxItemsTableTableManager(_db, _db.localOutboxItems);
  $$LocalTransactionsTableTableManager get localTransactions =>
      $$LocalTransactionsTableTableManager(_db, _db.localTransactions);
}
