import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;

  void connect([String url = 'ws://linktinger.xyz:8080']) {
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _isConnected = true;
    print("📡 Connected to WebSocket server");
  }

  void disconnect() {
    if (_isConnected) {
      _channel?.sink.close();
      _isConnected = false;
      print("🛑 Disconnected from WebSocket server");
    }
  }

  bool get isConnected => _isConnected;

  void sendMessage({
    required int senderId,
    required int receiverId,
    required String message,
    String type = 'text',
  }) {
    if (!_isConnected || _channel == null) {
      print("⚠️ Cannot send message, WebSocket not connected.");
      return;
    }

    final data = {
      'type': type,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message': message,
    };

    _channel!.sink.add(jsonEncode(data));
    print("📤 Sent message: $data");
  }

  void sendTyping({required int senderId, required int receiverId}) {
    if (!_isConnected || _channel == null) return;

    final data = {
      'type': 'typing',
      'sender_id': senderId,
      'receiver_id': receiverId,
    };

    _channel!.sink.add(jsonEncode(data));
    print("✍️ Sent typing: $data");
  }

  void sendStopTyping({required int senderId, required int receiverId}) {
    if (!_isConnected || _channel == null) return;

    final data = {
      'type': 'stop_typing',
      'sender_id': senderId,
      'receiver_id': receiverId,
    };

    _channel!.sink.add(jsonEncode(data));
    print("🛑 Sent stop typing: $data");
  }

  void sendSeen({required int senderId, required int receiverId}) {
    if (!_isConnected || _channel == null) return;

    final data = {
      'type': 'seen',
      'sender_id': senderId,
      'receiver_id': receiverId,
    };

    _channel!.sink.add(jsonEncode(data));
    print("👁️ Sent seen: $data");
  }

  void sendRawMessage(String message) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(message);
      print("📤 Sent raw message: $message");
    } else {
      print("❌ Cannot send raw message, WebSocket not connected");
    }
  }

  void listen(void Function(String message) onMessage) {
    if (_channel == null) return;

    _channel!.stream.listen(
      (message) {
        print("📨 Received: $message");
        onMessage(message.toString());
      },
      onError: (error) {
        print("❌ WebSocket error: $error");
      },
      onDone: () {
        print("⚠️ WebSocket connection closed");
        _isConnected = false;
      },
    );
  }
}
