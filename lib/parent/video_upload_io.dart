import 'dart:io';
import 'dart:typed_data';
import 'package:video_player/video_player.dart';

Future<VideoPlayerController> createVideoControllerFromFile(String path) async {
  final file = File(path);
  final controller = VideoPlayerController.file(file);
  await controller.initialize();
  return controller;
}

class createVideoControllerFromBytes {
  createVideoControllerFromBytes(Uint8List bytes);

  void then(Null Function(dynamic controller) param0) {}
}
