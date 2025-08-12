import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileImagePicker extends StatefulWidget {
  final String imageUrl;
  final Future<String> Function(File imageFile) onImageSelected;

  const ProfileImagePicker({
    super.key,
    required this.imageUrl,
    required this.onImageSelected,
  });

  @override
  State<ProfileImagePicker> createState() => _ProfileImagePickerState();
}

class _ProfileImagePickerState extends State<ProfileImagePicker> {
  String? updatedImageUrl;
  bool isUploading = false;

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );

    if (pickedFile == null) return;

    final imageFile = File(pickedFile.path);
    setState(() => isUploading = true);

    final imageUrl = await widget.onImageSelected(imageFile);

    setState(() {
      updatedImageUrl = imageUrl;
      isUploading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider image;

    final effectiveUrl =
        updatedImageUrl ??
        (widget.imageUrl.startsWith('http')
            ? widget.imageUrl
            : 'https://linktinger.xyz/linktinger-api/${widget.imageUrl}');

    if (effectiveUrl.isNotEmpty) {
      image = NetworkImage(
        '$effectiveUrl?ts=${DateTime.now().millisecondsSinceEpoch}',
      );
    } else {
      image = const AssetImage('assets/images/logo.png');
    }

    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(radius: 50, backgroundImage: image),
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.black54,
            child: isUploading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.edit, size: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
