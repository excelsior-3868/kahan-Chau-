import 'package:flutter/material.dart';
import '../../services/group_service.dart';
import '../../services/location_service.dart';
import '../../models/group_model.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../map/map_screen.dart';
import '../groups/group_detail_screen.dart';

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
  Map<String, dynamic>? _focusLocation;
  List<Group> _groups = [];
  bool _isSharingLocation = false;
  bool _isBiometricEnabled = false;
  bool _isLoadingGroups = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
    _checkInitialSharingStatus();
    _checkBiometricStatus();
  }

  Future<void> _checkBiometricStatus() async {
    final isEnabled = await BiometricService().isBiometricEnabled();
    if (mounted) setState(() => _isBiometricEnabled = isEnabled);
  }

  Future<void> _toggleBiometric(bool enable) async {
    final bioService = BiometricService();
    if (!enable) {
      final confirm = await _showConfirmDialog(
          'Disable Biometric Login',
          'Are you sure you want to disable biometric login? You will need your password to log in next time.',
          titleColor: Colors.black,
          titleSize: 18);
      if (confirm) {
        await bioService.setBiometricEnabled(false);
        setState(() => _isBiometricEnabled = false);
        _showStyledDialog('Disabled', 'Biometric login has been disabled.');
      }
      return;
    }

    // Attempt to enable: we need the user's password to store it securely!
    final passwordController = TextEditingController();
    bool isSavingLocal = false;
    bool obscurePasswordLocal = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Center(
            child: Text(
              'Enable Biometrics',
              style: TextStyle(
                  color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                  'Please verify your password to securely save it for biometric login.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black87)),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscurePasswordLocal,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePasswordLocal
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () => setStateDialog(
                        () => obscurePasswordLocal = !obscurePasswordLocal),
                  ),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: isSavingLocal
                  ? null
                  : () async {
                      final pwd = passwordController.text;
                      if (pwd.isEmpty) return;
                      setStateDialog(() => isSavingLocal = true);

                      final email = _authService.currentUserEmail;
                      if (email == null) {
                        Navigator.pop(context);
                        return;
                      }

                      final error =
                          await _authService.signIn(email: email, password: pwd);
                      if (mounted) setStateDialog(() => isSavingLocal = false);

                      if (error == null) {
                        await bioService.saveCredentials(email, pwd);
                        await bioService.setBiometricEnabled(true);
                        if (mounted) {
                          setState(() => _isBiometricEnabled = true);
                          Navigator.pop(context);
                          _showStyledDialog('Success',
                              'Biometric login enabled successfully!');
                        }
                      } else {
                        if (mounted) {
                          _showStyledDialog(
                              'Error', 'Incorrect password. Please try again.');
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0056A4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: isSavingLocal
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Enable', style: TextStyle(color: Colors.white)),
            ),
          ],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoadingGroups = true);
    final groups = await _groupService.getUserGroups();
    if (mounted) {
      setState(() {
        _groups = groups;
        _isLoadingGroups = false;
        // Auto-select first group if none selected
        if (_selectedGroup == null && groups.isNotEmpty) {
          _selectedGroup = groups.first;
        }
      });
    }
  }

  Future<void> _checkInitialSharingStatus() async {
    final isSharing = await _locationService.getSharingStatus();
    if (mounted) {
      setState(() {
        _isSharingLocation = isSharing;
      });
      // Start tracking if it was already enabled on the server
      if (isSharing) {
        _locationService.setSharingStatus(true);
      }
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
        title: const Center(
          child: Text(
            'Create New Group',
            style: TextStyle(
                color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                try {
                  await _groupService.createGroup(controller.text);
                  if (mounted) {
                    Navigator.pop(context);
                    _loadGroups(); // Refresh groups
                    _showStyledDialog('Success', 'Group created successfully!');
                  }
                } catch (e) {
                  _showStyledDialog('Error', 'Error creating group: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0056A4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Future<void> _showJoinGroupDialog() async {
    final controller = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Center(
          child: Text(
            'Join Group',
            style: TextStyle(
                color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '6-digit Invite Code',
                border: OutlineInputBorder(),
              ),
              maxLength: 6,
              keyboardType: TextInputType.text,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                try {
                  final success =
                      await _groupService.joinGroup(controller.text);
                  if (mounted) {
                    Navigator.pop(context);
                    if (success) {
                      _loadGroups(); // Refresh groups
                      _showStyledDialog('Success', 'Joined group successfully!');
                    } else {
                      _showStyledDialog('Error', 'Invalid invite code.');
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    _showStyledDialog('Error', 'Error joining group: $e');
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0056A4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Join', style: TextStyle(color: Colors.white)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // ============================================================
  // Map Tab - with group selector
  // ============================================================
  Widget _buildMapTab() {
    return Column(
      children: [
        // Map (Selected group is chosen from the Groups tab)
        Expanded(
          child: MapScreen(
            selectedGroup: _selectedGroup,
            focusLocation: _focusLocation,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Groups Tab - list with tap to view details
  // ============================================================
  Widget _buildGroupsList([ScrollController? scrollController]) {
    if (_isLoadingGroups) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_groups.isEmpty) {
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
              },
              icon: const Icon(Icons.add),
              label: const Text('Create a Group'),
            ),
            TextButton.icon(
              onPressed: () async {
                await _showJoinGroupDialog();
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Join with Code'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadGroups,
      child: ListView.builder(
        controller: scrollController,
        itemCount: _groups.length,
        itemBuilder: (context, index) {
          final group = _groups[index];
          final isSelected = _selectedGroup?.id == group.id;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  isSelected ? Colors.blue : Colors.blue.shade100,
              child: Icon(Icons.group,
                  color: isSelected ? Colors.white : Colors.blue),
            ),
            title: Text(
              group.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('Invite Code: ${group.inviteCode}'),
            trailing: Radio<String>(
              value: group.id,
              groupValue: _selectedGroup?.id,
              activeColor: Colors.blue,
              onChanged: (String? value) {
                setState(() {
                  _selectedGroup = group;
                  _focusLocation = null;
                });
                _showStyledDialog('Group Selected', '"${group.name}" selected for Map.');
              },
            ),
            onTap: () async {
              // Navigate to group detail as a bottom sheet
              final locationTarget = await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => GroupDetailScreen(group: group),
              );

              if (locationTarget != null && locationTarget is Map<String, dynamic>) {
                setState(() {
                  _selectedGroup = group;
                  _focusLocation = locationTarget;
                  _selectedIndex = 0; // Switch to map view
                });
                if (mounted) {
                  _showStyledDialog('Locating User', 'Locating ${locationTarget['name']}...');
                }
              }
            },
          );
        },
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isSaving = false;
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          title: const Center(
            child: Text(
              'Change Password',
              style: TextStyle(
                  color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          content: Container(
            width: MediaQuery.of(context).size.width,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(),
                  const SizedBox(height: 16),
                  TextField(
                    controller: oldPasswordController,
                    obscureText: obscureOld,
                    decoration: InputDecoration(
                      labelText: 'Old Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscureOld ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setStateDialog(() => obscureOld = !obscureOld),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newPasswordController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_reset),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setStateDialog(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_clock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setStateDialog(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
            ),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                final oldPwd = oldPasswordController.text;
                final newPwd = newPasswordController.text;
                final confirmPwd = confirmPasswordController.text;

                if (oldPwd.isEmpty || newPwd.isEmpty || confirmPwd.isEmpty) {
                  _showStyledDialog('Error', 'Please fill in all fields.');
                  return;
                }
                if (newPwd.length < 6) {
                  _showStyledDialog('Error', 'New password must be at least 6 characters.');
                  return;
                }
                if (newPwd != confirmPwd) {
                  _showStyledDialog('Error', 'Passwords do not match.');
                  return;
                }

                setStateDialog(() => isSaving = true);
                
                final email = AuthService().currentUserEmail;
                if (email == null) {
                  setStateDialog(() => isSaving = false);
                  return;
                }

                final reAuthError = await AuthService().signIn(email: email, password: oldPwd);
                if (reAuthError != null) {
                  if (mounted) {
                    setStateDialog(() => isSaving = false);
                    _showStyledDialog('Error', 'Incorrect old password.');
                  }
                  return;
                }

                final updateError = await AuthService().updatePassword(newPwd);
                
                if (mounted) {
                  setStateDialog(() => isSaving = false);
                  if (updateError == null) {
                    if (_isBiometricEnabled) {
                      await BiometricService().saveCredentials(email, newPwd);
                    }
                    Navigator.pop(context);
                    _showStyledDialog('Success', 'Password updated successfully!');
                  } else {
                    _showStyledDialog('Error', updateError);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0056A4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Update', style: TextStyle(color: Colors.white)),
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Future<void> _showEditDisplayNameDialog() async {
    final controller = TextEditingController(text: _authService.currentUserName ?? '');
    bool isSaving = false;

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Center(
            child: Text(
              'Edit Display Name',
              style: TextStyle(
                  color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Enter new name',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  setStateDialog(() => isSaving = true);
                  final error = await _authService.updateDisplayName(newName);
                  
                  if (mounted) {
                    setStateDialog(() => isSaving = false);
                    if (error == null) {
                      Navigator.pop(context);
                      setState(() {}); // Refresh settings view
                      _showStyledDialog('Success', 'Display name updated successfully!');
                    } else {
                      _showStyledDialog('Error', error);
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0056A4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildSettingsView([ScrollController? scrollController]) {
    return ListView(
      controller: scrollController,
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
        SwitchListTile(
          title: const Text('Biometric Login'),
          subtitle: const Text('Use Fingerprint/FaceID to log in securely.'),
          value: _isBiometricEnabled,
          onChanged: _toggleBiometric,
          secondary: Icon(
            Icons.fingerprint,
            color: _isBiometricEnabled ? Colors.blue : Colors.grey,
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.person),
          title: const Text('Display Name'),
          subtitle: Text(_authService.currentUserName ?? 'No Name Set'),
          trailing: const Icon(Icons.edit, size: 20),
          onTap: _showEditDisplayNameDialog,
        ),
        ListTile(
          leading: const Icon(Icons.email),
          title: const Text('Email'),
          subtitle: Text(_authService.currentUserEmail ?? 'Unknown'),
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Change Password'),
          subtitle: const Text('Update your account security.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showChangePasswordDialog,
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Logout', style: TextStyle(color: Colors.red)),
          onTap: () async {
            final confirm = await _showConfirmDialog(
                'Logout', 'Are you sure you want to sign out?');
            if (confirm) {
              await _locationService.setSharingStatus(false);
              await _authService.signOut();
              // StreamBuilder in AuthGate will handle navigation
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background is always Map
          _buildMapTab(),

          // Foreground sliding sheet for Groups and Settings
          if (_selectedIndex != 0)
            DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.2,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24.0),
                      topRight: Radius.circular(24.0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10.0,
                        spreadRadius: 0.0,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Drag handle pill
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12.0),
                        height: 4.0,
                        width: 40.0,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2.0),
                        ),
                      ),
                      // Title
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          _selectedIndex == 1 ? 'Your Groups' : 'Settings',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      const Divider(),
                      // Sheet content
                      Expanded(
                        child: _selectedIndex == 1
                            ? _buildGroupsList(scrollController)
                            : _buildSettingsView(scrollController),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
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

  void _showStyledDialog(String title, String message,
      {Color titleColor = Colors.black, double titleSize = 18}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Center(
          child: Text(
            title,
            style: TextStyle(
                color: titleColor,
                fontSize: titleSize,
                fontWeight: FontWeight.bold),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87)),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0056A4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Ok', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String message,
      {Color titleColor = Colors.black, double titleSize = 18}) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Center(
              child: Text(
                title,
                style: TextStyle(
                    color: titleColor,
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(),
                const SizedBox(height: 16),
                Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87)),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0056A4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Confirm', style: TextStyle(color: Colors.white)),
              ),
            ],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ) ??
        false;
  }
}
