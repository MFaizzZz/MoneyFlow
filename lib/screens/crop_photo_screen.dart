import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

class CropPhotoScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const CropPhotoScreen({super.key, required this.imageBytes});

  @override
  State<CropPhotoScreen> createState() => _CropPhotoScreenState();
}

class _CropPhotoScreenState extends State<CropPhotoScreen> {
  final _controller = CropController();
  bool _isCropping = false;

  void _cropImage() {
    setState(() => _isCropping = true);
    _controller.crop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Potong Foto')),
      body: Column(
        children: [
          Expanded(
            child: Crop(
              controller: _controller,
              image: widget.imageBytes,
              aspectRatio: 1,
              onCropped: (cropped) {
                if (!mounted) return;
                Navigator.of(context).pop(cropped);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isCropping)
                  Center(
                    child: CircularProgressIndicator(
                      color: colors.primary,
                    ),
                  )
                else
                  FilledButton(
                    onPressed: _cropImage,
                    child: const Text('Simpan Foto'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
