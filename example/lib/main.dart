import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FqveApp();
  }
}

class FqveApp extends StatefulWidget {
  @override
  _FqveAppState createState() => _FqveAppState();
}

class _FqveAppState extends State<FqveApp> {
  double progress = 0.0;
  static const int width = 1280;
  static const int height = 720;
  static const int fps = 30;
  static const int audioChannels = 2;
  static const int sampleRate = 44100;

  BuildContext? _context;

  @override
  void initState() {
    super.initState();
    FlutterQuickVideoEncoder.setLogLevel(LogLevel.verbose);
  }

  Future<Uint8List> _generateVideoFrame(int frameIndex) async {
    const int boxSize = 50; // Size of the moving box

    // Calculate the box position
    int boxX = (frameIndex * 5) % width;
    int boxY = (frameIndex * 5) % height;

    // Paint the moving box
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    // Draw a white background
    paint.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), paint);

    // Draw the blue box
    paint.color = Colors.blue;
    canvas.drawRect(Rect.fromLTWH(boxX.toDouble(), boxY.toDouble(), boxSize.toDouble(), boxSize.toDouble()), paint);

    // Convert canvas to image
    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);

    // Convert the image to a byte array
    final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    return byteData!.buffer.asUint8List();
  }

  // generate 1 frame worth of audio samples
  Uint8List _generateAudioFrame(int frameIndex) {
    const int bytesPerSample = 2;
    const double htz = 220.0; // sine wave htz
    const int sampleCount = sampleRate ~/ fps;

    // Calculate the phase shift for this frame to maintain continuity
    double phaseShift = 2 * pi * htz * frameIndex / fps;

    // Create a ByteData buffer for the audio data
    ByteData byteData = ByteData(sampleCount * bytesPerSample * audioChannels);

    // Fill in the buffer
    for (int i = 0; i < sampleCount; i++) {
      double t = i / sampleRate;
      double sampleValue = sin(2 * pi * htz * t + phaseShift);

      // Convert the sample value to 16-bit PCM format
      int sampleInt = (sampleValue * 32767).toInt();

      // Store the sample in the buffer as little-endian
      for (int n = 0; n < audioChannels; n++) {
        int bufferIndex = (i * audioChannels + n) * bytesPerSample;
        byteData.setInt16(bufferIndex, sampleInt, Endian.little);
      }
    }

    // Convert the buffer to Uint8List
    return byteData.buffer.asUint8List();
  }

  Future<void> exportVideo() async {
    try {
      Directory appDir = await getApplicationDocumentsDirectory();
      var filepath = "${appDir.path}/exportedVideo.mp4";

      await FlutterQuickVideoEncoder.setup(
        width: width,
        height: height,
        fps: fps,
        videoBitrate: 1000000,
        profileLevel: ProfileLevel.any,
        audioBitrate: 64000,
        audioChannels: audioChannels,
        sampleRate: sampleRate,
        filepath: filepath,
      );

      int totalFrames = 120;
      for (int i = 0; i < totalFrames; i++) {
        Uint8List frameData = await _generateVideoFrame(i);
        Uint8List audioData = _generateAudioFrame(i);
        await FlutterQuickVideoEncoder.appendVideoFrame(frameData);
        await FlutterQuickVideoEncoder.appendAudioFrame(audioData);
        setState(() {
          progress = (i + 1) / totalFrames;
        });
      }

      await FlutterQuickVideoEncoder.finish();
      showSnackBar('Success: Video Exported: $filepath');
    } catch (e) {
      showSnackBar('Error: $e');
    }
  }

  void showSnackBar(String message) {
    print(message);
    final snackBar = SnackBar(content: Text(message));
    if (_context != null && _context!.mounted) {
      ScaffoldMessenger.of(_context!).showSnackBar(snackBar);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: ScaffoldMessenger(
          child: Builder(builder: (context) {
            _context = context;
            return Scaffold(
              appBar: AppBar(
                centerTitle: true,
                title: Text('Flutter Quick Video Encoder'),
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: exportVideo,
                      child: Text('Export Test Video'),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Opacity(
                        opacity: progress > 0 ? 1 : 0,
                        child: LinearProgressIndicator(
                          value: progress,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ));
  }
}
