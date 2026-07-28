enum WatchState {
  planned('بعداً تماشا می‌کنم'),
  watching('در حال تماشا'),
  completed('مشاهده‌شده'),
  paused('متوقف‌شده'),
  dropped('رهاشده'),
  favorite('موردعلاقه');

  const WatchState(this.label);
  final String label;
}

class LocalUser {
  const LocalUser({
    required this.id,
    required this.name,
    required this.email,
    required this.passwordHash,
    this.bio = '',
    this.avatarPath,
  });

  final String id;
  final String name;
  final String email;
  final String passwordHash;
  final String bio;
  final String? avatarPath;

  factory LocalUser.fromJson(Map<String, dynamic> json) => LocalUser(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    passwordHash: json['passwordHash'] as String,
    bio: json['bio'] as String? ?? '',
    avatarPath: json['avatarPath'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'passwordHash': passwordHash,
    'bio': bio,
    'avatarPath': avatarPath,
  };

  LocalUser copyWith({String? name, String? bio, String? avatarPath}) =>
      LocalUser(
        id: id,
        name: name ?? this.name,
        email: email,
        passwordHash: passwordHash,
        bio: bio ?? this.bio,
        avatarPath: avatarPath ?? this.avatarPath,
      );
}

class Review {
  const Review({
    required this.id,
    required this.mediaId,
    required this.text,
    required this.createdAt,
    this.spoiler = false,
    this.userName,
    this.userAvatar,
  });

  final String id;
  final String mediaId;
  final String text;
  final DateTime createdAt;
  final bool spoiler;
  final String? userName;
  final String? userAvatar;

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    id: json['id'] as String,
    mediaId: json['mediaId'] as String,
    text: json['text'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    spoiler: json['spoiler'] as bool? ?? false,
    userName: json['userName'] as String?,
    userAvatar: json['userAvatar'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'mediaId': mediaId,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'spoiler': spoiler,
    'userName': userName,
    'userAvatar': userAvatar,
  };
}
