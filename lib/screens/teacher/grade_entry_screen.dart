import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GradeEntryScreen extends StatefulWidget {
  final String teacherId;

  const GradeEntryScreen({Key? key, required this.teacherId}) : super(key: key);

  @override
  State<GradeEntryScreen> createState() => _GradeEntryScreenState();
}

class _GradeEntryScreenState extends State<GradeEntryScreen> {
  String? selectedClassId;
  String? selectedSubjectId;
  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> subjects = [];
  List<Map<String, dynamic>> students = [];
  Map<String, String> grades = {};

  bool isLoadingClasses = true;
  bool isLoadingSubjects = false;
  bool isLoadingStudents = false;
  bool isSubmitting = false;

  final gradeOptions = ['O', 'A+', 'A', 'B+', 'B', 'C', 'Fail'];

  String? teacherName;

  @override
  void initState() {
    super.initState();
    loadClasses();
  }

  Future<void> loadClasses() async {
    setState(() {
      isLoadingClasses = true;
    });

    try {
      final teacherDoc = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(widget.teacherId)
          .get();

      final teacherData = teacherDoc.data();
      if (teacherData == null) {
        _showErrorSnackBar("Teacher data not found");
        return;
      }

      teacherName = teacherData['meta']['name'];

      // Get classes where this teacher is the class teacher
      final classQuery = await FirebaseFirestore.instance
          .collection('classes')
          .where('teacherId', isEqualTo: widget.teacherId)
          .get();

      classes = classQuery.docs
          .map((doc) => {'id': doc.id, 'data': doc.data()})
          .toList();

    } catch (e) {
      _showErrorSnackBar("Error loading classes: $e");
    }

    setState(() {
      isLoadingClasses = false;
    });
  }

  Future<void> loadSubjectsForClass(String classId) async {
    setState(() {
      isLoadingSubjects = true;
      subjects.clear();
      selectedSubjectId = null;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('subjects')
          .where('classIds', arrayContains: classId)
          .get();

      subjects = querySnapshot.docs
          .where((doc) => List<String>.from(doc['teacherIds'] ?? [])
          .contains(widget.teacherId))
          .map((doc) => {'id': doc.id, 'data': doc.data()})
          .toList();

    } catch (e) {
      _showErrorSnackBar("Error loading subjects: $e");
    }

    setState(() {
      isLoadingSubjects = false;
    });
  }

  Future<void> loadStudents(String classId) async {
    setState(() {
      isLoadingStudents = true;
      students.clear();
      grades.clear();
    });

    try {
      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .get();

      final studentIds = List<String>.from(classDoc.data()?['studentIds'] ?? []);

      for (final studentId in studentIds) {
        final studentDoc = await FirebaseFirestore.instance
            .collection('students')
            .doc(studentId)
            .get();

        if (studentDoc.exists) {
          students.add({'id': studentId, 'data': studentDoc.data()});
        }
      }

      // Load existing grades if any
      await loadExistingGrades();

    } catch (e) {
      _showErrorSnackBar("Error loading students: $e");
    }

    setState(() {
      isLoadingStudents = false;
    });
  }

  Future<void> loadExistingGrades() async {
    if (selectedClassId == null || selectedSubjectId == null) return;

    try {
      final gradeQuery = await FirebaseFirestore.instance
          .collection('grades')
          .where('classId', isEqualTo: selectedClassId)
          .where('subjectId', isEqualTo: selectedSubjectId)
          .where('teacherId', isEqualTo: widget.teacherId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (gradeQuery.docs.isNotEmpty) {
        final gradeDoc = gradeQuery.docs.first;
        final existingGrades = List<Map<String, dynamic>>.from(
            gradeDoc.data()['grades'] ?? []);

        for (final gradeEntry in existingGrades) {
          grades[gradeEntry['studentId']] = gradeEntry['grade'];
        }
      }
    } catch (e) {
      print("Error loading existing grades: $e");
    }
  }

  Future<void> submitGrades() async {
    if (selectedClassId == null || selectedSubjectId == null || grades.isEmpty) {
      _showErrorSnackBar("Please select class, subject and enter grades");
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final timestamp = Timestamp.now();

      await FirebaseFirestore.instance.collection('grades').add({
        'classId': selectedClassId,
        'subjectId': selectedSubjectId,
        'teacherId': widget.teacherId,
        'teacherName': teacherName,
        'grades': grades.entries
            .map((entry) => {
          'studentId': entry.key,
          'grade': entry.value,
        })
            .toList(),
        'timestamp': timestamp,
        'createdAt': timestamp,
      });

      _showSuccessSnackBar("Grades submitted successfully!");

      // Clear grades after successful submission
      setState(() {
        grades.clear();
      });

    } catch (e) {
      _showErrorSnackBar("Error submitting grades: $e");
    }

    setState(() {
      isSubmitting = false;
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Grade Entry",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue[800],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoadingClasses
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      )
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[400]!, Colors.blue[600]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Welcome, $teacherName",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Enter grades for your assigned classes",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Class Selection Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.school, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            "Select Class",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: InputBorder.none,
                            hintText: classes.isEmpty
                                ? 'No classes assigned'
                                : 'Choose a class',
                            hintStyle: TextStyle(color: Colors.blue[400]),
                          ),
                          value: selectedClassId,
                          items: classes.map((cls) {
                            final data = cls['data'];
                            return DropdownMenuItem<String>(
                              value: cls['id'],
                              child: Text(
                                'Grade ${data['grade']} - Section ${data['section']}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            );
                          }).toList(),
                          onChanged: classes.isEmpty ? null : (value) async {
                            setState(() {
                              selectedClassId = value;
                              selectedSubjectId = null;
                              subjects.clear();
                              students.clear();
                              grades.clear();
                            });
                            if (value != null) {
                              await loadSubjectsForClass(value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Subject Selection Card
              if (selectedClassId != null) ...[
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.book, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              "Select Subject",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        isLoadingSubjects
                            ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        )
                            : Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: InputBorder.none,
                              hintText: subjects.isEmpty
                                  ? 'No subjects assigned'
                                  : 'Choose a subject',
                              hintStyle: TextStyle(color: Colors.blue[400]),
                            ),
                            value: selectedSubjectId,
                            items: subjects.map((subj) {
                              final data = subj['data'];
                              return DropdownMenuItem<String>(
                                value: subj['id'],
                                child: Text(
                                  data['name'],
                                  style: const TextStyle(fontSize: 16),
                                ),
                              );
                            }).toList(),
                            onChanged: subjects.isEmpty ? null : (value) async {
                              setState(() {
                                selectedSubjectId = value;
                                students.clear();
                                grades.clear();
                              });
                              if (selectedClassId != null) {
                                await loadStudents(selectedClassId!);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Students Grade Entry Card
              if (selectedSubjectId != null) ...[
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.people, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              "Student Grades",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        isLoadingStudents
                            ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(),
                          ),
                        )
                            : students.isEmpty
                            ? Container(
                          padding: const EdgeInsets.all(40),
                          child: const Center(
                            child: Text(
                              "No students found in this class",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                            : Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue[200]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: MaterialStateProperty.all(
                                Colors.blue[50],
                              ),
                              columns: [
                                DataColumn(
                                  label: Text(
                                    "Student Name",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[800],
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    "Grade",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[800],
                                    ),
                                  ),
                                ),
                              ],
                              rows: students.map((student) {
                                final studentId = student['id'];
                                final name = student['data']['name'] ?? 'Unnamed';

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        name,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.blue[300]!,
                                          ),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: DropdownButton<String>(
                                          value: grades[studentId],
                                          hint: Text(
                                            "Select Grade",
                                            style: TextStyle(
                                              color: Colors.blue[400],
                                              fontSize: 14,
                                            ),
                                          ),
                                          underline: const SizedBox(),
                                          items: gradeOptions
                                              .map((grade) => DropdownMenuItem(
                                            value: grade,
                                            child: Text(
                                              grade,
                                              style: TextStyle(
                                                color: _getGradeColor(grade),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ))
                                              .toList(),
                                          onChanged: (value) {
                                            setState(() {
                                              if (value != null) {
                                                grades[studentId] = value;
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: grades.isEmpty || isSubmitting ? null : submitGrades,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: isSubmitting
                        ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          "Submitting...",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                        : const Text(
                      "Submit Grades",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'O':
        return Colors.green[700]!;
      case 'A+':
        return Colors.green[600]!;
      case 'A':
        return Colors.green[500]!;
      case 'B+':
        return Colors.blue[600]!;
      case 'B':
        return Colors.blue[500]!;
      case 'C':
        return Colors.orange[600]!;
      case 'Fail':
        return Colors.red[600]!;
      default:
        return Colors.grey[700]!;
    }
  }
}