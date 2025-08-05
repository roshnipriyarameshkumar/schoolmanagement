import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GradesScreen extends StatefulWidget {
  final String studentId;
  const GradesScreen({Key? key, required this.studentId}) : super(key: key);

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  String _error = '';

  // Student data
  Map<String, dynamic>? _studentData;
  String _classId = '';

  // Class data
  Map<String, dynamic>? _classData;

  // Grades data
  List<Map<String, dynamic>> _studentGrades = [];

  @override
  void initState() {
    super.initState();
    _fetchStudentGrades();
  }

  Future<void> _fetchStudentGrades() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      // Step 1: Get student data and class ID
      DocumentSnapshot studentDoc = await _firestore
          .collection('students')
          .doc(widget.studentId)
          .get();

      if (!studentDoc.exists) {
        throw Exception('Student not found');
      }

      _studentData = studentDoc.data() as Map<String, dynamic>;

      // Use classId instead of schoolId based on the database structure
      _classId = _studentData!['classId'] ?? '';

      if (_classId.isEmpty) {
        throw Exception('Class ID not found for student');
      }

      print('Student ClassId: $_classId'); // Debug print

      // Step 2: Get class data for displaying class info
      await _fetchClassData();

      // Step 3: Get grades for the class
      QuerySnapshot gradesQuery = await _firestore
          .collection('grades')
          .where('classId', isEqualTo: _classId)
          .get();

      print('Found ${gradesQuery.docs.length} grade documents'); // Debug print

      List<Map<String, dynamic>> studentGradesList = [];

      // Step 3: Process each grade document
      for (QueryDocumentSnapshot gradeDoc in gradesQuery.docs) {
        Map<String, dynamic> gradeData = gradeDoc.data() as Map<String, dynamic>;

        print('Processing grade document: ${gradeDoc.id}'); // Debug print
        print('Grade data: $gradeData'); // Debug print

        // Get the grades array
        List<dynamic> grades = gradeData['grades'] ?? [];

        print('Grades array length: ${grades.length}'); // Debug print

        // Find this student's grade in the array
        for (var gradeEntry in grades) {
          if (gradeEntry is Map<String, dynamic> &&
              gradeEntry['studentId'] == widget.studentId) {

            print('Found grade for student: $gradeEntry'); // Debug print

            // Get subject name
            String subjectId = gradeData['subjectId'] ?? '';
            String subjectName = await _getSubjectName(subjectId);

            // Get teacher name - use teacherName from the grade document
            String teacherName = gradeData['teacherName'] ?? 'Unknown Teacher';

            studentGradesList.add({
              'subjectName': subjectName,
              'grade': gradeEntry['grade'] ?? 'N/A',
              'subjectId': subjectId,
              'teacherId': gradeData['teacherId'] ?? '',
              'teacherName': teacherName,
            });
            break;
          }
        }
      }

      print('Final grades list: $studentGradesList'); // Debug print

      setState(() {
        _studentGrades = studentGradesList;
        _isLoading = false;
      });

    } catch (e) {
      print('Error fetching grades: $e'); // Debug print
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchClassData() async {
    try {
      if (_classId.isNotEmpty) {
        DocumentSnapshot classDoc = await _firestore
            .collection('classes')
            .doc(_classId)
            .get();

        if (classDoc.exists) {
          _classData = classDoc.data() as Map<String, dynamic>;
          print('Class data: $_classData'); // Debug print
        }
      }
    } catch (e) {
      print('Error fetching class data: $e');
    }
  }

  Future<String> _getSubjectName(String subjectId) async {
    try {
      if (subjectId.isEmpty) {
        return 'Unknown Subject';
      }

      DocumentSnapshot subjectDoc = await _firestore
          .collection('subjects')
          .doc(subjectId)
          .get();

      if (subjectDoc.exists) {
        Map<String, dynamic> subjectData = subjectDoc.data() as Map<String, dynamic>;
        return subjectData['name'] ?? 'Unknown Subject';
      }
    } catch (e) {
      print('Error fetching subject name for $subjectId: $e');
    }
    return 'Unknown Subject';
  }

  Color _getGradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'A':
        return Colors.green;
      case 'B':
        return Colors.blue;
      case 'C':
        return Colors.orange;
      case 'D':
        return Colors.red.shade300;
      case 'F':
      case 'FAIL':
        return Colors.red;
      case 'O':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text(
          'Student Grades',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue.shade700,
        elevation: 8,
        shadowColor: Colors.blue.shade200,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchStudentGrades,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            Text(
              'Loading grades...',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )
          : _error.isNotEmpty
          ? Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red.shade600,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Error Loading Grades',
                style: TextStyle(
                  color: Colors.red.shade800,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error,
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchStudentGrades,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchStudentGrades,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Student Information Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade200,
                      blurRadius: 10,
                      offset: const Offset(0, 5),
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
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Student Information',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _studentData?['name'] ?? 'Unknown Student',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildInfoItem(
                              'Email',
                              _studentData?['email'] ?? 'N/A',
                              Icons.email,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withOpacity(0.3),
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          Expanded(
                            child: _buildInfoItem(
                              'Phone',
                              _studentData?['phone'] ?? 'N/A',
                              Icons.phone,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Class info instead of debug class ID
                    if (_classData != null)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.class_,
                              color: Colors.white.withOpacity(0.8),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Class Information',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Grade ${_classData?['grade'] ?? 'N/A'} - Section ${_classData?['section'] ?? 'N/A'}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Grades Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade100,
                      blurRadius: 10,
                      offset: const Offset(0, 5),
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
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.grade,
                            color: Colors.blue.shade700,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Academic Grades',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Text(
                            '${_studentGrades.length} Subject${_studentGrades.length != 1 ? 's' : ''}',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    if (_studentGrades.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              size: 64,
                              color: Colors.blue.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Grades Available',
                              style: TextStyle(
                                color: Colors.blue.shade600,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Grades will appear here once they are assigned by teachers.',
                              style: TextStyle(
                                color: Colors.blue.shade400,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                    // Grades Table
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue.shade100),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            // Table Header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 20,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Subject',
                                      style: TextStyle(
                                        color: Colors.blue.shade800,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      'Grade',
                                      style: TextStyle(
                                        color: Colors.blue.shade800,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Teacher',
                                      style: TextStyle(
                                        color: Colors.blue.shade800,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Table Rows
                            ...List.generate(_studentGrades.length, (index) {
                              final grade = _studentGrades[index];
                              final isLast = index == _studentGrades.length - 1;

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 20,
                                ),
                                decoration: BoxDecoration(
                                  color: index % 2 == 0
                                      ? Colors.white
                                      : Colors.blue.shade50,
                                  borderRadius: isLast
                                      ? const BorderRadius.only(
                                    bottomLeft: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  )
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            grade['subjectName'],
                                            style: TextStyle(
                                              color: Colors.blue.shade800,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        alignment: Alignment.center,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getGradeColor(grade['grade']),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            grade['grade'],
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        grade['teacherName'],
                                        style: TextStyle(
                                          color: Colors.blue.shade600,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
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
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.8),
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}