import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final authService = AuthService();
  final bioService = BiometricService();
  bool _isLoading = false;
  bool _isBiometricSupported = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
  }

  Future<void> _checkBiometricSupport() async {
    final supported = await bioService.isBiometricAvailable();
    if (mounted) setState(() => _isBiometricSupported = supported);
  }

  Future<void> _handleBiometricLogin() async {
    if (!await bioService.isBiometricEnabled()) {
      _showStyledDialog('Notice', 'Biometric login is not enabled. Please log in with Google first.');
      return;
    }

    final success = await bioService.authenticate();
    if (success) {
      final creds = await bioService.getCredentials();
      if (creds != null) {
        setState(() => _isLoading = true);
        final error = await authService.signIn(
            email: creds['email']!, password: creds['password']!);
        if (error != null) {
          _showStyledDialog('Error', 'Biometric login failed: $error');
        }
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleAuth() async {
    setState(() => _isLoading = true);
    final error = await authService.signInWithGoogle();
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null && error != 'Sign-In canceled') {
        _showStyledDialog('Error', error);
      }
    }
  }

  void _showStyledDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Center(
          child: Text(
            title,
            style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
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
                backgroundColor: const Color(0xFFE53935),
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

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFE53935);
    const bgColor = Color(0xFFF8F9FB); // Very light grey background like Mero Vault

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Icon (Clean, no extra border container as per Mero Vault)
                Center(
                  child: Image.asset(
                    'assets/app_icon-removebg-preview.png',
                    height: 180,
                    width: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.location_on, size: 100, color: primaryRed),
                  ),
                ),
                const SizedBox(height: 40),
                
                const Text(
                  'कहाँ छौ ??',
                  style: TextStyle(
                    color: primaryRed, 
                    fontSize: 36, 
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                const Text(
                  'Secure. Private. Yours.',
                  style: TextStyle(
                    color: Color(0xFF9E9E9E), 
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 80),

                // Red Pill-shaped Google Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleGoogleAuth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const StadiumBorder(),
                      elevation: 2,
                    ),
                    child: _isLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Image.network(
                                'https://www.gstatic.com/images/branding/product/1x/gsa_512dp.png',
                                height: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Sign in with Google',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                  ),
                ),

                if (_isBiometricSupported) ...[
                  const SizedBox(height: 32),
                  IconButton(
                    icon: const Icon(Icons.fingerprint, color: primaryRed, size: 50),
                    onPressed: _handleBiometricLogin,
                  ),
                  const Text(
                    'Quick Login',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
