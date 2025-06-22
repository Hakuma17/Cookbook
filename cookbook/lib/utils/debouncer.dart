import 'dart:async';

/// Debouncer หน่วงเวลาให้ callback รันเมื่อไม่มีการเรียกซ้ำภายในช่วงเวลา [delay]
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 800)});

  /// เรียกใช้งานแบบ `.run(() {})`
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// เรียกใช้งานแบบ instance เช่น `debouncer(() {})`
  void call(void Function() action) => run(action);

  /// ยกเลิก timer ที่ค้างอยู่
  void dispose() {
    _timer?.cancel();
  }
}
