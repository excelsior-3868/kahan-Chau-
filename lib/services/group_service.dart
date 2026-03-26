import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group_model.dart';
import 'auth_service.dart';

class GroupService {
  final SupabaseClient _client = Supabase.instance.client;
  final AuthService _authService = AuthService();

  Future<List<Group>> getUserGroups() async {
    final userId = _authService.currentUserId;
    if (userId == null) return [];

    try {
      // Get group IDs the user belongs to
      final memberRows = await _client
          .from('group_members')
          .select('group_id')
          .eq('user_id', userId);

      if (memberRows.isEmpty) return [];

      final groupIds =
          memberRows.map((row) => row['group_id'] as String).toList();

      // Fetch the group details
      final groupRows =
          await _client.from('groups').select().inFilter('id', groupIds);

      return groupRows.map((json) => Group.fromJson(json)).toList();
    } catch (e) {
      print('Get Groups Error: $e');
      return [];
    }
  }

  Future<Group?> createGroup(String name) async {
    final userId = _authService.currentUserId;
    if (userId == null) return null;

    try {
      // Insert the group
      final groupData = await _client
          .from('groups')
          .insert({
            'name': name,
            'owner_id': userId,
          })
          .select()
          .single();

      // Add the owner as a member
      await _client.from('group_members').insert({
        'group_id': groupData['id'],
        'user_id': userId,
        'role': 'owner',
      });

      return Group.fromJson(groupData);
    } catch (e) {
      print('Create Group Error: $e');
      return null;
    }
  }

  Future<bool> joinGroup(String inviteCode) async {
    final userId = _authService.currentUserId;
    if (userId == null) return false;

    try {
      final result = await _client.rpc('join_group_by_code', params: {
        'code': inviteCode.trim(),
      });

      if (result is Map && result['status'] == 'ok') {
        return true;
      }

      print('Join Group Response: $result');
      return false;
    } catch (e) {
      print('Join Group Error: $e');
      return false;
    }
  }

  /// Fetch members of a group with their user profile info
  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    try {
      // Get member rows with user details
      final memberRows = await _client
          .from('group_members')
          .select('user_id, role, joined_at')
          .eq('group_id', groupId);

      if (memberRows.isEmpty) return [];

      final userIds =
          memberRows.map((row) => row['user_id'] as String).toList();

      // Fetch user profiles
      final userRows =
          await _client.from('users').select().inFilter('id', userIds);

      // Merge member data with user profiles
      final members = <Map<String, dynamic>>[];
      for (final member in memberRows) {
        final user = userRows.firstWhere(
          (u) => u['id'] == member['user_id'],
          orElse: () => <String, dynamic>{},
        );
        members.add({
          ...member,
          'display_name': user['display_name'] ?? user['email'] ?? 'Unknown',
          'email': user['email'] ?? '',
          'is_sharing': user['is_sharing'] ?? false,
          'last_location': user['last_location'],
          'profile_image': user['profile_image'],
        });
      }

      return members;
    } catch (e) {
      print('Get Group Members Error: $e');
      return [];
    }
  }

  Future<bool> updateGroupName(String groupId, String name) async {
    try {
      await _client.from('groups').update({'name': name}).eq('id', groupId);
      return true;
    } catch (e) {
      print('Update Group Name Error: $e');
      return false;
    }
  }

  Future<bool> updateGroupAvatar(String groupId, String avatarUrl) async {
    try {
      await _client
          .from('groups')
          .update({'avatar_url': avatarUrl}).eq('id', groupId);
      return true;
    } catch (e) {
      print('Update Group Avatar Error: $e');
      return false;
    }
  }

  Future<bool> removeMember(String groupId, String userId) async {
    try {
      await _client
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      print('Remove Member Error: $e');
      return false;
    }
  }

  Future<bool> leaveGroup(String groupId) async {
    final userId = _authService.currentUserId;
    if (userId == null) return false;

    try {
      await _client
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      print('Leave Group Error: $e');
      return false;
    }
  }
}
