import 'package:flutter/material.dart';
import 'staff_creation_screen.dart';
import 'class_creation_screen.dart';
import 'subject_creation_screen.dart';
import 'student_creation_screen.dart';

class SchoolManageScreen extends StatefulWidget {
  final String schoolId;
  final Map<String, dynamic> schoolData;

  const SchoolManageScreen({
    Key? key,
    required this.schoolId,
    required this.schoolData,
  }) : super(key: key);

  @override
  _SchoolManageScreenState createState() => _SchoolManageScreenState();
}

class _SchoolManageScreenState extends State<SchoolManageScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeCard(),
                const SizedBox(height: 24),
                _buildLeadershipSection(),
                const SizedBox(height: 32),
                _buildManagementSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: const Color(0xFF1E40AF),
      foregroundColor: Colors.white,
      title: Text(
        widget.schoolData['name'] ?? 'Manage School',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          letterSpacing: 0.5,
        ),
      ),
      centerTitle: true,
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
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3B82F6),
            Color(0xFF60A5FA),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.dashboard_rounded,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(height: 12),
          const Text(
            'School Management Dashboard',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your school efficiently with our comprehensive tools',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadershipSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Leadership Team', Icons.star_rounded),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildPremiumTile(
                title: 'Principal',
                subtitle: 'School Leader',
                icon: Icons.account_circle_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                ),
                onTap: () => _navigateToStaff('Principal'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildPremiumTile(
                title: 'Vice Principal',
                subtitle: 'Assistant Leader',
                icon: Icons.account_circle_outlined,
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                ),
                onTap: () => _navigateToStaff('Vice Principal'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Management Tools', Icons.settings_rounded),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: [
            _buildManagementTile(
              title: 'Staff',
              subtitle: 'Manage Faculty',
              icon: Icons.people_rounded,
              color: const Color(0xFF3B82F6),
              onTap: () => _navigateToStaff('Staff'),
            ),
            _buildManagementTile(
              title: 'Classes',
              subtitle: 'Academic Groups',
              icon: Icons.class_rounded,
              color: const Color(0xFF1D4ED8),
              onTap: () => _navigateToClass(),
            ),
            _buildManagementTile(
              title: 'Subjects',
              subtitle: 'Curriculum',
              icon: Icons.menu_book_rounded,
              color: const Color(0xFF2563EB),
              onTap: () => _navigateToSubject(),
            ),
            _buildManagementTile(
              title: 'Students',
              subtitle: 'Enrollment',
              icon: Icons.school_rounded,
              color: const Color(0xFF1E40AF),
              onTap: () => _navigateToStudent(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF1E40AF),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 32,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManagementTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 28,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToStaff(String role) {
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

  void _navigateToClass() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClassCreationScreen(
          schoolId: widget.schoolId,
        ),
      ),
    );
  }

  void _navigateToSubject() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubjectCreationScreen(
          schoolId: widget.schoolId,
        ),
      ),
    );
  }

  void _navigateToStudent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentCreationScreen(
          schoolId: widget.schoolId,
        ),
      ),
    );
  }
}