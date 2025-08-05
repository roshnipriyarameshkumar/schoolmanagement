import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StaffCreationScreen extends StatefulWidget {
  final String schoolId;
  final String role;

  const StaffCreationScreen({
    Key? key,
    required this.schoolId,
    required this.role,
  }) : super(key: key);

  @override
  State<StaffCreationScreen> createState() => _StaffCreationScreenState();
}

class _StaffCreationScreenState extends State<StaffCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _experienceController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  final _dobController = TextEditingController();
  final List<String> _selectedSubjects = [];
  String _gender = 'Male';
  bool _isLoading = false;

  // Blue Color Palette
  static const Color primaryBlue = Color(0xFF0F172A);      // Dark Blue
  static const Color secondaryBlue = Color(0xFF1E40AF);    // Royal Blue
  static const Color accentBlue = Color(0xFF3B82F6);       // Bright Blue
  static const Color lightBlue = Color(0xFF60A5FA);        // Light Blue
  static const Color paleBlue = Color(0xFF93C5FD);         // Pale Blue
  static const Color backgroundBlue = Color(0xFFEBF8FF);   // Very Light Blue
  static const Color surfaceBlue = Color(0xFFF0F9FF);      // Surface Blue

  final List<String> _subjects = [
    'Math', 'Science', 'English', 'History', 'Geography', 'Computer', 'Art'
  ];

  final List<String> _supportStaffRoles = [
    'Security',
    'Maintenance',
    'Cleaning',
    'Gardener',
    'Receptionist',
    'Office Assistant',
    'Library Assistant',
    'Transport Staff',
    'Lab Assistant',
    'Admin Room',
    'Groundskeeper',
  ];

  String? _selectedSubRole;
  String? _selectedSupportStaffRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundBlue,
      appBar: AppBar(
        title: Text(
          widget.role.toLowerCase() == 'staff'
              ? 'Create Staff'
              : 'Create ${widget.role}',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryBlue, secondaryBlue],
            ),
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: lightBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.admin_panel_settings, size: 16, color: Colors.white),
                SizedBox(width: 4),
                Text('Admin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primaryBlue,
              secondaryBlue,
              accentBlue,
              backgroundBlue,
            ],
            stops: [0.0, 0.2, 0.4, 0.8],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Animated Header Card
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, surfaceBlue],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: accentBlue.withOpacity(0.05),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                  border: Border.all(
                    color: paleBlue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accentBlue.withOpacity(0.1), lightBlue.withOpacity(0.1)],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: lightBlue.withOpacity(0.3), width: 2),
                      ),
                      child: Icon(
                        widget.role.toLowerCase() == 'teacher'
                            ? Icons.school_rounded
                            : widget.role.toLowerCase().contains('principal')
                            ? Icons.admin_panel_settings_rounded
                            : Icons.people_rounded,
                        size: 40,
                        color: secondaryBlue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [primaryBlue, secondaryBlue],
                      ).createShader(bounds),
                      child: const Text(
                        'Staff Registration Portal',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a comprehensive staff profile with detailed information',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: primaryBlue.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Enhanced Form Card
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, surfaceBlue],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withOpacity(0.08),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: secondaryBlue.withOpacity(0.05),
                      blurRadius: 50,
                      offset: const Offset(0, 20),
                    ),
                  ],
                  border: Border.all(
                    color: lightBlue.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Personal Information', Icons.person_rounded),
                      const SizedBox(height: 20),
                      _buildTextField(_nameController, 'Full Name', Icons.person_rounded),
                      _buildTextField(_emailController, 'Email', Icons.email_rounded, type: TextInputType.emailAddress),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(_dobController, 'Date of Birth (DD-MM-YYYY)', Icons.calendar_today_rounded)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildGenderDropdown()),
                        ],
                      ),
                      _buildTextField(_contactController, 'Contact Number', Icons.phone_rounded, type: TextInputType.phone),
                      _buildTextField(_addressController, 'Address', Icons.location_on_rounded),

                      const SizedBox(height: 32),
                      _buildSectionTitle('Professional Information', Icons.work_rounded),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(_experienceController, 'Years of Experience', Icons.timeline_rounded)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildTextField(_qualificationController, 'Qualification', Icons.school_rounded)),
                        ],
                      ),

                      if (widget.role.toLowerCase() == 'staff') ...[
                        const SizedBox(height: 20),
                        _buildSubRoleDropdown(),
                      ],

                      if (_selectedSubRole == 'Teacher' || widget.role.toLowerCase() == 'teacher') ...[
                        const SizedBox(height: 28),
                        _buildSubjectMultiSelect(),
                      ],

                      if (_selectedSubRole == 'Support Staff' || widget.role.toLowerCase() == 'support staff') ...[
                        const SizedBox(height: 20),
                        _buildSupportStaffRoleDropdown(),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Enhanced Submit Button
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: secondaryBlue.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createStaff,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                    padding: EdgeInsets.zero,
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _isLoading
                            ? [Colors.grey[400]!, Colors.grey[500]!]
                            : [secondaryBlue, accentBlue, lightBlue],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: _isLoading
                          ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Creating Account...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_circle_outline_rounded, size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Create Staff Account',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [secondaryBlue.withOpacity(0.1), accentBlue.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: lightBlue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: secondaryBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: secondaryBlue),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: primaryBlue,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String label,
      IconData icon, {
        TextInputType type = TextInputType.text,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: lightBlue.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextFormField(
          controller: controller,
          keyboardType: type,
          style: TextStyle(
            color: primaryBlue,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [lightBlue.withOpacity(0.2), paleBlue.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: secondaryBlue, size: 20),
            ),
            labelStyle: TextStyle(color: primaryBlue.withOpacity(0.7), fontWeight: FontWeight.w500),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: paleBlue.withOpacity(0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: secondaryBlue, width: 2.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: lightBlue.withOpacity(0.4)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            filled: true,
            fillColor: surfaceBlue,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          ),
          validator: (val) => val == null || val.isEmpty ? 'Enter $label' : null,
        ),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: lightBlue.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceBlue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: lightBlue.withOpacity(0.4)),
        ),
        child: DropdownButtonFormField<String>(
          value: _gender,
          decoration: InputDecoration(
            labelText: 'Gender',
            prefixIcon: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [lightBlue.withOpacity(0.2), paleBlue.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.wc_rounded, color: secondaryBlue, size: 20),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            labelStyle: TextStyle(color: primaryBlue.withOpacity(0.7), fontWeight: FontWeight.w500),
          ),
          dropdownColor: Colors.white,
          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w500, fontSize: 15),
          items: const [
            DropdownMenuItem(value: 'Male', child: Text('Male')),
            DropdownMenuItem(value: 'Female', child: Text('Female')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _gender = val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSubRoleDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: lightBlue.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceBlue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: lightBlue.withOpacity(0.4)),
        ),
        child: DropdownButtonFormField<String>(
          value: _selectedSubRole,
          decoration: InputDecoration(
            labelText: 'Select Sub Role',
            prefixIcon: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [lightBlue.withOpacity(0.2), paleBlue.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.work_outline_rounded, color: secondaryBlue, size: 20),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            labelStyle: TextStyle(color: primaryBlue.withOpacity(0.7), fontWeight: FontWeight.w500),
          ),
          dropdownColor: Colors.white,
          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w500, fontSize: 15),
          items: const [
            DropdownMenuItem(value: 'Teacher', child: Text('Teacher')),
            DropdownMenuItem(value: 'Support Staff', child: Text('Support Staff')),
          ],
          onChanged: (value) {
            setState(() {
              _selectedSubRole = value;
              _selectedSupportStaffRole = null;
              _selectedSubjects.clear();
            });
          },
          validator: (val) => val == null ? 'Select sub role' : null,
        ),
      ),
    );
  }

  Widget _buildSubjectMultiSelect() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accentBlue.withOpacity(0.1), lightBlue.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: lightBlue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.subject_rounded, size: 20, color: secondaryBlue),
              ),
              const SizedBox(width: 12),
              const Text(
                'Subjects Handled',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: primaryBlue,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [surfaceBlue, backgroundBlue.withOpacity(0.5)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: lightBlue.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: lightBlue.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _subjects.map((subject) {
              final isSelected = _selectedSubjects.contains(subject);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: FilterChip(
                  label: Text(
                    subject,
                    style: TextStyle(
                      color: isSelected ? Colors.white : secondaryBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _selectedSubjects.add(subject);
                      } else {
                        _selectedSubjects.remove(subject);
                      }
                    });
                  },
                  backgroundColor: Colors.white,
                  selectedColor: secondaryBlue,
                  checkmarkColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? secondaryBlue : lightBlue.withOpacity(0.5),
                    width: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: isSelected ? 4 : 1,
                  shadowColor: secondaryBlue.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSupportStaffRoleDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: lightBlue.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceBlue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: lightBlue.withOpacity(0.4)),
        ),
        child: DropdownButtonFormField<String>(
          value: _selectedSupportStaffRole,
          decoration: InputDecoration(
            labelText: 'Support Staff Role',
            prefixIcon: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [lightBlue.withOpacity(0.2), paleBlue.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.support_agent_rounded, color: secondaryBlue, size: 20),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            labelStyle: TextStyle(color: primaryBlue.withOpacity(0.7), fontWeight: FontWeight.w500),
          ),
          dropdownColor: Colors.white,
          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w500, fontSize: 15),
          items: _supportStaffRoles.map((role) {
            return DropdownMenuItem(value: role, child: Text(role));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedSupportStaffRole = value;
            });
          },
          validator: (val) {
            if (_selectedSubRole == 'Support Staff' && val == null) {
              return 'Select support staff role';
            }
            return null;
          },
        ),
      ),
    );
  }

  Future<void> _createStaff() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.role.toLowerCase() == 'staff' && _selectedSubRole == null) {
      _showSnackBar('Please select sub role', Colors.red[400]!, Icons.warning_rounded);
      return;
    }

    if (_selectedSubRole == 'Teacher' && _selectedSubjects.isEmpty) {
      _showSnackBar('Please select at least one subject', Colors.red[400]!, Icons.subject_rounded);
      return;
    }

    if (_selectedSubRole == 'Support Staff' && _selectedSupportStaffRole == null) {
      _showSnackBar('Please select support staff role', Colors.red[400]!, Icons.support_agent_rounded);
      return;
    }

    setState(() => _isLoading = true);

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final dob = _dobController.text.trim();
    final year = dob.split('-').last;
    final namePart = name.length >= 4 ? name.substring(0, 4).toUpperCase() : name.toUpperCase();
    final password = namePart + year;

    try {
      UserCredential userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final user = userCred.user;

      if (user == null) throw Exception("User creation failed");

      await user.sendEmailVerification();

      String collection;
      switch (widget.role.toLowerCase()) {
        case 'principal':
          collection = 'principal';
          break;
        case 'vice principal':
          collection = 'vice_principal';
          break;
        case 'support staff':
        case 'staff':
          collection = (_selectedSubRole?.toLowerCase() == 'support staff') ? 'supportstaff' : 'teachers';
          break;
        case 'teacher':
          collection = 'teachers';
          break;
        default:
          collection = 'staff';
          break;
      }

      final staffDoc = {
        'uid': user.uid,
        'email': email,
        'schoolId': widget.schoolId,
        'role': widget.role.toLowerCase() == 'staff'
            ? _selectedSubRole ?? 'Staff'
            : widget.role,
        'createdAt': Timestamp.now(),
        'classTeacher': null,
        'classesAssigned': [],
        'subjectsAssigned': [],
        'meta': {
          'name': name,
          'experience': _experienceController.text.trim(),
          'qualification': _qualificationController.text.trim(),
          'gender': _gender,
          'contact': _contactController.text.trim(),
          'address': _addressController.text.trim(),
          'dob': dob,
          'password': password,
          if (_selectedSubRole == 'Support Staff' || widget.role.toLowerCase() == 'support staff')
            'supportStaffRole': _selectedSupportStaffRole ?? '',
          if (_selectedSubRole == 'Teacher' || widget.role.toLowerCase() == 'teacher')
            'subjects': _selectedSubjects,
        }
      };

      // Save to main collection ONLY (removed school subcollection save)
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(user.uid)
          .set(staffDoc);

      // ✅ ONLY append to staffIds array in school's main document (NO subcollection creation)
      await FirebaseFirestore.instance.collection('schools').doc(widget.schoolId).update({
        'staffIds': FieldValue.arrayUnion([
          {
            'uid': user.uid,
            'role': widget.role.toLowerCase() == 'staff'
                ? _selectedSubRole ?? 'Staff'
                : widget.role,
          }
        ])
      });

      setState(() => _isLoading = false);

      _showSnackBar(
        '${widget.role} account created successfully. Password is "$password".',
        Colors.green,
        Icons.check_circle_rounded,
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar(
        e.message ?? 'Account creation failed',
        Colors.red[400]!,
        Icons.error_outline_rounded,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar(
        'Something went wrong. Please try again.',
        Colors.red[400]!,
        Icons.error_outline_rounded,
      );
    }
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _experienceController.dispose();
    _qualificationController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    super.dispose();
  }
}