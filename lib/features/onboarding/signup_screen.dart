import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/routing/role_router.dart';
import '../../core/session/user_session.dart';
import '../../core/theme/colors.dart';
import '../../main.dart';
import 'signin_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  String? selectedGender;
  UserRole? selectedRole;
  String? registerError;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  Future<void> _register() async {
    final lang = appLanguage;
    FocusScope.of(context).unfocus();
    setState(() {
      registerError = null;
      _isLoading = true;
    });

    if (!_formKey.currentState!.validate()) {
      setState(() => _isLoading = false);
      return;
    }

    if (selectedGender == null) {
      setState(() {
        registerError = lang.text(
          en: "Please select your gender",
          ar: "يرجى اختيار الجنس",
        );
        _isLoading = false;
      });
      return;
    }

    if (selectedRole == null) {
      setState(() {
        registerError = lang.text(
          en: "Please select your role",
          ar: "يرجى اختيار الدور",
        );
        _isLoading = false;
      });
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      setState(() {
        registerError = lang.text(
          en: "Passwords do not match",
          ar: "كلمتا المرور غير متطابقتين",
        );
        _isLoading = false;
      });
      return;
    }

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = userCredential.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': nameController.text.trim(),
        'email': emailController.text.trim().toLowerCase(),
        'phone': phoneController.text.trim(),
        'age': ageController.text.trim(),
        'gender': selectedGender,
        'role': selectedRole!.name,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await UserSession.loadUserRole();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RoleRouter()),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        registerError = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    ageController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = appLanguage;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: Icon(
                  lang.isArabic
                      ? Icons.arrow_forward_ios_rounded
                      : Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textPrimary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),

              const SizedBox(height: 20),

              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.emergencyRed,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Center(
                child: Text(
                  lang.text(en: 'Create Account', ar: 'إنشاء حساب'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Center(
                child: Text(
                  lang.text(
                    en: 'Register your account and join the SEEN safety network.',
                    ar: 'سجّل حسابك وانضم إلى شبكة سلامة SEEN.',
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildInput(
                        context,
                        lang.text(en: "Full Name", ar: "الاسم الكامل"),
                        nameController,
                        hint: lang.text(
                          en: "Enter your full name",
                          ar: "أدخل اسمك الكامل",
                        ),
                      ),
                      _buildInput(
                        context,
                        lang.text(en: "Email", ar: "البريد الإلكتروني"),
                        emailController,
                        hint: "your@email.com",
                        keyboardType: TextInputType.emailAddress,
                        isEmail: true,
                      ),
                      _buildInput(
                        context,
                        lang.text(en: "Phone Number", ar: "رقم الهاتف"),
                        phoneController,
                        hint: "+966 5X XXX XXXX",
                        keyboardType: TextInputType.phone,
                      ),
                      _buildInput(
                        context,
                        lang.text(en: "Age", ar: "العمر"),
                        ageController,
                        hint: lang.text(
                          en: "Enter your age",
                          ar: "أدخل عمرك",
                        ),
                        keyboardType: TextInputType.number,
                      ),

                      _buildGenderSelection(context),
                      _buildRoleSelection(context),

                      _buildInput(
                        context,
                        lang.text(en: "Password", ar: "كلمة المرور"),
                        passwordController,
                        hint: "••••••••",
                        isPassword: true,
                        obscureText: _obscurePassword,
                        onToggleVisibility: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),

                      _buildInput(
                        context,
                        lang.text(
                          en: "Confirm Password",
                          ar: "تأكيد كلمة المرور",
                        ),
                        confirmPasswordController,
                        hint: "••••••••",
                        isPassword: true,
                        obscureText: _obscureConfirmPassword,
                        onToggleVisibility: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),

                      if (registerError != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.dangerSoft,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.emergencyRed.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            registerError!,
                            style: const TextStyle(
                              color: AppColors.emergencyRed,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  lang.text(
                                    en: "Create Account",
                                    ar: "إنشاء حساب",
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      lang.text(
                        en: "Already have an account? ",
                        ar: "لديك حساب بالفعل؟ ",
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignInScreen(),
                          ),
                        );
                      },
                      child: Text(
                        lang.text(en: "Sign In", ar: "تسجيل الدخول"),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(
    BuildContext context,
    String label,
    TextEditingController controller, {
    bool isPassword = false,
    bool isEmail = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType keyboardType = TextInputType.text,
    String? hint,
  }) {
    final theme = Theme.of(context);
    final lang = appLanguage;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: isPassword ? obscureText : false,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              suffixIcon: isPassword
                  ? IconButton(
                      onPressed: onToggleVisibility,
                      icon: Icon(
                        obscureText
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textSecondary,
                      ),
                    )
                  : null,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return lang.text(
                  en: "$label is required",
                  ar: "$label مطلوب",
                );
              }
              if (isEmail &&
                  !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                      .hasMatch(value)) {
                return lang.text(
                  en: "Enter a valid email",
                  ar: "أدخل بريدًا إلكترونيًا صالحًا",
                );
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGenderSelection(BuildContext context) {
    final lang = appLanguage;
    return _buildDropdown<String>(
      context: context,
      title: lang.text(en: "Gender", ar: "الجنس"),
      value: selectedGender,
      hint: lang.text(en: "Select", ar: "اختر"),
      items: [
        DropdownMenuItem(
          value: "Female",
          child: Text(lang.text(en: "Female", ar: "أنثى")),
        ),
        DropdownMenuItem(
          value: "Male",
          child: Text(lang.text(en: "Male", ar: "ذكر")),
        ),
      ],
      onChanged: (value) => setState(() => selectedGender = value),
    );
  }

  Widget _buildRoleSelection(BuildContext context) {
    final lang = appLanguage;
    return _buildDropdown<UserRole>(
      context: context,
      title: lang.text(en: "Role", ar: "الدور"),
      value: selectedRole,
      hint: lang.text(en: "Select", ar: "اختر"),
      items: [
        DropdownMenuItem(
          value: UserRole.vulnerableUser,
          child: Text(
            lang.text(en: "Vulnerable Individual", ar: "مستخدم ضعيف"),
          ),
        ),
        DropdownMenuItem(
          value: UserRole.emergencyContact,
          child: Text(
            lang.text(en: "Emergency Contact", ar: "جهة اتصال طوارئ"),
          ),
        ),
        DropdownMenuItem(
          value: UserRole.admin,
          child: Text(lang.text(en: "Admin", ar: "مدير")),
        ),
      ],
      onChanged: (value) => setState(() => selectedRole = value),
    );
  }

  Widget _buildDropdown<T>({
    required BuildContext context,
    required String title,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required Function(T?) onChanged,
    required String hint,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<T>(
            initialValue: value,
            items: items,
            onChanged: onChanged,
            dropdownColor: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary,
            ),
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }
}