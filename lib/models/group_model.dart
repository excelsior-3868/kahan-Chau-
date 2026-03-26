class Group {
  final String id;
  final String name;
  final String ownerId;
  final String inviteCode;
  final String? avatarUrl;

  Group({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.inviteCode,
    this.avatarUrl,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['owner_id'] as String,
      inviteCode: json['invite_code'] as String,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
