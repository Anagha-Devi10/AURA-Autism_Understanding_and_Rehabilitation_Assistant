import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';

// Conditional imports for platform-specific video controller creation
import 'video_upload_io.dart'
    if (dart.library.html) 'video_upload_web.dart' as platform;

// Declare the function signatures so Dart knows they exist.
// The actual implementations should be in the imported files.
//external Future<VideoPlayerController> createVideoControllerFromBytes(Uint8List bytes);
//external Future<VideoPlayerController> createVideoControllerFromFile(String path);

class VideoUploadPage extends StatefulWidget {
  const VideoUploadPage({super.key});

  @override
  State<VideoUploadPage> createState() => _VideoUploadPageState();
}

class _VideoUploadPageState extends State<VideoUploadPage> {
  VideoPlayerController? _controller;
  String? _analysisResult;

  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );

    if (result != null) {
      _analysisResult = null;


      if (kIsWeb) {
        Uint8List bytes = result.files.first.bytes!;
        platform.createVideoControllerFromBytes(bytes).then((controller) {
          setState(() {
            _controller = controller;
            _controller!.play();
          });
        });
      }

      // fake AI analysis
      Future.delayed(const Duration(seconds: 3), () {
        setState(() {
          _analysisResult =
              "Observations: Limited eye contact, repetitive movements.\n"
              "Prediction: Possible signs of ASD.\n"
              "Suggestion: Consult a professional.";
          _controller!.play();
        });
      });

    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        title: const Text("Video Upload"),
        backgroundColor: const Color(0xFF1e1e2f),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickVideo,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1e1e2f),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent, width: 2),
                ),
                child: Center(
                  child: _controller == null
                      ? const Text(
                          "Tap to upload a video",
                          style: TextStyle(color: Colors.white70, fontSize: 18),
                        )
                      : _controller!.value.isInitialized
                          ? AspectRatio(
                              aspectRatio: _controller!.value.aspectRatio,
                              child: VideoPlayer(_controller!),
                            )
                          : const CircularProgressIndicator(
                              color: Colors.blueAccent),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1e1e2f),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _analysisResult == null
                    ? const Text(
                        "Analysis results will appear here after upload.",
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      )
                    : SingleChildScrollView(
                        child: Text(
                          _analysisResult!,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
