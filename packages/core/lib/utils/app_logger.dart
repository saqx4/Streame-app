import 'package:logging/logging.dart';

/// Global app logger — use `log.info(...)`, `log.warning(...)`, `log.severe(...)`.
///
/// In debug mode, messages print to console with tag + level.
/// In release mode, only warnings and errors are emitted.
final log = Logger('Streame');

/// Call once at app startup (before any log calls).
void initLogging() {
  Logger.root.level = _isDebug ? Level.ALL : Level.WARNING;
  Logger.root.onRecord.listen((record) {
    debugLogHandler(record);
  });
}

bool get _isDebug => bool.fromEnvironment('dart.vm.product') == false;

void debugLogHandler(LogRecord record) {
  final tag = record.loggerName;
  final level = record.level.name.padRight(7);
  // ignore: avoid_print
  print('[$level] [$tag] ${record.message}');
}
