import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/google_sheets_constants.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  String? _currentUserId;
  String? _currentUserEmail;
  String? _currentUserName;

  String? get currentUserId => _currentUserId;
  String? get currentUserEmail => _currentUserEmail;
  String? get currentUserName => _currentUserName;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('userId');
    _currentUserEmail = prefs.getString('userEmail');
    _currentUserName = prefs.getString('userName');
  }

  Future<bool> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.authenticate();
      if (googleUser == null) return false;

      // Sync with Google Sheets
      final response = await http.post(
        Uri.parse('${GoogleSheetsConstants.webAppUrl}?action=registerUser'),
        body: jsonEncode({
          'id': googleUser.id,
          'email': googleUser.email,
          'displayName': googleUser.displayName,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 302) {
        _currentUserId = googleUser.id;
        _currentUserEmail = googleUser.email;
        _currentUserName = googleUser.displayName;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', googleUser.id);
        await prefs.setString('userEmail', googleUser.email);
        await prefs.setString('userName', googleUser.displayName ?? '');
        return true;
      }
      return false;
    } catch (e) {
      print('Sign-In Error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await GoogleSignIn.instance.signOut();
    _currentUserId = null;
    _currentUserEmail = null;
    _currentUserName = null;
  }

  bool get isAuthenticated => _currentUserId != null;
}
