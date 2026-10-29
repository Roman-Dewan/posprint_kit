import 'dart:async';

import '../core/logger.dart';
import '../core/result.dart';

/// Represents an individual print job waiting or executing in a FIFO queue.
class PrintJob<T> {
  PrintJob({
    required this.execute,
    this.maxRetries = 3,
    this.retryDelays = const [
      Duration(milliseconds: 500),
      Duration(seconds: 1),
      Duration(seconds: 2),
    ],
  }) : completer = Completer<Result<T>>();

  /// The action to execute.
  final Future<Result<T>> Function() execute;

  /// Maximum retry attempts on transient failure.
  final int maxRetries;

  /// Backoff delays between retry attempts.
  final List<Duration> retryDelays;

  /// Completer signaled when the job succeeds or exhausts retries.
  final Completer<Result<T>> completer;
}

/// A FIFO job execution queue that runs strictly one print job at a time.
///
/// Prevents concurrent print jobs from interleaving bytes on the same printer,
/// and retries transient failures with exponential backoff.
class PrintQueue {
  PrintQueue();

  final _queue = <PrintJob<dynamic>>[];
  bool _isProcessing = false;

  /// Enqueues [action] and returns a future that completes with the outcome [Result<T>].
  Future<Result<T>> enqueue<T>(
    Future<Result<T>> Function() action, {
    int maxRetries = 3,
    List<Duration> retryDelays = const [
      Duration(milliseconds: 500),
      Duration(seconds: 1),
      Duration(seconds: 2),
    ],
  }) {
    final job = PrintJob<T>(
      execute: action,
      maxRetries: maxRetries,
      retryDelays: retryDelays,
    );
    _queue.add(job);
    _processNext();
    return job.completer.future;
  }

  /// Number of jobs currently waiting or executing in the queue.
  int get length => _queue.length;

  /// Whether the queue is actively executing a print job.
  bool get isProcessing => _isProcessing;

  void _processNext() async {
    if (_isProcessing || _queue.isEmpty) {
      return;
    }

    _isProcessing = true;
    final job = _queue.removeAt(0);

    var attempts = 0;
    Result<dynamic> result;

    while (true) {
      try {
        result = await job.execute();
        if (result.isOk) {
          break;
        }

        // Retry logic for transient errors
        attempts++;
        if (attempts > job.maxRetries) {
          PosLogger.warning(
            'Print job failed after $attempts attempts: '
            '${result.errorOrNull?.message}',
          );
          break;
        }

        final delayIndex = (attempts - 1).clamp(0, job.retryDelays.length - 1);
        final delay = job.retryDelays[delayIndex];
        PosLogger.info(
          'Print job failed; retrying attempt $attempts of ${job.maxRetries} '
          'in ${delay.inMilliseconds} ms...',
        );
        await Future<void>.delayed(delay);
      } catch (e, stackTrace) {
        // OLD: PosLogger.error('Unhandled exception executing print job: $e', e, stackTrace);
        PosLogger.error(
          'Unhandled exception executing print job: $e',
          error: e,
          stackTrace: stackTrace,
        );
        result = Result.error(PrinterError.unknown(detail: e.toString()));
        break;
      }
    }

    job.completer.complete(result);
    _isProcessing = false;

    // Continue processing next job in FIFO queue
    _processNext();
  }

  /// Clears all pending jobs in the queue with a cancellation error.
  void clear() {
    while (_queue.isNotEmpty) {
      final job = _queue.removeAt(0);
      job.completer.complete(
        const Result.error(
          PrinterError(
            PrinterErrorCode.connectionLost,
            message: 'Print job was cancelled.',
            hint: 'The print queue was cleared or closed before the job started.',
          ),
        ),
      );
    }
  }
}
