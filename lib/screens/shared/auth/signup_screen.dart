import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../viewmodel/auth/signup_view_model.dart';
import '../../../widgets/custom_loading_indicator.dart';
import 'login_screen.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SignupViewModel(),
      child: Scaffold(
        appBar: AppBar(
          title: Consumer<SignupViewModel>(
            builder: (context, vm, _) => Text(
              vm.signupType == SignupType.user
                  ? 'Create User Account'
                  : 'Driver Registration',
              style: TextStyle(color: Theme.of(context).textTheme.titleSmall!.color),
            ),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Consumer<SignupViewModel>(
                builder: (context, viewModel, child) {
                  final theme = Theme.of(context);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildUserTypeToggle(context, viewModel),
                      const SizedBox(height: 30),
                      _buildInputField(
                        controller: viewModel.firstNameController,
                        label: 'First Name',
                        hint: 'Enter your first name',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 20),
                      _buildInputField(
                        controller: viewModel.lastNameController,
                        label: 'Last Name',
                        hint: 'Enter your last name',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 20),
                      _buildInputField(
                        controller: viewModel.emailController,
                        label: 'Email Address',
                        hint: 'Enter your email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      _buildInputField(
                        controller: viewModel.phoneController,
                        label: 'Phone Number',
                        hint: 'Enter your phone number',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 20),
                      _buildInputField(
                        viewModel: viewModel,
                        controller: viewModel.passwordController,
                        label: 'Password',
                        hint: 'Enter your password',
                        icon: Icons.lock_outline,
                        isPassword: true,
                      ),
                      const SizedBox(height: 20),
                      _buildInputField(
                        viewModel: viewModel,
                        controller: viewModel.confirmPasswordController,
                        label: 'Confirm Password',
                        hint: 'Confirm your password',
                        icon: Icons.lock_outline,
                        isPassword: true,
                      ),

                      if (viewModel.signupType == SignupType.driver)
                        _buildLicenseUploader(context, viewModel),

                      const SizedBox(height: 40),
                      const SizedBox(height: 40),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: viewModel.isLoading ? null : () => viewModel.signUp(context),
                        child: viewModel.isLoading
                            ? const CustomLoadingIndicator(size: 24)
                            : const Text('SIGN UP', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 25),
                      _buildSignInPrompt(context, theme),
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

  Widget _buildInputField({
    SignupViewModel? viewModel,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: isPassword && (viewModel?.isPasswordVisible == false),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            suffixIcon: isPassword
                ? IconButton(
              icon: Icon(
                viewModel!.isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
              ),
              onPressed: viewModel.togglePasswordVisibility,
            )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSignInPrompt(BuildContext context, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Already have an account? ", style: theme.textTheme.bodyMedium),
        GestureDetector(
          onTap: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
          child: Text(
            "Sign In",
            style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
  Widget _buildLicenseUploader(BuildContext context, SignupViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16,),
        Text(
          'Driving Credentials',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  viewModel.selectedLicenseFile?.path.split('/').last ?? 'No file selected',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: viewModel.selectedLicenseFile != null
                        ? Theme.of(context).textTheme.bodyLarge?.color
                        : Colors.grey,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: viewModel.pickLicense,
                icon: const Icon(Icons.upload_file),
                label: const Text('Select'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
  // Place this inside the SignupScreen class
  Widget _buildUserTypeToggle(BuildContext context, SignupViewModel viewModel) {
    final theme = Theme.of(context);
    final isUser = viewModel.signupType == SignupType.user;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildToggleButton(
          theme: theme,
          text: "User",
          isSelected: isUser,
          onPressed: () => viewModel.setSignupType(SignupType.user),
        ),
        const SizedBox(width: 15),
        _buildToggleButton(
          theme: theme,
          text: "Driver",
          isSelected: !isUser,
          onPressed: () => viewModel.setSignupType(SignupType.driver),
        ),
      ],
    );
  }

// This is a private helper method for the toggle button itself
  Widget _buildToggleButton({
    required ThemeData theme,
    required String text,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    // This color is designed to be placed ON the primary color, ensuring readability.
    final Color selectedTextColor = theme.colorScheme.onPrimary;

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 40),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor : theme.colorScheme.surface,
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
}