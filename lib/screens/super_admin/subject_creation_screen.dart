import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectCreationScreen extends StatefulWidget {
  final String schoolId;
  const SubjectCreationScreen({Key? key, required this.schoolId}) : super(key: key);

  @override
  State<SubjectCreationScreen> createState() => _SubjectCreationScreenState();
}

class _SubjectCreationScreenState extends State<SubjectCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _classes = [];

  List<String> _selectedTeacherIds = [];
  List<String> _selectedClassIds = [];

  bool _isLoading = true;
  bool _isCreating = false;

  // Blue Color Palette (matching ClassCreationScreen)
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
    _loadTeachersAndClasses();
  }

  Future<void> _loadTeachersAndClasses() async {
    try {
      setState(() {
        _isLoading = true;
      });

      print('Loading data for school: ${widget.schoolId}');

      // Load school document
      final schoolDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .get();

      if (!schoolDoc.exists) {
        print('School document does not exist');
        _showError('School not found');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final schoolData = schoolDoc.data()!;
      print('School data loaded successfully');
      print('School data keys: ${schoolData.keys}');

      // Extract teacher IDs from staffIds
      List<String> teacherIds = [];

      if (schoolData.containsKey('staffIds') && schoolData['staffIds'] != null) {
        final staffIds = schoolData['staffIds'] as List<dynamic>;
        print('Total staff members: ${staffIds.length}');

        for (int i = 0; i < staffIds.length; i++) {
          final staff = staffIds[i];
          print('Staff $i: $staff');

          if (staff is Map<String, dynamic>) {
            final role = staff['role'];
            final uid = staff['uid'];

            print('Staff role: $role, uid: $uid');

            if (role == 'Teacher' && uid != null) {
              teacherIds.add(uid.toString());
              print('Added teacher ID: $uid');
            }
          }
        }
      } else {
        print('No staffIds found in school document');
      }

      // Get class IDs
      final classIds = List<String>.from(schoolData['classIds'] ?? []);

      print('Found ${teacherIds.length} teachers to load: $teacherIds');
      print('Found ${classIds.length} classes to load: $classIds');

      // Load teachers
      List<Map<String, dynamic>> teachersList = [];

      if (teacherIds.isNotEmpty) {
        print('=== LOADING ${teacherIds.length} TEACHERS ===');
        for (String teacherId in teacherIds) {
          try {
            print('Fetching teacher document: $teacherId');

            final teacherDoc = await FirebaseFirestore.instance
                .collection('teachers')
                .doc(teacherId)
                .get();

            if (teacherDoc.exists) {
              final data = teacherDoc.data()!;
              print('Teacher data keys: ${data.keys}');
              print('Full teacher data: $data');

              // Get meta data
              final meta = data['meta'] ?? {};
              print('Teacher meta data: $meta');

              // Parse subjects from meta
              List<String> subjects = [];
              if (meta.containsKey('subjects') && meta['subjects'] != null) {
                final subjectsData = meta['subjects'];
                print('Subjects data type: ${subjectsData.runtimeType}');
                print('Subjects data: $subjectsData');

                if (subjectsData is Map) {
                  subjects = (subjectsData as Map<String, dynamic>).keys.toList();
                } else if (subjectsData is List) {
                  subjects = List<String>.from(subjectsData);
                } else if (subjectsData is String) {
                  subjects = [subjectsData];
                }
              }

              // Get teacher name - try multiple possible locations
              String teacherName = 'Unnamed Teacher';
              if (meta.containsKey('name') && meta['name'] != null) {
                teacherName = meta['name'].toString();
              } else if (data.containsKey('name') && data['name'] != null) {
                teacherName = data['name'].toString();
              }

              final teacher = {
                'id': teacherDoc.id,
                'uid': teacherDoc.id,
                'name': teacherName,
                'qualification': meta['qualification'] ?? data['qualification'] ?? 'Not specified',
                'subjects': subjects,
                'email': meta['email'] ?? data['email'] ?? '',
                'contact': meta['contact']?.toString() ?? data['contact']?.toString() ?? '',
                'experience': meta['experience']?.toString() ?? data['experience']?.toString() ?? '0',
                'gender': meta['gender'] ?? data['gender'] ?? '',
                'role': data['role'] ?? 'Teacher',
                'address': meta['address'] ?? data['address'] ?? '',
                'dob': meta['dob'] ?? data['dob'] ?? '',
                'schoolId': data['schoolId'] ?? '',
                'meta': meta,
              };

              teachersList.add(teacher);
              print('✅ Successfully added teacher: ${teacher['name']} with subjects: $subjects');
            } else {
              print('❌ Teacher document not found for ID: $teacherId');
            }
          } catch (e) {
            print('❌ Error loading teacher $teacherId: $e');
            print('Stack trace: ${StackTrace.current}');
          }
        }
      } else {
        print('⚠️ No teacher IDs found to load');
      }

      // Load classes
      List<Map<String, dynamic>> classesList = [];

      if (classIds.isNotEmpty) {
        print('=== LOADING ${classIds.length} CLASSES ===');
        for (String classId in classIds) {
          try {
            print('Fetching class document: $classId');

            final classDoc = await FirebaseFirestore.instance
                .collection('classes')
                .doc(classId)
                .get();

            if (classDoc.exists) {
              final classData = classDoc.data()!;
              print('Class data: $classData');

              final grade = classData['grade']?.toString() ?? '';
              final section = classData['section']?.toString() ?? '';
              final className = '$grade - $section';

              final classItem = {
                'id': classDoc.id,
                'name': className,
                'grade': grade,
                'section': section,
                'capacity': classData['capacity'] ?? 0,
                'subjectIds': List<String>.from(classData['subjectIds'] ?? []),
                'schoolId': classData['schoolId'] ?? '',
              };

              classesList.add(classItem);
              print('✅ Successfully added class: $className');
            } else {
              print('❌ Class document not found for ID: $classId');
            }
          } catch (e) {
            print('❌ Error loading class $classId: $e');
            print('Stack trace: ${StackTrace.current}');
          }
        }
      } else {
        print('⚠️ No class IDs found to load');
      }

      setState(() {
        _teachers = teachersList;
        _classes = classesList;
        _isLoading = false;
      });

      print('=== FINAL LOADING RESULTS ===');
      print('Total teachers loaded: ${_teachers.length}');
      print('Total classes loaded: ${_classes.length}');
      if (_teachers.isNotEmpty) {
        print('Sample teacher data: ${_teachers.first}');
      }
    } catch (e) {
      print('Critical error in _loadTeachersAndClasses: $e');
      _showError('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    _showSnackBar(message, Colors.red[400]!, Icons.error_outline_rounded);
  }

  void _showSuccess(String message) {
    _showSnackBar(message, Colors.green, Icons.check_circle_rounded);
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

  Future<void> _createSubject() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTeacherIds.isEmpty) {
      _showError('Please assign at least one teacher');
      return;
    }

    if (_selectedClassIds.isEmpty) {
      _showError('Please assign at least one class');
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      // Create subject document
      final subjectData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'schoolId': widget.schoolId,
        'teacherIds': _selectedTeacherIds,
        'classIds': _selectedClassIds,
        'teachersAssigned': _selectedTeacherIds,
        'classesAssigned': _selectedClassIds,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': 'super_admin',
        'isActive': true,
      };

      final subjectRef = await FirebaseFirestore.instance
          .collection('subjects')
          .add(subjectData);

      final subjectId = subjectRef.id;
      print('✅ Created subject with ID: $subjectId');

      // Update school document - add subject ID to subjectIds array
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .update({
        'subjectIds': FieldValue.arrayUnion([subjectId]),
      });
      print('✅ Updated school with subject ID');

      // Update each assigned teacher - add subject ID and class IDs
      print('=== UPDATING ${_selectedTeacherIds.length} TEACHERS ===');
      for (final teacherId in _selectedTeacherIds) {
        try {
          // Prepare update data for teacher
          Map<String, dynamic> teacherUpdateData = {
            'subjectIds': FieldValue.arrayUnion([subjectId]),
            'subjectsAssigned': FieldValue.arrayUnion([subjectId]),
            'classesAssigned': FieldValue.arrayUnion(_selectedClassIds),
          };

          await FirebaseFirestore.instance
              .collection('teachers')
              .doc(teacherId)
              .update(teacherUpdateData);

          print('✅ Updated teacher $teacherId with:');
          print('   - Subject ID: $subjectId added to subjectIds and subjectsAssigned');
          print('   - Class IDs: $_selectedClassIds added to classesAssigned');
        } catch (e) {
          print('❌ Error updating teacher $teacherId: $e');
          // Continue with other teachers even if one fails
        }
      }

      // Update each assigned class - add subject ID to their subjectIds array
      print('=== UPDATING ${_selectedClassIds.length} CLASSES ===');
      for (final classId in _selectedClassIds) {
        try {
          print('📝 Updating class $classId with subject ID: $subjectId');

          // First, get the current class document to see its current state
          final classDoc = await FirebaseFirestore.instance
              .collection('classes')
              .doc(classId)
              .get();

          if (classDoc.exists) {
            final currentData = classDoc.data()!;
            final currentSubjectIds = List<String>.from(currentData['subjectIds'] ?? []);
            print('   Current subjectIds in class $classId: $currentSubjectIds');

            // Update the class with the new subject ID
            await FirebaseFirestore.instance
                .collection('classes')
                .doc(classId)
                .update({
              'subjectIds': FieldValue.arrayUnion([subjectId]),
            });

            // Verify the update
            final updatedClassDoc = await FirebaseFirestore.instance
                .collection('classes')
                .doc(classId)
                .get();

            if (updatedClassDoc.exists) {
              final updatedData = updatedClassDoc.data()!;
              final updatedSubjectIds = List<String>.from(updatedData['subjectIds'] ?? []);
              print('✅ Successfully updated class $classId');
              print('   Updated subjectIds: $updatedSubjectIds');

              if (updatedSubjectIds.contains(subjectId)) {
                print('   ✅ Confirmed: Subject ID $subjectId is now in class $classId');
              } else {
                print('   ⚠️ Warning: Subject ID $subjectId not found in updated class $classId');
              }
            }
          } else {
            print('❌ Class document $classId does not exist');
          }
        } catch (e) {
          print('❌ Error updating class $classId: $e');
          print('   Stack trace: ${StackTrace.current}');
          // Continue with other classes even if one fails
        }
      }

      print('=== SUBJECT CREATION COMPLETED ===');
      print('Subject ID: $subjectId');
      print('Assigned to ${_selectedTeacherIds.length} teachers: $_selectedTeacherIds');
      print('Assigned to ${_selectedClassIds.length} classes: $_selectedClassIds');

      _showSuccess('Subject "${_nameController.text}" created successfully!');

      // Navigate back with success result
      Navigator.pop(context, true);

    } catch (e) {
      print('❌ Critical error creating subject: $e');
      print('Stack trace: ${StackTrace.current}');
      _showError('Failed to create subject: $e');
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundBlue,
      appBar: AppBar(
        title: const Text(
          'Create Subject',
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
                Icon(Icons.book_outlined, size: 16, color: Colors.white),
                SizedBox(width: 4),
                Text('Subject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Container(
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
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
              SizedBox(height: 20),
              Text(
                'Loading teachers and classes...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      )
          : Container(
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
                        Icons.book_outlined,
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
                        'Subject Creation Portal',
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
                      'Create and assign subjects to teachers and classes',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: primaryBlue.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Loading Summary Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: backgroundBlue.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: lightBlue.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildInfoChip(
                            icon: Icons.person_outline,
                            label: 'Teachers',
                            count: _teachers.length,
                            color: accentBlue,
                          ),
                          Container(
                            height: 30,
                            width: 1,
                            color: lightBlue.withOpacity(0.3),
                          ),
                          _buildInfoChip(
                            icon: Icons.class_outlined,
                            label: 'Classes',
                            count: _classes.length,
                            color: secondaryBlue,
                          ),
                        ],
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
                      _buildSectionTitle('Subject Information', Icons.info_outline_rounded),
                      const SizedBox(height: 20),

                      _buildSubjectNameField(),
                      const SizedBox(height: 20),
                      _buildSubjectDescriptionField(),

                      const SizedBox(height: 32),
                      _buildSectionTitle('Teacher Assignment', Icons.person_outline_rounded),
                      const SizedBox(height: 20),
                      _buildTeacherAssignmentSection(),

                      const SizedBox(height: 32),
                      _buildSectionTitle('Class Assignment', Icons.class_outlined),
                      const SizedBox(height: 20),
                      _buildClassAssignmentSection(),

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
                          onPressed: _isCreating ? null : _createSubject,
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
                                colors: _isCreating
                                    ? [Colors.grey[400]!, Colors.grey[500]!]
                                    : [secondaryBlue, accentBlue, lightBlue],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: _isCreating
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
                                    'Creating Subject...',
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
                                  Icon(Icons.check_outlined, size: 22),
                                  SizedBox(width: 10),
                                  Text(
                                    'Create Subject',
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
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 6),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: primaryBlue.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
  Widget _buildSubjectDescriptionField() {
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
        controller: _descriptionController,
        maxLines: 3,
        style: const TextStyle(
          color: primaryBlue,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          labelText: 'Subject Description',
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [lightBlue.withOpacity(0.2), paleBlue.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.description_outlined, color: secondaryBlue, size: 20),
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
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter subject description';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildSubjectNameField() {
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
        controller: _nameController,
        style: const TextStyle(
          color: primaryBlue,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          labelText: 'Subject Name',
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [lightBlue.withOpacity(0.2), paleBlue.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.book_outlined, color: secondaryBlue, size: 20),
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
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter subject name';
          }
          return null;
        },
      ),
    );
  }


  Widget _buildTeacherAssignmentSection() {
    if (_teachers.isEmpty) {
      return Container(
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
              Icons.person_off_outlined,
              size: 48,
              color: lightBlue.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'No Teachers Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: primaryBlue.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add teachers to the school to assign them to subjects',
              style: TextStyle(
                fontSize: 14,
                color: primaryBlue.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      child: SingleChildScrollView(
        child: Column(
          children: _teachers.map((teacher) {
            final isSelected = _selectedTeacherIds.contains(teacher['id']);
            final name = teacher['name'] ?? 'Unnamed Teacher';
            final subjects = teacher['subjects'] as List<String>? ?? [];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isSelected
                      ? [accentBlue.withOpacity(0.1), lightBlue.withOpacity(0.05)]
                      : [Colors.white, surfaceBlue.withOpacity(0.3)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? accentBlue.withOpacity(0.15)
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
              child: CheckboxListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isSelected
                              ? [accentBlue.withOpacity(0.2), lightBlue.withOpacity(0.1)]
                              : [secondaryBlue.withOpacity(0.1), lightBlue.withOpacity(0.05)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.person_outline,
                        color: isSelected ? accentBlue : secondaryBlue,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: isSelected ? accentBlue : primaryBlue,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                subtitle: subjects.isNotEmpty
                    ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: subjects.map<Widget>((subject) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green[300]!, width: 0.5),
                        ),
                        child: Text(
                          subject,
                          style: TextStyle(
                            color: Colors.green[800],
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                )
                    : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'No subjects specified',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                value: isSelected,
                activeColor: accentBlue,
                checkColor: Colors.white,
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedTeacherIds.add(teacher['id']);
                    } else {
                      _selectedTeacherIds.remove(teacher['id']);
                    }
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildClassAssignmentSection() {
    if (_classes.isEmpty) {
      return Container(
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
              'No Classes Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: primaryBlue.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create classes in the school to assign subjects to them',
              style: TextStyle(
                fontSize: 14,
                color: primaryBlue.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      child: SingleChildScrollView(
        child: Column(
          children: _classes.map((klass) {
            final isSelected = _selectedClassIds.contains(klass['id']);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isSelected
                      ? [accentBlue.withOpacity(0.1), lightBlue.withOpacity(0.05)]
                      : [Colors.white, surfaceBlue.withOpacity(0.3)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? accentBlue.withOpacity(0.15)
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
              child: CheckboxListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isSelected
                              ? [accentBlue.withOpacity(0.2), lightBlue.withOpacity(0.1)]
                              : [secondaryBlue.withOpacity(0.1), lightBlue.withOpacity(0.05)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.school_outlined,
                        color: isSelected ? accentBlue : secondaryBlue,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Grade ${klass['name']}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: isSelected ? accentBlue : primaryBlue,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.people_outline,
                          size: 12,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Capacity: ${klass['capacity']} students',
                        style: TextStyle(
                          fontSize: 13,
                          color: primaryBlue.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                value: isSelected,
                activeColor: accentBlue,
                checkColor: Colors.white,
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedClassIds.add(klass['id']);
                    } else {
                      _selectedClassIds.remove(klass['id']);
                    }
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}