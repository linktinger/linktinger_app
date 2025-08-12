import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

import '../../services/websocket_service.dart';

class MessageInputField extends StatefulWidget {
  final Function(String content, {String type}) onSend;
  final int currentUserId;
  final int targetUserId;
  final VoidCallback? onTyping;

  const MessageInputField({
    super.key,
    required this.onSend,
    required this.currentUserId,
    required this.targetUserId,
    this.onTyping,
  });

  @override
  State<MessageInputField> createState() => _MessageInputFieldState();
}

class _MessageInputFieldState extends State<MessageInputField> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  final WebSocketService _socket = WebSocketService();

  bool _isWriting = false;
  bool _isRecording = false;
  Timer? _typingTimer;

  void _onTextChanged(String text) {
    final trimmed = text.trim();
    final isNowWriting = trimmed.isNotEmpty;

    if (isNowWriting && !_isWriting && widget.onTyping != null) {
      widget.onTyping!();
    }

    setState(() => _isWriting = isNowWriting);

    _typingTimer?.cancel();
    if (isNowWriting) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _isWriting = false;
      });
    }
  }

  Future<void> _startOrStopRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);

      if (path != null) {
        await _uploadAudio(File(path));
      }
    } else {
      final hasPermission = await _requestMicrophonePermission();
      if (!hasPermission) return;

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      setState(() => _isRecording = true);
    }
  }

  Future<void> _uploadAudio(File audioFile) async {
    final uri = Uri.parse(
      'https://linktinger.xyz/linktinger-api/send_message.php',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['sender_id'] = widget.currentUserId.toString()
      ..fields['receiver_id'] = widget.targetUserId.toString()
      ..fields['type'] = 'audio'
      ..files.add(await http.MultipartFile.fromPath('audio', audioFile.path));

    final response = await request.send();
    final body = await response.stream.bytesToString();
    print('🔊 AUDIO RESPONSE: $body');

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(body);
        if (data['status'] == 'success') {
          widget.onSend(data['stored_message'], type: 'audio');
        } else {
          print('❌ Audio Upload Error: ${data['message']}');
        }
      } catch (e) {
        print('❌ Audio JSON Decode Error: $e');
      }
    } else {
      print('❌ Failed to upload audio: ${response.statusCode}');
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final uploadedPath = await _uploadImage(File(picked.path));
      if (uploadedPath != null) {
        widget.onSend(uploadedPath, type: 'image');
      }
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    final uri = Uri.parse(
      'https://linktinger.xyz/linktinger-api/send_message.php',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['sender_id'] = widget.currentUserId.toString()
      ..fields['receiver_id'] = widget.targetUserId.toString()
      ..fields['type'] = 'image'
      ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    final response = await request.send();
    final body = await response.stream.bytesToString();
    print('🖼️ IMAGE RESPONSE: $body');

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(body);
        if (data['status'] == 'success') {
          return data['stored_message'];
        } else {
          print('❌ Image Upload Error: ${data['message']}');
        }
      } catch (e) {
        print('❌ Image JSON Decode Error: $e');
      }
    } else {
      print('❌ Failed to upload image: ${response.statusCode}');
    }

    return null;
  }

  Future<bool> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  void _sendText() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSend(text, type: 'text');
      _controller.clear();
      setState(() => _isWriting = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _recorder.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: const BoxDecoration(color: Colors.white),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.photo),
              onPressed: _pickImage,
              tooltip: "Send Image",
            ),
            IconButton(
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              color: _isRecording ? Colors.red : null,
              onPressed: _startOrStopRecording,
              tooltip: _isRecording ? "Stop Recording" : "Record Audio",
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: _onTextChanged,
                decoration: const InputDecoration(
                  hintText: "Write a message...",
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendText(),
              ),
            ),
            IconButton(
              icon: Icon(_isWriting ? Icons.send : Icons.thumb_up_alt_outlined),
              onPressed: _isWriting ? _sendText : () {},
              color: Theme.of(context).primaryColor,
              tooltip: "Send",
            ),
          ],
        ),
      ),
    );
  }
}
