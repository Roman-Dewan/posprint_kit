import 'dart:developer' as developer;

/// Log severity levels for posprint_kit / escpos_link.
///
/// Set [PosLogger.level] to control the threshold of messages printed or handled.
enum LogLevel {
  /// Detailed trace information, e.g. raw byte counts, chunk sizes.
  verbose(0),

  /// Debugging information useful during development.
  debug(1),

  /// Informational messages about routine operations.
  info(2),

  /// Warnings about unexpected situations that do not halt printing.
  warning(3),

  /// Errors that caused an operation to fail.
  error(4),

  /// Disables all logging output.
  none(5);

  const LogLevel(this.value);

  /// Numeric representation of the severity for comparison.
  final int value;

  /// Returns `true` if this level is at or above [threshold].
  bool isAtLeast(LogLevel threshold) => value >= threshold.value;
}

/// Package-wide logger that respects [LogLevel] and avoids raw `print()` calls.
///
/// Example:
/// ```dart
/// PosLogger.level = LogLevel.verbose;
/// PosLogger.info('Connecting to printer...');
/// ```
class PosLogger {
  PosLogger._();

  /// The active logging threshold. Messages below this level are ignored.
  ///
  /// Defaults to [LogLevel.warning].
  static LogLevel level = LogLevel.warning;

  /// Optional custom log listener for external log sinks (e.g. Firebase Crashlytics).
  static void Function(
    LogLevel level,
    String message,
    Object? error,
    StackTrace? stackTrace,
  )? onLog;

  /// Logs a [message] at the given [logLevel].
  static void log(
    LogLevel logLevel,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (logLevel == LogLevel.none || !logLevel.isAtLeast(level)) {
      return;
    }

    if (onLog != null) {
      onLog!(logLevel, message, error, stackTrace);
      return;
    }

    developer.log(
      message,
      name: 'posprint_kit',
      level: _toDeveloperLogLevel(logLevel),
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Logs a [message] at [LogLevel.verbose].
  static void verbose(String message) => log(LogLevel.verbose, message);

  /// Logs a [message] at [LogLevel.debug].
  static void debug(String message) => log(LogLevel.debug, message);

  /// Logs a [message] at [LogLevel.info].
  static void info(String message) => log(LogLevel.info, message);

  /// Logs a [message] at [LogLevel.warning].
  static void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => log(LogLevel.warning, message, error: error, stackTrace: stackTrace);

  /// Logs a [message] at [LogLevel.error].
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => log(LogLevel.error, message, error: error, stackTrace: stackTrace);

  static int _toDeveloperLogLevel(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return 300;
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
      case LogLevel.none:
        return 0;
    }
  }
}

