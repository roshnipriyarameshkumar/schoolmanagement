import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectManagementScreen extends StatefulWidget {
  final String schoolId;
  final String principalId;

  const SubjectManagementScreen({
    super.key,
    required this.schoolId,
    required this.principalId,
  });

  @override
  State<SubjectManagementScreen> createState() => _SubjectManagementScreenState();
}

class _SubjectManagementScreenState extends State<SubjectManagementScreen>
    with TickerProviderStateMixin {

  // Blue Color Palette
  static const Color primaryBlue = Color(0xFF0F172A);
  static const Color secondaryBlue = Color(0xFF1E40AF);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color lightBlue = Color(0xFF60A5FA);
  static const Color paleBlue = Color(0xFF93C5FD);
  static const Color backgroundBlue = Color(0xFFEBF8FF);
  static const Color surfaceBlue = Color(0xFFF0F9FF);

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _classes = [];

  bool _isLoading = true;
  bool _isRefreshing = false;
  String _searchQuery = '';
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadSchoolData();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
  }

  Future<void> _loadSchoolData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      print('Loading data for school: ${widget.schoolId}');

      // Load school document first
      final schoolDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .get();

      if (!schoolDoc.exists) {
        _showError('School not found');
        return;
      }

      final schoolData = schoolDoc.data()!;

      // Load subjects, teachers, and classes in parallel
      await Future.wait([
        _loadSubjects(),
        _loadTeachers(schoolData),
        _loadClasses(schoolData),
      ]);

      setState(() {
        _isLoading = false;
      });

      print('=== LOADING COMPLETE ===');
      print('Subjects: ${_subjects.length}');
      print('Teachers: ${_teachers.length}');
      print('Classes: ${_classes.length}');

    } catch (e) {
      print('Error loading school data: $e');
      _showError('Failed to load school data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSubjects() async {
    try {
      Query<Map<String, dynamic>> subjectsQuery;

      // Try the original query first, but with proper error handling
      try {
        subjectsQuery = FirebaseFirestore.instance
            .collection('subjects')
            .where('schoolId', isEqualTo: widget.schoolId)
            .where('isActive', isEqualTo: true)
            .orderBy('createdAt', descending: true);

        // Test the query by getting the first document
        await subjectsQuery.limit(1).get();

      } catch (indexError) {
        print('Composite index not available, using alternative query: $indexError');

        // Alternative approach: Query without orderBy and sort in memory
        subjectsQuery = FirebaseFirestore.instance
            .collection('subjects')
            .where('schoolId', isEqualTo: widget.schoolId)
            .where('isActive', isEqualTo: true);
      }

      final subjectsSnapshot = await subjectsQuery.get();
      List<Map<String, dynamic>> subjectsList = [];

      for (var doc in subjectsSnapshot.docs) {
        final data = doc.data();
        subjectsList.add({
          'id': doc.id,
          'name': data['name'] ?? 'Unnamed Subject',
          'description': data['description'] ?? '',
          'teacherIds': List<String>.from(data['teacherIds'] ?? []),
          'classIds': List<String>.from(data['classIds'] ?? []),
          'teachersAssigned': List<String>.from(data['teachersAssigned'] ?? []),
          'classesAssigned': List<String>.from(data['classesAssigned'] ?? []),
          'createdAt': data['createdAt'],
          'createdBy': data['createdBy'] ?? 'Unknown',
          'isActive': data['isActive'] ?? true,
          'schoolId': data['schoolId'],
        });
      }

      // Sort in memory if we couldn't use orderBy in the query
      subjectsList.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;

        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;

        return bTime.compareTo(aTime); // descending order
      });

      setState(() {
        _subjects = subjectsList;
      });
    } catch (e) {
      print('Error loading subjects: $e');
      throw e;
    }
  }

  Future<void> _loadTeachers(Map<String, dynamic> schoolData) async {
    try {
      List<String> teacherIds = [];

      if (schoolData.containsKey('staffIds') && schoolData['staffIds'] != null) {
        final staffIds = schoolData['staffIds'] as List<dynamic>;

        for (var staff in staffIds) {
          if (staff is Map<String, dynamic> &&
              staff['role'] == 'Teacher' &&
              staff['uid'] != null) {
            teacherIds.add(staff['uid'].toString());
          }
        }
      }

      List<Map<String, dynamic>> teachersList = [];

      for (String teacherId in teacherIds) {
        try {
          final teacherDoc = await FirebaseFirestore.instance
              .collection('teachers')
              .doc(teacherId)
              .get();

          if (teacherDoc.exists) {
            final data = teacherDoc.data()!;
            final meta = data['meta'] ?? {};

            List<String> subjects = [];
            if (meta.containsKey('subjects') && meta['subjects'] != null) {
              final subjectsData = meta['subjects'];
              if (subjectsData is Map) {
                subjects = (subjectsData as Map<String, dynamic>).keys.toList();
              } else if (subjectsData is List) {
                subjects = List<String>.from(subjectsData);
              }
            }

            String teacherName = 'Unnamed Teacher';
            if (meta.containsKey('name') && meta['name'] != null) {
              teacherName = meta['name'].toString();
            } else if (data.containsKey('name') && data['name'] != null) {
              teacherName = data['name'].toString();
            }

            teachersList.add({
              'id': teacherDoc.id,
              'name': teacherName,
              'email': meta['email'] ?? data['email'] ?? '',
              'subjects': subjects,
              'subjectsAssigned': List<String>.from(data['subjectsAssigned'] ?? []),
              'classesAssigned': List<String>.from(data['classesAssigned'] ?? []),
              'qualification': meta['qualification'] ?? 'Not specified',
              'experience': meta['experience']?.toString() ?? '0',
            });
          }
        } catch (e) {
          print('Error loading teacher $teacherId: $e');
        }
      }

      setState(() {
        _teachers = teachersList;
      });
    } catch (e) {
      print('Error loading teachers: $e');
      throw e;
    }
  }

  Future<void> _loadClasses(Map<String, dynamic> schoolData) async {
    try {
      final classIds = List<String>.from(schoolData['classIds'] ?? []);
      List<Map<String, dynamic>> classesList = [];

      for (String classId in classIds) {
        try {
          final classDoc = await FirebaseFirestore.instance
              .collection('classes')
              .doc(classId)
              .get();

          if (classDoc.exists) {
            final classData = classDoc.data()!;
            final grade = classData['grade']?.toString() ?? '';
            final section = classData['section']?.toString() ?? '';

            classesList.add({
              'id': classDoc.id,
              'name': '$grade - $section',
              'grade': grade,
              'section': section,
              'capacity': classData['capacity'] ?? 0,
              'subjectIds': List<String>.from(classData['subjectIds'] ?? []),
            });
          }
        } catch (e) {
          print('Error loading class $classId: $e');
        }
      }

      setState(() {
        _classes = classesList;
      });
    } catch (e) {
      print('Error loading classes: $e');
      throw e;
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
    });

    await _loadSchoolData();

    setState(() {
      _isRefreshing = false;
    });

    _showSuccess('Data refreshed successfully');
  }

  List<Map<String, dynamic>> get _filteredSubjects {
    List<Map<String, dynamic>> filtered = _subjects;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((subject) {
        final name = subject['name'].toString().toLowerCase();
        final description = subject['description'].toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || description.contains(query);
      }).toList();
    }

    // Apply category filter
    if (_selectedFilter != 'All') {
      switch (_selectedFilter) {
        case 'Recent':
          filtered.sort((a, b) {
            final aTime = a['createdAt'] as Timestamp?;
            final bTime = b['createdAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });
          filtered = filtered.take(10).toList();
          break;
        case 'Most Teachers':
          filtered.sort((a, b) {
            final aCount = (a['teacherIds'] as List).length;
            final bCount = (b['teacherIds'] as List).length;
            return bCount.compareTo(aCount);
          });
          break;
        case 'Most Classes':
          filtered.sort((a, b) {
            final aCount = (a['classIds'] as List).length;
            final bCount = (b['classIds'] as List).length;
            return bCount.compareTo(aCount);
          });
          break;
      }
    }

    return filtered;
  }

  void _showCreateSubjectDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateSubjectDialog(
        schoolId: widget.schoolId,
        teachers: _teachers,
        classes: _classes,
        onSubjectCreated: () {
          _loadSchoolData();
        },
      ),
    );
  }

  void _showSubjectDetails(Map<String, dynamic> subject) {
    showDialog(
      context: context,
      builder: (context) => SubjectDetailsDialog(
        subject: subject,
        teachers: _teachers,
        classes: _classes,
        onSubjectUpdated: () {
          _loadSchoolData();
        },
        onSubjectDeleted: () {
          _loadSchoolData();
        },
      ),
    );
  }

  Future<void> _deleteSubject(String subjectId, String subjectName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[600], size: 28),
            const SizedBox(width: 12),
            const Text('Delete Subject'),
          ],
        ),
        content: Text('Are you sure you want to delete "$subjectName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Mark subject as inactive instead of deleting
        await FirebaseFirestore.instance
            .collection('subjects')
            .doc(subjectId)
            .update({'isActive': false});

        _showSuccess('Subject deleted successfully');
        _loadSchoolData();
      } catch (e) {
        _showError('Failed to delete subject: $e');
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundBlue,
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoadingView() : _buildMainContent(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Subject Management',
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
        IconButton(
          onPressed: _refreshData,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _isRefreshing
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : const Icon(Icons.refresh, size: 18, color: Colors.white),
          ),
        ),
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
                '${_subjects.length} Subjects',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [primaryBlue, secondaryBlue, accentBlue, backgroundBlue],
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
              'Loading subjects and school data...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [primaryBlue, secondaryBlue, accentBlue, backgroundBlue],
          stops: [0.0, 0.2, 0.4, 0.8],
        ),
      ),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              _buildHeaderSection(),
              _buildSearchAndFilter(),
              Expanded(child: _buildSubjectsList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
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
        border: Border.all(color: paleBlue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentBlue.withOpacity(0.1), lightBlue.withOpacity(0.1)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: lightBlue.withOpacity(0.3), width: 2),
            ),
            child: const Icon(Icons.subject_outlined, size: 32, color: secondaryBlue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [primaryBlue, secondaryBlue],
                  ).createShader(bounds),
                  child: const Text(
                    'Subject Portal',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage school subjects and assignments',
                  style: TextStyle(
                    color: primaryBlue.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _buildStatsChip(),
        ],
      ),
    );
  }

  Widget _buildStatsChip() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundBlue.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: lightBlue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatItem(Icons.book_outlined, _subjects.length, 'Subjects'),
              const SizedBox(width: 12),
              Container(height: 20, width: 1, color: lightBlue.withOpacity(0.3)),
              const SizedBox(width: 12),
              _buildStatItem(Icons.person_outline, _teachers.length, 'Teachers'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, int count, String label) {
    return Column(
      children: [
        Icon(icon, color: accentBlue, size: 16),
        const SizedBox(height: 2),
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: secondaryBlue,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: primaryBlue.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _buildSearchBar()),
          const SizedBox(width: 12),
          _buildFilterDropdown(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
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
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Search subjects...',
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [lightBlue.withOpacity(0.2), paleBlue.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.search, color: secondaryBlue, size: 20),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: surfaceBlue,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: lightBlue.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: lightBlue.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFilter,
          icon: const Icon(Icons.filter_list, color: secondaryBlue, size: 20),
          items: ['All', 'Recent', 'Most Teachers', 'Most Classes']
              .map((filter) => DropdownMenuItem(
            value: filter,
            child: Text(
              filter,
              style: const TextStyle(
                color: primaryBlue,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ))
              .toList(),
          onChanged: (value) => setState(() => _selectedFilter = value!),
        ),
      ),
    );
  }

  Widget _buildSubjectsList() {
    final filteredSubjects = _filteredSubjects;

    if (filteredSubjects.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      margin: const EdgeInsets.all(20),
      child: ListView.builder(
        itemCount: filteredSubjects.length,
        itemBuilder: (context, index) {
          final subject = filteredSubjects[index];
          return _buildSubjectCard(subject, index);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: lightBlue.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.book_outlined,
              size: 64,
              color: lightBlue.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty ? 'No subjects found' : 'No subjects created yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search terms'
                : 'Create your first subject to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject, int index) {
    final teacherCount = (subject['teacherIds'] as List).length;
    final classCount = (subject['classIds'] as List).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: paleBlue.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showSubjectDetails(subject),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accentBlue.withOpacity(0.15), lightBlue.withOpacity(0.1)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: lightBlue.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.subject_outlined, color: secondaryBlue, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subject['name'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: primaryBlue,
                            ),
                          ),
                          if (subject['description'].isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subject['description'],
                              style: TextStyle(
                                fontSize: 14,
                                color: primaryBlue.withOpacity(0.7),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'delete') {
                          _deleteSubject(subject['id'], subject['name']);
                        } else if (action == 'edit') {
                          _showSubjectDetails(subject);
                        }
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: lightBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.more_vert, color: secondaryBlue, size: 18),
                      ),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, color: accentBlue, size: 18),
                              SizedBox(width: 8),
                              Text('Edit Subject'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Text('Delete Subject'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildInfoBadge(
                      Icons.person_outline,
                      teacherCount,
                      teacherCount == 1 ? 'Teacher' : 'Teachers',
                      accentBlue,
                    ),
                    const SizedBox(width: 12),
                    _buildInfoBadge(
                      Icons.class_outlined,
                      classCount,
                      classCount == 1 ? 'Class' : 'Classes',
                      secondaryBlue,
                    ),
                    const Spacer(),
                    if (subject['createdAt'] != null)
                      Text(
                        'Created ${_formatDate(subject['createdAt'] as Timestamp)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: primaryBlue.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, int count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accentBlue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: _showCreateSubjectDialog,
        backgroundColor: Colors.transparent,
        elevation: 0,
        label: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [secondaryBlue, accentBlue],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Create Subject',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

// Create Subject Dialog
class CreateSubjectDialog extends StatefulWidget {
  final String schoolId;
  final List<Map<String, dynamic>> teachers;
  final List<Map<String, dynamic>> classes;
  final VoidCallback onSubjectCreated;

  const CreateSubjectDialog({
    super.key,
    required this.schoolId,
    required this.teachers,
    required this.classes,
    required this.onSubjectCreated,
  });

  @override
  State<CreateSubjectDialog> createState() => _CreateSubjectDialogState();
}

class _CreateSubjectDialogState extends State<CreateSubjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<String> _selectedTeacherIds = [];
  List<String> _selectedClassIds = [];
  bool _isCreating = false;

  // Blue Color Palette
  static const Color primaryBlue = Color(0xFF0F172A);
  static const Color secondaryBlue = Color(0xFF1E40AF);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color lightBlue = Color(0xFF60A5FA);
  static const Color paleBlue = Color(0xFF93C5FD);
  static const Color surfaceBlue = Color(0xFFF0F9FF);

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
        'createdBy': 'principal',
        'isActive': true,
      };

      final subjectRef = await FirebaseFirestore.instance
          .collection('subjects')
          .add(subjectData);

      final subjectId = subjectRef.id;

      // Update school document
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .update({
        'subjectIds': FieldValue.arrayUnion([subjectId]),
      });

      // Update teachers
      for (final teacherId in _selectedTeacherIds) {
        await FirebaseFirestore.instance
            .collection('teachers')
            .doc(teacherId)
            .update({
          'subjectIds': FieldValue.arrayUnion([subjectId]),
          'subjectsAssigned': FieldValue.arrayUnion([subjectId]),
          'classesAssigned': FieldValue.arrayUnion(_selectedClassIds),
        });
      }

      // Update classes
      for (final classId in _selectedClassIds) {
        await FirebaseFirestore.instance
            .collection('classes')
            .doc(classId)
            .update({
          'subjectIds': FieldValue.arrayUnion([subjectId]),
        });
      }

      _showSuccess('Subject created successfully!');
      widget.onSubjectCreated();
      Navigator.pop(context);

    } catch (e) {
      _showError('Failed to create subject: $e');
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red[400],
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentBlue.withOpacity(0.1), lightBlue.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_box_outlined, color: secondaryBlue, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Create New Subject',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: primaryBlue,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: primaryBlue),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subject Name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Subject Name',
                          prefixIcon: const Icon(Icons.book_outlined, color: secondaryBlue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: accentBlue, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter subject name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          prefixIcon: const Icon(Icons.description_outlined, color: secondaryBlue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: accentBlue, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Teachers Section
                      const Text(
                        'Assign Teachers',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        decoration: BoxDecoration(
                          border: Border.all(color: paleBlue.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            children: widget.teachers.map((teacher) {
                              final isSelected = _selectedTeacherIds.contains(teacher['id']);
                              return CheckboxListTile(
                                title: Text(teacher['name']),
                                subtitle: Text('Subjects: ${teacher['subjects'].join(', ')}'),
                                value: isSelected,
                                onChanged: (selected) {
                                  setState(() {
                                    if (selected == true) {
                                      _selectedTeacherIds.add(teacher['id']);
                                    } else {
                                      _selectedTeacherIds.remove(teacher['id']);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Classes Section
                      const Text(
                        'Assign Classes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        decoration: BoxDecoration(
                          border: Border.all(color: paleBlue.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            children: widget.classes.map((klass) {
                              final isSelected = _selectedClassIds.contains(klass['id']);
                              return CheckboxListTile(
                                title: Text('Grade ${klass['name']}'),
                                subtitle: Text('Capacity: ${klass['capacity']} students'),
                                value: isSelected,
                                onChanged: (selected) {
                                  setState(() {
                                    if (selected == true) {
                                      _selectedClassIds.add(klass['id']);
                                    } else {
                                      _selectedClassIds.remove(klass['id']);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isCreating ? null : _createSubject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isCreating
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Text(
                      'Create Subject',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

// Subject Details Dialog
class SubjectDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> subject;
  final List<Map<String, dynamic>> teachers;
  final List<Map<String, dynamic>> classes;
  final VoidCallback onSubjectUpdated;
  final VoidCallback onSubjectDeleted;

  const SubjectDetailsDialog({
    super.key,
    required this.subject,
    required this.teachers,
    required this.classes,
    required this.onSubjectUpdated,
    required this.onSubjectDeleted,
  });

  @override
  State<SubjectDetailsDialog> createState() => _SubjectDetailsDialogState();
}

class _SubjectDetailsDialogState extends State<SubjectDetailsDialog> {
  // Blue Color Palette
  static const Color primaryBlue = Color(0xFF0F172A);
  static const Color secondaryBlue = Color(0xFF1E40AF);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color lightBlue = Color(0xFF60A5FA);
  static const Color paleBlue = Color(0xFF93C5FD);
  static const Color surfaceBlue = Color(0xFFF0F9FF);

  @override
  Widget build(BuildContext context) {
    final assignedTeachers = widget.teachers
        .where((teacher) =>
        (widget.subject['teacherIds'] as List).contains(teacher['id']))
        .toList();

    final assignedClasses = widget.classes
        .where((klass) =>
        (widget.subject['classIds'] as List).contains(klass['id']))
        .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentBlue.withOpacity(0.1), lightBlue.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.subject_outlined, color: secondaryBlue, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.subject['name'],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: primaryBlue,
                        ),
                      ),
                      if (widget.subject['description'].isNotEmpty)
                        Text(
                          widget.subject['description'],
                          style: TextStyle(
                            fontSize: 14,
                            color: primaryBlue.withOpacity(0.7),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: primaryBlue),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Assigned Teachers
                    _buildSection(
                      'Assigned Teachers',
                      Icons.person_outline,
                      assignedTeachers.isEmpty
                          ? [const Text('No teachers assigned')]
                          : assignedTeachers.map((teacher) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: accentBlue.withOpacity(0.1),
                          child: Text(
                            teacher['name'][0].toUpperCase(),
                            style: const TextStyle(
                              color: accentBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        title: Text(teacher['name']),
                        subtitle: Text('Subjects: ${teacher['subjects'].join(', ')}'),
                      )).toList(),
                    ),

                    const SizedBox(height: 20),

                    // Assigned Classes
                    _buildSection(
                      'Assigned Classes',
                      Icons.class_outlined,
                      assignedClasses.isEmpty
                          ? [const Text('No classes assigned')]
                          : assignedClasses.map((klass) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: secondaryBlue.withOpacity(0.1),
                          child: const Icon(Icons.school, color: secondaryBlue),
                        ),
                        title: Text('Grade ${klass['name']}'),
                        subtitle: Text('Capacity: ${klass['capacity']} students'),
                      )).toList(),
                    ),

                    const SizedBox(height: 20),

                    // Subject Info
                    _buildInfoSection(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Close current dialog
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => EditSubjectDialog(
                          subject: widget.subject,
                          teachers: widget.teachers,
                          classes: widget.classes,
                          onSubjectUpdated: widget.onSubjectUpdated,
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showDeleteConfirmation();
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceBlue.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: paleBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: secondaryBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    final createdAt = widget.subject['createdAt'] as Timestamp?;
    final createdBy = widget.subject['createdBy'] ?? 'Unknown';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceBlue.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: paleBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: secondaryBlue, size: 20),
              SizedBox(width: 8),
              Text(
                'Subject Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (createdAt != null)
            _buildInfoRow('Created', _formatDate(createdAt)),
          _buildInfoRow('Created By', createdBy),
          _buildInfoRow('Status', 'Active'),
          _buildInfoRow('School ID', widget.subject['schoolId']),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: primaryBlue.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange[600], size: 28),
              const SizedBox(width: 12),
              const Text('Delete Subject'),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "${widget.subject['name']}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onSubjectDeleted();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        )
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Edit Subject Dialog - Complete implementation
class EditSubjectDialog extends StatefulWidget {
  final Map<String, dynamic> subject;
  final List<Map<String, dynamic>> teachers;
  final List<Map<String, dynamic>> classes;
  final VoidCallback onSubjectUpdated;

  const EditSubjectDialog({
    super.key,
    required this.subject,
    required this.teachers,
    required this.classes,
    required this.onSubjectUpdated,
  });

  @override
  State<EditSubjectDialog> createState() => _EditSubjectDialogState();
}

class _EditSubjectDialogState extends State<EditSubjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<String> _selectedTeacherIds = [];
  List<String> _selectedClassIds = [];
  bool _isUpdating = false;

  // Blue Color Palette
  static const Color primaryBlue = Color(0xFF0F172A);
  static const Color secondaryBlue = Color(0xFF1E40AF);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color lightBlue = Color(0xFF60A5FA);
  static const Color paleBlue = Color(0xFF93C5FD);
  static const Color surfaceBlue = Color(0xFFF0F9FF);

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    _nameController.text = widget.subject['name'] ?? '';
    _descriptionController.text = widget.subject['description'] ?? '';
    _selectedTeacherIds = List<String>.from(widget.subject['teacherIds'] ?? []);
    _selectedClassIds = List<String>.from(widget.subject['classIds'] ?? []);
  }

  Future<void> _updateSubject() async {
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
      _isUpdating = true;
    });

    try {
      final subjectId = widget.subject['id'];
      final oldTeacherIds = List<String>.from(widget.subject['teacherIds'] ?? []);
      final oldClassIds = List<String>.from(widget.subject['classIds'] ?? []);

      // Update subject document
      await FirebaseFirestore.instance
          .collection('subjects')
          .doc(subjectId)
          .update({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'teacherIds': _selectedTeacherIds,
        'classIds': _selectedClassIds,
        'teachersAssigned': _selectedTeacherIds,
        'classesAssigned': _selectedClassIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Handle teacher assignments
      await _updateTeacherAssignments(subjectId, oldTeacherIds, _selectedTeacherIds, _selectedClassIds);

      // Handle class assignments
      await _updateClassAssignments(subjectId, oldClassIds, _selectedClassIds);

      _showSuccess('Subject updated successfully!');
      widget.onSubjectUpdated();
      Navigator.pop(context);

    } catch (e) {
      _showError('Failed to update subject: $e');
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _updateTeacherAssignments(
      String subjectId,
      List<String> oldTeacherIds,
      List<String> newTeacherIds,
      List<String> classIds
      ) async {
    // Remove subject from teachers who are no longer assigned
    final removedTeacherIds = oldTeacherIds.where((id) => !newTeacherIds.contains(id)).toList();
    for (final teacherId in removedTeacherIds) {
      await FirebaseFirestore.instance
          .collection('teachers')
          .doc(teacherId)
          .update({
        'subjectIds': FieldValue.arrayRemove([subjectId]),
        'subjectsAssigned': FieldValue.arrayRemove([subjectId]),
      });
    }

    // Add subject to newly assigned teachers
    final addedTeacherIds = newTeacherIds.where((id) => !oldTeacherIds.contains(id)).toList();
    for (final teacherId in addedTeacherIds) {
      await FirebaseFirestore.instance
          .collection('teachers')
          .doc(teacherId)
          .update({
        'subjectIds': FieldValue.arrayUnion([subjectId]),
        'subjectsAssigned': FieldValue.arrayUnion([subjectId]),
        'classesAssigned': FieldValue.arrayUnion(classIds),
      });
    }

    // Update class assignments for existing teachers
    for (final teacherId in newTeacherIds.where((id) => oldTeacherIds.contains(id))) {
      await FirebaseFirestore.instance
          .collection('teachers')
          .doc(teacherId)
          .update({
        'classesAssigned': FieldValue.arrayUnion(classIds),
      });
    }
  }

  Future<void> _updateClassAssignments(String subjectId, List<String> oldClassIds, List<String> newClassIds) async {
    // Remove subject from classes that are no longer assigned
    final removedClassIds = oldClassIds.where((id) => !newClassIds.contains(id)).toList();
    for (final classId in removedClassIds) {
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .update({
        'subjectIds': FieldValue.arrayRemove([subjectId]),
      });
    }

    // Add subject to newly assigned classes
    final addedClassIds = newClassIds.where((id) => !oldClassIds.contains(id)).toList();
    for (final classId in addedClassIds) {
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .update({
        'subjectIds': FieldValue.arrayUnion([subjectId]),
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red[400],
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentBlue.withOpacity(0.1), lightBlue.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit_outlined, color: secondaryBlue, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Edit Subject',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: primaryBlue,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: primaryBlue),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subject Name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Subject Name',
                          prefixIcon: const Icon(Icons.book_outlined, color: secondaryBlue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: accentBlue, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter subject name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          prefixIcon: const Icon(Icons.description_outlined, color: secondaryBlue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: accentBlue, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Teachers Section
                      const Text(
                        'Assign Teachers',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        decoration: BoxDecoration(
                          border: Border.all(color: paleBlue.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            children: widget.teachers.map((teacher) {
                              final isSelected = _selectedTeacherIds.contains(teacher['id']);
                              return CheckboxListTile(
                                title: Text(teacher['name']),
                                subtitle: Text('Subjects: ${teacher['subjects'].join(', ')}'),
                                value: isSelected,
                                activeColor: accentBlue,
                                onChanged: (selected) {
                                  setState(() {
                                    if (selected == true) {
                                      _selectedTeacherIds.add(teacher['id']);
                                    } else {
                                      _selectedTeacherIds.remove(teacher['id']);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Classes Section
                      const Text(
                        'Assign Classes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        decoration: BoxDecoration(
                          border: Border.all(color: paleBlue.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            children: widget.classes.map((klass) {
                              final isSelected = _selectedClassIds.contains(klass['id']);
                              return CheckboxListTile(
                                title: Text('Grade ${klass['name']}'),
                                subtitle: Text('Capacity: ${klass['capacity']} students'),
                                value: isSelected,
                                activeColor: accentBlue,
                                onChanged: (selected) {
                                  setState(() {
                                    if (selected == true) {
                                      _selectedClassIds.add(klass['id']);
                                    } else {
                                      _selectedClassIds.remove(klass['id']);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: accentBlue),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: accentBlue, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isUpdating ? null : _updateSubject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isUpdating
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Text(
                      'Update Subject',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}