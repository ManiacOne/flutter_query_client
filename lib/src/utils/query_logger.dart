import 'package:logging/logging.dart';

/// Internal logger for flutter_query.
///
/// Logging is disabled by default. Enable it by calling
/// [QueryLogger.enable] before creating any controllers.
///
/// ```dart
/// // In your main() or app initialization:
/// QueryLogger.enable();
///
/// // Or with a custom log handler:
/// QueryLogger.enable(onLog: (record) {
///   debugPrint('[${record.level.name}] ${record.loggerName}: ${record.message}');
/// });
/// ```
///
/// Log levels used:
/// - **INFO**: Query lifecycle events (fetch start, success, cache hit)
/// - **FINE**: Detailed operations (retry attempts, stale notifications)
/// - **WARNING**: Recoverable issues (network pause, abort)
/// - **SEVERE**: Errors (fetch failures, exhausted retries)
class QueryLogger {
  static final Logger _logger = Logger('flutter_query');
  static bool _enabled = false;

  QueryLogger._();

  /// Whether logging is currently enabled.
  static bool get isEnabled => _enabled;

  /// Enable logging for flutter_query.
  ///
  /// [level] controls the minimum severity level to log. Default is [Level.ALL].
  /// [onLog] is an optional custom handler. If not provided, logs are printed
  /// to the console via `Logger.root.onRecord`.
  static void enable({
    Level? level,
    void Function(LogRecord record)? onLog,
  }) {
    _enabled = true;
    final resolvedLevel = level ?? Level.ALL;
    hierarchicalLoggingEnabled = true;
    _logger.level = resolvedLevel;
    Logger.root.level = resolvedLevel;
    if (onLog != null) {
      Logger.root.onRecord.listen(onLog);
    } else {
      Logger.root.onRecord.listen((record) {
        // ignore-for-file: avoid_print
        // ignore: avoid_print
        print('[${record.level.name}] ${record.loggerName}: ${record.message}');
      });
    }
  }

  /// Disable logging.
  static void disable() {
    _enabled = false;
    _logger.level = Level.OFF;
  }

  // ─── Log methods ──────────────────────────────────────────────────

  static void info(String message) {
    if (_enabled) _logger.info(message);
  }

  static void fine(String message) {
    if (_enabled) _logger.fine(message);
  }

  static void warning(String message) {
    if (_enabled) _logger.warning(message);
  }

  static void severe(String message, [Object? error, StackTrace? stackTrace]) {
    if (_enabled) _logger.severe(message, error, stackTrace);
  }
}
