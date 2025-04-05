import 'dart:async';

class RetryHelper {
  static Future<T> retry<T>({
    required Future<T> Function() operation,
    int maxAttempts = 3,
    Duration delay = const Duration(seconds: 1),
    bool Function(Exception)? shouldRetry,
  }) async {
    int attempts = 0;
    while (true) {
      try {
        attempts++;
        return await operation();
      } catch (e) {
        if (attempts >= maxAttempts) {
          rethrow;
        }
        
        if (shouldRetry != null && !shouldRetry(e as Exception)) {
          rethrow;
        }
        
        await Future.delayed(delay * attempts);
      }
    }
  }
} 