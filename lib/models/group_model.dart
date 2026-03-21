class Group {
  final String id;
  final String name;
  final String ownerId;
  final String inviteCode;

  Group({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.inviteCode,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['owner_id'] as String,
      inviteCode: json['invite_code'] as String,
    );
  }
}
