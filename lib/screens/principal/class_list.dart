import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ClassListScreen extends StatefulWidget {
  final String principalId;
  final String schoolId;

  const ClassListScreen({
    Key? key,
    required this.principalId,
    required this.schoolId,
  }) : super(key: key);

  @override
  State<ClassListScreen> createState() => _ClassListScreenState();
}

class _ClassListScreenState extends State<ClassListScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _capacityController = TextEditingController();

  String? _selectedGrade;
  String? _selectedSection;
  int? _capacity;
  String? _selectedTeacherId;
  String? _editingClassId;

  List<Map<String, dynamic>> _teachers = [];
  List<DocumentSnapshot> _classDocs = [];
  bool _isLoading = false;
  bool _isFormVisible = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Professional Blue Color Palette
  static const Color primaryBlue = Color(0xFF0F172A);      // Dark Blue
  static const Color secondaryBlue = Color(0xFF1E40AF);    // Royal Blue
  static const Color accentBlue = Color(0xFF3B82F6);       // Bright Blue
  static const Color lightBlue = Color(0xFF60A5FA);        // Light Blue
  static const Color paleBlue = Color(0xFF93C5FD);         // Pale Blue
  static const Color backgroundBlue = Color(0xFFEBF8FF);   // Very Light Blue
  static const Color surfaceBlue = Color(0xFFF0F9FF);      // Surface Blue

  final List<String> grades = [
    '1st', '2nd', '3rd', '4th', '5th', '6th',
    '7th', '8th', '9th', '10th', '11th', '12th'
  ];
  final List<String> sections = ['A', 'B', 'C', 'D', 'E'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack));

    _initializeData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _fetchTeachers();
    await _fetchClasses();
  }

  Future<void> _fetchTeachers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('teachers')
          .where('schoolId', isEqualTo: widget.schoolId)
          .get();

      setState(() {
        _teachers = snapshot.docs.map((doc) => {
          'id': doc.id,
          'name': doc['meta']?['name'] ?? 'Unknown',
          'email': doc['meta']?['email'] ?? 'No Email',
        }).toList();
      });
    } catch (e) {
      _showSnackBar('Error loading teachers: $e', Colors.red[400]!, Icons.error_outline);
    }
  }

  Future<void> _fetchClasses() async {
    try {
      final schoolDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .get();

      List<dynamic> classIds = schoolDoc.data()?['classIds'] ?? [];

      if (classIds.isEmpty) {
        setState(() => _classDocs = []);
        return;
      }

      final classSnapshots = await FirebaseFirestore.instance
          .collection('classes')
          .where(FieldPath.documentId, whereIn: classIds)
          .orderBy('grade')
          .get();

      setState(() {
        _classDocs = classSnapshots.docs;
      });
    } catch (e) {
      _showSnackBar('Error loading classes: $e', Colors.red[400]!, Icons.error_outline);
    }
  }

  Future<void> _saveClass({String? classId}) async {
    if (!_formKey.currentState!.validate() || _selectedTeacherId == null) return;

    setState(() => _isLoading = true);

    final selectedTeacher = _teachers.firstWhere((t) => t['id'] == _selectedTeacherId);

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

    try {
      if (classId == null) {
        // Create new class
        final classDocRef = await FirebaseFirestore.instance
            .collection('classes')
            .add(classData);
        final newClassId = classDocRef.id;

        await FirebaseFirestore.instance
            .collection('schools')
            .doc(widget.schoolId)
            .update({
          'classIds': FieldValue.arrayUnion([newClassId])
        });

        await FirebaseFirestore.instance
            .collection('teachers')
            .doc(_selectedTeacherId)
            .update({
          'classesAssigned': FieldValue.arrayUnion([newClassId]),
          'teacherAssigned': FieldValue.arrayUnion([newClassId]),
          'classTeacher': newClassId,
        });

        _showSnackBar('Class created successfully!', Colors.green[400]!, Icons.check_circle_outline);
      } else {
        // Update existing class
        await FirebaseFirestore.instance
            .collection('classes')
            .doc(classId)
            .update(classData);

        await FirebaseFirestore.instance
            .collection('teachers')
            .doc(_selectedTeacherId)
            .update({
          'classesAssigned': FieldValue.arrayUnion([classId]),
          'teacherAssigned': FieldValue.arrayUnion([classId]),
          'classTeacher': classId,
        });

        _showSnackBar('Class updated successfully!', Colors.blue[400]!, Icons.update);
      }

      _resetForm();
      await _fetchClasses();
      _toggleForm();
    } catch (e) {
      _showSnackBar('Error saving class: $e', Colors.red[400]!, Icons.error_outline);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteClass(String classId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _buildDeleteConfirmationDialog(),
    );

    if (result == true) {
      try {
        await FirebaseFirestore.instance.collection('classes').doc(classId).delete();

        await FirebaseFirestore.instance
            .collection('schools')
            .doc(widget.schoolId)
            .update({
          'classIds': FieldValue.arrayRemove([classId])
        });

        await _fetchClasses();
        _showSnackBar('Class deleted successfully!', Colors.green[400]!, Icons.delete_outline);
      } catch (e) {
        _showSnackBar('Error deleting class: $e', Colors.red[400]!, Icons.error_outline);
      }
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
  }

  void _editClass(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      _selectedGrade = data['grade'];
      _selectedSection = data['section'];
      _capacityController.text = data['capacity'].toString();
      _selectedTeacherId = data['teacherId'];
      _editingClassId = doc.id;
      _isFormVisible = true;
    });
    _animationController.forward();
  }

  void _toggleForm() {
    setState(() {
      _isFormVisible = !_isFormVisible;
      if (!_isFormVisible) {
        _resetForm();
        _animationController.reverse();
      } else {
        _animationController.forward();
      }
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

  Widget _buildDeleteConfirmationDialog() {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.red),
          ),
          const SizedBox(width: 12),
          const Text(
            'Delete Class',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: primaryBlue,
            ),
          ),
        ],
      ),
      content: const Text(
        'Are you sure you want to delete this class? This action cannot be undone.',
        style: TextStyle(fontSize: 14, color: primaryBlue),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: TextStyle(color: primaryBlue.withOpacity(0.7), fontWeight: FontWeight.w600),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                          child: Icon(
                            _editingClassId != null ? Icons.edit : Icons.add,
                            color: accentBlue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          _editingClassId != null ? 'Edit Class' : 'Create New Class',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: primaryBlue,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _toggleForm,
                          icon: const Icon(Icons.close, color: primaryBlue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdownField(
                            label: 'Grade',
                            value: _selectedGrade,
                            items: grades,
                            onChanged: (val) => setState(() => _selectedGrade = val),
                            validator: (val) => val == null ? 'Select grade' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDropdownField(
                            label: 'Section',
                            value: _selectedSection,
                            items: sections,
                            onChanged: (val) => setState(() => _selectedSection = val),
                            validator: (val) => val == null ? 'Select section' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextFormField(
                      controller: _capacityController,
                      label: 'Capacity',
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        final num = int.tryParse(val ?? '');
                        if (num == null || num <= 0) return 'Enter valid capacity';
                        _capacity = num;
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTeacherDropdown(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => _saveClass(classId: _editingClassId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentBlue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : Text(
                          _editingClassId != null ? 'Update Class' : 'Create Class',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<T> items,
    required void Function(T?) onChanged,
    required String? Function(T?) validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: primaryBlue.withOpacity(0.7), fontWeight: FontWeight.w500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: paleBlue.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: paleBlue.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentBlue, width: 2),
        ),
        filled: true,
        fillColor: surfaceBlue.withOpacity(0.3),
      ),
      items: items.map((item) => DropdownMenuItem<T>(
        value: item,
        child: Text(item.toString(), style: const TextStyle(color: primaryBlue)),
      )).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: primaryBlue),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: primaryBlue.withOpacity(0.7), fontWeight: FontWeight.w500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: paleBlue.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: paleBlue.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentBlue, width: 2),
        ),
        filled: true,
        fillColor: surfaceBlue.withOpacity(0.3),
      ),
      validator: validator,
    );
  }

  Widget _buildTeacherDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedTeacherId,
      decoration: InputDecoration(
        labelText: 'Class Teacher',
        labelStyle: TextStyle(color: primaryBlue.withOpacity(0.7), fontWeight: FontWeight.w500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: paleBlue.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: paleBlue.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentBlue, width: 2),
        ),
        filled: true,
        fillColor: surfaceBlue.withOpacity(0.3),
      ),
      items: _teachers.map((teacher) => DropdownMenuItem<String>(
        value: teacher['id'],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              teacher['name'],
              style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w600),
            ),
            Text(
              teacher['email'],
              style: TextStyle(color: primaryBlue.withOpacity(0.6), fontSize: 12),
            ),
          ],
        ),
      )).toList(),
      onChanged: (val) => setState(() => _selectedTeacherId = val),
      validator: (val) => val == null ? 'Select teacher' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundBlue,
      appBar: AppBar(
        title: const Text(
          "Class Management",
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.school_outlined, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  '${_classDocs.length} Classes',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
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
        child: Column(
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
                    child: const Icon(Icons.dashboard_rounded, size: 32, color: secondaryBlue),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Class Management Dashboard',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage all classes in your school',
                          style: TextStyle(
                            fontSize: 14,
                            color: primaryBlue.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _toggleForm,
                    icon: Icon(_isFormVisible ? Icons.close : Icons.add, size: 18),
                    label: Text(_isFormVisible ? 'Cancel' : 'Add Class'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),

            // Form Section
            if (_isFormVisible) _buildForm(),

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
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: accentBlue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.class_outlined, size: 18, color: accentBlue),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "Existing Classes",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: primaryBlue,
                            ),
                          ),
                          const Spacer(),
                          if (_classDocs.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: lightBlue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_classDocs.length}',
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
                      child: _classDocs.isEmpty
                          ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(32),
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
                                "No Classes Found",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: primaryBlue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Start by creating your first class using the 'Add Class' button above.",
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
                      )
                          : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _classDocs.length,
                        itemBuilder: (context, index) {
                          final doc = _classDocs[index];
                          final data = doc.data() as Map<String, dynamic>;

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
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
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
                                              "Grade ${data['grade']} - Section ${data['section']}",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 18,
                                                color: primaryBlue,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: Colors.green.withOpacity(0.3),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    "Capacity: ${data['capacity']}",
                                                    style: const TextStyle(
                                                      color: Colors.green,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: Colors.blue.withOpacity(0.3),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    "Students: ${(data['studentIds'] as List?)?.length ?? 0}",
                                                    style: const TextStyle(
                                                      color: Colors.blue,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: lightBlue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.more_vert,
                                            color: accentBlue,
                                            size: 18,
                                          ),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _editClass(doc);
                                          } else if (value == 'delete') {
                                            _deleteClass(doc.id);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit, size: 18, color: accentBlue),
                                                const SizedBox(width: 8),
                                                const Text('Edit', style: TextStyle(color: primaryBlue)),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.delete, size: 18, color: Colors.red),
                                                const SizedBox(width: 8),
                                                const Text('Delete', style: TextStyle(color: Colors.red)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          secondaryBlue.withOpacity(0.05),
                                          accentBlue.withOpacity(0.03),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: paleBlue.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.person,
                                            color: Colors.orange,
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                "Class Teacher",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: primaryBlue,
                                                ),
                                              ),
                                              Text(
                                                data['classTeacher'] ?? 'Not Assigned',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: primaryBlue,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: data['timestamp'] != null
                                                ? Colors.green.withOpacity(0.1)
                                                : Colors.grey.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: data['timestamp'] != null
                                                  ? Colors.green.withOpacity(0.3)
                                                  : Colors.grey.withOpacity(0.3),
                                            ),
                                          ),
                                          child: Text(
                                            data['timestamp'] != null ? 'Active' : 'Inactive',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: data['timestamp'] != null
                                                  ? Colors.green
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (data['subjectIds'] != null && (data['subjectIds'] as List).isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: lightBlue.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: lightBlue.withOpacity(0.2),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.subject,
                                            size: 14,
                                            color: accentBlue,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            "Subjects: ${(data['subjectIds'] as List).length}",
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: accentBlue,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
        ),
      ),
      floatingActionButton: !_isFormVisible
          ? FloatingActionButton.extended(
        onPressed: _toggleForm,
        backgroundColor: accentBlue,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Class',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      )
          : null,
    );
  }
}