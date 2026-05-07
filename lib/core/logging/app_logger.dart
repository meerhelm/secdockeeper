import 'package:logger/logger.dart';

/// Single application-wide logger. Import this file and call [log.d], [log.i],
/// [log.w], [log.e], [log.f] anywhere — never use `print` or `debugPrint`.
///
/// In release builds the default [DevelopmentFilter] suppresses all output, so
/// these calls are safe to leave in production code paths. **Don't log
/// plaintext document contents, master passwords, decryption keys, or hidden
/// tag names.** Anything that ends up in the log is also visible in attached
/// debuggers and crash dumps.
final Logger log = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 8,
    lineLength: 100,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);
