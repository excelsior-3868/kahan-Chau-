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
  bool _isBiometricEnabledOnDevice = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
  }

  Future<void> _checkBiometricSupport() async {
    final enabled = await bioService.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _isBiometricEnabledOnDevice = enabled;
      });
      
      // Auto-trigger biometric if enabled
      if (enabled) {
        Future.delayed(const Duration(milliseconds: 500), _handleBiometricLogin);
      }
    }
  }

  Future<void> _handleBiometricLogin() async {
    final enabled = await bioService.isBiometricEnabled();
    if (!enabled) return;

    final token = await bioService.getToken();
    if (token == null) {
      if (mounted) setState(() => _isBiometricEnabledOnDevice = false);
      return;
    }

    final success = await bioService.authenticate();
    if (success) {
      setState(() => _isLoading = true);
      final error = await authService.signInWithToken(token);
      
      if (error != null) {
        _showStyledDialog('Session Error', 'Your session expired. Please log in with Google again.');
        if (mounted) setState(() => _isBiometricEnabledOnDevice = false);
      }
      if (mounted) setState(() => _isLoading = false);
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
                backgroundColor: const Color(0xFF0050A4),
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
    const primaryBlue = Color(0xFF0050A4);
    const bgColor = Color(0xFFF8F9FB); 

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: Image.asset(
                    'assets/app_icon-removebg-preview.png',
                    height: 180,
                    width: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.location_on, size: 100, color: primaryBlue),
                  ),
                ),
                const SizedBox(height: 40),
                
                const Text(
                  'कहाँ छौ ??',
                  style: TextStyle(
                    color: primaryBlue, 
                    fontSize: 36, 
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 80),

                if (_isBiometricEnabledOnDevice) ...[
                  // Biometric Toggle UI
                  Center(
                    child: Column(
                      children: [
                        InkWell(
                          onTap: _isLoading ? null : _handleBiometricLogin,
                          borderRadius: BorderRadius.circular(50),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: primaryBlue.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.fingerprint,
                              size: 80,
                              color: primaryBlue,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Tap the fingerprint icon to log in',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        const SizedBox(height: 48),
                        TextButton(
                          onPressed: () => setState(() => _isBiometricEnabledOnDevice = false),
                          child: const Text('Log in with Google Account instead', style: TextStyle(color: primaryBlue)),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Standard Google Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleGoogleAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const StadiumBorder(),
                        elevation: 2,
                      ),
                      child: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.network(
                                'https://www.gstatic.com/images/branding/product/1x/gsa_512dp.png',
                                height: 24,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Sign in with Google',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                    ),
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
