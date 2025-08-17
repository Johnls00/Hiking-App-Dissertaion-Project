// lib/screens/uploader_screen.dart
import 'package:flutter/material.dart';
import '../widgets/gpx_uploader_and_mapper.dart';

class UploaderScreen extends StatelessWidget {
  const UploaderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Public GPX Uploader')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: GpxUploaderAndMapper(),
      ),
    );
  }
}