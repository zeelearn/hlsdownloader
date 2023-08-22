import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hlsd/components/action_button.dart';
import 'package:hlsd/database/database.dart';
import 'package:hlsd/helpers/helpers.dart';
import 'package:hlsd/helpers/no_scrollglow_behavior.dart';
import 'package:typeweight/typeweight.dart';

class DownloadPage extends StatefulWidget {
  @override
  _DownloadPageState createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  TextEditingController? _controller;
  FocusNode? _focusNode;
  bool isDownloading = false;
  Map qualities = {};
  String? quality;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller!.dispose();
    _focusNode!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // final db = Provider.of<AppDatabase>(context);
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).requestFocus(FocusNode());
      },
      child: !isDownloading
          ? Scaffold(
              appBar: AppBar(
                title: Text(
                  'Download New',
                  style: GoogleFonts.ubuntuMono(
                    fontWeight: TypeWeight.bold,
                  ),
                ),
                automaticallyImplyLeading: false,
                titleSpacing: 0,
                leading: ActionButton(
                  onPressed: () {
                    Get.back();
                  },
                  icon: Icon(Icons.arrow_back),
                ),
              ),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(
                      NavigationToolbar.kMiddleSpacing,
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                    ),
                  ),
                  if (qualities.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(
                        NavigationToolbar.kMiddleSpacing,
                      ),
                      child: Text(
                        'Qualities',
                        style: GoogleFonts.ubuntuMono(
                          fontSize:
                              Theme.of(context).textTheme.titleMedium!.fontSize,
                          fontWeight: TypeWeight.bold,
                        ),
                      ),
                    ),
                  Expanded(
                    child: ScrollConfiguration(
                      behavior: NoScrollGlowBehavior(),
                      child: ListView.separated(
                        separatorBuilder: (_, index) {
                          return Container(
                            height: 1,
                            color: Colors.grey[300],
                          );
                        },
                        itemBuilder: (ctx, index) {
                          // return RadioListTile(value: qualities.entries.toList()[index].value, groupValue: quality, onChanged: (value) => 'dd',);
                          return Container(
                            child: RadioListTile<String>(
                              title:
                                  Text(qualities.entries.toList()[index].key),
                              value: qualities.entries.toList()[index].value,
                              groupValue: quality,
                              onChanged: (v) {
                                setState(() {
                                  quality = v.toString();
                                });
                              },
                            ),
                          );
                        },
                        itemCount: qualities.length,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(
                      NavigationToolbar.kMiddleSpacing,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: quality == null
                          ? ElevatedButton(
                              // padding: const EdgeInsets.symmetric(
                              //   vertical:
                              //       NavigationToolbar.kMiddleSpacing / 1.5,
                              // ),
                              // elevation: 0,
                              onPressed: () async {
                                final url = _controller!.text;
                                try {
                                  final q = await loadFileMetadata(url);
                                  debugPrint(
                                      'response from loadmetadata is - $q');
                                  setState(() {
                                    qualities = q;
                                    quality = q.entries.first.value;
                                  });
                                } catch (e) {
                                  print(e);
                                }
                              },
                              child: Text(
                                'Load Metadata',
                                style: GoogleFonts.ubuntuMono(
                                  fontWeight: TypeWeight.bold,
                                  fontSize: Theme.of(context)
                                      .textTheme
                                      .titleLarge!
                                      .fontSize,
                                ),
                              ),
                            )
                          : ElevatedButton(
                              // padding: const EdgeInsets.symmetric(
                              //   vertical:
                              //       NavigationToolbar.kMiddleSpacing / 1.5,
                              // ),
                              // elevation: 0,
                              onPressed: () async {
                                final url = quality;

                                var currentRecord =
                                    (await AppDatabase().getAllRecord())
                                        .where((r) => r.url == url);

                                // if (currentRecord.isEmpty) {
                                int id = await AppDatabase().insertNewRecord(
                                  Record(
                                      url: url!,
                                      downloaded: 0,
                                      id: Random.secure().nextInt(10000)),
                                );
                                /* await load(
                                    url,
                                    (p0) {
                                      debugPrint(
                                          'Progress of file download is - $p0');
                                    },
                                  ); */

                                final service = FlutterBackgroundService();
                                // var isRunning = await service.isRunning();
                                // if (isRunning) {
                                //   service.invoke('stopService');
                                // } else {
                                await service.startService();
                                service
                                    .invoke('download', {'url': url, 'id': id});

                                Get.back();
                                // }

                                /*              FlutterBackgroundService()
                                      .on('update')
                                      .listen(
                                    (event) async* {
                                      debugPrint(
                                          'onupdate is getting called - $event');
                                      if (event!['done'] == false) {
                                        await db.updateRecord(Record(
                                            id: id,
                                            url: url,
                                            downloaded: event['progress']));
                                      }
                                      // if (event['done'] == true) {
                                      //   DownloadQueue.add(
                                      //       () => event['responseurl']);
                                      // }
                                    },
                                    /* onDone: () async {
                                      await db.updateRecord(Record(
                                          id: id, url: url, downloaded: 100));
                                    }, */
                                  ); */

                                /*  await Workmanager().registerOneOffTask(
                                    '1',
                                    'Download',
                                    inputData: {'url': url, 'id': id},
                                  ).then((value) {
                                    debugPrint('response from background');
                                  }); */
                                // } else {
                                //   var currentRecord =
                                //       (await AppDatabase().getAllRecord())
                                //           .where((r) => r.url == url);

                                //   currentRecord.forEach((element) {
                                //     debugPrint('Current record is - $element');
                                //   });
                                // }
                              },
                              child: Text(
                                'Download',
                                style: GoogleFonts.ubuntuMono(
                                  fontWeight: TypeWeight.bold,
                                  fontSize: Theme.of(context)
                                      .textTheme
                                      .titleLarge!
                                      .fontSize,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            )
          : Scaffold(
              body: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: <Widget>[
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('Downloading...')
                  ],
                ),
              ),
            ),
    );
  }
}
