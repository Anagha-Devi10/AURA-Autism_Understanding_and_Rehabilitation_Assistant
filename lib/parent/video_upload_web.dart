import 'dart:typed_data';
import 'dart:html' as html;
import 'package:video_player/video_player.dart';

Future<VideoPlayerController> createVideoControllerFromBytes(Uint8List bytes) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final controller = VideoPlayerController.networkUrl(Uri.parse(url));
  await controller.initialize();
  return controller;
}
