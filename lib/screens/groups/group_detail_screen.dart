import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/group_model.dart';
import '../../services/group_service.dart';
import '../../services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GroupDetailScreen extends StatefulWidget {
  final Group group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final GroupService _groupService = GroupService();
  final AuthService _authService = AuthService();
  late Group _currentGroup;
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _currentGroup = widget.group;
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final members = await _groupService.getGroupMembers(_currentGroup.id);
    if (mounted) {
      setState(() {
        _members = members;
        _isLoading = false;
      });
    }
  }

  bool get _isOwner => _authService.currentUserId == _currentGroup.ownerId;

  Future<void> _editGroupName() async {
    final controller = TextEditingController(text: _currentGroup.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Group Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _currentGroup.name) {
      final success = await _groupService.updateGroupName(_currentGroup.id, newName);
      if (success) {
        setState(() {
          _currentGroup = Group(
            id: _currentGroup.id,
            name: newName,
            ownerId: _currentGroup.ownerId,
            inviteCode: _currentGroup.inviteCode,
            avatarUrl: _currentGroup.avatarUrl,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group name updated')),
        );
      }
    }
  }

  Future<void> _changeGroupPhoto() async {
    if (!_isOwner) return;

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );

    if (image == null) return;

    setState(() => _isLoading = true);

    try {
      final file = File(image.path);
      final fileExt = image.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final path = 'group_avatars/${_currentGroup.id}/$fileName';

      await Supabase.instance.client.storage
          .from('avatars')
          .upload(path, file);

      final imageUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(path);

      final success = await _groupService.updateGroupAvatar(_currentGroup.id, imageUrl);
      if (success) {
        setState(() {
          _currentGroup = Group(
            id: _currentGroup.id,
            name: _currentGroup.name,
            ownerId: _currentGroup.ownerId,
            inviteCode: _currentGroup.inviteCode,
            avatarUrl: imageUrl,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group photo updated')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeMember(String userId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Are you sure you want to remove $name from the group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _groupService.removeMember(_currentGroup.id, userId);
      if (success) {
        _loadMembers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name removed from group')),
        );
      }
    }
  }

  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _groupService.leaveGroup(_currentGroup.id);
      if (success) {
        Navigator.pop(context, 'left_group');
      }
    }
  }

  String _formatRole(String? role) {
    if (role == null) return 'Member';
    return role[0].toUpperCase() + role.substring(1);
  }

  IconData _getRoleIcon(String? role) {
    switch (role) {
      case 'owner':
        return Icons.star;
      case 'admin':
        return Icons.shield;
      default:
        return Icons.person;
    }
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'owner':
        return Colors.amber;
      case 'admin':
        return const Color(0xFF0050A4);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24.0),
              topRight: Radius.circular(24.0),
            ),
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Drag handle
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12.0),
                      height: 4.0,
                      width: 40.0,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                    // Group info header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 8),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 48,
                                backgroundColor: const Color(0xFF0050A4),
                                backgroundImage: _currentGroup.avatarUrl != null
                                    ? NetworkImage(_currentGroup.avatarUrl!)
                                    : null,
                                child: _currentGroup.avatarUrl == null
                                    ? const Icon(Icons.group, size: 48, color: Colors.white)
                                    : null,
                              ),
                              if (_isOwner)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _changeGroupPhoto,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: 4,
                                          )
                                        ],
                                      ),
                                      child: const Icon(Icons.camera_alt, size: 20, color: Color(0xFF0050A4)),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentGroup.name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_isOwner) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _editGroupName,
                                  child: const Icon(Icons.edit, size: 18, color: Color(0xFF0050A4)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.vpn_key, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                'Invite Code: ${_currentGroup.inviteCode}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  // Copy to clipboard
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Invite code: ${_currentGroup.inviteCode}'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: const Icon(Icons.copy, size: 16, color: const Color(0xFF0050A4)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${_members.length} member${_members.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (!_isOwner) ...[
                                const SizedBox(width: 16),
                                TextButton.icon(
                                  onPressed: _leaveGroup,
                                  icon: const Icon(Icons.exit_to_app, size: 18, color: Colors.red),
                                  label: const Text('Leave Group', style: TextStyle(color: Colors.red, fontSize: 13)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // Members list header
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.people, size: 20, color: const Color(0xFF0050A4)),
                          const SizedBox(width: 8),
                          Text(
                            'Members',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Members list
                    Expanded(
                      child: _members.isEmpty
                          ? const Center(child: Text('No members found'))
                          : RefreshIndicator(
                              onRefresh: _loadMembers,
                              child: ListView.separated(
                                controller: scrollController,
                                itemCount: _members.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final member = _members[index];
                                  final role = member['role'] as String?;
                                  final memberId = member['user_id'] as String;
                                  final displayName =
                                  member['display_name'] as String? ?? 'Unknown';
                              final email = member['email'] as String? ?? '';
                              final profileImage = member['profile_image'] as String?;
                              final isSharing =
                                  member['is_sharing'] as bool? ?? false;

                              final lastLocation = member['last_location'];
                              final hasLocation = lastLocation != null &&
                                  lastLocation is Map &&
                                  lastLocation['lat'] != null &&
                                  lastLocation['lng'] != null;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      _getRoleColor(role).withOpacity(0.2),
                                  backgroundImage: profileImage != null ? NetworkImage(profileImage) : null,
                                  child: profileImage == null
                                      ? Icon(
                                        _getRoleIcon(role),
                                        color: _getRoleColor(role),
                                      )
                                      : null,
                                ),
                                title: Text(
                                  displayName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (email.isNotEmpty)
                                      Text(email,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600)),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _getRoleColor(role)
                                                .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            _formatRole(role),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: _getRoleColor(role),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          isSharing
                                              ? Icons.location_on
                                              : Icons.location_off,
                                          size: 14,
                                          color: isSharing
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isSharing ? 'Sharing' : 'Not sharing',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isSharing
                                                ? Colors.green
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isOwner && role != 'owner')
                                      IconButton(
                                        icon: const Icon(Icons.person_remove, color: Colors.red),
                                        onPressed: () => _removeMember(memberId, displayName),
                                      ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.my_location,
                                        color: hasLocation ? const Color(0xFF0050A4) : Colors.grey.shade300,
                                      ),
                                      tooltip: hasLocation
                                          ? 'Locate on map'
                                          : 'No location available',
                                      onPressed: hasLocation
                                          ? () {
                                              // Return location data to HomeScreen
                                              Navigator.pop(context, {
                                                'lat': (lastLocation['lat'] as num).toDouble(),
                                                'lng': (lastLocation['lng'] as num).toDouble(),
                                                'name': displayName,
                                              });
                                            }
                                          : null,
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
        );
      },
    );
  }
}
