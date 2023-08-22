import 'dart:async';
import 'dart:developer';
import 'dart:io';

// import 'package:http/http.dart' as http;
import 'package:cancellation_token_http/http.dart' as http;
import 'package:flutter_hls_parser/flutter_hls_parser.dart';
import 'package:http/http.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<Directory> getDirectory() {
  return getApplicationCacheDirectory();
}

/// returns downloaded file path from url
Future<String> findFileLocation(String url) async {
  final hash = url.hashCode.toString();
  final filePath = getFilePath(url);
  final appDocDir = await getDirectory();
  final file = File(p.join(appDocDir.path, hash, filePath));
  return file.absolute.path;
}

/// takes a [url] and remove scheme, and last file part
///
/// for example, https://abc.com/a/b/c.m3u8
/// to
/// abc.com/a/b
String normalizeUrl(String url) {
  final uri = Uri.parse(url);
  final dir = p.join(
    uri.host,
    uri.pathSegments.sublist(0, uri.pathSegments.length - 1).join('/'),
  );

  return dir;
}

String stripFilePath(String url) {
  final uri = Uri.parse(url);
  final dir = p.join(
    uri.host,
    uri.pathSegments.sublist(0, uri.pathSegments.length - 1).join('/'),
  );
  return '${uri.scheme}://' + dir;
}

/// takes a [url] and returns last file path
///
/// for example, https://abc.com/a/b/c.m3u8
/// to
/// c.m3u8
String getFilePath(String url) {
  final uri = Uri.parse(url);

  return uri.pathSegments.last;
}

/// takes a file path and returns path that are not file
///
/// for example `a/b/c.m3u8` to `[a, b]`
List<String> pathSegments(String url) {
  final segments = url.split('/');
  return segments.sublist(0, segments.length - 1);
}

late StreamedRequest request;
late StreamSubscription<List<int>> streamSubscription;
bool isDownloading = false;
final client = http.Client();
Future<File?> downloadFile(String url, String filepath, String filename,
    http.CancellationToken token) async {
  /*  InternetConnectionChecker().onStatusChange.listen((status) {
    switch (status) {
      case InternetConnectionStatus.connected:
        print('Data connection is available.');

        break;
      case InternetConnectionStatus.disconnected:
        print('You are disconnected from the internet.');
        client.close();
        break;
    }
  }); */

  try {
    final req = await client.get(Uri.parse(url), cancellationToken: token);

    log('api call is canceled - ${token.isCancelled}');

    final bytes = req.bodyBytes;
    final file = File('$filepath/$filename');

    for (final f in pathSegments(filename)) {
      final d = Directory(p.join(filepath, f));
      if (!await d.exists()) {
        await d.create();
      }
    }

    if (!file.existsSync()) {
      await file.create(recursive: true);
    }

    await file.writeAsBytes(bytes);
    return file;
  } on Exception catch (e) {
    log('api call is cancelled - $e');
    return null;
  }
}

Future<List<Segment>> getHlsMediaFiles(Uri uri, List<String> lines) async {
  var playList;

  try {
    playList = await HlsPlaylistParser.create().parse(uri, lines);
  } on ParserException catch (e) {
    print('HLS Parsing Error:');
    print(e);
  }

  if (playList is HlsMediaPlaylist) {
    print('MEDIA Playlist');
    return playList.segments;
  } else {
    return [];
  }
}

Future<Map> loadFileMetadata(String url) async {
  final uri = Uri.parse(url);
  final client = http.Client();
  final req = await client.get(uri);
  final lines = req.body;

  var playList;

  try {
    playList = await HlsPlaylistParser.create().parseString(uri, lines);
  } on ParserException catch (_) {
    print('Unable to parse HLS playlist');
  }

  if (playList is HlsMediaPlaylist) {
    return {'default': url};
  } else if (playList is HlsMasterPlaylist) {
    final result = {};

    for (final p in playList.variants) {
      result['${p.format.height} x ${p.format.width}'] = p.url.toString();
    }

    return result;
  } else {
    throw 'Unable to recognize HLS playlist type';
  }
}

/// download file from [url] and returns downloaded file path
Future<String?> load(
    String url, http.CancellationToken token, Function(double) progress) async {
  // the file path without full url
  final filename = getFilePath(url);

  // the app's directory to store data
  final appDocDir = await getDirectory();

  // directory to download files
  final downloadDir = Directory(p.join(
    appDocDir.path,
    url.hashCode.toString(), // a hash of url
  ));

  if (!await downloadDir.exists()) {
    await downloadDir.create();
  }

  // the full directory + filename path to download
  final filepath = p.join(downloadDir.path, filename);
  File? file = File(filepath);
  if (!await file.exists()) {
    file = await downloadFile(url, downloadDir.path, filename, token);
    if (file == null) {
      return null;
    }
  }

  final lines = await file.readAsLines();
  final mediaSegments = await getHlsMediaFiles(Uri.parse(file.path), lines);

  final total = mediaSegments.length;
  var currentProgress = 0.0;

  print(total);

  for (final entry in mediaSegments.asMap().entries) {
    final index = entry.key;
    final seg = entry.value;

    // internet url to download from
    final urlToDownload = p.join(
      pathSegments(url).join('/'),
      seg.url,
    );

    print('urlToDownload $urlToDownload');
    // print(urlToDownload);

    // application's file to download into
    File? ff = File(p.join(downloadDir.path, seg.url));

    if (!await ff.exists()) {
      ff = await downloadFile(urlToDownload, downloadDir.path, seg.url!, token);
      if (ff == null) {
        return null;
      }
    }

    if (index != total - 1) {
      // if not last
      currentProgress += double.parse(((1 / total) * 100).toStringAsFixed(2));
      await progress(currentProgress);
    } else {
      currentProgress = 100.0;
      await progress(currentProgress);
    }
  }

  return file.absolute.path;
}
