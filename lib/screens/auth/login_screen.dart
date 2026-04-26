import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../utils/app_colors.dart';
import '../student/hostel_list_screen.dart';
import '../admin/admin_dashboard.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_button.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _loginUser() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      debugPrint("🟡 Attempting login...");

      User? user = await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      debugPrint("🟢 Login complete. User: ${user?.uid}");

      if (user == null) {
        throw Exception("Login failed");
      }

      if (!mounted) return;

      // ✅ FIXED: Better error handling for Firestore check
      debugPrint("📄 Fetching user document...");

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      debugPrint("📄 User document exists: ${userDoc.exists}");

      if (!userDoc.exists) {
        debugPrint("⚠️ User document not found in Firestore!");
        if (!mounted) return;

        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User profile not found. Please sign up again.'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      final userData = userDoc.data();
      debugPrint("📄 User data: $userData");

      // ✅ FIXED: More robust admin check
      final isAdmin = userData?['isAdmin'] == true;

      debugPrint("👤 isAdmin value: $isAdmin (Type: ${userData?['isAdmin'].runtimeType})");
      debugPrint("🚀 Navigating to ${isAdmin ? 'Admin' : 'Student'} screen...");

      // Navigate based on role
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => isAdmin
              ? const AdminDashboard()
              : const HostelListScreen(),
        ),
      );
    } catch (e) {
      debugPrint("🔴 Login error: $e");

      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                Text(
                  "Welcome Back! 👋",
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Login to continue",
                  style: TextStyle(
                    color: AppColors.textDark.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 40),
                CustomTextField(
                  controller: _emailController,
                  hintText: "Email",
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: _passwordController,
                  hintText: "Password",
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                CustomButton(
                  text: _isLoading ? "Logging in..." : "Login",
                  onPressed: _isLoading ? null : _loginUser,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: TextStyle(color: AppColors.textDark),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignupScreen(),
                          ),
                        );
                      },
                      child: Text(
                        "Sign Up",
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}