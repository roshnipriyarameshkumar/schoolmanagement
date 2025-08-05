import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class StudentManagementScreen extends StatefulWidget {
  final String schoolId;
  const StudentManagementScreen({Key? key, required this.schoolId}) : super(key: key);

  @override
  State<StudentManagementScreen> createState() => _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _fatherController = TextEditingController();
  final TextEditingController _motherController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // State variables
  List<DocumentSnapshot> _classList = [];
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  String? _selectedClassId;
  String? _filterClassId; // New variable for class filtering
  bool _isLoading = false;
  bool _isLoadingData = true;
  bool _isEditMode = false;
  String? _editingStudentId;
  String _searchQuery = '';

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Professional Blue Color Palette (matching AddAnnouncementScreen)
  static const Color primaryBlue = Color(0xFF0F172A);
  static const Color secondaryBlue = Color(0xFF1E40AF);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color lightBlue = Color(0xFF60A5FA);
  static const Color paleBlue = Color(0xFF93C5FD);
  static const Color backgroundBlue = Color(0xFFEBF8FF);
  static const Color surfaceBlue = Color(0xFFF0F9FF);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _setupSearchListener();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack));

    _animationController.forward();
  }

  void _setupSearchListener() {
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _filterStudents();
      });
    });
  }

  void _filterStudents() {
    _filteredStudents = _students.where((student) {
      final name = (student['name'] ?? '').toString().toLowerCase();
      final email = (student['email'] ?? '').toString().toLowerCase();
      final matchesSearch = name.contains(_searchQuery) || email.contains(_searchQuery);

      // Apply class filter
      if (_filterClassId == null || _filterClassId == 'all') {
        return matchesSearch;
      } else {
        return matchesSearch && student['classId'] == _filterClassId;
      }
    }).toList();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _fatherController.dispose();
    _motherController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingData = true);
    try {
      await _fetchClasses();
      await _fetchStudents();
    } catch (e) {
      _showSnackBar('Error loading data: $e', Colors.red[400]!, Icons.error_outline);
    } finally {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _fetchClasses() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('schoolId', isEqualTo: widget.schoolId)
          .get();

      setState(() {
        _classList = snapshot.docs;
      });
    } catch (e) {
      _showSnackBar('Error loading classes: $e', Colors.red[400]!, Icons.error_outline);
    }
  }

  Future<void> _fetchStudents() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('schoolId', isEqualTo: widget.schoolId)
          .get();

      setState(() {
        _students = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data() as Map<String, dynamic>,
          };
        }).toList();
        _filterStudents();
      });
    } catch (e) {
      _showSnackBar('Error loading students: $e', Colors.red[400]!, Icons.error_outline);
    }
  }

  String generatePassword(String name, String dob) {
    try {
      final year = DateFormat('yyyy').format(DateTime.parse(dob));
      final caps = name.replaceAll(' ', '').toUpperCase();
      final prefix = caps.length >= 4 ? caps.substring(0, 4) : caps.padRight(4, 'X');
      return '$prefix$year';
    } catch (e) {
      return 'STUD${DateTime.now().year}';
    }
  }

  Future<void> _createStudent() async {
    if (!_formKey.currentState!.validate() || _selectedClassId == null) {
      _showSnackBar('Please fill all fields and select a class', Colors.orange[400]!, Icons.warning);
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

      // Check if email already exists
      final emailExists = await FirebaseFirestore.instance
          .collection('students')
          .where('email', isEqualTo: email)
          .where('schoolId', isEqualTo: widget.schoolId)
          .get();

      if (emailExists.docs.isNotEmpty) {
        _showSnackBar('A student with this email already exists', Colors.red[400]!, Icons.error_outline);
        return;
      }

      // Create student document
      final studentData = {
        'name': name,
        'email': email,
        'fatherName': father,
        'motherName': mother,
        'dob': dob,
        'phone': phone,
        'password': password,
        'schoolId': widget.schoolId,
        'classId': _selectedClassId,
        'isActive': true,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('students').add(studentData);

      _showSnackBar('Student created successfully!', Colors.green[400]!, Icons.check_circle_outline);
      _resetForm();
      await _fetchStudents();
    } catch (e) {
      _showSnackBar('Error creating student: $e', Colors.red[400]!, Icons.error_outline);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStudent() async {
    if (!_formKey.currentState!.validate() || _selectedClassId == null || _editingStudentId == null) {
      _showSnackBar('Please fill all fields and select a class', Colors.orange[400]!, Icons.warning);
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

      // Check if email is being changed to one that already exists
      if (_students.firstWhere((s) => s['id'] == _editingStudentId)['email'] != email) {
        final emailExists = await FirebaseFirestore.instance
            .collection('students')
            .where('email', isEqualTo: email)
            .where('schoolId', isEqualTo: widget.schoolId)
            .get();

        if (emailExists.docs.isNotEmpty) {
          _showSnackBar('A student with this email already exists', Colors.red[400]!, Icons.error_outline);
          return;
        }
      }

      // Update student document
      final studentData = {
        'name': name,
        'email': email,
        'fatherName': father,
        'motherName': mother,
        'dob': dob,
        'phone': phone,
        'password': password,
        'classId': _selectedClassId,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('students')
          .doc(_editingStudentId)
          .update(studentData);

      _showSnackBar('Student updated successfully!', Colors.green[400]!, Icons.check_circle_outline);
      _resetForm();
      await _fetchStudents();
    } catch (e) {
      _showSnackBar('Error updating student: $e', Colors.red[400]!, Icons.error_outline);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteStudent(String studentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Student', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this student? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: accentBlue)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('students').doc(studentId).delete();
      _showSnackBar('Student deleted successfully', Colors.green[400]!, Icons.check_circle_outline);
      await _fetchStudents();
    } catch (e) {
      _showSnackBar('Error deleting student: $e', Colors.red[400]!, Icons.error_outline);
    }
  }

  void _editStudent(Map<String, dynamic> student) {
    setState(() {
      _isEditMode = true;
      _editingStudentId = student['id'];
      _nameController.text = student['name'] ?? '';
      _emailController.text = student['email'] ?? '';
      _fatherController.text = student['fatherName'] ?? '';
      _motherController.text = student['motherName'] ?? '';
      _dobController.text = student['dob'] ?? '';
      _phoneController.text = student['phone'] ?? '';
      _selectedClassId = student['classId'];
    });

    _scrollToForm();
  }

  void _scrollToForm() {
    Future.delayed(const Duration(milliseconds: 300), () {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _emailController.clear();
    _fatherController.clear();
    _motherController.clear();
    _dobController.clear();
    _phoneController.clear();
    setState(() {
      _selectedClassId = null;
      _isEditMode = false;
      _editingStudentId = null;
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
              primary: accentBlue,
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

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    IconData? prefixIcon,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: accentBlue, size: 20)
            : null,
        labelStyle: TextStyle(color: primaryBlue.withOpacity(0.7), fontWeight: FontWeight.w500),
        hintStyle: TextStyle(color: primaryBlue.withOpacity(0.5), fontSize: 14),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: surfaceBlue.withOpacity(0.3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator,
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: paleBlue.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: child,
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required IconData icon}) {
    return Row(
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
          child: Icon(icon, color: accentBlue, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: primaryBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
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
            color: primaryBlue.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: paleBlue.withOpacity(0.2)),
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
              child: const Icon(Icons.person, color: accentBlue, size: 24),
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
                      fontWeight: FontWeight.w700,
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
                  const SizedBox(height: 2),
                  Text(
                    'Class: ${_getClassDisplayName(student['classId'] ?? '')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: accentBlue.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.edit, color: accentBlue, size: 20),
                    onPressed: () => _editStudent(student),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _deleteStudent(student['id']),
                  ),
                ),
              ],
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
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const CircularProgressIndicator(color: accentBlue),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Loading student data...',
                    style: TextStyle(
                      color: primaryBlue,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundBlue,
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Student' : 'Student Management',
          style: const TextStyle(
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
          if (_isEditMode)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
                onPressed: _resetForm,
                tooltip: 'Cancel',
              ),
            ),
          if (!_isEditMode)
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
                  const Icon(Icons.people, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '${_students.length}',
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
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Search Bar and Class Filter
                        // Search Bar and Class Filter
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Colors.white, surfaceBlue],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryBlue.withOpacity(0.08),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                  border: Border.all(color: paleBlue.withOpacity(0.3)),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w500),
                                  decoration: InputDecoration(
                                    hintText: 'Search students...',
                                    hintStyle: TextStyle(color: primaryBlue.withOpacity(0.5)),
                                    prefixIcon: const Icon(Icons.search, color: accentBlue, size: 20),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Colors.white, surfaceBlue],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryBlue.withOpacity(0.08),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                  border: Border.all(color: paleBlue.withOpacity(0.3)),
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: _filterClassId,
                                  decoration: const InputDecoration(
                                    labelText: 'Filter',
                                    prefixIcon: Icon(Icons.filter_list, color: accentBlue, size: 18),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                                    labelStyle: TextStyle(fontSize: 12),
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: 'all',
                                      child: Text('All', style: TextStyle(fontSize: 12)),
                                    ),
                                    ..._classList.map((doc) {
                                      return DropdownMenuItem(
                                        value: doc.id,
                                        child: Text(
                                          _getClassDisplayName(doc.id),
                                          style: const TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _filterClassId = value;
                                      _filterStudents();
                                    });
                                  },
                                  dropdownColor: Colors.white,
                                  icon: const Icon(Icons.keyboard_arrow_down, color: accentBlue, size: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Form Section
                        _buildCard(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader(
                                  title: _isEditMode ? 'Edit Student' : 'Add New Student',
                                  icon: _isEditMode ? Icons.edit : Icons.person_add,
                                ),
                                const SizedBox(height: 20),

                                // Name and Email
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextFormField(
                                        controller: _nameController,
                                        label: 'Student Name',
                                        hint: 'Enter student full name',
                                        prefixIcon: Icons.person,
                                        validator: (value) => value?.isEmpty ?? true ? 'Name is required' : null,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildTextFormField(
                                        controller: _emailController,
                                        label: 'Email Address',
                                        hint: 'student@school.edu',
                                        prefixIcon: Icons.email,
                                        keyboardType: TextInputType.emailAddress,
                                        validator: (value) => value?.isEmpty ?? true ? 'Email is required' : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Parents' Names
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextFormField(
                                        controller: _fatherController,
                                        label: "Father's Name",
                                        hint: 'Enter father full name',
                                        prefixIcon: Icons.man,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildTextFormField(
                                        controller: _motherController,
                                        label: "Mother's Name",
                                        hint: 'Enter mother full name',
                                        prefixIcon: Icons.woman,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // DOB and Phone
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextFormField(
                                        controller: _dobController,
                                        label: 'Date of Birth',
                                        hint: 'Select birth date',
                                        prefixIcon: Icons.calendar_today,
                                        readOnly: true,
                                        onTap: _pickDate,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildTextFormField(
                                        controller: _phoneController,
                                        label: 'Phone Number',
                                        hint: 'Contact number',
                                        prefixIcon: Icons.phone,
                                        keyboardType: TextInputType.phone,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Class Selection
                                DropdownButtonFormField<String>(
                                  value: _selectedClassId,
                                  decoration: InputDecoration(
                                    labelText: 'Select Class',
                                    prefixIcon: const Icon(Icons.class_, color: accentBlue, size: 20),
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
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  ),
                                  items: _classList.map((doc) {
                                    return DropdownMenuItem(
                                      value: doc.id,
                                      child: Text(
                                        _getClassDisplayName(doc.id),
                                        style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w500),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) => setState(() => _selectedClassId = value),
                                  validator: (value) => value == null ? 'Please select a class' : null,
                                  dropdownColor: Colors.white,
                                  icon: const Icon(Icons.keyboard_arrow_down, color: accentBlue),
                                ),
                                const SizedBox(height: 24),

                                // Submit Button
                                Container(
                                  width: double.infinity,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: _isEditMode
                                          ? [secondaryBlue, lightBlue]
                                          : [accentBlue, lightBlue],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_isEditMode ? secondaryBlue : accentBlue).withOpacity(0.3),
                                        blurRadius: 15,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : (_isEditMode ? _updateStudent : _createStudent),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          _isEditMode ? 'Updating...' : 'Creating...',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    )
                                        : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _isEditMode ? Icons.update : Icons.person_add,
                                          size: 20,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _isEditMode ? 'Update Student' : 'Create Student',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Students List Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.white, surfaceBlue],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withOpacity(0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            border: Border.all(color: paleBlue.withOpacity(0.3)),
                          ),
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
                                child: const Icon(Icons.people, color: accentBlue, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Student List',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: primaryBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _searchQuery.isEmpty && (_filterClassId == null || _filterClassId == 'all')
                                          ? '${_filteredStudents.length} students enrolled'
                                          : '${_filteredStudents.length} students found',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: primaryBlue.withOpacity(0.7),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_searchQuery.isNotEmpty || (_filterClassId != null && _filterClassId != 'all'))
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: lightBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: lightBlue.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    'Filtered',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: accentBlue,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Students List
                        _filteredStudents.isEmpty
                            ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(40),
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
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            border: Border.all(color: paleBlue.withOpacity(0.3)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: paleBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: paleBlue.withOpacity(0.3)),
                                ),
                                child: Icon(
                                  (_searchQuery.isEmpty && (_filterClassId == null || _filterClassId == 'all'))
                                      ? Icons.people_outline
                                      : Icons.search_off,
                                  size: 48,
                                  color: paleBlue,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                (_searchQuery.isEmpty && (_filterClassId == null || _filterClassId == 'all'))
                                    ? 'No Students Added Yet'
                                    : 'No Matching Students Found',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: primaryBlue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                (_searchQuery.isEmpty && (_filterClassId == null || _filterClassId == 'all'))
                                    ? 'Add your first student using the form above'
                                    : 'Try adjusting your search or filter criteria',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: primaryBlue.withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                            : Column(
                          children: _filteredStudents
                              .map((student) => _buildStudentCard(student))
                              .toList(),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}