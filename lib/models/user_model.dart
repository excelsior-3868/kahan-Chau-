class AppUser {
  final String id;
  final String? displayName;
  final String? username;
  final String? email;
  final bool isSharing;

  AppUser({
    required this.id,
    this.displayName,
    this.username,
    this.email,
    this.isSharing = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      displayName: json['display_name'] as String?,
      username: json['username'] as String?,
      email: json['email'] as String?,
      isSharing: json['is_sharing'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'username': username,
      'email': email,
      'is_sharing': isSharing,
    };
  }
}
