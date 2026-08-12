import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// A client-generated UUID v4. Used for records (like transactions) that
/// need their ID decided before the request that creates them is even sent
/// — e.g. a retried offline-queue send can reuse the same ID, so the insert
/// is idempotent (a unique-constraint conflict on retry just means "already
/// synced", not a duplicate row) instead of relying on the server to hand
/// out a fresh auto-increment/default-generated ID on every attempt.
String newId() => _uuid.v4();
