import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportsScreen extends StatefulWidget {
  final String teacherId;
  final String schoolId;

  const ReportsScreen({
    super.key,
    required this.teacherId,
    required this.schoolId,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isLoading = true;

  // Report data
  int totalStudents = 0;
  int totalClasses = 0;
  int totalAssignments = 0;
  double averageAttendance = 0.0;
  List<Map<String, dynamic>> recentActivities = [];
  List<Map<String, dynamic>> classPerformance = [];

  @override
  void initState() {
    super.initState();
    _loadReportsData();
  }

  Future<void> _loadReportsData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Fetch teacher data
      final teacherDoc = await _firestore
          .collection('teachers')
          .doc(widget.teacherId)
          .get();

      if (teacherDoc.exists) {
        final teacherData = teacherDoc.data()!;

        // Get assigned classes
        List<String> classIds = [];
        if (teacherData.containsKey('classesAssigned')) {
          var classesAssigned = teacherData['classesAssigned'];
          if (classesAssigned is List) {
            classIds = classesAssigned.map((e) => e.toString()).toList();
          } else if (classesAssigned is String) {
            classIds = [classesAssigned];
          }
        }

        setState(() {
          totalClasses = classIds.length;
        });

        // Calculate total students across all classes
        int studentCount = 0;
        List<Map<String, dynamic>> classStats = [];

        for (String classId in classIds) {
          final classDoc = await _firestore
              .collection('classes')
              .doc(classId)
              .get();

          if (classDoc.exists) {
            final classData = classDoc.data()!;
            List<dynamic> students = classData['studentsIds'] ?? [];
            studentCount += students.length;

            classStats.add({
              'className': classData['className'] ?? 'Unknown Class',
              'studentCount': students.length,
              'classId': classId,
            });
          }
        }

        setState(() {
          totalStudents = studentCount;
          classPerformance = classStats;
        });

        // Fetch assignments count
        final assignmentsQuery = await _firestore
            .collection('assignments')
            .where('teacherId', isEqualTo: widget.teacherId)
            .get();

        setState(() {
          totalAssignments = assignmentsQuery.docs.length;
        });

        // Mock attendance data (you can implement actual attendance calculation)
        setState(() {
          averageAttendance = 85.5; // This should be calculated from actual attendance data
        });

        // Mock recent activities
        setState(() {
          recentActivities = [
            {
              'activity': 'Created Assignment: Math Quiz',
              'date': 'Today',
              'icon': Icons.assignment,
            },
            {
              'activity': 'Attendance marked for Class 10A',
              'date': 'Yesterday',
              'icon': Icons.check_circle,
            },
            {
              'activity': 'Graded 25 assignments',
              'date': '2 days ago',
              'icon': Icons.grade,
            },
          ];
        });
      }
    } catch (e) {
      debugPrint('Error loading reports data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading reports: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF6366F1),
        title: const Text(
          'Reports & Analytics',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadReportsData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewCards(),
            const SizedBox(height: 24),
            _buildClassPerformanceSection(),
            const SizedBox(height: 24),
            _buildRecentActivitiesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _buildStatCard(
              'Total Students',
              totalStudents.toString(),
              Icons.people_rounded,
              const Color(0xFF3B82F6),
            ),
            _buildStatCard(
              'Classes Assigned',
              totalClasses.toString(),
              Icons.class_rounded,
              const Color(0xFF10B981),
            ),
            _buildStatCard(
              'Assignments',
              totalAssignments.toString(),
              Icons.assignment_rounded,
              const Color(0xFF8B5CF6),
            ),
            _buildStatCard(
              'Avg. Attendance',
              '${averageAttendance.toStringAsFixed(1)}%',
              Icons.analytics_rounded,
              const Color(0xFFF59E0B),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
        mainAxisAlignment: MainAxisAlignment.center,
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
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildClassPerformanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Class Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        if (classPerformance.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'No classes assigned yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          )
        else
          ...classPerformance.map((classData) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.class_rounded,
                    color: Color(0xFF3B82F6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classData['className'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        '${classData['studentCount']} students',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
      ],
    );
  }

  Widget _buildRecentActivitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activities',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: recentActivities.map((activity) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    activity['icon'],
                    color: const Color(0xFF6366F1),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity['activity'],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        Text(
                          activity['date'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }
}