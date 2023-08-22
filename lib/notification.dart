import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'main.dart';

class ShowNotification {
  void updateNotification(
      int taskId, int progress, bool isResume, String payload) {
    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'download_channel', 'Downloads',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true, // Show progress bar in notification
      maxProgress: 100,
      progress: progress,
      actions: <AndroidNotificationAction>[
        isResume
            ? AndroidNotificationAction('id_1', 'Resume',
                cancelNotification: false)
            : AndroidNotificationAction('id_2', 'Pause',
                cancelNotification: false),
        AndroidNotificationAction(
          'id_3',
          'cancel',
          cancelNotification: false,
        ),
      ],
      ongoing: true,
    );
    final platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // Show/update the notification
    flutterLocalNotificationsPlugin.show(
      taskId,
      'Downloading...',
      'Download in progress',
      platformChannelSpecifics,
      payload: payload,
    );
  }

  Future<void> showPublicNotification(String fileName) async {
    const androidNotificationDetails = AndroidNotificationDetails(
        'your channel id', 'your channel name',
        channelDescription: 'your channel description',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        visibility: NotificationVisibility.public);
    const notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        id++, 'Download Complete', '$fileName', notificationDetails,
        payload: 'item x');
  }

  void cancelNotification(int id) {
    flutterLocalNotificationsPlugin.cancel(id);
  }
}
