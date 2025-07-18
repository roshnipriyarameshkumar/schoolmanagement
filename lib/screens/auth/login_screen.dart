import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../super_admin/super_admin_dashboard.dart';

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _selectedRole;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<Map<String, String>> _roles = [
    {'display': 'Super Admin', 'value': 'superadmin'},
    {'display': 'Principal', 'value': 'principal'},
    {'display': 'Teacher', 'value': 'teacher'},
    {'display': 'Student', 'value': 'student'},
    {'display': 'Support Staff', 'value': 'support_staff'},
  ];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeOutCubic),
    );

    _animationController?.forward();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user;
      if (user == null) {
        setState(() => _errorMessage = 'User authentication failed.');
        return;
      }

      if (!user.emailVerified) {
        await _auth.signOut();
        setState(() => _errorMessage = 'Please verify your email before logging in.');
        return;
      }

      String selectedRoleValue = _roles.firstWhere(
            (role) => role['display'] == _selectedRole,
        orElse: () => {'value': ''},
      )['value'] ?? '';

      if (selectedRoleValue.isEmpty) {
        setState(() => _errorMessage = 'Please select a role.');
        return;
      }

      final userDoc = await _firestore.collection(selectedRoleValue).doc(user.uid).get();

      if (!userDoc.exists) {
        await _auth.signOut();
        setState(() => _errorMessage = 'User not found in $selectedRoleValue collection.');
        return;
      }

      final userData = userDoc.data();
      if (userData == null || userData['role'] != selectedRoleValue) {
        await _auth.signOut();
        setState(() => _errorMessage =
        'Role mismatch: your account role is "${userData?['role']}", but you selected "$selectedRoleValue".');
        return;
      }

      if (selectedRoleValue == 'superadmin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => SuperAdminDashboard()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email address.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address format.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many attempts. Try again later.';
          break;
        default:
          errorMessage = e.message ?? 'Authentication failed.';
      }
      setState(() => _errorMessage = errorMessage);
    } catch (e) {
      setState(() => _errorMessage = 'Unexpected error: ${e.toString()}');
      print("Login error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Color(0xFF667EEA)),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: (_fadeAnimation != null && _slideAnimation != null)
                  ? FadeTransition(
                opacity: _fadeAnimation!,
                child: SlideTransition(
                  position: _slideAnimation!,
                  child: _buildCardForm(),
                ),
              )
                  : _buildCardForm(), // fallback
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardForm() {
    return Container(
      constraints: BoxConstraints(maxWidth: 400),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Icon(Icons.school_rounded, size: 60, color: Color(0xFF667EEA)),
                SizedBox(height: 20),
                Text("Welcome Back", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text("Sign in to access your dashboard", style: TextStyle(fontSize: 16)),
                SizedBox(height: 32),

                /// Role Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  items: _roles.map((role) {
                    return DropdownMenuItem(
                      value: role['display'],
                      child: Text(role['display']!),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedRole = val),
                  decoration: InputDecoration(
                    labelText: 'Select Role',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  validator: (val) => val == null ? 'Please select a role' : null,
                ),
                SizedBox(height: 20),

                /// Email
                _buildTextField(
                  label: 'Email',
                  icon: Icons.email,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Enter your email';
                    if (!val.contains('@')) return 'Enter valid email';
                    return null;
                  },
                ),

                /// Password
                _buildTextField(
                  label: 'Password',
                  icon: Icons.lock,
                  controller: _passwordController,
                  obscure: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      color: Color(0xFF667EEA),
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (val) =>
                  (val == null || val.length < 6) ? 'Enter 6+ char password' : null,
                ),

                /// Error
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),

                SizedBox(height: 20),

                /// Sign In Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF667EEA),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text("Sign In"),
                  ),
                ),

                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/signup');
                  },
                  child: Text("Don't have an account? Create Super Admin Account"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
