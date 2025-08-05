import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AssignmentManagerScreen extends StatefulWidget {
  final String teacherId;
  final String schoolId;
  const AssignmentManagerScreen({Key? key, required this.teacherId, required this.schoolId}) : super(key: key);

  @override
  State<AssignmentManagerScreen> createState() => _AssignmentManagerScreenState();
}

class _AssignmentManagerScreenState extends State<AssignmentManagerScreen> {
  String? _selectedClassId;
  String? _selectedClassName;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _selectedDueDate;
  bool _isLoading = false;
  bool _isCreatingAssignment = false;
  String? _editingAssignmentId;
  late Future<List<Map<String, dynamic>>> _classesFuture;

  // Blue Color Palette - Same as TeacherClassesAndStudentsScreen
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
    _classesFuture = _fetchAssignedClasses();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchAssignedClasses() async {
    try {
      final teacherDoc = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(widget.teacherId)
          .get();

      if (!teacherDoc.exists) return [];

      final teacherData = teacherDoc.data();
      final classIds = List<String>.from(teacherData?['classesAssigned'] ?? []);

      List<Map<String, dynamic>> classes = [];

      for (String classId in classIds) {
        final classDoc = await FirebaseFirestore.instance
            .collection('classes')
            .doc(classId)
            .get();

        if (classDoc.exists) {
          final classData = classDoc.data();
          if (classData != null) {
            classes.add({
              'id': classDoc.id,
              'data': classData,
            });
          }
        }
      }

      return classes;
    } catch (e) {
      _showSnackBar('Error loading classes: $e', Colors.red, Icons.error_outline);
      return [];
    }
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: accentBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDueDate = picked);
    }
  }

  Future<void> _createOrUpdate() async {
    if (!_formKey.currentState!.validate() || _selectedDueDate == null) {
      _showSnackBar('Please fill all fields and select due date', Colors.orange, Icons.warning);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final ref = _editingAssignmentId == null
          ? FirebaseFirestore.instance.collection('assignments').doc()
          : FirebaseFirestore.instance.collection('assignments').doc(_editingAssignmentId);

      await ref.set({
        'assignmentId': ref.id,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'dueDate': _selectedDueDate!.toIso8601String(),
        'classId': _selectedClassId,
        'className': _selectedClassName,
        'schoolId': widget.schoolId,
        'teacherId': widget.teacherId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _showSnackBar(
          _editingAssignmentId == null ? 'Assignment created successfully!' : 'Assignment updated successfully!',
          Colors.green,
          Icons.check_circle
      );

      _clearForm();
    } catch (e) {
      _showSnackBar('Error saving assignment: $e', Colors.red, Icons.error);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    setState(() {
      _isCreatingAssignment = false;
      _editingAssignmentId = null;
      _titleController.clear();
      _descriptionController.clear();
      _selectedDueDate = null;
    });
  }

  Future<void> _deleteAssignment(String docId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Delete Assignment'),
          ],
        ),
        content: Text('Are you sure you want to delete "$title"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('assignments').doc(docId).delete();
        _showSnackBar('Assignment deleted successfully', Colors.green, Icons.delete);
      } catch (e) {
        _showSnackBar('Error deleting assignment: $e', Colors.red, Icons.error);
      }
    }
  }

  void _editAssignment(DocumentSnapshot doc) {
    setState(() {
      _editingAssignmentId = doc.id;
      _titleController.text = doc['title'];
      _descriptionController.text = doc['description'];

      // Handle different date formats
      final dueDate = doc['dueDate'];
      if (dueDate is Timestamp) {
        _selectedDueDate = dueDate.toDate();
      } else if (dueDate is String) {
        _selectedDueDate = DateTime.tryParse(dueDate);
      }

      _isCreatingAssignment = true;
    });
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

  String _formatDate(dynamic rawDate) {
    if (rawDate is Timestamp) {
      return rawDate.toDate().toString().split(' ')[0];
    }
    if (rawDate is String) {
      final date = DateTime.tryParse(rawDate);
      return date?.toString().split(' ')[0] ?? rawDate.split('T').first;
    }
    return '—';
  }

  Widget _buildClassesView() {
    return FutureBuilder<List<Map<String, dynamic>>>(
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
                      Icons.assignment_outlined,
                      size: 48,
                      color: secondaryBlue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "No Classes Available",
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
                    child: const Icon(Icons.assignment_rounded, size: 32, color: secondaryBlue),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assignment Manager',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select a class to manage assignments',
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
                          colors: [secondaryBlue.withOpacity(0.1), accentBlue.withOpacity(0.05)],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: const Text(
                        "Select a Class",
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
                          final className = '${classData['grade']} - ${classData['section']}';

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
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: paleBlue.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  setState(() {
                                    _selectedClassId = classId;
                                    _selectedClassName = className;
                                    _isCreatingAssignment = false;
                                    _clearForm();
                                  });
                                },
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
                                          Icons.class_,
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
                                              className,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                                color: primaryBlue,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Teacher: ${classData['classTeacher'] ?? 'Not assigned'}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: primaryBlue.withOpacity(0.7),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_forward_ios,
                                        color: accentBlue,
                                        size: 16,
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
          ],
        );
      },
    );
  }

  Widget _buildAssignmentsList() {
    return Column(
      children: [
        // Header with Back Button
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
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedClassId = null;
                    _selectedClassName = null;
                    _clearForm();
                  });
                },
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_back, color: accentBlue),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assignments - $_selectedClassName',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Manage assignments for this class',
                      style: TextStyle(
                        fontSize: 14,
                        color: primaryBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Assignments List
        Expanded(
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('assignments')
                  .where('classId', isEqualTo: _selectedClassId)
                  .where('teacherId', isEqualTo: widget.teacherId)
                  .snapshots(),
              builder: (context, snapshot) {
                // Handle connection state
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(secondaryBlue),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading assignments...',
                          style: TextStyle(
                            color: primaryBlue,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Handle errors
                if (snapshot.hasError) {
                  print('Firestore Error: ${snapshot.error}'); // Debug log
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Error Loading Assignments',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Error: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryBlue.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Handle empty or null data
                if (!snapshot.hasData || snapshot.data == null) {
                  print('No data available'); // Debug log
                  return _buildEmptyAssignmentsView();
                }

                final assignments = snapshot.data!.docs;
                print('Found ${assignments.length} assignments'); // Debug log

                return Column(
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
                            child: const Icon(Icons.assignment, size: 18, color: accentBlue),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "Your Assignments",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: primaryBlue,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: lightBlue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${assignments.length}',
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
                      child: assignments.isEmpty
                          ? _buildEmptyAssignmentsView()
                          : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: assignments.length,
                        itemBuilder: (context, index) {
                          final assignment = assignments[index];
                          final data = assignment.data() as Map<String, dynamic>?;

                          // Safety check for data
                          if (data == null) {
                            return const SizedBox.shrink();
                          }

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
                                        child: const Icon(
                                          Icons.assignment,
                                          color: accentBlue,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          data['title'] ?? 'Untitled Assignment',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: primaryBlue,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            onPressed: () => _editAssignment(assignment),
                                            icon: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Icon(
                                                Icons.edit,
                                                color: Colors.orange,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () => _deleteAssignment(
                                              assignment.id,
                                              data['title'] ?? 'Untitled Assignment',
                                            ),
                                            icon: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.red.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    data['description'] ?? 'No description provided',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: primaryBlue.withOpacity(0.8),
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: lightBlue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: lightBlue.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.calendar_today,
                                          size: 14,
                                          color: accentBlue,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Due: ${_formatDate(data['dueDate'])}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: accentBlue,
                                          ),
                                        ),
                                      ],
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
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyAssignmentsView() {
    return Center(
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
                Icons.assignment_outlined,
                size: 48,
                color: lightBlue.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "No Assignments Yet",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: primaryBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Create your first assignment for this class by tapping the + button below.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: primaryBlue.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentForm() {
    return Container(
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
      child: Column(
        children: [
          // Header
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
                IconButton(
                  onPressed: _clearForm,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.arrow_back, color: accentBlue),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _editingAssignmentId == null ? 'Create Assignment' : 'Edit Assignment',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'For $_selectedClassName',
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

          // Form
          Expanded(
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
              child: _isLoading
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(secondaryBlue),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Saving assignment...',
                      style: TextStyle(
                        color: primaryBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
                  : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Title Field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assignment Title',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            hintText: 'Enter assignment title',
                            prefixIcon: const Icon(Icons.title, color: accentBlue),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: paleBlue.withOpacity(0.5)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: paleBlue.withOpacity(0.5)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: accentBlue, width: 2),
                            ),
                            filled: true,
                            fillColor: surfaceBlue.withOpacity(0.3),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter assignment title';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Description Field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assignment Description',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Enter assignment description and instructions',
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 60),
                              child: Icon(Icons.description, color: accentBlue),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: paleBlue.withOpacity(0.5)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: paleBlue.withOpacity(0.5)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: accentBlue, width: 2),
                            ),
                            filled: true,
                            fillColor: surfaceBlue.withOpacity(0.3),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter assignment description';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Due Date Field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Due Date',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: paleBlue.withOpacity(0.5)),
                            borderRadius: BorderRadius.circular(12),
                            color: surfaceBlue.withOpacity(0.3),
                          ),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: const Icon(Icons.calendar_today, color: accentBlue),
                            title: Text(
                              _selectedDueDate == null
                                  ? 'Select Due Date'
                                  : 'Due: ${_selectedDueDate!.toLocal().toString().split(' ')[0]}',
                              style: TextStyle(
                                color: _selectedDueDate == null
                                    ? primaryBlue.withOpacity(0.6)
                                    : primaryBlue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: const Icon(Icons.arrow_drop_down, color: accentBlue),
                            onTap: _selectDueDate,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _createOrUpdate,
                            icon: Icon(_editingAssignmentId == null ? Icons.add : Icons.save),
                            label: Text(_editingAssignmentId == null ? 'Create Assignment' : 'Update Assignment'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: _clearForm,
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Cancel'),
                            style: TextButton.styleFrom(
                              foregroundColor: primaryBlue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
        title: Text(
          _selectedClassName == null
              ? 'Assignment Manager'
              : _isCreatingAssignment
              ? (_editingAssignmentId == null ? 'Create Assignment' : 'Edit Assignment')
              : 'Assignments - $_selectedClassName',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.assignment, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  _selectedClassName == null ? 'Classes' : 'Assignments',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: (_selectedClassId != null && !_isCreatingAssignment)
          ? FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            _editingAssignmentId = null;
            _titleController.clear();
            _descriptionController.clear();
            _selectedDueDate = null;
            _isCreatingAssignment = true;
          });
        },
        backgroundColor: accentBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'New Assignment',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
      )
          : null,
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
        child: _selectedClassId == null
            ? _buildClassesView()
            : _isCreatingAssignment
            ? _buildAssignmentForm()
            : _buildAssignmentsList(),
      ),
    );
  }
}