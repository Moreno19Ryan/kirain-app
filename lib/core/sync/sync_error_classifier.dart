import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// What SyncWorker should do about a failed sync attempt.
enum SyncOutcome {
  /// Worth trying again — a transport hiccup or a server-side condition
  /// that's plausibly transient (rate limit, momentary outage).
  retryable,

  /// Won't succeed no matter how many times it's retried (bad data, RLS
  /// rejection, a real FK violation). Goes to FAILED for a human to look
  /// at, not into an infinite retry loop.
  permanent,

  /// The request failed because the session isn't valid right now, not
  /// because of anything wrong with the transaction itself. A sleep-and-
  /// retry loop can't fix this — only re-authentication can — so it's kept
  /// distinct from [permanent] (it's not that the data is bad) and from
  /// [retryable] (backing off and hammering the same request again is
  /// pointless without a session change in between).
  authRequired,

  /// Not actually a failure: the same UUID this attempt was sending already
  /// exists server-side (see ADR-002's "same UUID reused on retry, must not
  /// duplicate" invariant — normally prevented from ever surfacing here by
  /// `upsert(..., ignoreDuplicates: true)`, but classified defensively in
  /// case a duplicate-key condition reaches this code some other way).
  alreadySynced,
}

/// Maps a thrown sync error to a [SyncOutcome], per ADR-002's error
/// classification policy. Pure and synchronous — no I/O, so easy to test
/// with constructed exceptions rather than a real network/Supabase mock.
SyncOutcome classifySyncError(Object error) {
  // Auth: check the more specific retryable-fetch subtype before the
  // general AuthException case below.
  if (error is AuthRetryableFetchException) return SyncOutcome.retryable;
  if (error is AuthException) return _classifyAuthStatus(error.statusCode);

  if (error is PostgrestException) return _classifyPostgrest(error);

  // Network transport: nothing to inspect beyond "the request never
  // completed" — always worth another attempt.
  if (error is SocketException) return SyncOutcome.retryable;
  if (error is TimeoutException) return SyncOutcome.retryable;
  if (error is http.ClientException) return SyncOutcome.retryable;

  // Unknown/unrecognized error shape: fail safe toward bounded retry rather
  // than risking silent data loss by parking an untriaged error in FAILED.
  return SyncOutcome.retryable;
}

SyncOutcome _classifyPostgrest(PostgrestException error) {
  final code = error.code;
  if (code == null) return SyncOutcome.retryable;

  // Real Postgres/PostgREST error codes (SQLSTATE, or PostgREST's own
  // prefixed codes) — these come from a JSON error body the server
  // actually parsed and understood.
  switch (code) {
    case '23505': // unique_violation: this UUID already exists server-side.
      return SyncOutcome.alreadySynced;
    case '23503': // foreign_key_violation
    case '42501': // insufficient_privilege — RLS rejected the write
    case '22P02': // invalid_text_representation — malformed payload
    case '23514': // check_violation
      return SyncOutcome.permanent;
  }

  // Fallback shape: PostgrestException.fromJson stringifies the raw HTTP
  // status into `code` whenever the response body didn't carry a
  // recognizable Postgres error code (see postgrest_builder.dart). Treat
  // those as ordinary HTTP-status classification.
  return _classifyHttpStatus(code, error);
}

SyncOutcome _classifyHttpStatus(String status, PostgrestException error) {
  switch (status) {
    case '429':
    case '500':
    case '502':
    case '503':
    case '504':
      return SyncOutcome.retryable;
    case '400':
      return SyncOutcome.permanent;
    case '401':
      return SyncOutcome.authRequired;
    case '409':
      return _classifyConflict('${error.message} ${error.details ?? ''}');
  }
  return SyncOutcome.retryable;
}

SyncOutcome _classifyAuthStatus(String? statusCode) {
  if (statusCode == '401') return SyncOutcome.authRequired;
  // An auth error without a 401 (e.g. a malformed request the auth server
  // rejected outright) isn't something a session refresh fixes either, but
  // it's not necessarily permanent — fail safe toward bounded retry.
  return SyncOutcome.retryable;
}

/// A 409 is never classified by status code alone (per ADR-002) — it can
/// mean "this exact row already exists" (safe to treat as already-synced)
/// or a genuine, unresolved conflict (not safe to silently resolve either
/// way). Text-sniffing the actual PostgREST error is the only signal
/// available without a second round-trip.
SyncOutcome _classifyConflict(String description) {
  final normalized = description.toLowerCase();
  if (normalized.contains('duplicate') || normalized.contains('already exists')) {
    return SyncOutcome.alreadySynced;
  }
  // An unrecognized conflict shape: don't guess which side is right by
  // either retrying forever or silently discarding it. Park it in FAILED
  // so a human looks at it.
  return SyncOutcome.permanent;
}
