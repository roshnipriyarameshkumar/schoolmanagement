import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AttendanceScreen extends StatefulWidget {
  final String teacherId;
  const AttendanceScreen({Key? key, required this.teacherId}) : super(key: key);

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late Future<List<ClassInfo>> _classFuture;

  @override
  void initState() {
    super.initState();
    _classFuture = _fetchAssignedClasses();
  }

  Future<List<ClassInfo>> _fetchAssignedClasses() async {
    try {
      // Fetch teacher details to get school ID
      final teacherSnap = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(widget.teacherId)
          .get();

      if (!teacherSnap.exists) return [];

      final teacherData = teacherSnap.data() ?? {};
      final schoolId = teacherData['schoolId'];
      if (schoolId == null) return [];

      // Fetch classes where this teacher is the class teacher
      final classQuery = await FirebaseFirestore.instance
          .collection('classes')
          .where('teacherId', isEqualTo: widget.teacherId)
          .where('schoolId', isEqualTo: schoolId)
          .get();

      return classQuery.docs.map((doc) {
        final data = doc.data();
        return ClassInfo(
          id: doc.id,
          grade: data['grade'] ?? '',
          section: data['section'] ?? '',
          schoolId: schoolId,
        );
      }).toList();
    } catch (e) {
      print('Error fetching classes: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text(
          'My Classes',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.blue.shade900,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.blue.shade100,
            ],
          ),
        ),
        child: FutureBuilder<List<ClassInfo>>(
          future: _classFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading your classes...',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading classes',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }

            final classes = snapshot.data ?? [];

            if (classes.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.class_outlined,
                      size: 80,
                      color: Colors.blue.shade300,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Classes Assigned',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You are not assigned as a class teacher\nfor any classes yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.blue.shade600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Classes (${classes.length})',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: classes.length,
                      itemBuilder: (context, index) {
                        final classInfo = classes[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.shade600,
                                    Colors.blue.shade700,
                                  ],
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.school,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                title: Text(
                                  'Class ${classInfo.grade} - ${classInfo.section}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Class Teacher',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MarkAttendanceScreen(
                                        classInfo: classInfo,
                                        teacherId: widget.teacherId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class ClassInfo {
  final String id, grade, section, schoolId;
  const ClassInfo({
    required this.id,
    required this.grade,
    required this.section,
    required this.schoolId,
  });
}

class MarkAttendanceScreen extends StatefulWidget {
  final ClassInfo classInfo;
  final String teacherId;

  const MarkAttendanceScreen({
    Key? key,
    required this.classInfo,
    required this.teacherId,
  }) : super(key: key);

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  List<StudentAttendance> _students = [];
  bool _isLoading = true;
  bool _isSaving = false;
  DateTime _selectedDate = DateTime.now();

  int get totalStudents => _students.length;
  int get presentStudents => _students.where((s) =>
  s.forenoonStatus == 'Present' || s.afternoonStatus == 'Present').length;
  int get absentStudents => totalStudents - presentStudents;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    try {
      setState(() => _isLoading = true);

      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classInfo.id)
          .get();

      if (!classDoc.exists) {
        setState(() => _isLoading = false);
        return;
      }

      final studentIds = List<String>.from(classDoc.data()?['studentIds'] ?? []);
      final students = <StudentAttendance>[];

      // Fetch student details
      for (final studentId in studentIds) {
        final studentDoc = await FirebaseFirestore.instance
            .collection('students')
            .doc(studentId)
            .get();

        if (studentDoc.exists) {
          final data = studentDoc.data() ?? {};

          // Calculate attendance percentage
          final attendancePercentage = await _calculateAttendancePercentage(studentId);

          students.add(StudentAttendance(
            studentId: studentId,
            name: data['name'] ?? 'Unknown Student',
            rollNumber: data['rollNumber'] ?? '',
            attendancePercentage: attendancePercentage,
          ));
        }
      }

      // Sort students by roll number or name
      students.sort((a, b) => a.rollNumber.compareTo(b.rollNumber));

      setState(() {
        _students = students;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching students: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<double> _calculateAttendancePercentage(String studentId) async {
    try {
      final attendanceQuery = await FirebaseFirestore.instance
          .collection('attendance')
          .where('classId', isEqualTo: widget.classInfo.id)
          .where('students', arrayContains: {
        'studentId': studentId,
      })
          .get();

      if (attendanceQuery.docs.isEmpty) return 100.0;

      int totalSessions = 0;
      int presentSessions = 0;

      for (final doc in attendanceQuery.docs) {
        final data = doc.data();
        final students = List<Map<String, dynamic>>.from(data['students'] ?? []);

        final studentData = students.firstWhere(
              (s) => s['studentId'] == studentId,
          orElse: () => {},
        );

        if (studentData.isNotEmpty) {
          totalSessions += 2; // forenoon + afternoon
          if (studentData['forenoon'] == 'Present') presentSessions++;
          if (studentData['afternoon'] == 'Present') presentSessions++;
        }
      }

      return totalSessions > 0 ? (presentSessions / totalSessions * 100) : 100.0;
    } catch (e) {
      print('Error calculating attendance: $e');
      return 100.0;
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.blue.shade800,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submitAttendance() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final docId = '${widget.classInfo.id}_$dateString';

      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(docId)
          .set({
        'teacherId': widget.teacherId,
        'classId': widget.classInfo.id,
        'schoolId': widget.classInfo.schoolId,
        'date': dateString,
        'timestamp': FieldValue.serverTimestamp(),
        'students': _students.map((s) => s.toJson()).toList(),
        'totalStudents': totalStudents,
        'presentStudents': presentStudents,
        'absentStudents': absentStudents,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Attendance saved successfully!'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error saving attendance: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error saving attendance. Please try again.'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildStatusDropdown(String currentStatus, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(currentStatus).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getStatusColor(currentStatus), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentStatus,
          isDense: true,
          style: TextStyle(
            color: _getStatusColor(currentStatus),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          items: ['Present', 'Absent', 'On Duty'].map((status) {
            return DropdownMenuItem(
              value: status,
              child: Text(
                status,
                style: TextStyle(
                  color: _getStatusColor(status),
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Present':
        return Colors.green.shade600;
      case 'Absent':
        return Colors.red.shade600;
      case 'On Duty':
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.blue.shade50,
        appBar: AppBar(
          title: const Text('Loading...'),
          backgroundColor: Colors.blue.shade900,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading students...',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: Text(
          'Class ${widget.classInfo.grade} - ${widget.classInfo.section}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue.shade900,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : const Icon(Icons.save, color: Colors.white),
            onPressed: _isSaving ? null : _submitAttendance,
            tooltip: 'Save Attendance',
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade700, Colors.blue.shade800],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Attendance for ${_students.length} students',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: const Text('Change Date'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    backgroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Statistics Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total',
                    totalStudents.toString(),
                    Colors.blue.shade600,
                    Icons.group,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Present',
                    presentStudents.toString(),
                    Colors.green.shade600,
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Absent',
                    absentStudents.toString(),
                    Colors.red.shade600,
                    Icons.cancel,
                  ),
                ),
              ],
            ),
          ),

          // Attendance Table
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade100,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _students.isEmpty
                  ? const Center(
                child: Text(
                  'No students found',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              )
                  : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(
                      Colors.blue.shade600,
                    ),
                    headingTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    dataRowColor: MaterialStateProperty.resolveWith(
                          (states) => states.contains(MaterialState.hovered)
                          ? Colors.blue.shade50
                          : Colors.white,
                    ),
                    columns: const [

                      DataColumn(label: Text('Student Name')),
                      DataColumn(label: Text('Forenoon')),
                      DataColumn(label: Text('Afternoon')),
                      DataColumn(label: Text('Day %')),
                      DataColumn(label: Text('Overall %')),
                    ],
                    rows: _students.map((student) {
                      final dayPresentCount =
                          (student.forenoonStatus == 'Present' ? 1 : 0) +
                              (student.afternoonStatus == 'Present' ? 1 : 0);
                      final dayPercent = (dayPresentCount / 2 * 100).toStringAsFixed(0);

                      return DataRow(
                        cells: [

                          DataCell(
                            Text(
                              student.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          DataCell(
                            _buildStatusDropdown(
                              student.forenoonStatus,
                                  (val) => setState(() =>
                              student.forenoonStatus = val ?? 'Present'),
                            ),
                          ),
                          DataCell(
                            _buildStatusDropdown(
                              student.afternoonStatus,
                                  (val) => setState(() =>
                              student.afternoonStatus = val ?? 'Present'),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getPercentageColor(double.parse(dayPercent))
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$dayPercent%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _getPercentageColor(double.parse(dayPercent)),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getPercentageColor(student.attendancePercentage)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${student.attendancePercentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _getPercentageColor(student.attendancePercentage),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPercentageColor(double percentage) {
    if (percentage >= 90) return Colors.green.shade600;
    if (percentage >= 75) return Colors.orange.shade600;
    return Colors.red.shade600;
  }
}

class StudentAttendance {
  final String studentId;
  final String name;
  final String rollNumber;
  String forenoonStatus;
  String afternoonStatus;
  final double attendancePercentage;

  StudentAttendance({
    required this.studentId,
    required this.name,
    required this.rollNumber,
    this.forenoonStatus = 'Present',
    this.afternoonStatus = 'Present',
    this.attendancePercentage = 100.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'name': name,
      'rollNumber': rollNumber,
      'forenoon': forenoonStatus,
      'afternoon': afternoonStatus,
    };
  }
}