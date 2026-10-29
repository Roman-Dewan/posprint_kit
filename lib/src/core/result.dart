/// Error codes representing all standard failure modes of the printing library.
enum PrinterErrorCode {
  /// Unable to establish a connection to the printer (e.g. host unreachable, wrong port).
  connectionFailed,

  /// The active connection was unexpectedly terminated during or before a print job.
  connectionLost,

  /// An operation (connect, write, or read) exceeded its time limit.
  timeout,

  /// Operating system permission (Bluetooth, USB, or local network) was not granted.
  permissionDenied,

  /// The requested transport is not supported on the current operating system.
  unsupportedPlatform,

  /// The printer reported that it is out of paper.
  paperOut,

  /// The printer reported that its cover is open.
  coverOpen,

  /// A required font glyph or system font is missing on the device.
  fontMissing,

  /// Text or widget rasterization failed.
  renderFailed,

  /// An unexpected or unclassified error occurred.
  unknown,
}

/// A user-friendly error with a plain-language [message] explaining what happened
/// and a [hint] explaining how to resolve it.
///
/// Designed so junior developers and end users can troubleshoot printing issues
/// without deciphering stack traces or platform codes.
class PrinterError {
  const PrinterError(
    this.code, {
    required this.message,
    required this.hint,
  });

  /// The categorical code for this error.
  final PrinterErrorCode code;

  /// Plain-English explanation of what failed.
  final String message;

  /// Actionable instruction explaining how to fix the problem.
  final String hint;

  /// Standard permission denied error for Bluetooth or USB.
  static const permissionDenied = PrinterError(
    PrinterErrorCode.permissionDenied,
    message: 'Bluetooth or device permission was denied.',
    hint: 'Request the permission again. On Android 12+, ensure BLUETOOTH_CONNECT '
        'and BLUETOOTH_SCAN are declared in AndroidManifest.xml.',
  );

  /// Standard connection lost error.
  static const connectionLost = PrinterError(
    PrinterErrorCode.connectionLost,
    message: 'The connection to the printer was lost.',
    hint: 'Ensure the printer is powered on, within range, and that its cables '
        'or wireless connections are stable.',
  );

  /// Standard paper out error.
  static const paperOut = PrinterError(
    PrinterErrorCode.paperOut,
    message: 'The printer is out of paper.',
    hint: 'Open the printer cover, insert a fresh paper roll, and close the cover securely.',
  );

  /// Standard cover open error.
  static const coverOpen = PrinterError(
    PrinterErrorCode.coverOpen,
    message: 'The printer cover is open.',
    hint: 'Close the printer cover firmly until it clicks into place.',
  );

  /// Creates a [connectionFailed] error with host and port details.
  static PrinterError connectionFailed({required String host, required int port}) =>
      PrinterError(
        PrinterErrorCode.connectionFailed,
        message: 'Could not connect to the printer at $host:$port.',
        hint: 'Check that the printer is on, connected to the same network as this device, '
            'and that the IP is correct (print a self-test page by holding the FEED button '
            'while powering on). Most network receipt printers use port 9100.',
      );

  /// Creates a [timeout] error with connection or write context.
  static PrinterError timeout({required String host, Duration? duration}) =>
      PrinterError(
        PrinterErrorCode.timeout,
        message: 'The printer connection to $host timed out'
            '${duration != null ? ' after ${duration.inSeconds} seconds' : ''}.',
        hint: 'Check that the printer is powered on and reachable on your local network. '
            'Check for firewall restrictions blocking port 9100.',
      );

  /// Creates an [unsupportedPlatform] error for a given transport.
  static PrinterError unsupportedPlatform({
    required String transport,
    required String platform,
  }) =>
      PrinterError(
        PrinterErrorCode.unsupportedPlatform,
        message: '$transport is not supported on $platform.',
        hint: 'Consult the platform compatibility matrix in the documentation. '
            'For example, iOS does not permit generic USB or Bluetooth Classic SPP printing.',
      );

  /// Creates a [fontMissing] error for scripts requiring special fonts.
  static PrinterError fontMissing({required String language}) => PrinterError(
        PrinterErrorCode.fontMissing,
        message: 'No system font found on this device for $language.',
        hint: 'Supply a custom font family or fallback font (e.g. Noto Sans) in your '
            'TextStyleSpec configuration, or use an optional font pack.',
      );

  /// Creates a [renderFailed] error when bitmap rendering fails.
  static PrinterError renderFailed({required String reason}) => PrinterError(
        PrinterErrorCode.renderFailed,
        message: 'Failed to rasterize receipt content: $reason',
        hint: 'Verify that receipt dimensions are positive and that image assets exist and are valid.',
      );

  /// Creates an [unknown] error with optional [detail].
  static PrinterError unknown({String? detail}) => PrinterError(
        PrinterErrorCode.unknown,
        message: detail != null && detail.isNotEmpty
            ? 'An unexpected error occurred: $detail'
            : 'An unexpected printing error occurred.',
        hint: 'Check the device console and package logs (EscposLink.logLevel = LogLevel.verbose) '
            'for more details.',
      );

  @override
  String toString() => 'PrinterError($code, message: "$message", hint: "$hint")';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterError &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          message == other.message &&
          hint == other.hint;

  @override
  int get hashCode => Object.hash(code, message, hint);
}

/// A discriminated union representing either a successful outcome ([Ok])
/// or an error outcome ([Err]).
///
/// Prevents unhandled exceptions across the public API and gives junior developers
/// a straightforward `.when()` method to handle both outcomes.
sealed class Result<T> {
  const Result();

  /// Constructs a successful [Result] holding [value].
  const factory Result.ok(T value) = Ok<T>;

  /// Constructs an error [Result] holding [error].
  const factory Result.error(PrinterError error) = Err<T>;

  /// Returns `true` if this result is an [Ok].
  bool get isOk => this is Ok<T>;

  /// Returns `true` if this result is an [Err].
  bool get isError => this is Err<T>;

  /// Returns the successful value if [isOk], or `null` otherwise.
  T? get valueOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => null,
      };

  /// Returns the error if [isError], or `null` otherwise.
  PrinterError? get errorOrNull => switch (this) {
        Ok<T>() => null,
        Err<T>(:final error) => error,
      };

  /// Evaluates [ok] if this is a success, or [error] if this is a failure.
  ///
  /// ```dart
  /// final result = await printer.print(receipt);
  /// result.when(
  ///   ok: (_) => print('Printed!'),
  ///   error: (e) => print('${e.message} Hint: ${e.hint}'),
  /// );
  /// ```
  R when<R>({
    required R Function(T value) ok,
    required R Function(PrinterError error) error,
  });
}

/// A successful [Result] containing [value].
final class Ok<T> extends Result<T> {
  const Ok(this.value);

  /// The outcome value.
  final T value;

  @override
  R when<R>({
    required R Function(T value) ok,
    required R Function(PrinterError error) error,
  }) =>
      ok(value);

  @override
  String toString() => 'Result.ok($value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Ok<T> && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => Object.hash(runtimeType, value);
}

/// An error [Result] containing [error].
final class Err<T> extends Result<T> {
  const Err(this.error);

  /// The printer error details.
  final PrinterError error;

  @override
  R when<R>({
    required R Function(T value) ok,
    required R Function(PrinterError error) error,
  }) =>
      error(this.error);

  @override
  String toString() => 'Result.error($error)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Err<T> && runtimeType == other.runtimeType && error == other.error;

  @override
  int get hashCode => Object.hash(runtimeType, error);
}

