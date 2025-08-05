import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherClassesAndStudentsScreen extends StatefulWidget {
  final String teacherId;

  const TeacherClassesAndStudentsScreen({Key? key, required this.teacherId}) : super(key: key);

  @override
  State<TeacherClassesAndStudentsScreen> createState() => _TeacherClassesAndStudentsScreenState();
}

class _TeacherClassesAndStudentsScreenState extends State<TeacherClassesAndStudentsScreen> {
  late Future<List<Map<String, dynamic>>> _classesFuture;
  String? _selectedClassId;
  List<Map<String, dynamic>> _students = [];
  bool _isLoadingStudents = false;

  // Blue Color Palette - Same as ClassCreationScreen
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
    _classesFuture = _fetchClasses(widget.teacherId);
  }

  Future<List<Map<String, dynamic>>> _fetchClasses(String teacherId) async {
    final teacherDoc = await FirebaseFirestore.instance.collection('teachers').doc(teacherId).get();
    final data = teacherDoc.data();

    if (data == null) return [];

    List classIds = data['classesAssigned'] ?? [];
    String? classTeacherId = data['classTeacher'];

    List<Map<String, dynamic>> classes = [];

    for (String classId in classIds) {
      final classDoc = await FirebaseFirestore.instance.collection('classes').doc(classId).get();
      final classData = classDoc.data();

      if (classData != null) {
        bool isClassTeacher = (classId == classTeacherId);
        classes.add({
          'id': classDoc.id,
          'data': classData,
          'isClassTeacher': isClassTeacher,
        });
      }
    }

    return classes;
  }

  Future<void> _fetchStudents(String classId) async {
    setState(() {
      _selectedClassId = classId;
      _students = [];
      _isLoadingStudents = true;
    });

    try {
      final classDoc = await FirebaseFirestore.instance.collection('classes').doc(classId).get();
      final classData = classDoc.data();
      final studentIds = List<String>.from(classData?['studentIds'] ?? []);

      List<Map<String, dynamic>> fetchedStudents = [];

      for (String studentId in studentIds) {
        final studentDoc = await FirebaseFirestore.instance.collection('students').doc(studentId).get();
        if (studentDoc.exists) {
          final studentData = studentDoc.data();
          if (studentData != null) {
            fetchedStudents.add(studentData);
          }
        }
      }

      setState(() {
        _students = fetchedStudents;
        _isLoadingStudents = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingStudents = false;
      });
      _showSnackBar('Error loading students: $e', Colors.red[400]!, Icons.error_outline_rounded);
    }
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundBlue,
      appBar: AppBar(
        title: const Text(
          "Your Classes & Students",
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
                Icon(Icons.people_outline, size: 16, color: Colors.white),
                SizedBox(width: 4),
                Text('Students', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)),
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
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _classesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
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
                            color: primaryBlue.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(secondaryBlue),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading your classes...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }

            final classes = snapshot.data ?? [];

            if (classes.isEmpty) {
              return Center(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(32),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accentBlue.withOpacity(0.1), lightBlue.withOpacity(0.1)],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: lightBlue.withOpacity(0.3), width: 2),
                        ),
                        child: const Icon(
                          Icons.class_outlined,
                          size: 48,
                          color: secondaryBlue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "No Classes Assigned",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "You haven't been assigned to any classes yet.\nPlease contact your administrator.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: primaryBlue.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: [
                // Header Section
                Container(
                  margin: const EdgeInsets.all(20),
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
                  child: Row(
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
                        child: const Icon(Icons.school_rounded, size: 32, color: secondaryBlue),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Classes',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: primaryBlue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${classes.length} class${classes.length == 1 ? '' : 'es'} assigned',
                              style: TextStyle(
                                fontSize: 14,
                                color: primaryBlue.withOpacity(0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Classes List
                Expanded(
                  flex: _selectedClassId != null ? 2 : 3,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, surfaceBlue],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: primaryBlue.withOpacity(0.08),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [secondaryBlue.withOpacity(0.1), accentBlue.withOpacity(0.05)],
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          child: const Text(
                            "Assigned Classes",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: primaryBlue,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: classes.length,
                            itemBuilder: (context, index) {
                              final classInfo = classes[index];
                              final classData = classInfo['data'];
                              final classId = classInfo['id'];
                              final isClassTeacher = classInfo['isClassTeacher'];
                              final isSelected = _selectedClassId == classId;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: isSelected
                                        ? [accentBlue.withOpacity(0.1), lightBlue.withOpacity(0.05)]
                                        : [Colors.white, surfaceBlue.withOpacity(0.5)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isSelected
                                          ? accentBlue.withOpacity(0.2)
                                          : lightBlue.withOpacity(0.1),
                                      blurRadius: 15,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: isSelected
                                        ? accentBlue.withOpacity(0.4)
                                        : paleBlue.withOpacity(0.3),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => _fetchStudents(classId),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: isClassTeacher
                                                    ? [Colors.green.withOpacity(0.2), Colors.green.withOpacity(0.1)]
                                                    : [Colors.orange.withOpacity(0.2), Colors.orange.withOpacity(0.1)],
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isClassTeacher
                                                    ? Colors.green.withOpacity(0.4)
                                                    : Colors.orange.withOpacity(0.4),
                                              ),
                                            ),
                                            child: Icon(
                                              isClassTeacher ? Icons.admin_panel_settings : Icons.subject,
                                              color: isClassTeacher ? Colors.green : Colors.orange,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "${classData['grade']} - ${classData['section']}",
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 16,
                                                    color: primaryBlue,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isClassTeacher
                                                        ? Colors.green.withOpacity(0.1)
                                                        : Colors.orange.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: isClassTeacher
                                                          ? Colors.green.withOpacity(0.3)
                                                          : Colors.orange.withOpacity(0.3),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    isClassTeacher ? "Class Teacher" : "Subject Teacher",
                                                    style: TextStyle(
                                                      color: isClassTeacher ? Colors.green : Colors.orange,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            isSelected ? Icons.expand_less : Icons.people_outline,
                                            color: isSelected ? accentBlue : primaryBlue.withOpacity(0.6),
                                            size: 24,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Students Section
                if (_selectedClassId != null) ...[
                  const SizedBox(height: 16),
                  Expanded(
                    flex: 3,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.white, surfaceBlue],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: primaryBlue.withOpacity(0.08),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [accentBlue.withOpacity(0.1), lightBlue.withOpacity(0.05)],
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
                                    color: accentBlue.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.people_outline, size: 18, color: accentBlue),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  "Students in Selected Class",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: primaryBlue,
                                  ),
                                ),
                                const Spacer(),
                                if (!_isLoadingStudents)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: lightBlue.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_students.length}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: secondaryBlue,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: _isLoadingStudents
                                ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(secondaryBlue),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Loading students...',
                                    style: TextStyle(
                                      color: primaryBlue,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                                : _students.isEmpty
                                ? Center(
                              child: Container(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: lightBlue.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.person_outline,
                                        size: 48,
                                        color: lightBlue.withOpacity(0.6),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      "No Students Found",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: primaryBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "This class doesn't have any students assigned yet.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: primaryBlue.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                                : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _students.length,
                              itemBuilder: (context, index) {
                                final student = _students[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Colors.white, surfaceBlue],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: lightBlue.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: paleBlue.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [accentBlue.withOpacity(0.1), lightBlue.withOpacity(0.1)],
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: lightBlue.withOpacity(0.3)),
                                          ),
                                          child: const Icon(
                                            Icons.person,
                                            color: accentBlue,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                student['name'] ?? 'No Name',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: primaryBlue,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                student['email'] ?? 'No Email',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: primaryBlue.withOpacity(0.7),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                                          ),
                                          child: const Text(
                                            'Active',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}