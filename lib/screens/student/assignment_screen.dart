import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AssignmentScreen extends StatefulWidget {
  final String studentId;
  const AssignmentScreen({Key? key, required this.studentId}) : super(key: key);

  @override
  State<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends State<AssignmentScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Future<List<Map<String, dynamic>>> _assignmentsFuture;
  String _className = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _assignmentsFuture = _fetchAssignments();
  }

  Future<List<Map<String, dynamic>>> _fetchAssignments() async {
    try {
      setState(() => _isLoading = true);

      // Step 1: Get student document to retrieve classId
      print("🔍 Fetching student data for ID: ${widget.studentId}");
      final studentDoc = await _firestore
          .collection('students')
          .doc(widget.studentId)
          .get();

      if (!studentDoc.exists) {
        throw Exception("Student not found with ID: ${widget.studentId}");
      }

      final studentData = studentDoc.data()!;
      final classId = studentData['classId'];

      if (classId == null || classId.toString().isEmpty) {
        throw Exception("Class ID not found for student");
      }

      print("📚 Student's class ID: $classId");

      // Step 2: Get class details to retrieve class name
      final classDoc = await _firestore
          .collection('classes')
          .doc(classId)
          .get();

      if (classDoc.exists) {
        final classData = classDoc.data()!;
        final grade = classData['grade'] ?? '';
        final section = classData['section'] ?? '';

        if (grade.isNotEmpty && section.isNotEmpty) {
          _className = '$grade - $section';
        } else if (grade.isNotEmpty) {
          _className = grade;
        } else if (section.isNotEmpty) {
          _className = section;
        } else {
          _className = classData['className'] ?? 'Unknown Class';
        }

        print("🏫 Class name: $_className");
      }

      // Step 3: Get all assignments for this specific class
      print("📋 Fetching assignments for class ID: $classId");
      final assignmentSnapshot = await _firestore
          .collection('assignments')
          .where('classId', isEqualTo: classId)
          .get();

      print("✅ Found ${assignmentSnapshot.docs.length} assignments");

      final assignments = assignmentSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort assignments by due date locally
      assignments.sort((a, b) {
        DateTime dateA = DateTime.now();
        DateTime dateB = DateTime.now();

        if (a['dueDate'] is Timestamp) {
          dateA = (a['dueDate'] as Timestamp).toDate();
        }
        if (b['dueDate'] is Timestamp) {
          dateB = (b['dueDate'] as Timestamp).toDate();
        }

        return dateA.compareTo(dateB);
      });

      setState(() => _isLoading = false);
      return assignments;

    } catch (e) {
      print("❌ Error fetching assignments: $e");
      setState(() => _isLoading = false);
      rethrow;
    }
  }

  Color _getDueDateColor(DateTime dueDate) {
    final now = DateTime.now();
    final diffDays = dueDate.difference(now).inDays;

    if (diffDays < 0) {
      return const Color(0xFFD32F2F); // Red for overdue
    } else if (diffDays <= 2) {
      return const Color(0xFFFF5722); // Deep Orange for urgent
    } else if (diffDays <= 5) {
      return const Color(0xFFFF9800); // Orange for soon
    } else {
      return const Color(0xFF4CAF50); // Green for plenty of time
    }
  }

  IconData _getDueDateIcon(DateTime dueDate) {
    final now = DateTime.now();
    final diffDays = dueDate.difference(now).inDays;

    if (diffDays < 0) {
      return Icons.warning_rounded;
    } else if (diffDays <= 2) {
      return Icons.access_time_filled_rounded;
    } else if (diffDays <= 5) {
      return Icons.schedule_rounded;
    } else {
      return Icons.check_circle_outline_rounded;
    }
  }

  String _getDueDateStatus(DateTime dueDate) {
    final now = DateTime.now();
    final diffDays = dueDate.difference(now).inDays;

    if (diffDays < 0) {
      return "Overdue";
    } else if (diffDays == 0) {
      return "Due Today";
    } else if (diffDays == 1) {
      return "Due Tomorrow";
    } else if (diffDays <= 5) {
      return "Due Soon";
    } else {
      return "Upcoming";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assignments',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_className.isNotEmpty)
              Text(
                'Class: $_className',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFFE3F2FD),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() {
                _assignmentsFuture = _fetchAssignments();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _assignmentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1565C0)),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading assignments...',
                    style: TextStyle(
                      color: Color(0xFF64B5F6),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1565C0).withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: Color(0xFFD32F2F),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error Loading Assignments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _assignmentsFuture = _fetchAssignments();
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final assignments = snapshot.data ?? [];

          if (assignments.isEmpty) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1565C0).withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Icon(
                        Icons.assignment_outlined,
                        size: 48,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Assignments Found',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _className.isNotEmpty
                          ? 'No assignments have been posted for $_className yet.'
                          : 'No assignments found for your class.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _fetchAssignments(),
            color: const Color(0xFF1565C0),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: assignments.length,
              itemBuilder: (context, index) {
                final assignment = assignments[index];
                final title = assignment['title'] ?? 'Untitled Assignment';
                final description = assignment['description'] ?? 'No description provided';
                final className = assignment['className'] ?? assignment['section'] ?? '';

                // Safely convert Firestore Timestamp to DateTime
                DateTime dueDate = DateTime.now().add(const Duration(days: 7));
                if (assignment['dueDate'] is Timestamp) {
                  dueDate = (assignment['dueDate'] as Timestamp).toDate();
                } else if (assignment['dueDate'] is String) {
                  try {
                    dueDate = DateTime.parse(assignment['dueDate']);
                  } catch (e) {
                    print("Error parsing date: ${assignment['dueDate']}");
                  }
                }

                final formattedDate = DateFormat('MMM dd, yyyy').format(dueDate);
                final formattedTime = DateFormat('hh:mm a').format(dueDate);
                final dueDateColor = _getDueDateColor(dueDate);
                final dueDateIcon = _getDueDateIcon(dueDate);
                final dueDateStatus = _getDueDateStatus(dueDate);

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1565C0).withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFFE3F2FD),
                      width: 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      // Handle assignment tap - could navigate to detail screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Opened: $title'),
                          backgroundColor: const Color(0xFF1565C0),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1565C0).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.assignment_rounded,
                                  color: Color(0xFF1565C0),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1A237E),
                                        height: 1.2,
                                      ),
                                    ),
                                    if (className.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF64B5F6).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          className,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF1565C0),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: dueDateColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: dueDateColor.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      dueDateIcon,
                                      size: 14,
                                      color: dueDateColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      dueDateStatus,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: dueDateColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Description
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[700],
                                height: 1.4,
                              ),
                            ),
                          ],

                          // Due Date Section
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE3F2FD),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.schedule_rounded,
                                  color: Color(0xFF1565C0),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Due: ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                Text(
                                  '$formattedDate at $formattedTime',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1565C0),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}