import 'dart:io';
import 'package:better_player/better_player.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:typeweight/typeweight.dart';
// import 'package:video_player/video_player.dart';

import 'package:hlsd/components/action_button.dart';

class VideoPlayerPage extends StatefulWidget {
  final String path;

  VideoPlayerPage(this.path);

  @override
  _VideoPlayerPageState createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  // VideoPlayerController? _videoPlayerController;
  late BetterPlayerController _betterPlayerController;
  Future<void>? _future;

  // Future<void> initVideoPlayer() async {
  //   await _videoPlayerController!.initialize();
  //   setState(() {
  //     print(_videoPlayerController!.value.aspectRatio);
  //   });
  // }

  @override
  void initState() {
    super.initState();
    var betterPlayerConfiguration = const BetterPlayerConfiguration(
        aspectRatio: 16 / 9, fit: BoxFit.contain, autoPlay: true);

    _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);

    var file = File(widget.path);

    debugPrint('File path of video is - ${widget.path}');

    var dataSource = BetterPlayerDataSource.file(
      file.path, /* videoExtension: 'm3u8' */
    );
    _betterPlayerController.setupDataSource(dataSource);
  }

  @override
  void dispose() {
    // _videoPlayerController!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Video Player',
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
      body: AspectRatio(
        aspectRatio: 16 / 9,
        child: BetterPlayer(
          controller: _betterPlayerController,
        ),
      ),
      floatingActionButton: StatefulBuilder(
        builder: (_, setCurrentState) {
          return FloatingActionButton(
            child: Icon(
              Icons.play_arrow,
            ),
            onPressed: () {},
          );
        },
      ),
    );
  }
}
