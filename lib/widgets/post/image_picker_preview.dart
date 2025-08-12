
import 'dart:io';
import 'package:flutter/material.dart';

class ImagePickerPreview extends StatelessWidget {
  final File image;

  const ImagePickerPreview({super.key, required this.image});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Image.file(image, fit: BoxFit.cover, width: double.infinity),
    );
  }
}
