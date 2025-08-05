import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AttendanceScreen extends StatefulWidget {
  final String studentId;
  const AttendanceScreen({Key? key, required this.studentId}) : super(key: key);

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<AttendanceRecord> attendanceRecords = [];
  bool isLoading = true;
  String studentName = '';
  String classId = '';
  String schoolId = '';

  // Statistics
  int totalDays = 0;
  int presentDays = 0;
  int absentDays = 0;
  double attendancePercentage = 0.0;
  int forenoonPresent = 0;
  int forenoonAbsent = 0;
  int afternoonPresent = 0;
  int afternoonAbsent = 0;

  @override
  void initState() {
    super.initState();
    fetchStudentData();
  }

  Future<void> fetchStudentData() async {
    try {
      print('Fetching student data for ID: ${widget.studentId}');

      // First, get student details to find classId and schoolId
      DocumentSnapshot studentDoc = await _firestore
          .collection('students')
          .doc(widget.studentId)
          .get();

      if (studentDoc.exists) {
        Map<String, dynamic> studentData = studentDoc.data() as Map<String, dynamic>;
        print('Student data found: $studentData');

        setState(() {
          studentName = studentData['name'] ?? 'Unknown Student';
          classId = studentData['classId'] ?? '';
          schoolId = studentData['schoolId'] ?? '';
        });

        print('ClassId: $classId, SchoolId: $schoolId');

        // Now fetch attendance records
        await fetchAttendanceRecords();
      } else {
        print('Student document not found');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching student data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchAttendanceRecords() async {
    try {
      print('Fetching attendance records for classId: $classId, schoolId: $schoolId');

      // Query attendance collection where classId and schoolId match
      Query attendanceQuery = _firestore
          .collection('attendance')
          .where('classId', isEqualTo: classId)
          .where('schoolId', isEqualTo: schoolId);

      QuerySnapshot attendanceSnapshot = await attendanceQuery.get();

      print('Found ${attendanceSnapshot.docs.length} attendance documents');

      List<AttendanceRecord> records = [];

      for (var doc in attendanceSnapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          print('Processing attendance document: ${doc.id}');
          print('Document data: $data');

          // Get date from document
          DateTime attendanceDate;
          if (data['date'] is Timestamp) {
            attendanceDate = (data['date'] as Timestamp).toDate();
          } else if (data['date'] is String) {
            attendanceDate = DateTime.parse(data['date']);
          } else {
            print('Invalid date format in document ${doc.id}');
            continue;
          }

          // Check if this attendance record contains our student
          if (data['students'] != null) {
            List<dynamic> students = data['students'];
            print('Students array length: ${students.length}');

            // Find our student in the students array
            Map<String, dynamic>? studentAttendance;

            for (var student in students) {
              if (student is Map<String, dynamic> &&
                  student['studentId'] == widget.studentId) {
                studentAttendance = student;
                break;
              }
            }

            if (studentAttendance != null) {
              print('Found attendance for student: $studentAttendance');

              String forenoonStatus = studentAttendance['forenoon'] ?? 'Absent';
              String afternoonStatus = studentAttendance['afternoon'] ?? 'Absent';

              records.add(AttendanceRecord(
                date: attendanceDate,
                forenoon: forenoonStatus,
                afternoon: afternoonStatus,
              ));

              print('Added record: ${DateFormat('dd-MM-yyyy').format(attendanceDate)} - F: $forenoonStatus, A: $afternoonStatus');
            } else {
              print('Student not found in attendance record for ${DateFormat('dd-MM-yyyy').format(attendanceDate)}');
            }
          } else {
            print('No students array found in attendance document ${doc.id}');
          }
        } catch (e) {
          print('Error processing attendance document ${doc.id}: $e');
        }
      }

      // Sort records by date (newest first)
      records.sort((a, b) => b.date.compareTo(a.date));

      // Calculate statistics
      calculateStatistics(records);

      print('Total records found: ${records.length}');
      print('Statistics - Total: $totalDays, Present: $presentDays, Absent: $absentDays, Percentage: $attendancePercentage%');

      setState(() {
        attendanceRecords = records;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching attendance records: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void calculateStatistics(List<AttendanceRecord> records) {
    totalDays = records.length;
    presentDays = 0;
    absentDays = 0;
    forenoonPresent = 0;
    forenoonAbsent = 0;
    afternoonPresent = 0;
    afternoonAbsent = 0;

    for (var record in records) {
      // Count forenoon attendance
      if (record.forenoon == 'Present') {
        forenoonPresent++;
      } else {
        forenoonAbsent++;
      }

      // Count afternoon attendance
      if (record.afternoon == 'Present') {
        afternoonPresent++;
      } else {
        afternoonAbsent++;
      }

      // Count overall daily attendance (present if either session is present)
      if (record.forenoon == 'Present' || record.afternoon == 'Present') {
        presentDays++;
      } else {
        absentDays++;
      }
    }

    attendancePercentage = totalDays > 0 ? (presentDays / totalDays) * 100 : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text(
          'Attendance Report',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF1565C0),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                isLoading = true;
              });
              fetchStudentData();
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
            ),
            SizedBox(height: 16),
            Text(
              'Loading attendance records...',
              style: TextStyle(
                color: Color(0xFF1976D2),
                fontSize: 16,
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: () async {
          await fetchStudentData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Header Section
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                  child: Column(
                    children: [
                      // Student Info Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    studentName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Student ID: ${widget.studentId.length > 8 ? '${widget.studentId.substring(0, 8)}...' : widget.studentId}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (classId.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Class: $classId',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Statistics Cards
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Days',
                            totalDays.toString(),
                            Icons.calendar_today,
                            const Color(0xFF1976D2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Present',
                            presentDays.toString(),
                            Icons.check_circle,
                            const Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Absent',
                            absentDays.toString(),
                            Icons.cancel,
                            const Color(0xFFD32F2F),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Forenoon Present',
                            forenoonPresent.toString(),
                            Icons.wb_sunny,
                            const Color(0xFF1976D2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Afternoon Present',
                            afternoonPresent.toString(),
                            Icons.wb_sunny_outlined,
                            const Color(0xFF42A5F5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Attendance Percentage Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF42A5F5).withOpacity(0.1),
                        const Color(0xFF1E88E5).withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0xFF42A5F5).withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Overall Attendance',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${attendancePercentage.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: attendancePercentage / 100,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            attendancePercentage >= 75
                                ? const Color(0xFF2E7D32)
                                : attendancePercentage >= 50
                                ? const Color(0xFFFF9800)
                                : const Color(0xFFD32F2F),
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Attendance Records Table
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1976D2).withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Table Header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(15),
                            topRight: Radius.circular(15),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Date',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Forenoon',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Afternoon',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Status',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Table Body
                      Container(
                        constraints: const BoxConstraints(
                          minHeight: 200,
                          maxHeight: 400,
                        ),
                        child: attendanceRecords.isEmpty
                            ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.assignment_outlined,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No attendance records found',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Pull down to refresh',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                            : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: attendanceRecords.length,
                          itemBuilder: (context, index) {
                            final record = attendanceRecords[index];
                            final isEven = index % 2 == 0;

                            return Container(
                              color: isEven
                                  ? const Color(0xFFF8FAFF)
                                  : Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      DateFormat('dd MMM yyyy')
                                          .format(record.date),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF333333),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildStatusChip(record.forenoon),
                                  ),
                                  Expanded(
                                    child: _buildStatusChip(record.afternoon),
                                  ),
                                  Expanded(
                                    child: _buildOverallStatusChip(
                                      record.forenoon,
                                      record.afternoon,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final isPresent = status == 'Present';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPresent
            ? const Color(0xFF2E7D32).withOpacity(0.1)
            : const Color(0xFFD32F2F).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPresent
              ? const Color(0xFF2E7D32).withOpacity(0.3)
              : const Color(0xFFD32F2F).withOpacity(0.3),
        ),
      ),
      child: Text(
        status == 'Present' ? 'P' : 'A',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isPresent ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
        ),
      ),
    );
  }

  Widget _buildOverallStatusChip(String forenoon, String afternoon) {
    final isPresent = forenoon == 'Present' || afternoon == 'Present';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPresent
            ? const Color(0xFF2E7D32).withOpacity(0.1)
            : const Color(0xFFD32F2F).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPresent
              ? const Color(0xFF2E7D32).withOpacity(0.3)
              : const Color(0xFFD32F2F).withOpacity(0.3),
        ),
      ),
      child: Icon(
        isPresent ? Icons.check : Icons.close,
        size: 14,
        color: isPresent ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
      ),
    );
  }
}

class AttendanceRecord {
  final DateTime date;
  final String forenoon;
  final String afternoon;

  AttendanceRecord({
    required this.date,
    required this.forenoon,
    required this.afternoon,
  });
}