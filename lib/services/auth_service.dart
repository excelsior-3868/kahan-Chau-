import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _client = Supabase.instance.client;
  final String _resendApiKey = 're_DNRHbyFj_HvmvLBvboERXH7zH6FnT6Jrq';

  String? get currentUserId => _client.auth.currentUser?.id;
  String? get currentUserEmail => _client.auth.currentUser?.email;
  String? get currentUserName =>
      _client.auth.currentUser?.userMetadata?['display_name'] as String?;

  bool get isAuthenticated => _client.auth.currentSession != null;

  /// Generate a random 6-digit OTP
  String generateOtp() {
    final random = Random();
    return (random.nextInt(900000) + 100000).toString();
  }

  /// Send OTP via Resend API
  Future<String?> sendOtpViaResend(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.resend.com/emails'),
        headers: {
          'Authorization': 'Bearer $_resendApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': 'कहाँ छौ ?? <onboarding@resend.dev>',
          'to': [email],
          'subject': 'Your Password Reset OTP - कहाँ छौ ??',
          'html': '''
<div style="font-family: sans-serif; max-width: 400px; margin: 0 auto; border: 1px solid #ddd; padding: 20px; border-radius: 12px; border-top: 4px solid #0056A4;">
  <h2 style="color: #0056A4; margin-top:0;">Reset Your Password</h2>
  <p style="font-size: 16px; color: #333;">Your 6-digit verification code is:</p>
  <div style="font-size: 32px; font-weight: bold; background: #f4f4f4; padding: 15px; border-radius: 8px; text-align: center; letter-spacing: 5px; color: #000;">
    $otp
  </div>
  <p style="font-size: 14px; color: #666; margin-top: 20px;">Use this code to verify your identity. This code will expire soon.</p>
</div>
''',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return null; // Success
      } else {
        final error = jsonDecode(response.body);
        return 'Email Error: ${error['message'] ?? 'Unknown error'}';
      }
    } catch (e) {
      return 'Request failed: $e';
    }
  }

  /// Update password directly via secure RPC
  Future<String?> updatePasswordDirectly(String email, String newPassword) async {
    try {
      final response = await _client.rpc('update_user_password', params: {
        'search_email': email.toLowerCase().trim(),
        'new_password': newPassword,
      });

      if (response == true) {
        return null; // Success
      }
      return 'Could not update password. Please try again.';
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Unexpected error: $e';
    }
  }

  /// Sign up with email and password
  Future<String?> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          if (displayName != null) 'display_name': displayName,
        },
      );

      if (response.user != null) {
        return null; // success, no error
      }
      return 'Sign-up failed. Please try again.';
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Unexpected error: $e';
    }
  }

  /// Sign in with email and password
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session != null) {
        return null; // success, no error
      }
      return 'Sign-in failed. Please try again.';
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Unexpected error: $e';
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<String?> updateDisplayName(String name) async {
    try {
      final userId = currentUserId;
      if (userId == null) return 'Not authenticated';

      // Update auth metadata
      await _client.auth.updateUser(
        UserAttributes(
          data: {'display_name': name},
        ),
      );

      // Also update public.users table for other users to query
      await _client.from('users').update({
        'display_name': name,
      }).eq('id', userId);

      return null; // success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Unexpected error: $e';
    }
  }

  /// Request password reset (NOT USED FOR CUSTOM FLOW)
  Future<String?> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return null; // Success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Verify OTP for recovery (NOT USED FOR CUSTOM FLOW)
  Future<String?> verifyResetOtp(String email, String token) async {
    try {
      await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );
      return null; // Success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Update password (Usually for authenticated user)
  Future<String?> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return null; // Success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Check if a user exists with the given email via a secure RPC call
  Future<bool> checkUserExists(String email) async {
    try {
      // We use a database function (RPC) because direct queries on 'users' 
      // are blocked by RLS for unauthenticated users.
      final response = await _client.rpc('check_user_exists', params: {
        'search_email': email.toLowerCase().trim(),
      });

      return response == true;
    } catch (e) {
      return true; // fail-open
    }
  }

  /// Resolve email from username via secure RPC
  Future<String?> getEmailByUsername(String username) async {
    try {
      final response = await _client.rpc('get_email_by_username', params: {
        'search_username': username.toLowerCase().trim(),
      });
      return response as String?;
    } catch (e) {
      return null;
    }
  }

  /// Check if username is already taken
  Future<bool> checkUsernameAvailable(String username) async {
    try {
      final response = await _client
          .from('users')
          .select('id')
          .eq('username', username.toLowerCase().trim())
          .maybeSingle();

      return response == null;
    } catch (e) {
      return true; // assume available if error
    }
  }
}
