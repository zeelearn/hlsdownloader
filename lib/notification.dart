import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'main.dart';

class ShowNotification {
  void updateNotification(String taskId, int progress) {
    final androidPlatformChannelSpecifics =
        AndroidNotificationDetails('download_channel', 'Downloads',
            importance: Importance.low,
            priority: Priority.low,
            showProgress: true, // Show progress bar in notification
            maxProgress: 100,
            progress: progress,
            ongoing: true);
    final platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // Show/update the notification
    flutterLocalNotificationsPlugin.show(
      0,
      'Downloading...',
      'Download in progress',
      platformChannelSpecifics,
      payload: taskId,
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

  void cancelNotification() {
    flutterLocalNotificationsPlugin.cancelAll();
  }
}
