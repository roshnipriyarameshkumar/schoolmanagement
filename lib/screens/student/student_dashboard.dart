// FILE: lib/screens/student/student_dashboard.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/login_screen.dart';
import 'grades_screen.dart';
import 'attendance_screen.dart';
import 'assignment_screen.dart';
import 'announcements_screen.dart';

class StudentDashboard extends StatefulWidget {
  final String studentId;
  const StudentDashboard({Key? key, required this.studentId}) : super(key: key);

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();

  Map<String, dynamic>? studentData;
  Map<String, dynamic>? principalData;
  Map<String, dynamic>? vicePrincipalData;
  Map<String, dynamic>? teacherData;
  bool _isLoading = true;
  String studentName = '';

  // Animation controllers
  AnimationController? _fadeController;
  AnimationController? _slideController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _fetchStudentDetails();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController!, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController!, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _fadeController?.dispose();
    _slideController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudentDetails() async {
    setState(() => _isLoading = true);
    try {
      final studentDoc = await _firestore.collection('students').doc(widget.studentId).get();
      if (!studentDoc.exists) throw Exception("Student not found");

      final student = studentDoc.data()!;
      final classId = student['classId'];
      final schoolId = student['schoolId'];

      setState(() {
        studentData = student;
        studentName = student['name'] ?? 'Student';
      });

      // Fetch class details properly
      final classDoc = await _firestore.collection('classes').doc(classId).get();
      if (classDoc.exists) {
        final classData = classDoc.data()!;
        final teacherId = classData['teacherId'];

        // Update student data with correct class information
        if (mounted) {
          setState(() {
            studentData!['className'] = classData['name'] != null && classData['name'].toString().trim().isNotEmpty
                ? classData['name']
                : (classData['grade'] ?? 'N/A');
            studentData!['section'] = classData['section'] ?? 'A';
          });
        }


        // Fetch teacher details
        if (teacherId != null) {
          final teacherDoc = await _firestore.collection('teachers').doc(teacherId).get();
          if (teacherDoc.exists) {
            final teacher = teacherDoc.data()?['meta'] ?? teacherDoc.data() ?? {};
            setState(() {
              teacherData = teacher;
            });
          }
        }
      }

      // Fetch school staff details
      final schoolDoc = await _firestore.collection('schools').doc(schoolId).get();
      if (schoolDoc.exists) {
        final staffList = List<Map<String, dynamic>>.from(schoolDoc.data()?['staffIds'] ?? []);

        String? principalUid;
        String? vicePrincipalUid;
        for (var staff in staffList) {
          if (staff['role'] == 'Principal') principalUid = staff['uid'];
          if (staff['role'] == 'Vice Principal') vicePrincipalUid = staff['uid'];
        }

        // Fetch principal details
        if (principalUid != null) {
          final principalDoc = await _firestore.collection('principal').doc(principalUid).get();
          if (principalDoc.exists) {
            setState(() {
              principalData = principalDoc.data()?['meta'] ?? principalDoc.data() ?? {};
            });
          }
        }

        // Fetch vice principal details
        if (vicePrincipalUid != null) {
          final vicePrincipalDoc = await _firestore.collection('vice_principal').doc(vicePrincipalUid).get();
          if (vicePrincipalDoc.exists) {
            setState(() {
              vicePrincipalData = vicePrincipalDoc.data()?['meta'] ?? vicePrincipalDoc.data() ?? {};
            });
          }
        }
      }

      setState(() => _isLoading = false);

      if (mounted && _fadeController != null && _slideController != null) {
        _fadeController!.forward();
        _slideController!.forward();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print("Error fetching student dashboard data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading dashboard: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginScreen()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildLoadingScreen()
          : studentData == null
          ? _buildErrorScreen()
          : _buildDashboardContent(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: const Color(0xFF1E40AF),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E40AF),
              Color(0xFF3B82F6),
              Color(0xFF60A5FA),
            ],
          ),
        ),
      ),
      title: Text(
        _isLoading ? 'Student Dashboard' : 'Welcome $studentName',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 18,
          letterSpacing: 0.5,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.logout_rounded, color: Colors.white),
        onPressed: _logout,
        tooltip: "Logout",
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _fetchStudentDetails,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E40AF).withOpacity(0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E40AF)),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Welcome Student',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Loading your dashboard...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 60,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Failed to Load Data',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please try refreshing the page',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchStudentDetails,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E40AF),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    Widget content = SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStudentInfoCard(),
          const SizedBox(height: 24),
          _buildQuickActionsGrid(),
          const SizedBox(height: 24),
          _buildSchoolStaffSection(),
          const SizedBox(height: 16),
        ],
      ),
    );

    if (_fadeAnimation != null && _slideAnimation != null) {
      return FadeTransition(
        opacity: _fadeAnimation!,
        child: SlideTransition(
          position: _slideAnimation!,
          child: content,
        ),
      );
    } else {
      return content;
    }
  }

  Widget _buildStudentInfoCard() {
    if (studentData == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E40AF),
            Color(0xFF3B82F6),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E40AF).withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 3,
              ),
            ),
            child: const Icon(
              Icons.school_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Student Name
          Text(
            studentData!['name']?.toString() ?? 'Student Name',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Student ID
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'ID: ${widget.studentId}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 16),

          // Student Details Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _buildInfoPill(
                  Icons.class_rounded,
                  '${studentData!['className']?.toString() ?? 'N/A'} ${studentData!['section']?.toString() ?? ''}',
                  'Class',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoPill(
                  Icons.phone_rounded,
                  studentData!['phone']?.toString() ?? 'N/A',
                  'Phone',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Parent Information
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                // Father's information
                Row(
                  children: [
                    const Icon(Icons.person_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Father: ${studentData!['fatherName']?.toString() ?? 'N/A'}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (studentData!['fatherPhone'] != null)
                            Text(
                              'Ph: ${studentData!['fatherPhone']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Mother's information
                Row(
                  children: [
                    const Icon(Icons.person_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mother: ${studentData!['motherName']?.toString() ?? 'N/A'}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (studentData!['motherPhone'] != null)
                            Text(
                              'Ph: ${studentData!['motherPhone']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPill(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Academic Activities',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: [
            _buildActionCard(
              'Grades',
              Icons.grade_rounded,
              const Color(0xFF10B981),
              'View Your Scores',
                  () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GradesScreen(studentId: widget.studentId),
                ),
              ),
            ),
            _buildActionCard(
              'Attendance',
              Icons.check_circle_outline_rounded,
              const Color(0xFFF59E0B),
              'Check Attendance',
                  () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AttendanceScreen(studentId: widget.studentId),
                ),
              ),
            ),
            _buildActionCard(
              'Assignments',
              Icons.assignment_rounded,
              const Color(0xFF8B5CF6),
              'View Tasks',
                  () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AssignmentScreen(studentId: widget.studentId),
                ),
              ),
            ),
            _buildActionCard(
              'Announcements',
              Icons.announcement_rounded,
              const Color(0xFFEF4444),
              'Latest News',
                  () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AnnouncementsScreen(studentId: widget.studentId),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, String subtitle, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.1),
                      color.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSchoolStaffSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'School Staff & Administration',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),

        // Teacher Card
        if (teacherData != null && teacherData!.isNotEmpty)
          _buildStaffCard(
            'Class Teacher',
            teacherData!,
            Icons.person_rounded,
            const Color(0xFF3B82F6),
          ),

        const SizedBox(height: 16),

        // Administration Row
        Row(
          children: [
            // Principal Card
            if (principalData != null && principalData!.isNotEmpty)
              Expanded(
                child: _buildStaffCard(
                  'Principal',
                  principalData!,
                  Icons.admin_panel_settings_rounded,
                  const Color(0xFF1E40AF),
                ),
              ),

            if (principalData != null && principalData!.isNotEmpty &&
                vicePrincipalData != null && vicePrincipalData!.isNotEmpty)
              const SizedBox(width: 12),

            // Vice Principal Card
            if (vicePrincipalData != null && vicePrincipalData!.isNotEmpty)
              Expanded(
                child: _buildStaffCard(
                  'Vice Principal',
                  vicePrincipalData!,
                  Icons.supervisor_account_rounded,
                  const Color(0xFF8B5CF6),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStaffCard(String role, Map<String, dynamic> staffData, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.1),
                      color.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      staffData['name']?.toString() ?? 'Name not available',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                        letterSpacing: -0.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withOpacity(0.1),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.phone_rounded,
                  color: Colors.grey,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    staffData['contact']?.toString() ?? 'Contact not available',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}