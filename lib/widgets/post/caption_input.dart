
import 'package:flutter/material.dart';

class CaptionInput extends StatelessWidget {
  final TextEditingController controller;

  const CaptionInput({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: controller,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Write a description...',
          border: InputBorder.none,
        ),
      ),
    );
  }
}
