import 'package:flutter/material.dart';
import '../../models/group_model.dart';
import '../../services/group_service.dart';

class GroupDetailScreen extends StatefulWidget {
  final Group group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final GroupService _groupService = GroupService();
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final members = await _groupService.getGroupMembers(widget.group.id);
    if (mounted) {
      setState(() {
        _members = members;
        _isLoading = false;
      });
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
                          const CircleAvatar(
                            radius: 32,
                            backgroundColor: const Color(0xFF0050A4),
                            child: Icon(Icons.group, size: 36, color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.group.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.vpn_key, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                'Invite Code: ${widget.group.inviteCode}',
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
                                          'Invite code: ${widget.group.inviteCode}'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: const Icon(Icons.copy, size: 16, color: const Color(0xFF0050A4)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_members.length} member${_members.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
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
                                  final displayName =
                                  member['display_name'] as String? ?? 'Unknown';
                              final email = member['email'] as String? ?? '';
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
                                      _getRoleColor(role).withValues(alpha: 0.2),
                                  child: Icon(
                                    _getRoleIcon(role),
                                    color: _getRoleColor(role),
                                  ),
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
                                                .withValues(alpha: 0.15),
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
                                trailing: IconButton(
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
