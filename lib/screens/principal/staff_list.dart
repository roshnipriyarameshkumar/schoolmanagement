import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StaffListScreen extends StatefulWidget {
  final String schoolId;
  const StaffListScreen({Key? key, required this.schoolId}) : super(key: key);

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> with TickerProviderStateMixin {
  // Professional Blue Color Palette (matching AddAnnouncementScreen)
  static const Color primaryBlue = Color(0xFF0F172A);      // Dark Blue
  static const Color secondaryBlue = Color(0xFF1E40AF);    // Royal Blue
  static const Color accentBlue = Color(0xFF3B82F6);       // Bright Blue
  static const Color lightBlue = Color(0xFF60A5FA);        // Light Blue
  static const Color paleBlue = Color(0xFF93C5FD);         // Pale Blue
  static const Color backgroundBlue = Color(0xFFEBF8FF);   // Very Light Blue
  static const Color surfaceBlue = Color(0xFFF0F9FF);      // Surface Blue

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _confirmDelete(String uid, String collection) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_rounded, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Confirm Delete',
              style: TextStyle(
                color: primaryBlue,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this staff member?',
          style: TextStyle(
            color: primaryBlue,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: primaryBlue.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance.collection(collection).doc(uid).delete();
              await FirebaseFirestore.instance.collection('schools').doc(widget.schoolId).update({
                'staffIds': FieldValue.arrayRemove([{'uid': uid}])
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToAddStaff(String collection, String role) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StaffCreationScreen(
          schoolId: widget.schoolId,
          role: role,
        ),
      ),
    );
  }

  void _navigateToEditStaff(String collection, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StaffCreationScreen(
          schoolId: widget.schoolId,
          role: data['role'] ?? 'staff',
          isEdit: true,
          staffData: data,
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required IconData icon, required int count}) {
    return Container(
      padding: const EdgeInsets.all(20),
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
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: paleBlue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentBlue.withOpacity(0.1), lightBlue.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: lightBlue.withOpacity(0.3)),
            ),
            child: Icon(icon, color: accentBlue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: primaryBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count ${count == 1 ? 'member' : 'members'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: primaryBlue.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: lightBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: lightBlue.withOpacity(0.3)),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: secondaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffCard(Map<String, dynamic> data, String collection) {
    final meta = data['meta'] ?? {};
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, surfaceBlue],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: paleBlue.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentBlue.withOpacity(0.2), lightBlue.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: lightBlue.withOpacity(0.3)),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: secondaryBlue,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meta['name'] ?? 'No name',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['role'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: accentBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['email'] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: primaryBlue.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (meta['subjects'] != null && (meta['subjects'] as List).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: (meta['subjects'] as List).take(2).map<Widget>((subject) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: lightBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: lightBlue.withOpacity(0.3)),
                          ),
                          child: Text(
                            subject,
                            style: const TextStyle(
                              fontSize: 10,
                              color: secondaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  if (meta['supportStaffRole'] != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Text(
                        meta['supportStaffRole'],
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
                    onPressed: () => _navigateToEditStaff(collection, data),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 20),
                    onPressed: () => _confirmDelete(data['uid'], collection),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(String collection, String role) {
    return Container(
      width: double.infinity,
      height: 56,
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [accentBlue, lightBlue],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accentBlue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => _navigateToAddStaff(collection, role),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, size: 22, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Add ${role == 'teacher' ? 'Teacher' : 'Support Staff'}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildList(String title, String collection, IconData icon) {
    final isTeacher = collection == 'teachers';
    final role = isTeacher ? 'teacher' : 'support staff';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
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
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: paleBlue.withOpacity(0.3)),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(collection)
            .where('schoolId', isEqualTo: widget.schoolId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildSectionHeader(title: title, icon: icon, count: 0),
                  const SizedBox(height: 20),
                  const Center(
                    child: CircularProgressIndicator(
                      color: accentBlue,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(title: title, icon: icon, count: docs.length),
                const SizedBox(height: 24),
                if (docs.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: surfaceBlue.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: paleBlue.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 48,
                          color: primaryBlue.withOpacity(0.4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No ${title.toLowerCase()} found',
                          style: TextStyle(
                            fontSize: 16,
                            color: primaryBlue.withOpacity(0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first ${role} to get started',
                          style: TextStyle(
                            fontSize: 14,
                            color: primaryBlue.withOpacity(0.5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildStaffCard(data, collection);
                  }).toList(),
                _buildAddButton(collection, role),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundBlue,
      appBar: AppBar(
        title: const Text(
          "Staff Management",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            letterSpacing: 0.5,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryBlue,
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
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people, size: 16, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'Staff',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
                ),
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
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Section
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
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
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [accentBlue.withOpacity(0.1), lightBlue.withOpacity(0.1)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: lightBlue.withOpacity(0.3), width: 2),
                                ),
                                child: const Icon(Icons.groups_rounded, size: 32, color: secondaryBlue),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Staff Management',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: primaryBlue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Manage your school teaching and support staff',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: primaryBlue.withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        buildList("Teaching Staff", "teachers", Icons.school_rounded),
                        buildList("Support Staff", "supportstaff", Icons.support_agent_rounded),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Keep the existing StaffCreationScreen class unchanged
class StaffCreationScreen extends StatefulWidget {
  final String schoolId;
  final String role;
  final bool isEdit;
  final Map<String, dynamic>? staffData;

  const StaffCreationScreen({
    Key? key,
    required this.schoolId,
    required this.role,
    this.isEdit = false,
    this.staffData,
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
  static const Color primaryBlue = Color(0xFF0F172A);
  static const Color secondaryBlue = Color(0xFF1E40AF);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color lightBlue = Color(0xFF60A5FA);
  static const Color paleBlue = Color(0xFF93C5FD);
  static const Color backgroundBlue = Color(0xFFEBF8FF);
  static const Color surfaceBlue = Color(0xFFF0F9FF);

  final List<String> _subjects = [
    'Mathematics', 'Physics', 'Chemistry', 'Biology', 'English', 'Hindi', 'Tamil',
    'Social Science', 'History', 'Geography', 'Computer Science', 'Physical Education',
    'Art', 'Music', 'Commerce', 'Economics', 'Accountancy', 'Business Studies'
  ];

  final List<String> _supportStaffRoles = [
    'Security Guard',
    'Maintenance Staff',
    'Cleaning Staff',
    'Gardener',
    'Receptionist',
    'Office Assistant',
    'Library Assistant',
    'Transport Staff',
    'Lab Assistant',
    'Admin Room Staff',
    'Groundskeeper',
    'Canteen Staff',
    'IT Support',
    'Nurse',
    'Counselor'
  ];

  String? _selectedSubRole;
  String? _selectedSupportStaffRole;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit && widget.staffData != null) {
      _loadStaffData();
    }
    _setInitialRole();
  }

  void _setInitialRole() {
    if (widget.role.toLowerCase() == 'teacher') {
      _selectedSubRole = 'Teacher';
    } else if (widget.role.toLowerCase() == 'support staff') {
      _selectedSubRole = 'Support Staff';
    }
  }

  void _loadStaffData() {
    final data = widget.staffData!;
    final meta = data['meta'] ?? {};

    _nameController.text = meta['name'] ?? '';
    _emailController.text = data['email'] ?? '';
    _experienceController.text = meta['experience'] ?? '';
    _qualificationController.text = meta['qualification'] ?? '';
    _contactController.text = meta['contact'] ?? '';
    _addressController.text = meta['address'] ?? '';
    _dobController.text = meta['dob'] ?? '';
    _gender = meta['gender'] ?? 'Male';

    if (meta['subjects'] != null) {
      _selectedSubjects.addAll(List<String>.from(meta['subjects']));
    }

    if (meta['supportStaffRole'] != null) {
      _selectedSupportStaffRole = meta['supportStaffRole'];
    }

    // Set role based on data
    final role = data['role']?.toString().toLowerCase();
    if (role == 'teacher') {
      _selectedSubRole = 'Teacher';
    } else if (role == 'support staff' || _selectedSupportStaffRole != null) {
      _selectedSubRole = 'Support Staff';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundBlue,
      appBar: AppBar(
        title: Text(
          widget.isEdit
              ? 'Edit ${widget.role.toUpperCase()}'
              : 'Create ${widget.role.toUpperCase()}',
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
              // Header Card
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
                      child: Text(
                        widget.isEdit ? 'Staff Update Portal' : 'Staff Registration Portal',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isEdit
                          ? 'Update staff profile with detailed information'
                          : 'Create a comprehensive staff profile with detailed information',
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

              // Form Card
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
                      _buildTextField(_emailController, 'Email', Icons.email_rounded,
                          type: TextInputType.emailAddress, enabled: !widget.isEdit),
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

              // Submit Button
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
                  onPressed: _isLoading ? null : _submitStaff,
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
                        children: [
                          const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            widget.isEdit ? 'Updating...' : 'Creating Account...',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(widget.isEdit ? Icons.update_rounded : Icons.add_circle_outline_rounded, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            widget.isEdit ? 'Update Staff Account' : 'Create Staff Account',
                            style: const TextStyle(
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
        bool enabled = true,
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
          enabled: enabled,
          style: TextStyle(
            color: enabled ? primaryBlue : Colors.grey,
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
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            filled: true,
            fillColor: enabled ? surfaceBlue : Colors.grey[100],
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
          style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w500, fontSize: 15),
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
          style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w500, fontSize: 15),
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
                'Subjects Specialization',
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
          style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w500, fontSize: 15),
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

  Future<void> _submitStaff() async {
    if (!_formKey.currentState!.validate()) return;

    // Validation for staff role
    if (widget.role.toLowerCase() == 'staff' && _selectedSubRole == null) {
      _showSnackBar('Please select sub role', Colors.red[400]!, Icons.warning_rounded);
      return;
    }

    // Validation for teacher subjects
    if ((_selectedSubRole == 'Teacher' || widget.role.toLowerCase() == 'teacher') && _selectedSubjects.isEmpty) {
      _showSnackBar('Please select at least one subject', Colors.red[400]!, Icons.subject_rounded);
      return;
    }

    // Validation for support staff role
    if ((_selectedSubRole == 'Support Staff' || widget.role.toLowerCase() == 'support staff') && _selectedSupportStaffRole == null) {
      _showSnackBar('Please select support staff role', Colors.red[400]!, Icons.support_agent_rounded);
      return;
    }

    setState(() => _isLoading = true);

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final dob = _dobController.text.trim();

    try {
      if (widget.isEdit) {
        await _updateStaff();
      } else {
        await _createNewStaff();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar(
        'Error: ${e.toString()}',
        Colors.red[400]!,
        Icons.error_outline_rounded,
      );
    }
  }

  Future<void> _createNewStaff() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final dob = _dobController.text.trim();

    // Generate password
    final year = dob.split('-').last;
    final namePart = name.length >= 4 ? name.substring(0, 4).toUpperCase() : name.toUpperCase();
    final password = namePart + year;

    try {
      // Create Firebase Auth user
      UserCredential userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final user = userCred.user;

      if (user == null) throw Exception("User creation failed");

      // Send email verification
      await user.sendEmailVerification();

      // Determine collection based on role
      String collection = _getCollectionName();
      String finalRole = _getFinalRole();

      // Create staff document
      final staffDoc = {
        'uid': user.uid,
        'email': email,
        'schoolId': widget.schoolId,
        'role': finalRole,
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

      // Save to Firestore collection
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(user.uid)
          .set(staffDoc);

      // Update school's staffIds array
      await FirebaseFirestore.instance.collection('schools').doc(widget.schoolId).update({
        'staffIds': FieldValue.arrayUnion([
          {
            'uid': user.uid,
            'role': finalRole,
          }
        ])
      });

      setState(() => _isLoading = false);

      _showSnackBar(
        'Staff account created successfully! Password: "$password"',
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
    }
  }

  Future<void> _updateStaff() async {
    final staffData = widget.staffData!;
    final uid = staffData['uid'];

    // Determine collection
    String collection = _getCollectionName();
    String finalRole = _getFinalRole();

    // Update staff document
    final updatedDoc = {
      'uid': uid,
      'email': _emailController.text.trim(),
      'schoolId': widget.schoolId,
      'role': finalRole,
      'updatedAt': Timestamp.now(),
      'classTeacher': staffData['classTeacher'],
      'classesAssigned': staffData['classesAssigned'] ?? [],
      'subjectsAssigned': staffData['subjectsAssigned'] ?? [],
      'meta': {
        'name': _nameController.text.trim(),
        'experience': _experienceController.text.trim(),
        'qualification': _qualificationController.text.trim(),
        'gender': _gender,
        'contact': _contactController.text.trim(),
        'address': _addressController.text.trim(),
        'dob': _dobController.text.trim(),
        'password': staffData['meta']['password'], // Keep existing password
        if (_selectedSubRole == 'Support Staff' || widget.role.toLowerCase() == 'support staff')
          'supportStaffRole': _selectedSupportStaffRole ?? '',
        if (_selectedSubRole == 'Teacher' || widget.role.toLowerCase() == 'teacher')
          'subjects': _selectedSubjects,
      }
    };

    await FirebaseFirestore.instance
        .collection(collection)
        .doc(uid)
        .set(updatedDoc);

    setState(() => _isLoading = false);

    _showSnackBar(
      'Staff profile updated successfully!',
      Colors.green,
      Icons.check_circle_rounded,
    );

    Navigator.pop(context);
  }

  String _getCollectionName() {
    switch (widget.role.toLowerCase()) {
      case 'principal':
        return 'principal';
      case 'vice principal':
        return 'vice_principal';
      case 'support staff':
        return 'supportstaff';
      case 'teacher':
        return 'teachers';
      case 'staff':
        return (_selectedSubRole?.toLowerCase() == 'support staff') ? 'supportstaff' : 'teachers';
      default:
        return 'staff';
    }
  }

  String _getFinalRole() {
    if (widget.role.toLowerCase() == 'staff') {
      return _selectedSubRole ?? 'Staff';
    }
    return widget.role;
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