import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_school_screen.dart';
import 'manage_school_screen.dart';
import '../auth/login_screen.dart'; // Add this import
class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({Key? key}) : super(key: key);

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();

  int totalSchools = 0;
  int activeSchools = 0;
  int totalStudents = 0;
  int totalTeachers = 0;
  bool isLoading = true;
  String adminName = '';
  String adminEmail = '';
  String superAdminId = '';

  // Non-nullable animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _fetchDashboardData();
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
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  Future<void> _logout() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error logging out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  Future<void> _fetchDashboardData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        adminEmail = user.email ?? '';

        final superAdminSnapshot = await _firestore
            .collection('superadmin')
            .where('email', isEqualTo: adminEmail)
            .limit(1)
            .get();

        if (superAdminSnapshot.docs.isNotEmpty) {
          final superAdminDoc = superAdminSnapshot.docs.first;
          final data = superAdminDoc.data();

          setState(() {
            adminName = data['name'] ?? 'Super Admin';
            superAdminId = superAdminDoc.id;
          });

          final schoolIdsData = data['schoolIds'];
          List<String> schoolIds = [];

          if (schoolIdsData != null) {
            if (schoolIdsData is List) {
              schoolIds = List<String>.from(schoolIdsData);
            } else if (schoolIdsData is Map) {
              schoolIds = schoolIdsData.values.cast<String>().toList();
            }
          }

          setState(() {
            totalSchools = schoolIds.length;
          });

          if (schoolIds.isNotEmpty) {
            await _fetchSchoolStatistics(schoolIds);
          } else {
            setState(() {
              activeSchools = 0;
              totalStudents = 0;
              totalTeachers = 0;
            });
          }
        } else {
          setState(() {
            adminName = 'Super Admin';
            totalSchools = 0;
            activeSchools = 0;
            totalStudents = 0;
            totalTeachers = 0;
          });
        }
      }
    } catch (e) {
      print('Error fetching dashboard data: $e');
      setState(() {
        totalSchools = 0;
        activeSchools = 0;
        totalStudents = 0;
        totalTeachers = 0;
      });
    } finally {
      setState(() {
        isLoading = false;
      });
      // Safe animation start
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
      }
    }
  }

  Future<void> _fetchSchoolStatistics(List<String> schoolIds) async {
    try {
      int activeCount = 0;
      int studentCount = 0;
      int teacherCount = 0;

      for (String schoolId in schoolIds) {
        try {
          final schoolDoc =
          await _firestore.collection('schools').doc(schoolId).get();

          if (schoolDoc.exists) {
            final schoolData = schoolDoc.data() as Map<String, dynamic>;
            final isActive = schoolData['isActive'] ?? true;
            if (isActive) activeCount++;
          }

          final studentsSnapshot = await _firestore
              .collection('students')
              .where('schoolId', isEqualTo: schoolId)
              .get();
          studentCount += studentsSnapshot.docs.length;

          final teachersSnapshot = await _firestore
              .collection('teachers')
              .where('schoolId', isEqualTo: schoolId)
              .get();
          teacherCount += teachersSnapshot.docs.length;
        } catch (e) {
          print('Error fetching data for school $schoolId: $e');
        }
      }

      setState(() {
        activeSchools = activeCount;
        totalStudents = studentCount;
        totalTeachers = teacherCount;
      });
    } catch (e) {
      print('Error fetching school statistics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: isLoading
                  ? SizedBox(
                height: screenHeight * 0.6,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF1E40AF),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Loading dashboard...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  : _buildDashboardContent(screenWidth),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent(double screenWidth) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth > 600 ? 24.0 : 16.0,
            vertical: 8.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeSection(),
              const SizedBox(height: 24),
              _buildStatisticsSection(),
              const SizedBox(height: 24),
              _buildActionCardsSection(),
              const SizedBox(height: 24),
              _buildAdditionalInfoSection(),
              const SizedBox(height: 24),
              _buildFooter(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF1E40AF),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
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
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.2),
                ],
              ),
            ),
          ),
        ),
        title: const Text(
          'Super Admin Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (mounted) {
                  _fadeController.reset();
                  _slideController.reset();
                  _fetchDashboardData();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
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
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _logout,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.logout_rounded,
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

  Widget _buildWelcomeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E40AF).withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
            spreadRadius: 0,
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
                      const Color(0xFF1E40AF).withValues(alpha: 0.1),
                      const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
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
                      'Welcome back! 👋',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      adminName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
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
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1E40AF).withValues(alpha: 0.05),
                  const Color(0xFF3B82F6).withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF1E40AF).withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF1E40AF),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Manage your educational institutions with ease and efficiency',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview Statistics',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
            final childAspectRatio = constraints.maxWidth > 600 ? 1.1 : 1.0;

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: childAspectRatio,
              children: [
                _buildStatCard(
                  'Total Schools',
                  totalSchools,
                  Icons.school_rounded,
                  const Color(0xFF3B82F6),
                  0,
                ),
                _buildStatCard(
                  'Active Schools',
                  activeSchools,
                  Icons.check_circle_rounded,
                  const Color(0xFF10B981),
                  1,
                ),
                _buildStatCard(
                  'Total Students',
                  totalStudents,
                  Icons.groups_rounded,
                  const Color(0xFF8B5CF6),
                  2,
                ),
                _buildStatCard(
                  'Total Teachers',
                  totalTeachers,
                  Icons.person_rounded,
                  const Color(0xFFF59E0B),
                  3,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 800 + (index * 200)),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                  spreadRadius: 0,
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
                        color.withValues(alpha: 0.1),
                        color.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: color,
                  ),
                ),
                const SizedBox(height: 12),
                TweenAnimationBuilder<int>(
                  duration: Duration(milliseconds: 1500 + (index * 200)),
                  tween: IntTween(begin: 0, end: count),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Text(
                      value.toString(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1F2937),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionCardsSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                // Wide screen layout with 2 cards side-by-side
                return Row(
                  children: [
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.add_business_rounded,
                        title: 'Create School',
                        subtitle: 'Add new institution',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreateSchoolScreen(
                              superAdminId: superAdminId,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.manage_accounts_rounded,
                        title: 'Manage Schools',
                        subtitle: 'View & edit schools',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ManageSchoolScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                // Small screen layout with horizontal scroll and constrained card height
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 260,
                        height: 160,
                        child: _buildScrollableCard(
                          icon: Icons.add_business_rounded,
                          title: 'Create School',
                          subtitle: 'Add new institution',
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreateSchoolScreen(
                                superAdminId: superAdminId,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 260,
                        height: 160,
                        child: _buildScrollableCard(
                          icon: Icons.manage_accounts_rounded,
                          title: 'Manage Schools',
                          subtitle: 'View & edit schools',
                          gradient: const LinearGradient(
                            colors: [Color(0xFF5B02FF), Color(0xFF8B5CF6)],
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ManageSchoolScreen(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }


  Widget _buildScrollableCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: 280,
        child: _buildActionCard(
          icon: icon,
          title: title,
          subtitle: subtitle,
          gradient: gradient,
          onTap: onTap,
        ),
      ),
    );
  }


  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withOpacity(0.4),
                blurRadius: 25,
                offset: const Offset(0, 10),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                right: -30,
                bottom: -30,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
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



  Widget _buildAdditionalInfoSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
            spreadRadius: 0,
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
                      const Color(0xFF1E40AF).withValues(alpha: 0.1),
                      const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_circle_rounded,
                  color: Color(0xFF1E40AF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Admin Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow('Email Address', adminEmail, Icons.email_rounded),
          const SizedBox(height: 12),
          _buildInfoRow('Full Name', adminName, Icons.person_rounded),
          const SizedBox(height: 12),
          _buildInfoRow('Role', 'Super Administrator', Icons.shield_rounded),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF1E40AF),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F2937), Color(0xFF374151)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E40AF),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E40AF).withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.security_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'School Management System',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Secure • Reliable • Efficient',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}