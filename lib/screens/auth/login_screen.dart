import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../super_admin/super_admin_dashboard.dart';
import '../principal/principal_dashboard.dart';
import '../teacher/teacher_dashboard.dart';
import '../student/student_dashboard.dart';
import '../support_staff/dashboard.dart'; // adjust the path as needed


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

  // Fixed the roles array to match Firebase collections and expected values
  final List<Map<String, String>> _roles = [
    {'display': 'Super Admin', 'value': 'superadmin'},
    {'display': 'Principal', 'value': 'principal'},
    {'display': 'Teachers', 'value': 'teachers'},
    {'display': 'Students', 'value': 'students'}, // Fixed: changed to 'students' to match collection
    {'display': 'Support Staff', 'value': 'supportstaff'},
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

  Future<void> signIn() async {
    if (!_formKey.currentState!.validate()) return;

    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    setState(() {
      _errorMessage = '';
    });

    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final User? user = userCredential.user;
      if (user == null) {
        setState(() => _errorMessage = 'Authentication failed');
        return;
      }

      // Get the role value from the selected display name
      String selectedRoleValue = '';
      for (var role in _roles) {
        if (role['display'] == _selectedRole) {
          selectedRoleValue = role['value']!;
          break;
        }
      }

      if (selectedRoleValue.isEmpty) {
        setState(() => _errorMessage = 'Please select a role');
        return;
      }

      // 🔍 Fetch user document from Firestore
      DocumentSnapshot? userDoc;

      if (selectedRoleValue == 'students') {
        // Students: UID is used directly as document ID
        final doc = await _firestore.collection('students').doc(user.uid).get();
        if (!doc.exists) {
          setState(() => _errorMessage = 'Student not found in students collection');
          return;
        }
        userDoc = doc;
      } else {
        // All other roles: try where uid == user.uid first
        final querySnapshot = await _firestore
            .collection(selectedRoleValue)
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          userDoc = querySnapshot.docs.first;
        } else {
          // Fallback: check if UID is doc ID
          final fallbackDoc = await _firestore
              .collection(selectedRoleValue)
              .doc(user.uid)
              .get();
          if (fallbackDoc.exists) {
            userDoc = fallbackDoc;
          } else if (selectedRoleValue == 'supportstaff') {
            // Special case for support staff: try finding by email
            final emailQuerySnapshot = await _firestore
                .collection(selectedRoleValue)
                .where('email', isEqualTo: user.email)
                .limit(1)
                .get();
            if (emailQuerySnapshot.docs.isNotEmpty) {
              userDoc = emailQuerySnapshot.docs.first;
            }
          }
        }

        if (userDoc == null || !userDoc.exists) {
          setState(() => _errorMessage = 'User not found in $selectedRoleValue collection');
          return;
        }
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      // Role verification - more flexible role checking
      String userRole = (userData['role'] as String?)?.toLowerCase().trim() ?? '';

      // Debug: Print the actual role value found
      print('User role from Firebase: "$userRole"');
      print('Expected role: "$selectedRoleValue"');

      // Enhanced role matching logic
      bool roleMatches = false;

      if (selectedRoleValue == 'students') {
        // If user is in students collection, assume they are a student
        // Check role field only if it exists and is not empty
        if (userRole.isEmpty) {
          roleMatches = true; // Allow empty role for students collection
        } else {
          roleMatches = (userRole == 'student' || userRole == 'students');
        }
      } else if (selectedRoleValue == 'teachers') {
        // For teachers, accept both 'teacher' and 'teachers'
        roleMatches = (userRole == 'teacher' || userRole == 'teachers');
      } else if (selectedRoleValue == 'superadmin') {
        // For superadmin, accept variations
        roleMatches = (userRole == 'superadmin' || userRole == 'super_admin' || userRole == 'super admin');
      } else if (selectedRoleValue == 'principal') {
        // For principal, exact match
        roleMatches = (userRole == 'principal');
      } else if (selectedRoleValue == 'supportstaff') {
        // For support staff, accept variations (userRole is already lowercase)
        // Handle "Support Staff" with capital letters and space
        roleMatches = (userRole == 'supportstaff' ||
            userRole == 'support staff' ||
            userRole == 'supportstaff' ||
            userRole == 'support_staff');
      } else {
        // Default: exact match
        roleMatches = (userRole == selectedRoleValue);
      }

      if (!roleMatches) {
        setState(() => _errorMessage = 'Role mismatch. Expected: $selectedRoleValue, Found: "$userRole"');
        return;
      }

      // ✅ Navigate to respective dashboard
      switch (selectedRoleValue) {
        case 'superadmin':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => SuperAdminDashboard()),
          );
          break;
        case 'principal':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => PrincipalDashboard(principalId: user.uid)),
          );
          break;
        case 'teachers':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => TeacherProfileScreen(teacherId: user.uid)),
          );
          break;
        case 'students': // Fixed: changed from 'student' to 'students'
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => StudentDashboard(studentId: user.uid)),
          );
          break;
        case 'supportstaff':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => SupportStaffDashboard(supportStaffId: user.uid)),
          );
          break;
        default:
          setState(() => _errorMessage = 'Dashboard not implemented for $selectedRoleValue');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Login failed: ${e.toString()}';
      });
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
                  : _buildCardForm(),
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

                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),

                SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () async {
                      setState(() => _isLoading = true);
                      await signIn();
                      setState(() => _isLoading = false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF667EEA),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text("Sign In", style: TextStyle(color: Colors.white)),
                  ),
                ),

                SizedBox(height: 16),

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