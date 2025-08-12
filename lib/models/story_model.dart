class StoryModel {
  final String imageUrl;
  final DateTime timestamp;

  StoryModel({required this.imageUrl, required this.timestamp});

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    return StoryModel(
      imageUrl: json['imageUrl'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'imageUrl': imageUrl, 'timestamp': timestamp.toIso8601String()};
  }
}
