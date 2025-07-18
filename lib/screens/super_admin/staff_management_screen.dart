import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';

class StaffManagementScreen extends StatefulWidget {
  final String schoolId;
  final String schoolName;

  StaffManagementScreen({
    required this.schoolId,
    required this.schoolName,
  });

  @override
  _StaffManagementScreenState createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final _uuid = Uuid(); // ✅ Correct initialization

  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _experienceController = TextEditingController();
  final _salaryController = TextEditingController();

  List<Map<String, dynamic>> staffList = [];
  List<String> availableRoles = [
    'Principal',
    'Vice Principal',
    'Head of Department',
    'Teacher',
    'Assistant Teacher',
    'Librarian',
    'Lab Assistant',
    'Sports Teacher',
    'Music Teacher',
    'Art Teacher',
    'Counselor',
    'Administrative Assistant',
    'Security Guard',
    'Maintenance Staff',
    'Accountant',
    'Nurse',
  ];

  String selectedRole = 'Teacher';
  String selectedGender = 'Male';
  bool isLoading = false;
  bool isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _qualificationController.dispose();
    _experienceController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    setState(() => isLoading = true);
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('schools')
          .doc(widget.schoolId)
          .collection('staff')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        staffList = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
            .toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar('Error loading staff: $e');
    }
  }

  String _generateStaffId() {
    final random = Random();
    return 'STF${random.nextInt(900000) + 100000}';
  }

  String _generatePassword() {
    final random = Random();
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(
      List.generate(8, (index) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  Future<void> _createStaff() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isCreating = true);

    try {
      String staffId = _generateStaffId();
      String password = _generatePassword();
      String docId = _uuid.v4(); // ✅ Generates unique staff document ID

      await _firestore
          .collection('schools')
          .doc(widget.schoolId)
          .collection('staff')
          .doc(docId)
          .set({
        'staffId': staffId,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'qualification': _qualificationController.text.trim(),
        'experience': _experienceController.text.trim(),
        'salary': double.tryParse(_salaryController.text.trim()) ?? 0.0,
        'role': selectedRole,
        'gender': selectedGender,
        'schoolId': widget.schoolId,
        'schoolName': widget.schoolName,
        'password': password,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _auth.currentUser?.uid,
        'lastLogin': null,
        'profileComplete': false,
      });

      await _firestore
          .collection('schools')
          .doc(widget.schoolId)
          .update({'staffCount': FieldValue.increment(1)});

      _clearForm();
      _loadStaff();
      _showLoginCredentials(staffId, password);
    } catch (e) {
      _showSnackBar('Error creating staff: $e');
    } finally {
      setState(() => isCreating = false);
    }
  }

  void _showLoginCredentials(String staffId, String password) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Staff Created Successfully'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Staff ID: $staffId'),
            Text('Password: $password'),
            SizedBox(height: 10),
            Text(
              'Share this with the staff securely.',
              style: TextStyle(color: Colors.orange),
            )
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('OK'))
        ],
      ),
    );
  }

  Future<void> _deleteStaff(String docId, String staffName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Staff'),
        content: Text('Are you sure you want to delete $staffName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ??
        false;

    if (confirm) {
      try {
        await _firestore
            .collection('schools')
            .doc(widget.schoolId)
            .collection('staff')
            .doc(docId)
            .update({'isActive': false});

        await _firestore
            .collection('schools')
            .doc(widget.schoolId)
            .update({'staffCount': FieldValue.increment(-1)});

        _loadStaff();
        _showSnackBar('Staff deleted successfully.');
      } catch (e) {
        _showSnackBar('Error deleting staff: $e');
      }
    }
  }

  Future<void> _updateStaff(String docId) async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await _firestore
          .collection('schools')
          .doc(widget.schoolId)
          .collection('staff')
          .doc(docId)
          .update({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'qualification': _qualificationController.text.trim(),
        'experience': _experienceController.text.trim(),
        'salary': double.tryParse(_salaryController.text.trim()) ?? 0.0,
        'role': selectedRole,
        'gender': selectedGender,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _auth.currentUser?.uid,
      });

      _clearForm();
      _loadStaff();
      Navigator.pop(context);
      _showSnackBar('Staff updated successfully');
    } catch (e) {
      _showSnackBar('Error updating staff: $e');
    }
  }

  void _editStaff(Map<String, dynamic> staff) {
    _nameController.text = staff['name'] ?? '';
    _emailController.text = staff['email'] ?? '';
    _phoneController.text = staff['phone'] ?? '';
    _addressController.text = staff['address'] ?? '';
    _qualificationController.text = staff['qualification'] ?? '';
    _experienceController.text = staff['experience'] ?? '';
    _salaryController.text = staff['salary']?.toString() ?? '';
    selectedRole = staff['role'] ?? 'Teacher';
    selectedGender = staff['gender'] ?? 'Male';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Staff'),
        content: SingleChildScrollView(child: _buildStaffForm()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _updateStaff(staff['id']),
            child: Text('Update'),
          ),
        ],
      ),
    );
  }

  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _addressController.clear();
    _qualificationController.clear();
    _experienceController.clear();
    _salaryController.clear();
    selectedRole = 'Teacher';
    selectedGender = 'Male';
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    // Your UI code here (not repeated for brevity)
    return Scaffold(
      appBar: AppBar(title: Text("Staff Management")),
      body: Center(child: Text("UI Code Here")),
    );
  }

  Widget _buildStaffForm() {
    // Your staff form UI here (already correct in your original code)
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(labelText: 'Name'),
          validator: (value) =>
          value == null || value.isEmpty ? 'Enter name' : null,
        ),
        // Add more fields similarly...
      ],
    );
  }
}
