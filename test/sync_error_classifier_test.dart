import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kirain/core/sync/sync_error_classifier.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('classifySyncError', () {
    group('network transport', () {
      test('SocketException is retryable', () {
        expect(classifySyncError(const SocketException('no route')), SyncOutcome.retryable);
      });

      test('TimeoutException is retryable', () {
        expect(classifySyncError(TimeoutException('timed out')), SyncOutcome.retryable);
      });

      test('http.ClientException is retryable', () {
        expect(classifySyncError(http.ClientException('connection reset')), SyncOutcome.retryable);
      });
    });

    group('HTTP status policy (PostgrestException.code as stringified status)', () {
      for (final status in ['429', '500', '502', '503', '504']) {
        test('$status is retryable', () {
          final error = PostgrestException(message: 'server trouble', code: status);
          expect(classifySyncError(error), SyncOutcome.retryable);
        });
      }

      test('400 is permanent', () {
        final error = PostgrestException(message: 'bad request', code: '400');
        expect(classifySyncError(error), SyncOutcome.permanent);
      });
    });

    group('Postgres SQLSTATE policy', () {
      test('23505 unique_violation is already-synced, not a failure', () {
        final error = PostgrestException(message: 'duplicate key value violates unique constraint', code: '23505');
        expect(classifySyncError(error), SyncOutcome.alreadySynced);
      });

      test('23503 foreign_key_violation is permanent', () {
        final error = PostgrestException(message: 'violates foreign key constraint', code: '23503');
        expect(classifySyncError(error), SyncOutcome.permanent);
      });

      test('42501 insufficient_privilege (RLS rejection) is permanent', () {
        final error = PostgrestException(message: 'new row violates row-level security policy', code: '42501');
        expect(classifySyncError(error), SyncOutcome.permanent);
      });

      test('22P02 invalid_text_representation (malformed payload) is permanent, not retried forever', () {
        final error = PostgrestException(message: 'invalid input syntax for type uuid', code: '22P02');
        expect(classifySyncError(error), SyncOutcome.permanent);
      });
    });

    group('409 — must be classified by actual error content, not status code alone', () {
      test('a duplicate-flavored 409 is already-synced', () {
        final error = PostgrestException(message: 'duplicate key value violates unique constraint "x"', code: '409');
        expect(classifySyncError(error), SyncOutcome.alreadySynced);
      });

      test('a 409 whose message says "already exists" is already-synced', () {
        final error = PostgrestException(message: 'Resource already exists', code: '409');
        expect(classifySyncError(error), SyncOutcome.alreadySynced);
      });

      test('an unrecognized 409 conflict is permanent, not guessed at', () {
        final error = PostgrestException(message: 'could not serialize access due to concurrent update', code: '409');
        expect(classifySyncError(error), SyncOutcome.permanent);
      });
    });

    group('auth — handled separately from generic HTTP/Postgrest errors', () {
      test('401 via PostgrestException.code is authRequired', () {
        final error = PostgrestException(message: 'JWT expired', code: '401');
        expect(classifySyncError(error), SyncOutcome.authRequired);
      });

      test('AuthApiException with statusCode 401 is authRequired', () {
        const error = AuthApiException('invalid JWT', statusCode: '401');
        expect(classifySyncError(error), SyncOutcome.authRequired);
      });

      test('AuthRetryableFetchException is retryable, not authRequired', () {
        final error = AuthRetryableFetchException(statusCode: '0');
        expect(classifySyncError(error), SyncOutcome.retryable);
      });

      test('a non-401 AuthException fails safe toward retryable', () {
        const error = AuthApiException('unexpected auth error', statusCode: '500');
        expect(classifySyncError(error), SyncOutcome.retryable);
      });
    });

    test('an unrecognized error shape fails safe toward bounded retry, not silent data loss', () {
      expect(classifySyncError(Exception('something odd')), SyncOutcome.retryable);
    });

    test('a PostgrestException with no code at all fails safe toward retryable', () {
      const error = PostgrestException(message: 'unknown');
      expect(classifySyncError(error), SyncOutcome.retryable);
    });
  });
}
