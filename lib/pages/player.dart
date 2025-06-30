import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class Player extends StatefulWidget {
  final String videoUrl;

  const Player({super.key, required this.videoUrl});

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  late VideoPlayerController _controller;
  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize()
          .then((_) {
            if (mounted) setState(() {});
            _controller.setVolume(0.0); // Mute the video
            _controller.setLooping(true); // Play on loop
            _controller.play();
          })
          .catchError((e) {
            if (mounted) setState(() {});
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Center(child: SpinKitChasingDots(color: Colors.black));
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }
}
