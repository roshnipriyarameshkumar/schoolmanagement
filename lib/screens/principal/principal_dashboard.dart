import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'class_list.dart';
import 'staff_list.dart';
import 'student_list.dart';
import 'subject_list.dart';
import 'reports.dart';
import 'announcements_screen.dart';
import '../auth/login_screen.dart';

class PrincipalDashboard extends StatefulWidget {
  final String principalId;
  const PrincipalDashboard({Key? key, required this.principalId}) : super(key: key);

  @override
  State<PrincipalDashboard> createState() => _PrincipalDashboardState();
}

class _PrincipalDashboardState extends State<PrincipalDashboard>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();

  // Principal Data
  String? schoolId;
  String? principalName;
  String? principalPhone;
  String? principalQualification;
  String? principalExperience;
  String? principalAddress;
  String? principalEmail;

  // School Data
  String? schoolName;
  String? schoolAddress;
  String? schoolPhone;
  String? schoolEmail;

  // Stats
  int totalTeachers = 0;
  int totalStudents = 0;
  int totalClasses = 0;
  int totalSubjects = 0;
  int totalSupportStaff = 0;
  int totalVicePrincipals = 0;

  bool isLoading = true;

  // Animation controllers
  AnimationController? _fadeController;
  AnimationController? _slideController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    fetchAllData();
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
    ).animate(
        CurvedAnimation(parent: _slideController!, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _fadeController?.dispose();
    _slideController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchAllData() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
    });

    try {
      // Fetch Principal Data
      final principalSnap = await _firestore
          .collection('principal')
          .doc(widget.principalId)
          .get();

      if (principalSnap.exists) {
        final data = principalSnap.data()!;
        final meta = data['meta'] ?? {};

        setState(() {
          schoolId = data['schoolId'];
          principalName = meta['name'];
          principalPhone = meta['phone'];
          principalQualification = meta['qualification'];
          principalExperience = meta['experience'];
          principalAddress = meta['address'];
          principalEmail = data['email'];
        });

        // Fetch School Data & Statistics
        if (schoolId != null) {
          final schoolSnap = await _firestore
              .collection('schools')
              .doc(schoolId!)
              .get();

          if (schoolSnap.exists) {
            final sData = schoolSnap.data()!;
            setState(() {
              schoolName = sData['name'];
              schoolAddress = sData['address'];
              schoolPhone = sData['phone'];
              schoolEmail = sData['email'];
            });

            // Fetch Statistics based on your corrected logic
            await _fetchStatistics(sData);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading dashboard: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        _fadeController!.forward();
        _slideController!.forward();
      }
    }
  }

  Future<void> _fetchStatistics(Map<String, dynamic> schoolData) async {
    if (!mounted || schoolId == null) return;

    try {
      // Get Staff Counts from staffIds array in school document
      final staffIds = schoolData['staffIds'] as List<dynamic>? ?? [];
      int teachers = 0;
      int vicePrincipals = 0;
      int supportStaff = 0;

      // Fetch staff documents and count their roles
      if (staffIds.isNotEmpty) {
        final staffSnapshots = await Future.wait(
          staffIds.map((staffId) => _firestore.collection('teachers').doc(staffId).get()),
        );

        for (var staffSnap in staffSnapshots) {
          if (staffSnap.exists) {
            final staffData = staffSnap.data();
            final role = staffData?['role'];
            if (role == 'Teacher') {
              teachers++;
            } else if (role == 'Vice Principal') {
              vicePrincipals++;
            } else if (role == 'Support Staff') {
              supportStaff++;
            }
          }
        }
      }

      // Get Classes Count from classIds array in school document
      final classIds = schoolData['classIds'] as List<dynamic>? ?? [];

      // Get Subjects Count
      final subjectsQuery = await _firestore
          .collection('subjects')
          .where('schoolId', isEqualTo: schoolId)
          .get();

      // Get Students Count from studentsIds array in classes documents
      int studentsCount = 0;
      if (classIds.isNotEmpty) {
        final classesSnapshots = await Future.wait(
          classIds.map((classId) => _firestore.collection('classes').doc(classId).get()),
        );

        for (var classSnap in classesSnapshots) {
          if (classSnap.exists) {
            final students = classSnap.data()?['studentIds'] as List<dynamic>? ?? [];
            studentsCount += students.length;
          }
        }
      }

      setState(() {
        totalTeachers = teachers;
        totalVicePrincipals = vicePrincipals;
        totalSupportStaff = supportStaff;
        totalClasses = classIds.length;
        totalStudents = studentsCount;
        totalSubjects = subjectsQuery.docs.length;
      });
    } catch (e) {
      debugPrint('Error fetching statistics: $e');
    }
  }

  void logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: isLoading
          ? _buildLoadingScreen()
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
        isLoading ? 'Principal Dashboard' : 'Welcome ${principalName ??
            'Principal'}',
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
        onPressed: logout,
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: fetchAllData,
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
            'Welcome Principal',
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

  Widget _buildDashboardContent() {
    Widget content = SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPrincipalInfoCard(),
          const SizedBox(height: 24),

          const SizedBox(height: 24),
          _buildQuickActionsGrid(),
          const SizedBox(height: 24),
          _buildSchoolInfoSection(),
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

  Widget _buildPrincipalInfoCard() {
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
              Icons.admin_panel_settings_rounded,
              size: 50,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Principal Name
          Text(
            principalName ?? 'Principal Name',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Principal Email
          if (principalEmail != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                principalEmail!,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Principal Details Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildInfoPill(
                Icons.work_outline_rounded,
                principalExperience != null
                    ? '$principalExperience Years'
                    : 'N/A',
                'Experience',
              ),
              _buildInfoPill(
                Icons.school_outlined,
                principalQualification ?? 'N/A',
                'Qualification',
              ),
              _buildInfoPill(
                Icons.business_rounded,
                schoolName != null ? 'Principal' : 'N/A',
                'Role',
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
            textAlign: TextAlign.center,
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

  Widget _buildStatsOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'School Overview',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Teachers',
                totalTeachers.toString(),
                Icons.people_rounded,
                const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Students',
                totalStudents.toString(),
                Icons.school_rounded,
                const Color(0xFF3B82F6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Classes',
                totalClasses.toString(),
                Icons.class_rounded,
                const Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Subjects',
                totalSubjects.toString(),
                Icons.book_rounded,
                const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Vice Principals',
                totalVicePrincipals.toString(),
                Icons.person_outline,
                const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Support Staff',
                totalSupportStaff.toString(),
                Icons.support_agent_rounded,
                const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon,
      Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
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
              const Spacer(),
              Text(
                count,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
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
          'Quick Actions',
          style: TextStyle(
            fontSize: 24,
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
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: [
            _buildActionCard(
              'Manage Classes',
              Icons.class_rounded,
              const Color(0xFF3B82F6),
              'View & manage all classes',
                  () {
                if (schoolId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ClassListScreen(
                            principalId: widget.principalId,
                            schoolId: schoolId!,
                          ),
                    ),
                  );
                }
              },
            ),
            _buildActionCard(
              'Manage Staff',
              Icons.people_rounded,
              const Color(0xFF10B981),
              'View & manage Staffs',
                  () {
                if (schoolId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          StaffListScreen(
                            schoolId: schoolId!,
                          ),
                    ),
                  );
                }
              },
            ),
            _buildActionCard(
              'Manage Students',
              Icons.school_rounded,
              const Color(0xFF8B5CF6),
              'Monitor Students ',
                  () {
                if (schoolId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          StudentManagementScreen (
                            schoolId: schoolId!,
                          ),
                    ),
                  );
                }
              },
            ),
            _buildActionCard(
              'Manage Subjects',
              Icons.book_rounded,
              const Color(0xFFF59E0B),
              'View & manage subjects',
                  () {
                if (schoolId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SubjectManagementScreen(
                            schoolId: schoolId!,
                            principalId: widget.principalId,
                          ),
                    ),
                  );
                }
              },
            ),
            _buildActionCard(
              'Reports & Analytics',
              Icons.insert_chart_rounded,
              const Color(0xFF6366F1),
              'View Analytics',
                  () {
                if (schoolId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ReportsScreen(
                            schoolId: schoolId!,
                          ),
                    ),
                  );
                }
              },
            ),
            _buildActionCard(
              'Announcements',
              Icons.campaign_rounded,
              const Color(0xFFEF4444),
              'School Updates',
                  () {
                if (schoolId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AddAnnouncementScreen(
                            schoolId: schoolId!,
                            principalId: widget.principalId,
                          ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color,
      String subtitle, VoidCallback onTap) {
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

  Widget _buildSchoolInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'School Information',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Container(
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
                          schoolName ?? 'School Name',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F2937),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          schoolEmail ?? 'school@example.com',
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
              if (schoolPhone != null || schoolAddress != null) ...[
                const SizedBox(height: 16),
                if (schoolPhone != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
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
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          schoolPhone!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (schoolAddress != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            schoolAddress!,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}