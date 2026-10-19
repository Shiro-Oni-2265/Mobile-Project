import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../domain/models.dart';

class Reminders {
  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  final void Function()? onOpen;
  bool _ready = false;
  Future<void> _pending = Future.value();
  Reminders({this.onOpen});
  Future<void> initialize() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone));
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
      ),
      onDidReceiveNotificationResponse: (_) => onOpen?.call(),
    );
    _ready = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    return await plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        false;
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final job = _pending.catchError((Object _) {}).then((_) => action());
    _pending = job;
    return job;
  }

  Future<void> cancel() => _enqueue(() async {
    await initialize();
    await plugin.cancelAll();
  });

  Future<void> sync(Notebook book, Map<String, Ingredient> catalog) =>
      _enqueue(() => _sync(book, catalog));

  Future<void> _sync(Notebook book, Map<String, Ingredient> catalog) async {
    await initialize();
    await plugin.cancelAll();
    if (!book.preferences.reminders) return;
    final pending = <({DateTime date, String title, String body})>[];
    for (final lot in book.pantry) {
      final expiry = DateTime.parse(lot.expiry);
      for (final before in [2, 0]) {
        final day = DateTime(expiry.year, expiry.month, expiry.day - before, 8);
        if (day.isAfter(DateTime.now())) {
          pending.add((
            date: day,
            title: before == 0
                ? 'Thực phẩm đến hạn hôm nay'
                : 'Dùng sớm để tránh lãng phí',
            body:
                '${catalog[lot.ingredientId]?.name ?? lot.ingredientId} • Hạn ${lot.expiry}',
          ));
        }
      }
    }
    pending.sort((a, b) => a.date.compareTo(b.date));
    var id = 0;
    // Bound Android's scheduled alarm count; refreshed on app open and edits.
    for (final reminder in pending.take(200)) {
      await plugin.zonedSchedule(
        id++,
        reminder.title,
        reminder.body,
        tz.TZDateTime.from(reminder.date, tz.local),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'pantry',
      );
    }
  }

  Future<void> test() async {
    if (!await requestPermission()) {
      throw StateError('Chưa được cấp quyền thông báo.');
    }
    await plugin.zonedSchedule(
      99999,
      'NauGi • Nhắc hạn thử',
      'Thông báo thử cho tủ lạnh của bạn.',
      tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1)),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'pantry',
    );
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'expiry',
      'Hạn sử dụng thực phẩm',
      channelDescription: 'Nhắc dùng nguyên liệu trước và trong ngày hết hạn',
      importance: Importance.defaultImportance,
    ),
  );
}
