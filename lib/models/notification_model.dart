class NotificationModel {
  final String type;
  final String message;
  final String senderUsername;
  final String senderImage;
  final String createdAt;
  final int senderId;
  final int? postId;
  final int? tweetId;
  final String? followStatus;
  final bool isRead; 

  const NotificationModel({
    required this.type,
    required this.message,
    required this.senderUsername,
    required this.senderImage,
    required this.createdAt,
    required this.senderId,
    this.postId,
    this.tweetId,
    this.followStatus,
    this.isRead = false, 
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      type: json['type'] ?? '',
      message: json['message'] ?? '',
      senderUsername: json['senderUsername'] ?? '',
      senderImage: json['senderImage'] ?? '',
      createdAt: json['createdAt'] ?? '',
      senderId: json['senderId'] ?? 0,
      postId: json['postId'] is int
          ? json['postId']
          : int.tryParse(json['postId']?.toString() ?? ''),
      tweetId: json['tweetId'] is int
          ? json['tweetId']
          : int.tryParse(json['tweetId']?.toString() ?? ''),
      followStatus: json['followStatus'],
      isRead: json['isRead'] == 1 || json['is_read'] == 1, 
    );
  }

  factory NotificationModel.fromFirebase(Map<String, dynamic> data) {
    final notification = data['notification'] ?? {};
    final payload = data['data'] ?? {};

    return NotificationModel(
      type: payload['type'] ?? '',
      message: notification['body'] ?? '',
      senderUsername: payload['senderUsername'] ?? '',
      senderImage: payload['senderImage'] ?? '',
      createdAt: payload['createdAt'] ?? DateTime.now().toIso8601String(),
      senderId: int.tryParse(payload['senderId'] ?? '') ?? 0,
      postId: int.tryParse(payload['postId'] ?? ''),
      tweetId: int.tryParse(payload['tweetId'] ?? ''),
      followStatus: payload['followStatus'],
      isRead: false,
    );
  }
}
