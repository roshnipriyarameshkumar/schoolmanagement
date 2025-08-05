import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'announcements.dart';
import 'self_attendance.dart';
import 'task_screen.dart';
import '../auth/login_screen.dart';

class SupportStaffDashboard extends StatefulWidget {
  final String supportStaffId;

  const SupportStaffDashboard({super.key, required this.supportStaffId});

  @override
  State<SupportStaffDashboard> createState() => _SupportStaffDashboardState();
}

class _SupportStaffDashboardState extends State<SupportStaffDashboard>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  Map<String, dynamic>? supportData;
  Map<String, dynamic>? schoolData;
  Map<String, dynamic>? principalData;
  bool _isLoading = true;
  String supportStaffName = '';
  String? errorMessage;

  // Animation controllers
  AnimationController? _fadeController;
  AnimationController? _slideController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    fetchData();
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

  Future<void> fetchData() async {
    try {
      setState(() {
        _isLoading = true;
        errorMessage = null;
      });

      // 1. Get support staff data from 'supportstaff' collection
      print("🔍 Fetching support staff data for ID: ${widget.supportStaffId}");
      final staffSnap = await FirebaseFirestore.instance
          .collection('supportstaff')
          .doc(widget.supportStaffId)
          .get();

      if (!staffSnap.exists) {
        throw Exception("Support staff not found");
      }

      supportData = staffSnap.data();

      // Handle different data structures - check if 'meta' exists or use direct fields
      if (supportData!['meta'] != null) {
        supportStaffName = supportData!['meta']['name'] ?? 'Support Staff';
      } else {
        supportStaffName = supportData!['name'] ?? 'Support Staff';
      }

      print("✅ Support staff data: $supportStaffName");

      final schoolId = supportData?['schoolId'];
      if (schoolId != null) {
        // 2. Get school data from 'schools' collection (make this optional)
        try {
          print("🔍 Fetching school data for ID: $schoolId");
          final schoolSnap = await FirebaseFirestore.instance
              .collection('schools')
              .doc(schoolId)
              .get();

          if (schoolSnap.exists) {
            schoolData = schoolSnap.data();
            print("✅ School data: ${schoolData?['name']}");

            // 3. Try to find principal data (make this optional)
            try {
              final staffIds = schoolData?['staffIds'] as List<dynamic>? ?? [];
              print("🔍 Staff IDs in school: $staffIds");

              List<String> principalIds = [];
              for (var staff in staffIds) {
                if (staff is Map<String, dynamic> &&
                    staff['role'] == 'Principal') {
                  principalIds.add(staff['uid']);
                }
              }

              print("🔍 Found principal IDs: $principalIds");

              if (principalIds.isNotEmpty) {
                // Try to get principal data
                for (String principalId in principalIds) {
                  print("🔍 Trying to fetch principal with ID: $principalId");

                  final principalSnap = await FirebaseFirestore.instance
                      .collection('principal')
                      .doc(principalId)
                      .get();

                  if (principalSnap.exists) {
                    principalData = principalSnap.data();
                    print(
                        "✅ Found principal data: ${principalData?['meta']?['name'] ??
                            principalData?['name']}");
                    break;
                  }
                }

                // If no principal found in 'principal' collection, try alternatives
                if (principalData == null) {
                  print("🔍 Trying alternative approaches for principal");
                  final principalQuery = await FirebaseFirestore.instance
                      .collection('principal')
                      .where('schoolId', isEqualTo: schoolId)
                      .limit(1)
                      .get();

                  if (principalQuery.docs.isNotEmpty) {
                    principalData = principalQuery.docs.first.data();
                    print("✅ Found principal by schoolId");
                  }
                }
              }
            } catch (principalError) {
              print("⚠️ Could not fetch principal data: $principalError");
              // Continue without principal data
            }
          } else {
            print("⚠️ School not found, continuing without school data");
          }
        } catch (schoolError) {
          print("⚠️ Could not fetch school data: $schoolError");
          // Continue without school data
        }
      } else {
        print("⚠️ No school ID found, continuing without school data");
      }

      // Always set loading to false and show what we have
      setState(() {
        _isLoading = false;
      });

      if (mounted && _fadeController != null && _slideController != null) {
        _fadeController!.forward();
        _slideController!.forward();
      }

      print(
          "🎉 Data loading completed! Staff: $supportStaffName, School: ${schoolData !=
              null ? 'Found' : 'Not found'}, Principal: ${principalData != null
              ? 'Found'
              : 'Not found'}");
    } catch (e) {
      print("❌ Error fetching data: $e");
      setState(() {
        _isLoading = false;
        errorMessage = e.toString();
      });
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
          : errorMessage != null
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
        _isLoading ? 'Support Staff Dashboard' : 'Welcome $supportStaffName',
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
              onTap: fetchData,
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
            'Welcome Support Staff',
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
            onPressed: fetchData,
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
          _buildSupportStaffInfoCard(),
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

  Widget _buildSupportStaffInfoCard() {
    if (supportData == null) return const SizedBox.shrink();

    // Handle different data structures
    String staffName = 'Support Staff';
    String staffRole = 'N/A';
    String staffContact = 'N/A';
    String staffQualification = 'N/A';
    String staffExperience = 'N/A';
    String staffEmail = 'N/A';

    if (supportData!['meta'] != null) {
      // If meta exists, use meta structure
      staffName = supportData!['meta']['name']?.toString() ?? 'Support Staff';
      staffContact = supportData!['meta']['contact']?.toString() ?? 'N/A';
      staffQualification =
          supportData!['meta']['qualification']?.toString() ?? 'N/A';
      staffExperience = supportData!['meta']['experience']?.toString() ?? 'N/A';
    } else {
      // If no meta, use direct fields
      staffName = supportData!['name']?.toString() ?? 'Support Staff';
      staffContact = supportData!['contact']?.toString() ?? 'N/A';
      staffQualification = supportData!['qualification']?.toString() ?? 'N/A';
      staffExperience = supportData!['experience']?.toString() ?? 'N/A';
    }

    staffRole = supportData!['supportStaffRole']?.toString() ??
        supportData!['role']?.toString() ?? 'N/A';
    staffEmail = supportData!['email']?.toString() ?? 'N/A';

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
              Icons.support_agent_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Support Staff Name
          Text(
            staffName,
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

          // Staff ID
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'ID: ${widget.supportStaffId}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 16),

          // Staff Details Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _buildInfoPill(
                  Icons.work_rounded,
                  staffRole,
                  'Role',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoPill(
                  Icons.phone_rounded,
                  staffContact,
                  'Phone',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Additional Information
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
                // Experience and Qualification
                Row(
                  children: [
                    const Icon(
                        Icons.school_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Qualification: $staffQualification',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Experience: $staffExperience years',
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
                // Email
                Row(
                  children: [
                    const Icon(
                        Icons.email_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        staffEmail,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
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
          'Staff Activities',
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
              'Announcements',
              Icons.announcement_rounded,
              const Color(0xFFEF4444),
              'View Latest News',
                  () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SupportStaffAnnouncementsScreen(
                    supportStaffId: widget.supportStaffId, // Pass the required parameter
                  ),
                ),
              ),
            ),
            _buildActionCard(
              'Mark Attendance',
              Icons.check_circle_outline_rounded,
              const Color(0xFFF59E0B),
              'Self Attendance',
                  () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SelfAttendanceScreen(
                    staffId: widget.supportStaffId,
                  ),
                ),
              ),
            ),
            if (supportData != null && _shouldShowRoleTasks())
              _buildActionCard(
                'Role Tasks',
                Icons.task_alt_rounded,
                const Color(0xFF8B5CF6),
                'View Role Tasks',
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TaskScreen(
                      role: _getStaffRole(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  bool _shouldShowRoleTasks() {
    if (supportData == null) return false;
    String role = _getStaffRole().toLowerCase();
    return role.contains('security') ||
        role.contains('lab assistant') ||
        role.contains('assistant');
  }

  String _getStaffRole() {
    if (supportData == null) return 'N/A';
    return supportData!['supportStaffRole']?.toString() ??
        supportData!['role']?.toString() ??
        'N/A';
  }

  Widget _buildActionCard(String title, IconData icon, Color color,
      String subtitle, VoidCallback onTap) {
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

  Widget _buildSchoolInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'School Information',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),

        // School Card
        if (schoolData != null && schoolData!.isNotEmpty)
          _buildInfoCard(
            'School Details',
            schoolData!,
            Icons.school_rounded,
            const Color(0xFF10B981),
          ),

        const SizedBox(height: 16),

        // Principal Card
        if (principalData != null && principalData!.isNotEmpty)
          _buildInfoCard(
            'Principal',
            principalData!,
            Icons.admin_panel_settings_rounded,
            const Color(0xFF1E40AF),
          ),
      ],
    );
  }

  Widget _buildInfoCard(String role, Map<String, dynamic> data, IconData icon,
      Color color) {
    String displayName = 'Name not available';
    String displayEmail = 'Email not available';

    if (role == 'School Details') {
      displayName = data['name']?.toString() ?? 'School Name';
      displayEmail = data['email']?.toString() ?? 'Email not available';
    } else {
      // Handle both meta and direct structure for principal data
      if (data['meta'] != null) {
        displayName = data['meta']['name']?.toString() ?? 'Name not available';
      } else {
        displayName = data['name']?.toString() ?? 'Name not available';
      }
      displayEmail = data['email']?.toString() ?? 'Email not available';
    }

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
                      displayName,
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
                  Icons.email_rounded,
                  color: Colors.grey,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayEmail,
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