import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/google_sheets_constants.dart';
import '../models/group_model.dart';
import 'auth_service.dart';

class GroupService {
  final AuthService _authService = AuthService();

  Future<List<Group>> getUserGroups() async {
    final userId = _authService.currentUserId;
    if (userId == null) return [];

    final response = await http.get(
      Uri.parse('${GoogleSheetsConstants.webAppUrl}?action=getUserGroups&userId=$userId'),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(response.body);
      if (body['status'] == 'success') {
        final List<dynamic> data = body['data'];
        return data.map((json) => Group.fromJson(json)).toList();
      }
    }
    return [];
  }

  Future<Group?> createGroup(String name) async {
    final userId = _authService.currentUserId;
    if (userId == null) return null;

    final response = await http.post(
      Uri.parse('${GoogleSheetsConstants.webAppUrl}?action=createGroup'),
      body: jsonEncode({
        'name': name,
        'owner_id': userId,
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(response.body);
      if (body['status'] == 'success') {
        return Group.fromJson(body['data']);
      }
    }
    return null;
  }

  Future<bool> joinGroup(String inviteCode) async {
    final userId = _authService.currentUserId;
    if (userId == null) return false;

    final response = await http.post(
      Uri.parse('${GoogleSheetsConstants.webAppUrl}?action=joinGroup'),
      body: jsonEncode({
        'invite_code': inviteCode.toUpperCase(),
        'user_id': userId,
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(response.body);
      return body['status'] == 'success';
    }
    return false;
  }
}
