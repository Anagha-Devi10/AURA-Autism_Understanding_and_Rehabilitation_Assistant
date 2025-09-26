// video_upload_page.dart
import 'package:flutter/material.dart';

class VideoUploadPage extends StatelessWidget {
  const VideoUploadPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("Video Upload Page",
            style: TextStyle(color: Colors.white, fontSize: 24)),
      ),
      backgroundColor: Color(0xFF0f0f23),
    );
  }
}
