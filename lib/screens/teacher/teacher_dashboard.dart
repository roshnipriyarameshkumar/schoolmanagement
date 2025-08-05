// FILE: lib/screens/teacher/teacher_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/login_screen.dart';
import '../principal/class_list.dart';
import 'assignment_creation.dart';
import 'attendance_screen.dart';
import 'class_list.dart';
import 'grade_entry_screen.dart';
import 'announcements_screen.dart'; // Add this import
import 'reports_screen.dart';

class TeacherProfileScreen extends StatefulWidget {
  final String teacherId;
  const TeacherProfileScreen({super.key, required this.teacherId});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();

  Map<String, dynamic>? teacherData;
  Map<String, dynamic>? schoolData;
  List<Map<String, dynamic>> principalData = [];
  List<Map<String, dynamic>> vicePrincipalData = [];
  List<Map<String, dynamic>> assignedClasses = [];
  bool isLoading = true;
  String teacherName = '';
  String? schoolId;

  // Animation controllers
  AnimationController? _fadeController;
  AnimationController? _slideController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    fetchProfileData();
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

  Future<void> fetchProfileData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Fetch teacher data
      final teacherSnap = await _firestore
          .collection('teachers')
          .doc(widget.teacherId)
          .get();

      if (!teacherSnap.exists) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      final teacher = teacherSnap.data()!;
      schoolId = teacher['schoolId'];

      setState(() {
        teacherData = teacher;
        teacherName = teacher['meta']?['name'] ?? 'Teacher';
      });

      // Fetch school data
      final schoolSnap = await _firestore
          .collection('schools')
          .doc(schoolId)
          .get();

      if (schoolSnap.exists) {
        final school = schoolSnap.data()!;
        setState(() {
          schoolData = school;
        });

        // Fetch staff data from school's staffIds
        if (school.containsKey('staffIds') && school['staffIds'] != null) {
          List<dynamic> staffIds = school['staffIds'];
          List<Map<String, dynamic>> principals = [];
          List<Map<String, dynamic>> vicePrincipals = [];

          for (var staffInfo in staffIds) {
            if (staffInfo is Map<String, dynamic>) {
              String role = staffInfo['role']?.toString() ?? '';
              String uid = staffInfo['uid']?.toString() ?? '';

              try {
                if (role == 'Principal') {
                  final principalSnap = await _firestore
                      .collection('principal')
                      .doc(uid)
                      .get();
                  if (principalSnap.exists) {
                    var principalData = principalSnap.data()!;
                    principalData['uid'] = uid;
                    principals.add(principalData);
                  }
                } else if (role == 'Vice Principal') {
                  final vpSnap = await _firestore
                      .collection('vice_principal')
                      .doc(uid)
                      .get();
                  if (vpSnap.exists) {
                    var vpData = vpSnap.data()!;
                    vpData['uid'] = uid;
                    vicePrincipals.add(vpData);
                  }
                }
              } catch (e) {
                print('Error fetching staff member $uid: $e');
              }
            }
          }

          setState(() {
            principalData = principals;
            vicePrincipalData = vicePrincipals;
          });
        }
      }

      // Fetch assigned classes
      if (teacherData != null && teacherData!.containsKey('classesAssigned')) {
        var classesAssignedData = teacherData!['classesAssigned'];
        List<String> classIds = [];

        if (classesAssignedData is List) {
          classIds = classesAssignedData.map((e) => e.toString()).toList();
        } else if (classesAssignedData is String) {
          classIds = [classesAssignedData];
        }

        List<Map<String, dynamic>> classes = [];
        for (String classId in classIds) {
          try {
            final classSnap = await _firestore
                .collection('classes')
                .doc(classId)
                .get();
            if (classSnap.exists) {
              Map<String, dynamic> classData = classSnap.data()!;
              classData['id'] = classId;
              classes.add(classData);
            }
          } catch (e) {
            print('Error fetching class $classId: $e');
          }
        }

        setState(() {
          assignedClasses = classes;
        });
      }

    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });

      if (mounted && _fadeController != null && _slideController != null) {
        _fadeController!.forward();
        _slideController!.forward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: isLoading
          ? _buildLoadingScreen()
          : _buildProfileContent(),
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
        isLoading ? 'My Profile' : 'Welcome $teacherName',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: 0.5,
        ),
      ),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.logout_rounded, color: Colors.white),
        onPressed: () async {
          await FirebaseAuth.instance.signOut();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => LoginScreen()),
                (route) => false,
          );
        },
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: fetchProfileData,
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
            'Welcome Teacher',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Loading your profile...',
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

  Widget _buildProfileContent() {
    Widget content = SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTeacherInfoCard(),
          const SizedBox(height: 24),
          _buildQuickActionsGrid(context, widget.teacherId, assignedClasses),
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

  Widget _buildTeacherInfoCard() {
    if (teacherData == null) return const SizedBox.shrink();

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
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 3,
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 50,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Teacher Name
          Text(
            (teacherData!['meta'] != null && teacherData!['meta']['name'] != null)
                ? teacherData!['meta']['name'].toString()
                : 'Teacher Name',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Teacher Email
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              teacherData!['email']?.toString() ?? 'email@example.com',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Teacher Details Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildInfoPill(
                Icons.work_outline_rounded,
                (teacherData!['meta'] != null && teacherData!['meta']['experience'] != null)
                    ? '${teacherData!['meta']['experience']} Years'
                    : 'N/A Years',
                'Experience',
              ),
              _buildInfoPill(
                Icons.school_outlined,
                teacherData!['meta']['qualification']?.toString() ?? 'N/A',
                'Qualification',
              ),
              _buildInfoPill(
                Icons.class_rounded,
                '${assignedClasses.length}',
                'Classes',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPill(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context, String teacherId, List<Map<String, dynamic>> assignedClasses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          children: [
            _buildActionCard(
              'View Classes',
              Icons.class_rounded,
              const Color(0xFF3B82F6),
              '${assignedClasses.length} Classes',
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeacherClassesAndStudentsScreen(
                      teacherId: teacherId,
                    ),
                  ),
                );
              },
            ),
            _buildActionCard(
              'Take Attendance',
              Icons.check_circle_outline_rounded,
              const Color(0xFF10B981),
              'Mark Present/Absent',
                  () {
                if (assignedClasses.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AttendanceScreen(
                        teacherId: teacherId,
                      ),
                    ),
                  );
                } else {
                  _showFeatureSnackBar('No class assigned for attendance');
                }
              },
            ),
            _buildActionCard(
              'Create Assignment',
              Icons.assignment_rounded,
              const Color(0xFF8B5CF6),
              'New Assignment',
                  () {
                if (assignedClasses.isNotEmpty) {
                  if (schoolId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AssignmentManagerScreen(
                          teacherId: teacherId,
                          schoolId: schoolId!,
                        ),
                      ),
                    );
                  } else {
                    _showFeatureSnackBar('School ID not available');
                  }
                } else {
                  _showFeatureSnackBar('No class assigned for assignment creation');
                }
              },
            ),
            _buildActionCard(
              'Enter Grades',
              Icons.grade_rounded,
              const Color(0xFFF59E0B),
              'Student Grades',
                  () {
                if (assignedClasses.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GradeEntryScreen(
                        teacherId: teacherId,
                      ),
                    ),
                  );
                } else {
                  _showFeatureSnackBar('No class assigned for grade entry');
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Full-width announcements card
        SizedBox(
          width: double.infinity,
          child: _buildActionCard(
            'Announcements',
            Icons.campaign_rounded,
            const Color(0xFFEF4444),
            'School Updates',
                () {
              if (schoolId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AnnouncementsScreen(
                      teacherId: teacherId,
                      schoolId: schoolId!,
                    ),
                  ),
                );
              } else {
                _showFeatureSnackBar('School ID not available');
              }
            },
          ),
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
          padding: const EdgeInsets.all(20),
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
                padding: const EdgeInsets.all(16),
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
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
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
          'School & Administration',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),

        // School Information Card
        if (schoolData != null) _buildSchoolCard(),

        const SizedBox(height: 16),

        // Staff Information
        Row(
          children: [
            // Principal Card
            if (principalData.isNotEmpty)
              Expanded(
                child: _buildStaffCard(
                  'Principal',
                  principalData.first,
                  Icons.admin_panel_settings_rounded,
                  const Color(0xFF1E40AF),
                ),
              ),

            if (principalData.isNotEmpty && vicePrincipalData.isNotEmpty)
              const SizedBox(width: 16),

            // Vice Principal Card
            if (vicePrincipalData.isNotEmpty)
              Expanded(
                child: _buildStaffCard(
                  'Vice Principal',
                  vicePrincipalData.first,
                  Icons.supervisor_account_rounded,
                  const Color(0xFF8B5CF6),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSchoolCard() {
    if (schoolData == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E40AF).withOpacity(0.08),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1E40AF).withOpacity(0.1),
                      const Color(0xFF3B82F6).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Color(0xFF1E40AF),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schoolData!['name']?.toString() ?? 'School Name',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      schoolData!['email']?.toString() ?? 'school@example.com',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey,
                width: 0.1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.phone_rounded,
                  color: Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  schoolData!['phone']?.toString() ?? 'Contact not available',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffCard(String role, Map<String, dynamic> staffData, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  role,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            (staffData['meta'] != null && staffData['meta']['name'] != null)
                ? staffData['meta']['name'].toString()
                : 'Name not available',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              staffData['email']?.toString() ?? 'Email not available',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (staffData['meta'] != null && staffData['meta']['contact'] != null)
                ? staffData['meta']['contact'].toString()
                : 'Contact not available',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  void _showClassesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.class_rounded,
                        color: Color(0xFF3B82F6),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Assigned Classes',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (assignedClasses.isEmpty)
                  const Text(
                    'No classes assigned yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  )
                else
                  ...assignedClasses.map((classData) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.class_rounded,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            classData['className'] ?? classData['id'] ?? 'Unknown Class',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFeatureSnackBar(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigate to $feature'),
        backgroundColor: const Color(0xFF1E40AF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}