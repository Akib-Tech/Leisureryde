import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../viewmodel/auth/login_view_model.dart';
import '../../../widgets/custom_loading_indicator.dart';
import 'signup_screen.dart';


class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginViewModel(),
      child: Scaffold(
        // The Scaffold's background color is now automatically handled by the theme.
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Consumer<LoginViewModel>(
                builder: (context, viewModel, child) {
                  final theme = Theme.of(context);
                  final isUser = viewModel.loginType == LoginType.user;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "LeisureRyde",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontFamily: "Monospace",
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        isUser ? "Sign-In as User" : "Driver Sign-In",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          // Color is now inherited from the theme's text style
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildUserTypeToggle(context, viewModel),
                      const SizedBox(height: 30),

                      // Email Field
                      Text('Email Address', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      _buildInputField(
                        viewModel: viewModel,
                        controller: viewModel.emailController,
                        hint: 'Enter your email',
                        icon: Icons.email,
                      ),
                      const SizedBox(height: 20),

                      // Password Field
                      Text('Password', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      _buildInputField(
                        viewModel: viewModel,
                        controller: viewModel.passwordController,
                        hint: 'Enter your password',
                        icon: Icons.lock,
                        isPassword: true,
                      ),
                      const SizedBox(height: 30),

                      // Login Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: viewModel.isLoading ? null : () => viewModel.signIn(context),
                        child: viewModel.isLoading
                            ? const CustomLoadingIndicator(size: 24)
                            : const Text('LOGIN', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 25),

                      // Sign Up prompt
                      _buildSignUpPrompt(context, theme, isUser),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserTypeToggle(BuildContext context, LoginViewModel viewModel) {
    final theme = Theme.of(context);
    final isUser = viewModel.loginType == LoginType.user;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildToggleButton(theme, "User", isUser, () => viewModel.setLoginType(LoginType.user)),
        const SizedBox(width: 15),
        _buildToggleButton(theme, "Driver", !isUser, () => viewModel.setLoginType(LoginType.driver)),
      ],
    );
  }

  Widget _buildToggleButton(ThemeData theme, String text, bool isSelected, VoidCallback onPressed) {
    // This color is designed to be placed ON the primary color, ensuring readability.
    final Color selectedTextColor = theme.colorScheme.onPrimary;

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 40),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: theme.primaryColor, width: 1.5),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? selectedTextColor : theme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required LoginViewModel viewModel,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    // The InputDecoration now fully relies on the `InputDecorationTheme`
    // defined in `app_theme.dart` for its styling.
    return TextField(
      controller: controller,
      obscureText: isPassword && !viewModel.isPasswordVisible,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon), // Icon color is handled by theme
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            viewModel.isPasswordVisible ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
          ),
          onPressed: viewModel.togglePasswordVisibility,
        )
            : null,
      ),
    );
  }

  Widget _buildSignUpPrompt(BuildContext context, ThemeData theme, bool isUser) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don’t have an account? ",
          style: theme.textTheme.bodyMedium,
        ),
        GestureDetector(
          onTap: () {

            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>SignupScreen()));
          },
          child: Text(
            "Sign Up",
            style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}