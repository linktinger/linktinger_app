class NotificationModel {
  final int id;

  final String type;
  final String message;
  final String senderUsername;
  final String senderImage;
  final String createdAt;

  final dynamic senderId;
  final dynamic postId; 
  final dynamic tweetId; 

  final String? followStatus;
  final bool isRead;

  const NotificationModel({
    required this.id,
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

  int? get senderIdInt => _asInt(senderId);
  int? get postIdInt => _asInt(postId);
  int? get tweetIdInt => _asInt(tweetId);

  String get stableKey =>
      'notif_${type}_${senderIdInt ?? 'na'}_${postIdInt ?? tweetIdInt ?? 'na'}_$createdAt';

  DateTime? get createdAtDate {
    final s = createdAt.trim();
    if (s.isEmpty) return null;
    try {
      return DateTime.parse(s).toLocal();
    } catch (_) {
      return null;
    }
  }

  /// ===== Factories =====
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['notification_id'];
    final rawType = json['type'];
    final rawMsg = json['message'] ?? json['body'];
    final rawSenderU = json['senderUsername'] ?? json['sender_username'];
    final rawSenderImg =
        json['senderImage'] ?? json['sender_image'] ?? json['profileImage'];
    final rawCreated = json['createdAt'] ?? json['created_at'];

    final rawSenderId =
        json['senderId'] ??
        json['sender_id'] ??
        json['user_id'] ??
        json['userId'];
    final rawPostId = json['postId'] ?? json['post_id'] ?? json['reference_id'];
    final rawTweetId =
        json['tweetId'] ?? json['tweet_id'] ?? json['reference_id'];

    final rawFollow = json['followStatus'] ?? json['follow_status'];
    final rawIsRead = json['isRead'] ?? json['is_read'];

    return NotificationModel(
      id: _asInt(rawId) ?? 0,
      type: '${rawType ?? ''}',
      message: '${rawMsg ?? ''}',
      senderUsername: '${rawSenderU ?? ''}',
      senderImage: '${rawSenderImg ?? ''}',
      createdAt: '${rawCreated ?? ''}',
      senderId: rawSenderId,
      postId: rawPostId,
      tweetId: rawTweetId,
      followStatus: rawFollow?.toString(),
      isRead: _asBool(rawIsRead),
    );
  }

  /// من بنية رسائل FCM (notification + data)
  factory NotificationModel.fromFirebase(Map<String, dynamic> data) {
    final notification = data['notification'] ?? const {};
    final payload = data['data'] ?? const {};

    final rawId = payload['id'] ?? payload['notification_id'];
    final rawType = payload['type'] ?? data['type'];
    final rawMsg = notification['body'] ?? payload['message'];
    final rawSenderU = payload['senderUsername'] ?? payload['sender_username'];
    final rawSenderImg = payload['senderImage'] ?? payload['sender_image'];
    final rawCreated = payload['createdAt'] ?? payload['created_at'];

    final rawSenderId =
        payload['senderId'] ??
        payload['sender_id'] ??
        payload['user_id'] ??
        payload['userId'];
    final rawPostId =
        payload['postId'] ?? payload['post_id'] ?? payload['reference_id'];
    final rawTweetId =
        payload['tweetId'] ?? payload['tweet_id'] ?? payload['reference_id'];

    final rawFollow = payload['followStatus'] ?? payload['follow_status'];
    final rawIsRead = payload['isRead'] ?? payload['is_read'];

    return NotificationModel(
      id: _asInt(rawId) ?? 0,
      type: '${rawType ?? ''}',
      message: '${rawMsg ?? ''}',
      senderUsername: '${rawSenderU ?? ''}',
      senderImage: '${rawSenderImg ?? ''}',
      createdAt: (rawCreated is String && rawCreated.trim().isNotEmpty)
          ? rawCreated
          : DateTime.now().toIso8601String(),
      senderId: rawSenderId,
      postId: rawPostId,
      tweetId: rawTweetId,
      followStatus: rawFollow?.toString(),
      isRead: _asBool(rawIsRead),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'message': message,
      'senderUsername': senderUsername,
      'senderImage': senderImage,
      'createdAt': createdAt,
      'senderId': senderIdInt ?? senderId,
      'postId': postIdInt ?? postId,
      'tweetId': tweetIdInt ?? tweetId,
      'followStatus': followStatus,
      'isRead': isRead,
    };
  }

  /// ===== محوّلات داخلية =====
  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final s = '$v'.trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  static bool _asBool(dynamic v) {
    // نقبل 1/0، true/false، "1"/"0"/"true"/"false"
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = '$v'.trim().toLowerCase();
    if (s == '1' || s == 'true' || s == 'yes') return true;
    if (s == '0' || s == 'false' || s == 'no') return false;
    return false;
  }
}
