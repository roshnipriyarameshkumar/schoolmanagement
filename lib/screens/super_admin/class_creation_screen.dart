import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ClassCreationScreen extends StatefulWidget {
  final String schoolId;

  const ClassCreationScreen({Key? key, required this.schoolId}) : super(key: key);

  @override
  State<ClassCreationScreen> createState() => _ClassCreationScreenState();
}

class _ClassCreationScreenState extends State<ClassCreationScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedGrade;
  String? _selectedSection;
  int? _capacity;
  String? _selectedTeacherId;
  String? _editingClassId; // Track which class is being edited
  final TextEditingController _capacityController = TextEditingController();

  final List<String> grades = ['1st', '2nd', '3rd', '4th', '5th', '6th', '7th', '8th', '9th', '10th', '11th', '12th'];
  final List<String> sections = ['A', 'B', 'C', 'D', 'E'];

  List<Map<String, dynamic>> _teachers = [];
  List<DocumentSnapshot> _classes = [];
  bool _isLoading = false;
  bool _isLoadingData = true; // Track initial data loading

  // Blue Color Palette
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
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingData = true);
    await Future.wait([
      _fetchTeachers(),
      _fetchClasses(),
    ]);
    setState(() => _isLoadingData = false);
  }

  Future<void> _fetchTeachers() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('teachers').get();
      setState(() {
        _teachers = snapshot.docs.map((doc) => {
          'id': doc.id,
          'name': doc['meta']?['name'] ?? doc['name'] ?? 'Unknown Teacher',
        }).toList();
      });
    } catch (e) {
      _showSnackBar('Error loading teachers: $e', Colors.red[400]!, Icons.error_outline_rounded);
    }
  }

  Future<void> _fetchClasses() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('schoolId', isEqualTo: widget.schoolId)
          .get();
      setState(() {
        _classes = snapshot.docs;
      });
    } catch (e) {
      _showSnackBar('Error loading classes: $e', Colors.red[400]!, Icons.error_outline_rounded);
    }
  }

  Future<void> _saveClass() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTeacherId == null) {
      _showSnackBar('Please select a class teacher', Colors.red[400]!, Icons.warning_rounded);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final selectedTeacher = _teachers.firstWhere(
            (t) => t['id'] == _selectedTeacherId,
        orElse: () => {'id': _selectedTeacherId, 'name': 'Unknown Teacher'},
      );

      final classData = {
        'grade': _selectedGrade,
        'section': _selectedSection,
        'capacity': _capacity,
        'classTeacher': selectedTeacher['name'],
        'teacherId': _selectedTeacherId,
        'schoolId': widget.schoolId,
        'subjectIds': [],
        'studentIds': [],
        'timestamp': Timestamp.now(),
        'teachersAssigned': [_selectedTeacherId],
      };

      if (_editingClassId == null) {
        // Create new class
        final classDocRef = await FirebaseFirestore.instance.collection('classes').add(classData);
        final newClassId = classDocRef.id;

        // Update school document
        await FirebaseFirestore.instance.collection('schools').doc(widget.schoolId).update({
          'classIds': FieldValue.arrayUnion([newClassId])
        });

        // Update teacher document
        await FirebaseFirestore.instance.collection('teachers').doc(_selectedTeacherId).update({
          'classesAssigned': FieldValue.arrayUnion([newClassId]),
          'teacherAssigned': FieldValue.arrayUnion([newClassId]),
          'classTeacher': newClassId,
        });

        _showSnackBar('Class created successfully', Colors.green, Icons.check_circle_rounded);
      } else {
        // Update existing class
        final classRef = FirebaseFirestore.instance.collection('classes').doc(_editingClassId);
        await classRef.update(classData);

        // Update teacher document
        await FirebaseFirestore.instance.collection('teachers').doc(_selectedTeacherId).update({
          'classesAssigned': FieldValue.arrayUnion([_editingClassId]),
          'teacherAssigned': FieldValue.arrayUnion([_editingClassId]),
          'classTeacher': _editingClassId,
        });

        _showSnackBar('Class updated successfully', Colors.green, Icons.check_circle_rounded);
      }

      _resetForm();
      await _fetchClasses();
    } catch (e) {
      _showSnackBar('Error saving class: $e', Colors.red[400]!, Icons.error_outline_rounded);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    setState(() {
      _selectedGrade = null;
      _selectedSection = null;
      _selectedTeacherId = null;
      _editingClassId = null;
      _capacityController.clear();
    });
    _formKey.currentState?.reset();
  }

  void _editClass(DocumentSnapshot classDoc) {
    final data = classDoc.data() as Map<String, dynamic>;

    setState(() {
      _editingClassId = classDoc.id;

      // Safely set grade - ensure it exists in grades list
      final grade = data['grade'];
      _selectedGrade = (grade != null && grades.contains(grade)) ? grade : null;

      // Safely set section - ensure it exists in sections list
      final section = data['section'];
      _selectedSection = (section != null && sections.contains(section)) ? section : null;

      // Safely set capacity
      final capacity = data['capacity'];
      if (capacity != null) {
        _capacityController.text = capacity.toString();
      } else {
        _capacityController.clear();
      }

      // Safely set teacher ID - ensure teacher exists in teachers list
      final teacherId = data['teacherId'];
      if (teacherId != null && _teachers.isNotEmpty && _teachers.any((t) => t['id'] == teacherId)) {
        _selectedTeacherId = teacherId;
      } else {
        _selectedTeacherId = null;
      }
    });

    // Show a message if some data couldn't be loaded
    if (_selectedGrade == null || _selectedSection == null || _selectedTeacherId == null) {
      _showSnackBar(
          'Some class data may be incomplete. Please verify all fields.',
          Colors.orange[400]!,
          Icons.warning_outlined
      );
    }

    // Scroll to top to show the form
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_formKey.currentContext != null) {
        Scrollable.ensureVisible(
          _formKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _deleteClass(String classId, String? teacherId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Delete Class', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this class? This action cannot be undone.',
          style: TextStyle(color: primaryBlue, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('classes').doc(classId).delete();

      await FirebaseFirestore.instance.collection('schools').doc(widget.schoolId).update({
        'classIds': FieldValue.arrayRemove([classId])
      });

      if (teacherId != null) {
        await FirebaseFirestore.instance.collection('teachers').doc(teacherId).update({
          'classesAssigned': FieldValue.arrayRemove([classId]),
          'teacherAssigned': FieldValue.arrayRemove([classId]),
          'classTeacher': FieldValue.delete(),
        });
      }

      _showSnackBar('Class deleted successfully', Colors.green, Icons.check_circle_rounded);
      await _fetchClasses();

      // Reset form if we were editing the deleted class
      if (_editingClassId == classId) {
        _resetForm();
      }
    } catch (e) {
      _showSnackBar('Error deleting class: $e', Colors.red[400]!, Icons.error_outline_rounded);
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
    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: backgroundBlue,
        appBar: AppBar(
          title: const Text('Manage Classes'),
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(secondaryBlue),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundBlue,
      appBar: AppBar(
        title: const Text(
          'Manage Classes',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
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
                Icon(Icons.class_outlined, size: 16, color: Colors.white),
                SizedBox(width: 4),
                Text('Classes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Animated Header Card
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: double.infinity,
                padding: const EdgeInsets.all(28),
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
                    BoxShadow(
                      color: accentBlue.withOpacity(0.05),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                  border: Border.all(
                    color: paleBlue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
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
                        size: 40,
                        color: secondaryBlue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [primaryBlue, secondaryBlue],
                      ).createShader(bounds),
                      child: const Text(
                        'Class Management Portal',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _editingClassId != null
                          ? 'Edit class section and assigned teacher'
                          : 'Create and manage class sections with assigned teachers',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: primaryBlue.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Enhanced Form Card
              Container(
                padding: const EdgeInsets.all(28),
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
                    BoxShadow(
                      color: secondaryBlue.withOpacity(0.05),
                      blurRadius: 50,
                      offset: const Offset(0, 20),
                    ),
                  ],
                  border: Border.all(
                    color: lightBlue.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildSectionTitle('Class Information', Icons.info_outline_rounded),
                          if (_editingClassId != null)
                            TextButton.icon(
                              onPressed: _resetForm,
                              icon: const Icon(Icons.cancel_outlined, size: 18),
                              label: const Text('Cancel Edit'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.orange,
                                backgroundColor: Colors.orange.withOpacity(0.1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(child: _buildGradeDropdown()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildSectionDropdown()),
                        ],
                      ),

                      const SizedBox(height: 20),
                      _buildCapacityField(),

                      const SizedBox(height: 32),
                      _buildSectionTitle('Teacher Assignment', Icons.person_outline_rounded),
                      const SizedBox(height: 20),
                      _buildTeacherDropdown(),

                      const SizedBox(height: 32),

                      // Enhanced Submit Button
                      Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: secondaryBlue.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveClass,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                            padding: EdgeInsets.zero,
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: _isLoading
                                    ? [Colors.grey[400]!, Colors.grey[500]!]
                                    : [secondaryBlue, accentBlue, lightBlue],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: _isLoading
                                  ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Saving Class...',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                                  : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                      _editingClassId != null ? Icons.update_outlined : Icons.save_outlined,
                                      size: 22
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _editingClassId != null ? 'Update Class' : 'Save Class',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Existing Classes Section
              _buildExistingClassesSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [secondaryBlue.withOpacity(0.1), accentBlue.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: lightBlue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: secondaryBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: secondaryBlue),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: primaryBlue,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: lightBlue.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceBlue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: lightBlue.withOpacity(0.4)),
        ),
        child: DropdownButtonFormField<String>(
          value: _selectedGrade,
          decoration: InputDecoration(
            labelText: 'Grade',
            prefixIcon: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [lightBlue.withOpacity(0.2), paleBlue.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.grade_rounded, color: secondaryBlue, size: 20),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            labelStyle: TextStyle(color: primaryBlue.withOpacity(0.7), fontWeight: FontWeight.w500),
          ),
          dropdownColor: Colors.white,
          style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w500, fontSize: 15),
          items: grades.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
          onChanged: (val) => setState(() => _selectedGrade = val),
          validator: (val) => val == null ? 'Select grade' : null,
        ),
      ),
    );
  }

  Widget _buildSectionDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: lightBlue.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceBlue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: lightBlue.withOpacity(0.4)),
        ),
        child: DropdownButtonFormField<String>(
          value: _selectedSection,
          decoration: InputDecoration(
            labelText: 'Section',
            prefixIcon: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [lightBlue.withOpacity(0.2), paleBlue.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.group_work_rounded, color: secondaryBlue, size: 20),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            labelStyle: TextStyle(color: primaryBlue.withOpacity(0.7), fontWeight: FontWeight.w500),
          ),
          dropdownColor: Colors.white,
          style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w500, fontSize: 15),
          items: sections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (val) => setState(() => _selectedSection = val),
          validator: (val) => val == null ? 'Select section' : null,
        ),
      ),
    );
  }

  Widget _buildCapacityField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: lightBlue.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: _capacityController,
        keyboardType: TextInputType.number,
        style: const TextStyle(
          color: primaryBlue,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          labelText: 'Capacity',
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [lightBlue.withOpacity(0.2), paleBlue.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.people_outline_rounded, color: secondaryBlue, size: 20),
          ),
          labelStyle: TextStyle(color: primaryBlue.withOpacity(0.7), fontWeight: FontWeight.w500),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: paleBlue.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: secondaryBlue, width: 2.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: lightBlue.withOpacity(0.4)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          filled: true,
          fillColor: surfaceBlue,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        validator: (val) {
          if (val == null || val.isEmpty) return 'Enter capacity';
          final parsed = int.tryParse(val);
          if (parsed == null || parsed <= 0) return 'Invalid number';
          _capacity = parsed;
          return null;
        },
      ),
    );
  }

  Widget _buildTeacherDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: lightBlue.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceBlue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: lightBlue.withOpacity(0.4)),
        ),
        child: DropdownButtonFormField<String>(
          value: _teachers.any((t) => t['id'] == _selectedTeacherId) ? _selectedTeacherId : null,
          decoration: InputDecoration(
            labelText: 'Class Teacher',
            prefixIcon: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [lightBlue.withOpacity(0.2), paleBlue.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_outline_rounded, color: secondaryBlue, size: 20),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            labelStyle: TextStyle(color: primaryBlue.withOpacity(0.7), fontWeight: FontWeight.w500),
          ),
          dropdownColor: Colors.white,
          style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w500, fontSize: 15),
          items: _teachers.isEmpty
              ? [const DropdownMenuItem<String>(
            value: null,
            child: Text('Loading teachers...', style: TextStyle(color: Colors.grey)),
          )]
              : _teachers.map<DropdownMenuItem<String>>((teacher) {
            return DropdownMenuItem<String>(
              value: teacher['id'] as String,
              child: Text(teacher['name'] ?? 'Unknown Teacher'),
            );
          }).toList(),
          onChanged: _teachers.isEmpty ? null : (String? newValue) {
            setState(() {
              _selectedTeacherId = newValue;
            });
          },
          validator: (val) => val == null || val.isEmpty ? 'Select teacher' : null,
        ),
      ),
    );
  }

  Widget _buildExistingClassesSection() {
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
            color: primaryBlue.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: secondaryBlue.withOpacity(0.05),
            blurRadius: 50,
            offset: const Offset(0, 20),
          ),
        ],
        border: Border.all(
          color: lightBlue.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Existing Classes', Icons.list_alt_rounded),
          const SizedBox(height: 20),

          if (_classes.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: backgroundBlue.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: lightBlue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.class_outlined,
                    size: 48,
                    color: lightBlue.withOpacity(0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Classes Created Yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: primaryBlue.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first class using the form above',
                    style: TextStyle(
                      fontSize: 14,
                      color: primaryBlue.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            )
          else
            ...(_classes.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final isBeingEdited = _editingClassId == doc.id;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isBeingEdited
                        ? [Colors.orange.withOpacity(0.05), Colors.orange.withOpacity(0.02)]
                        : [Colors.white, surfaceBlue],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isBeingEdited
                          ? Colors.orange.withOpacity(0.2)
                          : lightBlue.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: isBeingEdited
                        ? Colors.orange.withOpacity(0.4)
                        : paleBlue.withOpacity(0.3),
                    width: isBeingEdited ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row with Class Info and Actions
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Class Icon
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isBeingEdited
                                    ? [Colors.orange.withOpacity(0.2), Colors.orange.withOpacity(0.1)]
                                    : [accentBlue.withOpacity(0.1), lightBlue.withOpacity(0.1)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isBeingEdited
                                    ? Colors.orange.withOpacity(0.4)
                                    : lightBlue.withOpacity(0.3),
                              ),
                            ),
                            child: Icon(
                              Icons.school_rounded,
                              color: isBeingEdited ? Colors.orange : secondaryBlue,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Class Information
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Grade ${data['grade']} - Section ${data['section']}',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          color: primaryBlue,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isBeingEdited) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'EDITING',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Teacher Info
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: secondaryBlue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(
                                        Icons.person_outline,
                                        size: 12,
                                        color: secondaryBlue,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Teacher: ${data['classTeacher'] ?? 'Not Assigned'}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: primaryBlue.withOpacity(0.8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),

                                // Capacity Info
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: accentBlue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(
                                        Icons.people_outline,
                                        size: 12,
                                        color: accentBlue,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Capacity: ${data['capacity'] ?? 'Not Set'}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: primaryBlue.withOpacity(0.8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Action Buttons - OVERFLOW FIXED
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isBeingEdited
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: isBeingEdited ? null : () => _editClass(doc),
                                    child: Icon(
                                      isBeingEdited ? Icons.check_outlined : Icons.edit_outlined,
                                      color: isBeingEdited ? Colors.green : Colors.orange,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () => _deleteClass(doc.id, data['teacherId']),
                                    child: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList()),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _capacityController.dispose();
    super.dispose();
  }
}