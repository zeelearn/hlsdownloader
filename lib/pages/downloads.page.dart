import 'dart:collection';
import 'dart:io';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:typeweight/typeweight.dart';

import 'package:hlsd/pages/pages.dart';
import 'package:hlsd/database/database.dart';
import 'package:hlsd/helpers/helpers.dart';
import 'package:hlsd/helpers/download_queue.dart';
import 'package:hlsd/components/action_button.dart';

class DownloadsPage extends StatefulWidget {
  @override
  _DownloadsPageState createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  List<File> downloadedFiles = [];
  Future<void> getDownloadedFiles() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final fileEntities = appDocDir.listSync();

    downloadedFiles =
        fileEntities.whereType<File>().map((entity) => entity).toList();

    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    getDownloadedFiles();
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final downloadStream = DownloadQueue.load();
    final dbStream = db.watchAllRecord();

    return StreamBuilder(
      stream: downloadStream,
      builder: (context, snapshot) {
        print('stream');
        print(snapshot.data);

        if (snapshot.hasData) {
          var queue = Queue<Dfn>();
          queue.add((() => Future(
                () => snapshot.data as dynamic,
              )));
          DownloadQueue.execute(queue);

          if (snapshot.data != null) {
            db.deleteUncompleteDownloads();
          }
        }
        return StreamBuilder<Map<String, dynamic>?>(
            stream: FlutterBackgroundService().on('update'),
            builder: (context, snapshot) {
              debugPrint('onupdate is getting called - ${snapshot.data}');
              if (snapshot.hasData) {
                if (snapshot.data!['done'] == false) {
                  db.updateRecord(Record(
                      id: snapshot.data!['id'],
                      url: snapshot.data!['url'],
                      downloaded:
                          double.parse(snapshot.data!['progress'].toString())));
                }
                // if (snapshot.data!['done'] == true) {
                //   DownloadQueue.add(() => snapshot.data!['responseurl']);
                // }
              }
              return Scaffold(
                appBar: AppBar(
                  title: Text(
                    'Downloads',
                    style: GoogleFonts.ubuntuMono(
                      fontWeight: TypeWeight.bold,
                    ),
                  ),
                  // actions: <Widget>[
                  //   ActionButton(
                  //     icon: Icon(Icons.play_circle_outline),
                  //     onPressed: () async {
                  //       print(DownloadQueue.queue);
                  //       await DownloadQueue.execute(snapshot.data);

                  //       print('finished download queue');
                  //     },
                  //   )
                  // ],
                ),
                body: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: downloadedFiles.length,
                        itemBuilder: (context, index) {
                          return InkWell(
                            onTap: () async {
                              final loc = await findFileLocation(
                                  downloadedFiles[index].path);

                              await Get.to(
                                  VideoPlayerPage(downloadedFiles[index].path));
                            },
                            child: ListTile(
                              title: Text(downloadedFiles[index].path),
                            ),
                          );
                        },
                      ),
                    ),
                    StreamBuilder(
                      stream: dbStream,
                      builder: (context, AsyncSnapshot<List<Record>> snapshot) {
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(
                            child: Text(
                              'No Files Downloaded!',
                              style: GoogleFonts.ibmPlexMono(
                                fontStyle: FontStyle.italic,
                                fontSize: Theme.of(context)
                                    .textTheme
                                    .titleLarge!
                                    .fontSize,
                                fontWeight: TypeWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        } else {
                          final dls = snapshot.data;

                          return Expanded(
                            child: ListView.builder(
                              itemCount: dls!.length,
                              itemBuilder: (context, index) {
                                final record = dls[index];
                                return Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        width: 1,
                                        color: Colors.grey[200]!,
                                      ),
                                    ),
                                  ),
                                  child: ListTile(
                                    enabled: record.downloaded >= 100,
                                    onTap: () async {
                                      final loc =
                                          await findFileLocation(record.url);

                                      // print(await Directory(
                                      //         '/data/user/0/com.example.download_hls_flutter/app_flutter/')
                                      //     .delete(recursive: true));

                                      await Get.to(VideoPlayerPage(loc));
                                    },
                                    contentPadding: const EdgeInsets.all(
                                      NavigationToolbar.kMiddleSpacing,
                                    ),
                                    title: Text(getFilePath(record.url)),
                                    isThreeLine: true,
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                            height: NavigationToolbar
                                                    .kMiddleSpacing /
                                                2),
                                        Text(stripFilePath(record.url)),
                                        SizedBox(
                                            height: NavigationToolbar
                                                    .kMiddleSpacing /
                                                2),
                                        (record.downloaded < 100)
                                            ? Text(
                                                'Downloading...${record.downloaded.toStringAsFixed(1)}%',
                                                style: GoogleFonts.ubuntuMono(
                                                  color: Colors.indigoAccent,
                                                ),
                                              )
                                            : Text(
                                                'Downloaded',
                                                style: GoogleFonts.ubuntuMono(
                                                  color: Colors.indigoAccent,
                                                ),
                                              ),
                                      ],
                                    ),
                                    trailing: Visibility(
                                      visible: record.downloaded >= 100,
                                      child: ActionButton(
                                        icon: Icon(Icons.delete),
                                        onPressed: () async {
                                          final loc = await findFileLocation(
                                              record.url);
                                          await Directory(normalizeUrl(loc))
                                              .delete(recursive: true);

                                          print('DELETED.');
                                          await db.deleteRecord(record);
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
                floatingActionButton: FloatingActionButton.extended(
                  onPressed: () async {
                    await Get.toNamed('/download');
                  },
                  label: Text(
                    'NEW',
                    style: GoogleFonts.ubuntuMono(
                      fontWeight: TypeWeight.bold,
                      fontSize:
                          Theme.of(context).textTheme.titleMedium!.fontSize,
                    ),
                  ),
                  icon: Icon(
                    Icons.file_download,
                    size: Theme.of(context).textTheme.titleLarge!.fontSize,
                  ),
                ),
              );
            });
      },
    );
  }
}
