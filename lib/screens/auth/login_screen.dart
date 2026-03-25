import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _generatedOtp = ""; // Store locally generated OTP
  bool _isLoading = false;
  bool _isSignUp = false; // Toggle between Sign In / Sign Up
  bool _isBiometricSupported = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
  }

  Future<void> _checkBiometricSupport() async {
    final supported = await BiometricService().isBiometricAvailable();
    if (mounted) setState(() => _isBiometricSupported = supported);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleBiometricLogin() async {
    final bioService = BiometricService();
    if (!await bioService.isBiometricEnabled()) {
      _showError('Biometric login is not enabled. Please log in normally first or check Settings.');
      return;
    }

    final success = await bioService.authenticate();
    if (success) {
      final creds = await bioService.getCredentials();
      if (creds != null) {
        setState(() => _isLoading = true);
        final error = await AuthService().signIn(
            email: creds['email']!, password: creds['password']!);
        if (error != null) {
          _showStyledDialog('Error', 'Biometric login failed: $error');
        }
        if (mounted) setState(() => _isLoading = false);
      } else {
        _showStyledDialog('Error', 'No saved credentials found. Please log in manually once to save them.');
      }
    }
  }

  Future<void> _handleAuth() async {
    final authService = AuthService();
    final bioService = BiometricService();

    if (_isSignUp) {
      final name = _nameController.text.trim();
      final username = _usernameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final confirm = _confirmPasswordController.text;

      if (name.isEmpty || username.isEmpty || email.isEmpty || password.isEmpty) {
        _showStyledDialog('Error', 'Please fill in all fields.');
        return;
      }

      if (password != confirm) {
        _showStyledDialog('Error', 'Passwords do not match.');
        return;
      }

      setState(() => _isLoading = true);

      // Check username availability
      final isAvailable = await authService.checkUsernameAvailable(username);
      if (!isAvailable) {
        _showStyledDialog('Error', 'This username is already taken. Please choose another.');
        setState(() => _isLoading = false);
        return;
      }

      final error = await authService.signUp(
        email: email,
        password: password,
        displayName: name,
      );

      if (error == null) {
        // Manually update username in the public.users table
        // Note: SignUp creates the user, but we need to ensure the username is stored.
        // Usually handled by a trigger, but we'll try to update it explicitly if needed.
        _showStyledDialog('Success', 'Account created! Please log in.');
        setState(() {
          _isSignUp = false;
          _emailController.text = username; // Pre-fill username for login
        });
      } else {
        _showStyledDialog('Error', error);
      }
    } else {
      // Login flow
      final identifier = _emailController.text.trim(); // This is the Username field
      final password = _passwordController.text;

      if (identifier.isEmpty || password.isEmpty) {
        _showStyledDialog('Warning', 'Please enter your username and password.');
        return;
      }

      setState(() => _isLoading = true);

      String signInEmail = identifier;
      // If it's not a direct email, try to find the email associated with this username
      if (!identifier.contains('@')) {
        final resolvedEmail = await authService.getEmailByUsername(identifier);
        if (resolvedEmail != null) {
          signInEmail = resolvedEmail;
        } else {
          _showStyledDialog('Error', 'Username not found. Please try again.');
          setState(() => _isLoading = false);
          return;
        }
      }

      final error = await authService.signIn(email: signInEmail, password: password);
      
      if (error == null) {
        // Handle Biometric Prompt on first login
        final prefs = await SharedPreferences.getInstance();
        if (!(prefs.getBool('bio_prompted') ?? false) && _isBiometricSupported) {
          bool? wantBio = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Enable Biometric Login?'),
              content: const Text('Would you like to use Fingerprint/FaceID for faster logins?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Maybe Later')),
                ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Enable')),
              ],
            ),
          );
          await prefs.setBool('bio_prompted', true);
          if (wantBio == true) {
            await bioService.setBiometricEnabled(true);
            await bioService.saveCredentials(signInEmail, password);
            _showStyledDialog('Success', 'Biometric Login Enabled!');
          }
        } else if (await bioService.isBiometricEnabled()) {
          // Update saved credentials in case password changed
          await bioService.saveCredentials(signInEmail, password);
        }
      } else {
        _showStyledDialog('Error', error);
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController(text: _emailController.text);
    final authService = AuthService();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Center(
          child: Text(
            'Reset Password',
            style: TextStyle(
                color: Color(0xFF0056A4),
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Enter your Username to get the OTP in your registered email.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'your_username',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final identifier = emailController.text.trim();
              if (identifier.isEmpty) {
                _showStyledDialog('Error', 'Please enter your Username.');
                return;
              }

              setState(() => _isLoading = true);
              String targetEmail = identifier;
              
              // Resolve email from username if it's not already an email
              if (!identifier.contains('@')) {
                final resolved = await authService.getEmailByUsername(identifier);
                if (resolved != null) {
                  targetEmail = resolved;
                } else {
                  _showStyledDialog('Error', 'Account not found.');
                  setState(() => _isLoading = false);
                  return;
                }
              }

              // Use Supabase built-in reset functionality
              final error = await authService.resetPassword(targetEmail);
              if (mounted) {
                Navigator.pop(context);
                setState(() => _isLoading = false);
                if (error == null) {
                  _showOtpVerificationDialog(targetEmail);
                } else {
                  _showStyledDialog('Error', error);
                }
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0056A4)),
            child: const Text('Send OTP', style: TextStyle(color: Colors.white)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Future<void> _showOtpVerificationDialog(String email) async {
    final otpController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Center(
          child: Text(
            'Verify OTP',
            style: TextStyle(
                color: Color(0xFF0056A4),
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Please enter the 6-digit code sent to $email',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              decoration: const InputDecoration(
                labelText: 'OTP Code',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.security),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final otp = otpController.text.trim();
              if (otp.isEmpty) return;

              setState(() => _isLoading = true);
              final authService = AuthService();
              final error = await authService.verifyResetOtp(email, otp);
              
              if (mounted) {
                setState(() => _isLoading = false);
                if (error == null) {
                  Navigator.pop(context);
                  _showNewPasswordDialog(email);
                } else {
                  _showStyledDialog('Error', 'Invalid OTP code. Please try again or check your email.');
                }
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0056A4)),
            child: const Text('Verify', style: TextStyle(color: Colors.white)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Future<void> _showNewPasswordDialog(String email) async {
    final passwordController = TextEditingController();
    final authService = AuthService();
    bool obscure = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Center(
            child: Text(
              'New Password',
              style: TextStyle(
                  color: Color(0xFF0056A4),
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Enter your new password below.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_reset),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final pwd = passwordController.text.trim();
                if (pwd.length < 6) {
                  _showStyledDialog('Error', 'Password must be at least 6 characters.');
                  return;
                }

                // After verifyOTP, we are logged in with recovery session, so we can use standard update
                final error = await authService.updatePassword(pwd);
                if (mounted) {
                  Navigator.pop(context);
                  if (error == null) {
                    _showStyledDialog('Success', 'Password updated successfully! You can now log in.');
                  } else {
                    _showStyledDialog('Error', error);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0056A4),
                  minimumSize: const Size(double.infinity, 50)),
              child: const Text('Update Password', style: TextStyle(color: Colors.white)),
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  void _showStyledDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Center(
          child: Text(
            title,
            style: const TextStyle(
                color: Color(0xFF0056A4), fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ok', style: TextStyle(color: Color(0xFF0056A4))),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showError(String message) {
    _showStyledDialog('Error', message);
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0056A4); // Exact tone from the Nepal Telecom image

    return Scaffold(
      backgroundColor: primaryBlue,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Container(
              padding: const EdgeInsets.only(top: 32.0, bottom: 24.0, left: 24.0, right: 24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Icon
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/app_icon.png',
                          height: 70,
                          width: 70,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    _isSignUp ? 'Create Account' : 'कहाँ छौ ??',
                    style: const TextStyle(
                      color: primaryBlue,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  const Text(
                    'Real-time Family Location Sharing',
                    style: TextStyle(
                      color: primaryBlue,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Name field (only for Sign Up)
                  if (_isSignUp) ...[
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Display Name',
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.badge_outlined, color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryBlue, width: 2),
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Username field (Always shown, replaces email in Login)
                  TextField(
                    controller: _isSignUp ? _usernameController : _emailController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: primaryBlue, width: 2),
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Email field (Only for Sign Up)
                  if (_isSignUp) ...[
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryBlue, width: 2),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Password field
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: primaryBlue, width: 2),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    textInputAction: _isSignUp ? TextInputAction.next : TextInputAction.done,
                    onSubmitted: _isSignUp ? null : (_) => _handleAuth(),
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password field (Only for Sign Up)
                  if (_isSignUp) ...[
                    TextField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.lock_clock_outlined, color: Colors.grey),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryBlue, width: 2),
                        ),
                      ),
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleAuth(),
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    const SizedBox(height: 8),
                  ],

                  // Submit button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleAuth,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            _isSignUp ? 'Sign Up' : 'Login',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Toggle Sign In / Sign Up
                  TextButton(
                    onPressed: () {
                      setState(() => _isSignUp = !_isSignUp);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: primaryBlue,
                    ),
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Login'
                          : 'Don\'t have an account? Sign Up',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),

                  if (!_isSignUp)
                    TextButton(
                      onPressed: _showForgotPasswordDialog,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                      ),
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(fontSize: 13, decoration: TextDecoration.underline),
                      ),
                    ),

                  // Optional fingerprint/bottom icon
                  if (!_isSignUp && _isBiometricSupported) ...[
                    const SizedBox(height: 16),
                    IconButton(
                      icon: const Icon(
                        Icons.fingerprint,
                        color: Color(0xFF0056A4),
                        size: 50,
                      ),
                      onPressed: _handleBiometricLogin,
                    ),
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
