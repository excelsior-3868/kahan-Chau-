import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../core/constants/google_sheets_constants.dart';
import 'auth_service.dart';

class LocationService {
  final AuthService _authService = AuthService();
  StreamSubscription<Position>? _positionStream;

  Future<void> setSharingStatus(bool isSharing) async {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    // Google Sheets doesn't have a simple boolean update without a custom action 
    // or reusing updateLocation. We'll just start/stop the local stream.
    if (isSharing) {
      _startTracking();
    } else {
      _stopTracking();
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
      await _updateLocationInSheets(position);
    });
  }

  void _stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  Future<void> _updateLocationInSheets(Position position) async {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    try {
      await http.post(
        Uri.parse('${GoogleSheetsConstants.webAppUrl}?action=updateLocation'),
        body: jsonEncode({
          'user_id': userId,
          'lat': position.latitude,
          'lng': position.longitude,
        }),
      );
    } catch (e) {
      print('Location Update Error: $e');
    }
  }

  // Polling Stream to simulate real-time for Google Sheets
  Stream<List<Map<String, dynamic>>> streamGroupLocations(String groupId) async* {
    while (true) {
      try {
        final response = await http.get(
          Uri.parse('${GoogleSheetsConstants.webAppUrl}?action=getGroupLocations&groupId=$groupId'),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> body = jsonDecode(response.body);
          if (body['status'] == 'success') {
            final List<dynamic> data = body['data'];
            yield data.cast<Map<String, dynamic>>();
          }
        }
      } catch (e) {
        print('Stream Locations Error: $e');
      }
      await Future.delayed(const Duration(seconds: 10)); // Poll every 10 seconds
    }
  }

  void dispose() {
    _stopTracking();
  }
}
