import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class StudentCreationScreen extends StatefulWidget {
  final String schoolId;
  const StudentCreationScreen({Key? key, required this.schoolId}) : super(key: key);

  @override
  State<StudentCreationScreen> createState() => _StudentCreationScreenState();
}

class _StudentCreationScreenState extends State<StudentCreationScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _fatherController = TextEditingController();
  final TextEditingController _motherController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  List<DocumentSnapshot> _classList = [];
  List<Map<String, dynamic>> _students = [];
  String? _selectedClassId;
  bool _isLoading = false;
  bool _isLoadingData = true;

  // Blue Palette - Enhanced
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
      fetchClasses(),
      _fetchStudents(),
    ]);
    setState(() => _isLoadingData = false);
  }

  Future<void> fetchClasses() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('schoolId', isEqualTo: widget.schoolId)
          .get();
      setState(() {
        _classList = snapshot.docs;
      });
    } catch (e) {
      _showSnackBar('Error loading classes: $e', Colors.red[400]!, Icons.error_outline_rounded);
    }
  }

  Future<void> _fetchStudents() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('schoolId', isEqualTo: widget.schoolId)
          .get();

      setState(() {
        _students = snapshot.docs.map((doc) => {
          'id': doc.id,
          'name': doc['name'] ?? 'Unknown',
          'email': doc['email'] ?? '',
          'classId': doc['classId'] ?? '',
          'phone': doc['phone'] ?? '',
          'dob': doc['dob'] ?? '',
        }).toList();
      });
    } catch (e) {
      _showSnackBar('Error loading students: $e', Colors.red[400]!, Icons.error_outline_rounded);
    }
  }

  String generatePassword(String name, String dob) {
    final year = DateFormat('yyyy').format(DateTime.parse(dob));
    final caps = name.replaceAll(' ', '').toUpperCase();
    final prefix = caps.length >= 4 ? caps.substring(0, 4) : caps;
    return '$prefix$year';
  }

  Future<void> createStudent() async {
    if (!_formKey.currentState!.validate() || _selectedClassId == null) {
      if (_selectedClassId == null) {
        _showSnackBar('Please select a class', Colors.red[400]!, Icons.warning_rounded);
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final father = _fatherController.text.trim();
      final mother = _motherController.text.trim();
      final dob = _dobController.text.trim();
      final phone = _phoneController.text.trim();
      final password = generatePassword(name, dob);

      // Create user authentication
      final authResult = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      await authResult.user!.sendEmailVerification();
      final studentId = authResult.user!.uid;

      // Prepare student data with classId
      final studentData = {
        'name': name,
        'email': email,
        'fatherName': father,
        'motherName': mother,
        'dob': dob,
        'phone': phone,
        'schoolId': widget.schoolId,
        'classId': _selectedClassId,  // Store the selected class ID
        'password': password,
        'timestamp': Timestamp.now(),
      };

      // Use transaction to ensure both operations succeed or fail together
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Get class reference and data
        final classRef = FirebaseFirestore.instance.collection('classes').doc(_selectedClassId);
        final classSnap = await transaction.get(classRef);

        if (!classSnap.exists) {
          throw Exception('Selected class not found');
        }

        final classData = classSnap.data() as Map<String, dynamic>;

        // Check class capacity
        int currentCapacity = classData['capacity'] ?? 0;
        if (currentCapacity <= 0) {
          throw Exception('Class is full. Cannot add more students.');
        }

        // Get current student IDs array
        List<dynamic> studentIds = List.from(classData['studentIds'] ?? []);

        // Check if student is already in the class (safety check)
        if (studentIds.contains(studentId)) {
          throw Exception('Student is already enrolled in this class');
        }

        // Add student ID to the class's studentIds array
        studentIds.add(studentId);

        // Create student document
        final studentRef = FirebaseFirestore.instance.collection('students').doc(studentId);
        transaction.set(studentRef, studentData);

        // Update class document with new student ID and decreased capacity
        transaction.update(classRef, {
          'capacity': currentCapacity - 1,           // Decrease available capacity
          'studentIds': studentIds,                  // Updated student IDs array
          'enrolledCount': studentIds.length,        // Track total enrolled students
          'lastUpdated': Timestamp.now(),            // Track last update
        });
      });

      _showSnackBar('Student created successfully! Verification email sent.', Colors.green, Icons.check_circle_rounded);
      _resetForm();
      await _fetchStudents();

    } catch (e) {
      _showSnackBar('Error creating student: ${e.toString()}', Colors.red[400]!, Icons.error_outline_rounded);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    _nameController.clear();
    _emailController.clear();
    _fatherController.clear();
    _motherController.clear();
    _dobController.clear();
    _phoneController.clear();
    setState(() {
      _selectedClassId = null;
    });
  }

  Future<void> _pickDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(2010),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: secondaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: primaryBlue,
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null) {
      setState(() {
        _dobController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
      });
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

  String _getClassDisplayName(String classId) {
    try {
      final classDoc = _classList.firstWhere((doc) => doc.id == classId);
      final data = classDoc.data() as Map<String, dynamic>?;
      if (data == null) return 'Unknown Class';
      return '${data['grade']} - ${data['section']}';
    } catch (_) {
      return 'Unknown Class';
    }
  }

  Future<void> _deleteStudent(String studentId) async {
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
            const Text('Delete Student', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this student? This action cannot be undone.',
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
      await FirebaseFirestore.instance.collection('students').doc(studentId).delete();
      final student = _students.firstWhere((s) => s['id'] == studentId);
      final classId = student['classId'];

      if (classId.isNotEmpty) {
        final classRef = FirebaseFirestore.instance.collection('classes').doc(classId);
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final classSnap = await transaction.get(classRef);
          if (classSnap.exists) {
            List<dynamic> studentIds = List.from(classSnap['studentIds'] ?? []);
            studentIds.remove(studentId);
            int currentCapacity = classSnap['capacity'] ?? 0;
            transaction.update(classRef, {
              'capacity': currentCapacity + 1,
              'studentIds': studentIds,
            });
          }
        });
      }

      _showSnackBar('Student deleted successfully', Colors.green, Icons.check_circle_rounded);
      await _fetchStudents();
    } catch (e) {
      _showSnackBar('Error deleting student', Colors.red[400]!, Icons.error_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: backgroundBlue,
        appBar: AppBar(
          title: const Text('Student Management'),
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
          'Student Management',
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
                Icon(Icons.school_outlined, size: 16, color: Colors.white),
                SizedBox(width: 4),
                Text('Students', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
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
                        Icons.school_outlined,
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
                        'Students Portal',
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
                      'Register new students and manage existing ones',
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

              // Enhanced Form Section
              _buildFormSection(),
              const SizedBox(height: 32),

              // Existing Students Section
              _buildExistingStudentsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormSection() {
    return Container(
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
            _buildSectionTitle('Student Information', Icons.person_add_outlined),
            const SizedBox(height: 20),

            // Name and Email Row
            Row(
              children: [
                Expanded(child: _buildTextField(controller: _nameController, label: 'Student Name', icon: Icons.person_outlined)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField(controller: _emailController, label: 'Email', icon: Icons.email_outlined)),
              ],
            ),
            const SizedBox(height: 20),

            // Parents Row
            Row(
              children: [
                Expanded(child: _buildTextField(controller: _fatherController, label: 'Father\'s Name', icon: Icons.person_outline)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField(controller: _motherController, label: 'Mother\'s Name', icon: Icons.person_outline)),
              ],
            ),
            const SizedBox(height: 20),

            // DOB and Phone Row
            Row(
              children: [
                Expanded(child: _buildDateField()),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField(controller: _phoneController, label: 'Phone', icon: Icons.phone_outlined, keyboardType: TextInputType.phone)),
              ],
            ),
            const SizedBox(height: 32),

            _buildSectionTitle('Class Assignment', Icons.class_outlined),
            const SizedBox(height: 20),
            _buildClassDropdown(),

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
                onPressed: _isLoading ? null : createStudent,
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
                          'Creating Student...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                        : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_add_outlined, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Create Student',
                          style: TextStyle(
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
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
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(
          color: primaryBlue,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
        validator: (val) => val == null || val.isEmpty ? 'Enter $label' : null,
        decoration: InputDecoration(
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [lightBlue.withOpacity(0.2), paleBlue.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: secondaryBlue, size: 20),
          ),
          labelText: label,
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
      ),
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: _pickDate,
      child: AbsorbPointer(
        child: _buildTextField(controller: _dobController, label: 'Date of Birth', icon: Icons.calendar_today_outlined),
      ),
    );
  }

  Widget _buildClassDropdown() {
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
          value: _selectedClassId,
          decoration: InputDecoration(
            labelText: 'Select Class',
            prefixIcon: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [lightBlue.withOpacity(0.2), paleBlue.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.class_outlined, color: secondaryBlue, size: 20),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            labelStyle: TextStyle(color: primaryBlue.withOpacity(0.7), fontWeight: FontWeight.w500),
          ),
          dropdownColor: Colors.white,
          style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w500, fontSize: 15),
          items: _classList.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final grade = data['grade'] ?? '';
            final section = data['section'] ?? '';
            return DropdownMenuItem(value: doc.id, child: Text('$grade - $section'));
          }).toList(),
          onChanged: (val) => setState(() => _selectedClassId = val),
          validator: (val) => val == null ? 'Select class' : null,
        ),
      ),
    );
  }

  Widget _buildExistingStudentsSection() {
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
          _buildSectionTitle('Existing Students', Icons.list_alt_rounded),
          const SizedBox(height: 20),

          if (_students.isEmpty)
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
                    Icons.school_outlined,
                    size: 48,
                    color: lightBlue.withOpacity(0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Students Registered Yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: primaryBlue.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Register your first student using the form above',
                    style: TextStyle(
                      fontSize: 14,
                      color: primaryBlue.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            )
          else
            ...(_students.map((student) {
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
                  child: Row(
                    children: [
                      // Student Avatar
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accentBlue.withOpacity(0.1), lightBlue.withOpacity(0.1)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: lightBlue.withOpacity(0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          color: secondaryBlue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Student Information
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student['name'],
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: primaryBlue,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),

                            // Class Info
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: secondaryBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(
                                    Icons.class_outlined,
                                    size: 12,
                                    color: secondaryBlue,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Class: ${_getClassDisplayName(student['classId'])}',
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

                            // Email Info
                            if (student['email'].isNotEmpty)
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: accentBlue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.email_outlined,
                                      size: 12,
                                      color: accentBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      student['email'],
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
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Delete Button
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _deleteStudent(student['id']),
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 18,
                            ),
                          ),
                        ),
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
    _nameController.dispose();
    _emailController.dispose();
    _fatherController.dispose();
    _motherController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}