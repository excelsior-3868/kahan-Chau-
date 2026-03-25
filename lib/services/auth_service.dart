import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
      _client.auth.currentUser?.userMetadata?['display_name'] as String? ??
      _client.auth.currentUser?.userMetadata?['full_name'] as String?;

  String? get currentUserProfileImage => 
      _client.auth.currentUser?.userMetadata?['avatar_url'] as String? ??
      _client.auth.currentUser?.userMetadata?['profile_image'] as String?;

  bool get isAuthenticated => _client.auth.currentSession != null;

  /// The Web Client ID from Google Cloud Console (required for Android ID Tokens)
  static const String webClientId = '919498628933-jifmst36e9b760cinn6734pmn0jshd63.apps.googleusercontent.com';

  /// Sign in with Google Web/Android
  Future<String?> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: webClientId != 'REPLACE_WITH_YOUR_WEB_CLIENT_ID_FROM_GOOGLE_CONSOLE' ? webClientId : null,
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return 'Sign-In canceled';

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        return 'Google Sign-In failed to retrieve ID Token. Please check your Google Cloud Console configuration.';
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user != null) {
        final user = response.user!;
        final metadata = user.userMetadata ?? {};
        final displayName = metadata['full_name'] as String? ?? metadata['display_name'] as String? ?? 'User';
        
        try {
          final profile = await _client.from('users').select('id').eq('id', user.id).maybeSingle();
          
          if (profile == null) {
            String baseUsername = (metadata['full_name'] as String? ?? user.email?.split('@')[0] ?? 'user').replaceAll(' ', '_').toLowerCase();
            final isTaken = !(await checkUsernameAvailable(baseUsername));
            if (isTaken) {
              baseUsername = '$baseUsername${Random().nextInt(9999)}';
            }

            await _client.from('users').upsert({
              'id': user.id,
              'email': user.email,
              'display_name': displayName,
              'username': baseUsername,
              'profile_image': user.userMetadata?['avatar_url'],
              'updated_at': DateTime.now().toIso8601String(),
            });
          }
        } catch (e) {
          print('Sync Google profile error: $e');
        }
      }

      return null; // success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      if (e.toString().contains('sign_in_canceled')) {
        return 'Sign-In canceled';
      }
      return 'Unexpected error: $e';
    }
  }

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
    required String username,
    String? displayName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username.toLowerCase().trim(),
          if (displayName != null) 'display_name': displayName,
        },
      );

      if (response.user != null) {
        // Since we may not be authenticated yet (email confirm), we rely on 
        // a database trigger to sync metadata to public.users table.
        // If we are authenticated (auto-confirm is on), we try an explicit update.
        if (_client.auth.currentUser != null) {
          try {
            await _client.from('users').update({
              'username': username.toLowerCase().trim(),
            }).eq('id', response.user!.id);
          } catch (_) {
            // Ignore error here, since trigger might be doing it
          }
        }
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
    final googleSignIn = GoogleSignIn();
    try {
      await googleSignIn.signOut();
    } catch (_) {}
    await _client.auth.signOut();
  }

  /// Sign in using a stored refresh token (for biometric re-auth)
  Future<String?> signInWithToken(String refreshToken) async {
    try {
      final response = await _client.auth.refreshSession(refreshToken);
      if (response.session != null) {
        return null;
      }
      return 'Session expired. Please log in with Google.';
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Unexpected error: $e';
    }
  }

  /// Get current session refresh token
  String? get currentRefreshToken => _client.auth.currentSession?.refreshToken;

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
    final cleanUsername = username.toLowerCase().trim();
    try {
      final response = await _client.rpc('get_email_by_username', params: {
        'search_username': cleanUsername,
      });
      return response as String?;
    } catch (e) {
      print('RPC get_email_by_username error ($cleanUsername): $e');
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
