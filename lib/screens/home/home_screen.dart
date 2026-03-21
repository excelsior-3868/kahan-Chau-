import 'package:flutter/material.dart';
import '../../services/group_service.dart';
import '../../services/location_service.dart';
import '../../models/group_model.dart';
import '../../services/auth_service.dart';
import '../map/map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final GroupService _groupService = GroupService();
  final LocationService _locationService = LocationService();
  int _selectedIndex = 0;
  Group? _selectedGroup;
  bool _isSharingLocation = false;

  @override
  void initState() {
    super.initState();
    _checkInitialSharingStatus();
  }

  Future<void> _checkInitialSharingStatus() async {
    final userId = _authService.currentUserId;
    if (userId != null) {
      // For simplicity in Google Sheets, we'll start with sharing off 
      // or we can fetch the status if we add a GET action for it.
      setState(() {
        _isSharingLocation = false; 
      });
    }
  }

  Future<void> _toggleSharing(bool value) async {
    setState(() => _isSharingLocation = value);
    await _locationService.setSharingStatus(value);
  }

  Future<void> _showCreateGroupDialog() async {
    final controller = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Group'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Group Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                try {
                  await _groupService.createGroup(controller.text);
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating group: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _showJoinGroupDialog() async {
    final controller = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Group'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '6-digit Invite Code'),
          maxLength: 6,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                try {
                  await _groupService.joinGroup(controller.text);
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error joining group: $e')),
                  );
                }
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsList() {
    return FutureBuilder<List<Group>>(
      future: _groupService.getUserGroups(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final groups = snapshot.data ?? [];

        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.group_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('You are not in any groups yet.'),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    await _showCreateGroupDialog();
                    setState(() {}); // Refresh to show the groups list
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create a Group'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await _showJoinGroupDialog();
                    setState(() {}); // Refresh
                  },
                  icon: const Icon(Icons.person_add),
                  label: const Text('Join with Code'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            final isSelected = _selectedGroup?.id == group.id;

            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.group)),
              title: Text(group.name),
              subtitle: Text('Invite Code: ${group.inviteCode}'),
              trailing: isSelected
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const Icon(Icons.map_outlined),
              selected: isSelected,
              onTap: () {
                setState(() {
                  _selectedGroup = group;
                  _selectedIndex = 0; // Switch to map view
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSettingsView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Share My Location'),
          subtitle: const Text('Allow group members to see where you are.'),
          value: _isSharingLocation,
          onChanged: _toggleSharing,
          secondary: Icon(
            _isSharingLocation ? Icons.location_on : Icons.location_off,
            color: _isSharingLocation ? Colors.blue : Colors.grey,
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.person),
          title: const Text('User ID'),
          subtitle: Text(_authService.currentUserId ?? 'Unknown'),
        ),
        ListTile(
          leading: const Icon(Icons.email),
          title: const Text('Email'),
          subtitle: Text(_authService.currentUserEmail ?? 'Unknown'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Logout', style: TextStyle(color: Colors.red)),
          onTap: () async {
            await _locationService.setSharingStatus(false);
            await _authService.signOut();
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/login');
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> widgetOptions = <Widget>[
      MapScreen(selectedGroup: _selectedGroup),
      _buildGroupsList(),
      _buildSettingsView(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo.png', height: 32),
            const SizedBox(width: 8),
            const Text('Kahan Chau ??'),
          ],
        ),
        centerTitle: true,
      ),
      body: widgetOptions.elementAt(_selectedIndex),
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.add),
                        title: const Text('Create New Group'),
                        onTap: () {
                          Navigator.pop(context);
                          _showCreateGroupDialog();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.person_add),
                        title: const Text('Join Existing Group'),
                        onTap: () {
                          Navigator.pop(context);
                          _showJoinGroupDialog();
                        },
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Groups'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
