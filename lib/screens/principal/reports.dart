import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportsScreen extends StatefulWidget {
  final String schoolId;
  const ReportsScreen({Key? key, required this.schoolId}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with TickerProviderStateMixin {
  int numTeachers = 0;
  int numSupportStaff = 0;
  int numClasses = 0;
  int numStudents = 0;
  int numSubjects = 0;
  bool isLoading = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Professional Blue Color Palette (matching AddAnnouncementScreen)
  static const Color primaryBlue = Color(0xFF0F172A);      // Dark Blue
  static const Color secondaryBlue = Color(0xFF1E40AF);    // Royal Blue
  static const Color accentBlue = Color(0xFF3B82F6);       // Bright Blue
  static const Color lightBlue = Color(0xFF60A5FA);        // Light Blue
  static const Color paleBlue = Color(0xFF93C5FD);         // Pale Blue
  static const Color backgroundBlue = Color(0xFFEBF8FF);   // Very Light Blue
  static const Color surfaceBlue = Color(0xFFF0F9FF);      // Surface Blue

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack));

    fetchReportData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> fetchReportData() async {
    try {
      final schoolDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .get();

      final schoolData = schoolDoc.data() as Map<String, dynamic>;

      // Staff IDs
      final rawStaffList = schoolData['staffIds'] as List<dynamic>? ?? [];
      final staffList = rawStaffList.whereType<Map<String, dynamic>>().toList();

      numTeachers =
          staffList.where((s) => s['role'] == 'Teacher').toList().length;
      numSupportStaff =
          staffList.where((s) => s['role'] == 'Support Staff').toList().length;

      // Classes
      final classIds = schoolData['classIds'] as List<dynamic>? ?? [];
      numClasses = classIds.length;

      // Subjects directly from school-level subjectIds
      final subjectIds = schoolData['subjectIds'] as List<dynamic>? ?? [];
      numSubjects = subjectIds.length;

      // Count students across all classes
      int students = 0;

      for (var classId in classIds) {
        final classDoc = await FirebaseFirestore.instance
            .collection('classes')
            .doc(classId)
            .get();

        final classData = classDoc.data() as Map<String, dynamic>?;

        if (classData != null) {
          final studentIds = classData['studentIds'] as List<dynamic>? ?? [];
          students += studentIds.length;
        }
      }

      setState(() {
        numStudents = students;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching report: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildStatCard({
    required String title,
    required String count,
    required IconData icon,
    required Color iconColor,
    required int index,
  }) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, surfaceBlue],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
              border: Border.all(color: paleBlue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: iconColor.withOpacity(0.3)),
                      ),
                      child: Icon(icon, color: iconColor, size: 24),
                    ),
                    Text(
                      count,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: primaryBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primaryBlue.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportsTable() {
    final List<Map<String, dynamic>> reportData = [
      {
        'category': 'Teaching Staff',
        'count': numTeachers,
        'icon': Icons.school,
        'color': const Color(0xFF10B981), // Green
        'description': 'Active Teachers',
      },
      {
        'category': 'Support Staff',
        'count': numSupportStaff,
        'icon': Icons.support_agent,
        'color': const Color(0xFF8B5CF6), // Purple
        'description': 'Support Personnel',
      },
      {
        'category': 'Classes',
        'count': numClasses,
        'icon': Icons.class_,
        'color': const Color(0xFFF59E0B), // Amber
        'description': 'Total Classes',
      },
      {
        'category': 'Students',
        'count': numStudents,
        'icon': Icons.groups,
        'color': const Color(0xFFEF4444), // Red
        'description': 'Enrolled Students',
      },
      {
        'category': 'Subjects',
        'count': numSubjects,
        'icon': Icons.book,
        'color': accentBlue,
        'description': 'Available Subjects',
      },
    ];

    return Container(
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
        border: Border.all(color: paleBlue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [primaryBlue, secondaryBlue],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.analytics, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'School Statistics Overview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: lightBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Live Data',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Table Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1.5),
              },
              children: [
                // Table Headers
                TableRow(
                  children: [
                    _buildTableHeader(''),
                    _buildTableHeader('Category'),
                    _buildTableHeader('Count'),
                    _buildTableHeader('Description'),
                  ],
                ),
                // Add spacing row
                TableRow(
                  children: List.generate(4, (index) => const SizedBox(height: 16)),
                ),
                // Table Data Rows
                ...reportData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  return _buildTableRow(
                    icon: data['icon'],
                    iconColor: data['color'],
                    category: data['category'],
                    count: data['count'].toString(),
                    description: data['description'],
                    index: index,
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: primaryBlue.withOpacity(0.8),
          letterSpacing: 0.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  TableRow _buildTableRow({
    required IconData icon,
    required Color iconColor,
    required String category,
    required String count,
    required String description,
    required int index,
  }) {
    return TableRow(
      children: [
        // Icon
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Center(
            child: TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 400 + (index * 100)),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: iconColor.withOpacity(0.3)),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                );
              },
            ),
          ),
        ),
        // Category
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Text(
            category,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: primaryBlue,
            ),
            textAlign: TextAlign.left,
          ),
        ),
        // Count
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentBlue.withOpacity(0.1), lightBlue.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentBlue.withOpacity(0.3)),
            ),
            child: Text(
              count,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: primaryBlue,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // Description
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Text(
            description,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: primaryBlue.withOpacity(0.7),
            ),
            textAlign: TextAlign.left,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final totalStaff = numTeachers + numSupportStaff;
    final avgStudentsPerClass = numClasses > 0 ? (numStudents / numClasses).toStringAsFixed(1) : '0';

    return Container(
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
        border: Border.all(color: paleBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentBlue.withOpacity(0.1), lightBlue.withOpacity(0.1)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: lightBlue.withOpacity(0.3)),
                ),
                child: const Icon(Icons.summarize, color: accentBlue, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Quick Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Total Staff',
                  totalStaff.toString(),
                  Icons.group,
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryItem(
                  'Avg Students/Class',
                  avgStudentsPerClass,
                  Icons.calculate,
                  const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primaryBlue.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundBlue,
      appBar: AppBar(
        title: const Text(
          "School Reports",
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
                Icon(Icons.analytics, size: 16, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'Reports',
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
          child: isLoading
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const CircularProgressIndicator(
                    color: accentBlue,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Loading school reports...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          )
              : AnimatedBuilder(
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
                                child: const Icon(Icons.analytics_rounded, size: 32, color: secondaryBlue),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'School Analytics Dashboard',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: primaryBlue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Comprehensive overview of your school statistics',
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

                        // Quick Stats Cards
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.4,
                          children: [
                            _buildStatCard(
                              title: 'Total Teachers',
                              count: numTeachers.toString(),
                              icon: Icons.school,
                              iconColor: const Color(0xFF10B981),
                              index: 0,
                            ),
                            _buildStatCard(
                              title: 'Total Students',
                              count: numStudents.toString(),
                              icon: Icons.groups,
                              iconColor: const Color(0xFFEF4444),
                              index: 1,
                            ),
                            _buildStatCard(
                              title: 'Active Classes',
                              count: numClasses.toString(),
                              icon: Icons.class_,
                              iconColor: const Color(0xFFF59E0B),
                              index: 2,
                            ),
                            _buildStatCard(
                              title: 'Available Subjects',
                              count: numSubjects.toString(),
                              icon: Icons.book,
                              iconColor: accentBlue,
                              index: 3,
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Summary Card
                        _buildSummaryCard(),

                        const SizedBox(height: 24),

                        // Detailed Reports Table
                        _buildReportsTable(),

                        const SizedBox(height: 20),
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