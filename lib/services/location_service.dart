import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class LocationService {
  final SupabaseClient _client = Supabase.instance.client;
  final AuthService _authService = AuthService();
  StreamSubscription<Position>? _positionStream;

  Future<void> setSharingStatus(bool isSharing) async {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    try {
      await _client
          .from('users')
          .update({'is_sharing': isSharing}).eq('id', userId);
    } catch (e) {
      print('Set Sharing Status Error: $e');
    }

    if (isSharing) {
      // 1. Immediately update server with current location
      try {
        final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium));
        await _updateLocation(position);
      } catch (e) {
        print('Initial Location Update Error: $e');
      }
      
      // 2. Then start the stream to track movement
      _startTracking();
    } else {
      _stopTracking();
    }
  }

  Future<bool> getSharingStatus() async {
    final userId = _authService.currentUserId;
    if (userId == null) return false;

    try {
      final row =
          await _client.from('users').select('is_sharing').eq('id', userId).single();
      return row['is_sharing'] as bool? ?? false;
    } catch (e) {
      print('Get Sharing Status Error: $e');
      return false;
    }
  }

  void _startTracking() {
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 30, // Update every 30 meters
      ),
    ).listen((Position position) async {
      await _updateLocation(position);
    });
  }

  void _stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  Future<void> _updateLocation(Position position) async {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    try {
      // 1. Update the user's master last_location
      await _client.from('users').update({
        'last_location': {
          'lat': position.latitude,
          'lng': position.longitude,
        },
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      // 2. Update the 'locations' table for every group the user is in
      // This is what the MapScreen listens to for real-time member updates
      final groupService = Supabase.instance.client.from('group_members');
      final groupsResponse = await groupService.select('group_id').eq('user_id', userId);
      
      final List<dynamic> groups = groupsResponse as List<dynamic>;
      if (groups.isNotEmpty) {
        final List<Map<String, dynamic>> upserts = groups.map((g) {
          final groupId = g['group_id'] as String;
          return {
            'user_id': userId,
            'group_id': groupId,
            'lat': position.latitude,
            'lng': position.longitude,
            'status': 'live',
            'timestamp': DateTime.now().toIso8601String(),
          };
        }).toList();

        await _client.from('locations').upsert(upserts);
      }
    } catch (e) {
      print('Location Update Error: $e');
    }
  }

  Future<void> updateLocationForGroup(String groupId) async {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );

      await _client.from('locations').upsert({
        'user_id': userId,
        'group_id': groupId,
        'lat': position.latitude,
        'lng': position.longitude,
        'status': 'live',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Update Location For Group Error: $e');
    }
  }

  /// Real-time stream of group member locations using Supabase Realtime
  Stream<List<Map<String, dynamic>>> streamGroupLocations(
      String groupId) {
    return _client
        .from('locations')
        .stream(primaryKey: ['user_id', 'group_id'])
        .eq('group_id', groupId);
  }

  void dispose() {
    _stopTracking();
  }
}
