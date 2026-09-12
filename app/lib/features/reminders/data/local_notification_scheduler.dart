import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:nourishly_domain/nourishly_domain.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// The v1.0 adapter for [ReminderScheduler] (§29.3): local notifications,
/// no server, nothing leaving the device.
///
/// Deliberately thin. Every decision about *what* fires and *when* lives
/// in [ReminderPlanner], which is pure and tested; this class does the two
/// things only a plugin can do — ask the OS for permission, and make the
/// platform's pending set match a list it is handed.
class LocalNotificationScheduler implements ReminderScheduler {
  LocalNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channelId = 'nourishly_reminders';
  static const _channelName = 'Reminders';
  static const _channelDescription =
      'Water, meal and end-of-day reminders you have turned on.';

  bool _initialised = false;
  String? _launchRoute;

  /// Whether the platform side actually answered.
  ///
  /// False on a host with no notification implementation — a widget test,
  /// a desktop build, an OS that has removed the capability. Every method
  /// then becomes a no-op rather than throwing, because §29.4's "the app
  /// remains fully functional" has to hold when the *platform* is what
  /// says no, not only when the user does.
  bool _available = false;

  /// Called once at startup, before any reminder work.
  ///
  /// Initialising does **not** ask for permission — §29.1 is explicit that
  /// the ask belongs to the moment the user turns on their first reminder.
  /// All this does is register the channel and find out whether the app
  /// was opened by tapping a notification.
  Future<void> initialise({void Function(String route)? onTap}) async {
    if (_initialised) return;
    _initialised = true;

    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } on Object catch (error) {
      // A device whose zone name the database does not recognise falls
      // back to UTC rather than failing to schedule anything. Reminders
      // being an hour out is a bug; reminders not existing is a broken
      // feature.
      debugPrint('Nourishly: could not resolve the local time zone ($error).');
    }

    try {
      await _initialisePlatform(onTap);
      _available = true;
    } on Object catch (error) {
      // Nothing here is worth failing a launch over. The app runs; the
      // reminders screen will report the permission as unavailable and
      // every other path is untouched.
      debugPrint('Nourishly: notifications are unavailable ($error).');
      _available = false;
    }
  }

  Future<void> _initialisePlatform(void Function(String route)? onTap) async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // All three false: asking here would be asking at launch.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route == null || route.isEmpty) return;
        _launchRoute = route;
        onTap?.call(route);
      },
    );

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _launchRoute = launch?.notificationResponse?.payload;
    }

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.defaultImportance,
          ),
        );
  }

  @override
  Future<NotificationPermission> permission() async {
    if (!_available) return NotificationPermission.denied;
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final enabled = await android?.areNotificationsEnabled();
      return switch (enabled) {
        true => NotificationPermission.granted,
        false => NotificationPermission.denied,
        null => NotificationPermission.notRequested,
      };
    }
    // iOS gives no "has it been asked yet" signal short of requesting, and
    // requesting in order to find out would be the launch-time prompt
    // §29.1 rules out. Unknown reads as not-yet-asked, which is the state
    // that leads to a prompt at the right moment instead.
    return NotificationPermission.notRequested;
  }

  @override
  Future<NotificationPermission> requestPermission() async {
    if (!_available) return NotificationPermission.denied;
    final granted = Platform.isAndroid
        ? await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission()
        : await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true);
    return (granted ?? false)
        ? NotificationPermission.granted
        : NotificationPermission.denied;
  }

  @override
  Future<void> apply(List<ScheduledReminder> reminders) async {
    if (!_available) return;
    // Cancel-then-schedule rather than diff-and-patch. The pending set is
    // at most four notifications; reconciling it wholesale is cheap, and
    // it is the only version of this that cannot leave a stale reminder
    // behind after a rule changes.
    await _plugin.cancelAll();
    if (reminders.isEmpty) return;

    if (await permission() == NotificationPermission.denied) return;

    for (var i = 0; i < reminders.length; i++) {
      final reminder = reminders[i];
      await _plugin.zonedSchedule(
        i,
        reminder.title,
        reminder.body,
        tz.TZDateTime.from(reminder.when, tz.local),
        NotificationDetails(
          android: const AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        // Inexact, and allowed while the device is idle. See the manifest
        // for why an exact alarm is not worth a restricted permission
        // here: the OS may slide a reminder by a few minutes, which for
        // "drink some water" is not a difference anyone can perceive.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: reminder.route,
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    if (!_available) return;
    await _plugin.cancelAll();
  }

  @override
  Future<String?> takeLaunchRoute() async {
    final route = _launchRoute;
    _launchRoute = null;
    return route;
  }
}

/// A scheduler for tests, and for any platform without a notification
/// implementation — everything works, nothing is posted.
class NoopReminderScheduler implements ReminderScheduler {
  NoopReminderScheduler({
    this.permissionState = NotificationPermission.granted,
  });

  NotificationPermission permissionState;

  /// The last set [apply] was given, so a test can assert on what would
  /// have been scheduled.
  List<ScheduledReminder> applied = const [];

  @override
  Future<void> apply(List<ScheduledReminder> reminders) async {
    applied = reminders;
  }

  @override
  Future<void> cancelAll() async => applied = const [];

  @override
  Future<NotificationPermission> permission() async => permissionState;

  @override
  Future<NotificationPermission> requestPermission() async =>
      permissionState = NotificationPermission.granted;

  @override
  Future<String?> takeLaunchRoute() async => null;
}
