import 'package:flutter/material.dart';
import 'package:linktinger_app/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final specialtyController =
      TextEditingController(); // ← أضفنا هذا لحقل التخصص
  final passController = TextEditingController();
  final confirmPassController = TextEditingController();

  bool isLoading = false;
  bool obscurePass = true;
  bool obscureConfirm = true;

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> registerUser() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final specialty = specialtyController.text.trim(); // ← جلب التخصص
    final password = passController.text.trim();
    final confirmPassword = confirmPassController.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        specialty.isEmpty || // ← تحقق من وجود التخصص
        password.isEmpty ||
        confirmPassword.isEmpty) {
      showMessage("All fields are required");
      return;
    }

    if (password != confirmPassword) {
      showMessage("Passwords do not match");
      return;
    }

    setState(() => isLoading = true);

    final result = await AuthService.registerUser(
      username: name,
      email: email,
      specialty: specialty, // ← إرسال التخصص للخدمة
      password: password,
    );

    if (!mounted) return;

    if (result['status'] == 'success') {
      showMessage("Account created successfully!");
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      showMessage(result['message'] ?? 'Signup failed');
    }

    setState(() => isLoading = false);
  }

  InputDecoration buildInputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white.withAlpha(230),
      prefixIcon: Icon(icon, color: Colors.grey[600]),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      hintText: hint,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/splash_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Welcome",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Create Account to keep exploring amazing destinations around the world!",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: nameController,
                      decoration: buildInputDecoration(
                        hint: "Enter your full name",
                        icon: Icons.person,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: buildInputDecoration(
                        hint: "Enter your email address",
                        icon: Icons.email,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: specialtyController, // ← حقل التخصص
                      decoration: buildInputDecoration(
                        hint: "Enter your specialty",
                        icon: Icons.work_outline,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passController,
                      obscureText: obscurePass,
                      decoration: buildInputDecoration(
                        hint: "Enter password",
                        icon: Icons.lock,
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePass
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() => obscurePass = !obscurePass);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPassController,
                      obscureText: obscureConfirm,
                      decoration: buildInputDecoration(
                        hint: "Confirm password",
                        icon: Icons.lock,
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() => obscureConfirm = !obscureConfirm);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: isLoading ? null : registerUser,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      icon: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.arrow_forward),
                      label: Text(isLoading ? "Creating..." : "Create Account"),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        child: const Text("Already have an account? Sign in"),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text.rich(
                        TextSpan(
                          text: "By creating an account, you agree to our ",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                          children: [
                            const TextSpan(
                              text: "Terms & Conditions",
                              style: TextStyle(color: Colors.blue),
                            ),
                            const TextSpan(text: " and "),
                            const TextSpan(
                              text: "Privacy Policy",
                              style: TextStyle(color: Colors.blue),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
