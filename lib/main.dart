import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:cancellation_token_http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hlsd/database/database.dart';
import 'package:provider/provider.dart';

import 'helpers/download_queue.dart';
import 'helpers/helpers.dart';
import 'notification.dart';
import 'pages/pages.dart';

int id = 0;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Streams are created so that app can respond to notification-related events
/// since the plugin is initialised in the `main` function
final StreamController<ReceivedNotification> didReceiveLocalNotificationStream =
    StreamController<ReceivedNotification>.broadcast();

final StreamController<String?> selectNotificationStream =
    StreamController<String?>.broadcast();

const MethodChannel platform =
    MethodChannel('dexterx.dev/flutter_local_notifications_example');

const String portName = 'notification_send_port';

class ReceivedNotification {
  ReceivedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final String? title;
  final String? body;
  final String? payload;
}

String? selectedNotificationPayload;

/// A notification action which triggers a url launch event
const String urlLaunchActionId = 'id_1';

/// A notification action which triggers a App navigation event
const String navigationActionId = 'id_3';

/// Defines a iOS/MacOS notification category for text input actions.
const String darwinNotificationCategoryText = 'textCategory';

/// Defines a iOS/MacOS notification category for plain actions.
const String darwinNotificationCategoryPlain = 'plainCategory';

@pragma('vm:entry-point')
void notificationTapBackground(
    NotificationResponse notificationResponse) async {
  // ignore: avoid_print
  log('notification(${notificationResponse.id}) action tapped: '
      '${notificationResponse.actionId} with'
      ' payload: ${notificationResponse.payload}');
  var url = jsonDecode(notificationResponse.payload!)['url'];
  var id = jsonDecode(notificationResponse.payload!)['id'];
  debugPrint('data coming from payload is - $url and id is - $id');
  if (notificationResponse.actionId == 'id_3') {
    final service = FlutterBackgroundService();
    debugPrint('Download  is canceled notificationTapBackground');
    if (!await service.isRunning()) {
      var serviceStatus = await service.startService();
    }
    if (await service.isRunning()) {
      service.invoke('cancelDownload', {'url': url, 'id': id});
    }
  } else if (notificationResponse.actionId == 'id_2') {
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      var serviceStatus = await service.startService();
    }
    debugPrint('Download is paused notificationTapBackground');
    if (await service.isRunning()) {
      service.invoke('pauseDownload', {'url': url, 'id': id});
    }
  } else if (notificationResponse.actionId == 'id_1') {
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      var serviceStatus = await service.startService();
    }
    debugPrint('resume button is clicked notificationTapBackground');
    if (await service.isRunning()) {
      service.invoke('download', {'url': url, 'id': id});
    } else {
      log('service is not running');
    }
  }
}

StreamController<int>? progressStream;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await Workmanager().initialize(
  //     callbackDispatcher, // The top level function, aka callbackDispatcher
  //     isInDebugMode:
  //         true // If enabled it will post a notification whenever the task is running. Handy for debugging tasks
  //     );
  await initializeService();

  // final notificationAppLaunchDetails = !kIsWeb && Platform.isLinux
  //     ? null
  // : await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  // String initialRoute = HomePage.routeName;
  // if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
  //   selectedNotificationPayload =
  //       notificationAppLaunchDetails!.notificationResponse?.payload;
  //   initialRoute = SecondPage.routeName;
  // }

  const initializationSettingsAndroid =
      AndroidInitializationSettings('app_icon');

  final darwinNotificationCategories = <DarwinNotificationCategory>[
    DarwinNotificationCategory(
      darwinNotificationCategoryText,
      actions: <DarwinNotificationAction>[
        DarwinNotificationAction.text(
          'text_1',
          'Action 1',
          buttonTitle: 'Send',
          placeholder: 'Placeholder',
        ),
      ],
    ),
    DarwinNotificationCategory(
      darwinNotificationCategoryPlain,
      actions: <DarwinNotificationAction>[
        DarwinNotificationAction.plain('id_1', 'Action 1'),
        DarwinNotificationAction.plain(
          'id_2',
          'Action 2 (destructive)',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.destructive,
          },
        ),
        DarwinNotificationAction.plain(
          navigationActionId,
          'Action 3 (foreground)',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.foreground,
          },
        ),
        DarwinNotificationAction.plain(
          'id_4',
          'Action 4 (auth required)',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.authenticationRequired,
          },
        ),
      ],
      options: <DarwinNotificationCategoryOption>{
        DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
      },
    )
  ];

  /// Note: permissions aren't requested here just to demonstrate that can be
  /// done later
  final initializationSettingsDarwin = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
    onDidReceiveLocalNotification:
        (int id, String? title, String? body, String? payload) async {
      didReceiveLocalNotificationStream.add(
        ReceivedNotification(
          id: id,
          title: title,
          body: body,
          payload: payload,
        ),
      );
    },
    notificationCategories: darwinNotificationCategories,
  );
  final initializationSettingsLinux = LinuxInitializationSettings(
    defaultActionName: 'Open notification',
    defaultIcon: AssetsLinuxIcon('icons/app_icon.png'),
  );
  final initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
    // macOS: initializationSettingsDarwin,
    // linux: initializationSettingsLinux,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse:
        (NotificationResponse notificationResponse) {
      /* switch (notificationResponse.notificationResponseType) {
        case NotificationResponseType.selectedNotification:
          selectNotificationStream.add(notificationResponse.payload);
          break;
        case NotificationResponseType.selectedNotificationAction:
          if (notificationResponse.actionId == navigationActionId) {
            selectNotificationStream.add(notificationResponse.payload);
          }
          break;
      } */
      // if (notificationResponse.actionId == 'id_3') {
      //   debugPrint('Download is canceled');
      // } else if (notificationResponse.actionId == 'id_2') {
      //   debugPrint('Download is paused');
      // } else if (notificationResponse.actionId == 'id_1') {
      //   debugPrint('resume button is clicked');
      // }
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(Mainframe());
}

class Mainframe extends StatelessWidget {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  @override
  Widget build(BuildContext context) {
    return Provider(
      create: (_) => AppDatabase(),
      child: GetMaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        title: 'HLS Downloader',
        theme: ThemeData(
          fontFamily: GoogleFonts.ubuntuMono().fontFamily,
          primaryColor: Colors.indigo,
          // accentColor: Colors.indigoAccent,
          splashFactory: InkRipple.splashFactory,
        ),
        initialRoute: '/',
        routes: {
          '/': (_) => DownloadsPage(),
          '/download': (_) => DownloadPage(),
        },
      ),
    );
  }
}

// @pragma(
//     'vm:entry-point') // Mandatory if the App is obfuscated or using Flutter 3.1+
// void callbackDispatcher() async {
//   Workmanager().executeTask((task, inputData) async {
//     final db = Provider.of<AppDatabase>(Mainframe.navigatorKey.currentContext!,
//         listen: false);
//     var url = inputData!['url'];
//     var videoUrl = inputData['videoUrl'];

//     var responseurl = load(url, (progress) async {
//       debugPrint('File  download progress is - $progress}');

//       if (progress < 100) {
//         ShowNotification().updateNotification('1', progress.round());
//       } else {
//         ShowNotification().cancelNotification();
//         await ShowNotification().showPublicNotification(url);
//       }

//       await db.updateRecord(
//         Record(id: id, downloaded: progress, url: url),
//       );
//     });
//     debugPrint('after downloading url is - ${await responseurl}');
//     // DownloadQueue.add(() => responseurl);

//     return Future(() => true);
//   });
// }

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  /// OPTIONAL, using custom notification channel id
  const channel = AndroidNotificationChannel(
    'my_foreground', // id
    'MY FOREGROUND SERVICE', // title
    description:
        'This channel is used for important notifications.', // description
    importance: Importance.low, // importance must be at low or higher level
  );

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  if (Platform.isIOS || Platform.isAndroid) {
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        iOS: DarwinInitializationSettings(),
        android: AndroidInitializationSettings('ic_bg_service_small'),
      ),
    );
  }

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      // this will be executed when app is in foreground or background in separated isolate
      onStart: onStart,

      // auto start service
      autoStart: true,
      isForegroundMode: true,

      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'AWESOME SERVICE',
      initialNotificationContent: 'Initializing',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      // auto start service
      autoStart: true,

      // this will be executed when app is in foreground in separated isolate
      onForeground: onStart,

      // you have to enable background fetch capability on xcode project
      onBackground: onIosBackground,
    ),
  );

  await service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  /* SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.reload();
  final log = preferences.getStringList('log') ?? <String>[];
  log.add(DateTime.now().toIso8601String());
  await preferences.setStringList('log', log); */

  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Only available for flutter 3.0.0 and later
  DartPluginRegistrant.ensureInitialized();

  // For flutter prior to version 3.0.0
  // We have to register the plugin manually

  /// OPTIONAL when use custom notification
  var flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  http.CancellationToken? token;
  double? progressGlobal;

  service.on('download').listen((event) async {
    debugPrint('download function is invoked');
    var url = event!['url'];
    var id = event['id'];
    token = http.CancellationToken();

    await load(url, token!, (progress) async {
      debugPrint('File  download progress is - $progress id is $id');
      progressGlobal = progress;
      await AppDatabase().updateRecord(Record(
          id: int.parse(id.toString()),
          url: url,
          downloaded: double.parse(progress.toString())));

      service.invoke(
        'update',
        {'progress': progress, 'done': false, 'id': id, 'url': url},
      );
      var payload = '{ "url":"$url", "id":"$id"}';
      ShowNotification().updateNotification(
          int.parse(id.toString()), progress.round(), false, payload);
      if (progress == 100) {
        ShowNotification().cancelNotification(int.parse(id.toString()));
        await ShowNotification().showPublicNotification(url);
        // await service.stopSelf();
      }
    }).then((value) async {
      debugPrint('after file download is done - $value');
      if (value != null) {
        DownloadQueue.add(() => Future(() => value));
      }
      await service.stopSelf();
      // service.invoke(
      //   'update',
      //   {'done': true, 'responseurl': value, 'id': id},
      // );
    });
    // DownloadQueue.add(() => responseurl);
  });

  // if (service is AndroidServiceInstance) {
  service.on('cancelDownload').listen((event) async {
    var url = event!['url'];
    var id = event['id'];
    var payload = '''{
        "url":$url,
        "id":$id
      }''';
    if (token != null) {
      token!.cancel();
    }
    // ShowNotification()
    //     .updateNotification(id, progressGlobal!.round(), true, payload);
    ShowNotification().cancelNotification(int.parse(id));
    await service.stopSelf();
  });

  service.on('pauseDownload').listen((event) {
    if (token != null) {
      token!.cancel();
    }

    var url = event!['url'];
    var id = event['id'];
    var payload = '{ "url":"$url", "id":"$id"}';
    ShowNotification().updateNotification(
        int.parse(id), progressGlobal!.round(), true, payload);
  });

  service.on('resumeDownload').listen((event) async {
    var url = event!['url'];
    var id = event['id'];
    token = http.CancellationToken();

    await load(url, token!, (progress) async {
      debugPrint('File  download progress is - $progress');
      progressGlobal = progress;
      await AppDatabase().updateRecord(Record(
          id: id, url: url, downloaded: double.parse(progress.toString())));

      service.invoke(
        'update',
        {'progress': progress, 'done': false, 'id': id, 'url': url},
      );
      var payload = '''{
        "url":$url,
        "id":$id
      }''';
      ShowNotification()
          .updateNotification(int.parse(id), progress.round(), false, payload);
      if (progress == 100) {
        ShowNotification().cancelNotification(int.parse(id));
        await ShowNotification().showPublicNotification(url);
        // await service.stopSelf();
      }
    }).then((value) async {
      debugPrint('after file download is done - $value');
      if (value != null) {
        DownloadQueue.add(() => Future(() => value));
      }
      await service.stopSelf();
      // service.invoke(
      //   'update',
      //   {'done': true, 'responseurl': value, 'id': id},
      // );
    });
  });
  // }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // bring to foreground
  /*  Timer.periodic(const Duration(seconds: 1), (timer) async {
    // if (service is AndroidServiceInstance) {
    //   if (await service.isForegroundService()) {
    /// OPTIONAL for use custom notification
    /// the notification id must be equals with AndroidConfiguration when you call configure() method.
    await flutterLocalNotificationsPlugin.show(
      888,
      'COOL SERVICE',
      'Awesome ${DateTime.now()}',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'my_foreground',
          'MY FOREGROUND SERVICE',
          icon: 'ic_bg_service_small',
          ongoing: true,
        ),
      ),
    );

    // if you don't using custom notification, uncomment this
    // service.setForegroundNotificationInfo(
    //   title: "My App Service",
    //   content: "Updated at ${DateTime.now()}",
    // );
    //   }
    // }

    /// you can see this log in logcat
    print('FLUTTER BACKGROUND SERVICE: ${DateTime.now()}');

    // test using external plugin
    // final deviceInfo = DeviceInfoPlugin();
    String? device;
    if (Platform.isAndroid) {
      final androidInfo = 'This is dummy android device';
      device = androidInfo;
    }

    if (Platform.isIOS) {
      final iosInfo = 'This is dummy android device';
      device = iosInfo;
    }

    service.invoke(
      'update',
      {
        'current_date': DateTime.now().toIso8601String(),
        'device': device,
      },
    );
  }); */
}
