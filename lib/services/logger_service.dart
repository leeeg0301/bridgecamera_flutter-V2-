import 'dart:io';
import 'package:path/path.dart' as p;

class LoggerService {
  LoggerService._();
  static final LoggerService I = LoggerService._();

  Future<Directory> logsDir() async {
    // ✅ [변경] 공용 Download 폴더에 logs 저장
    final d = Directory('/storage/emulated/0/Download/BridgeCameraApp/logs');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  String _stamp() {
    final now = DateTime.now();
    String two(int x) => x.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  }

  Future<File> _todayFile() async {
    final now = DateTime.now();
    String two(int x) => x.toString().padLeft(2, '0');
    final name = 'error_${now.year}${two(now.month)}${two(now.day)}.log';
    return File(p.join((await logsDir()).path, name));
  }

  Future<void> e(String message, {Object? error, StackTrace? st}) async {
    final f = await _todayFile();
    final buf = StringBuffer()
      ..writeln('[$_stamp()] ERROR: $message');
    if (error != null) buf.writeln('  error: $error');
    if (st != null) buf.writeln('  stack: $st');
    buf.writeln('---');
    await f.writeAsString(buf.toString(), mode: FileMode.append, flush: true);
  }
}
