import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ManageSchoolScreen extends StatelessWidget {
  const ManageSchoolScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Schools'),
        backgroundColor: Colors.teal,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('schools').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No schools created yet.'));
          }

          final schools = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: schools.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final school = schools[index];
              final schoolName = school['name'];
              final schoolId = school.id;

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
                child: ListTile(
                  leading: const Icon(Icons.school, color: Colors.teal),
                  title: Text(schoolName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Tap to manage school setup'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SchoolSetupPanel(
                          schoolId: schoolId,
                          schoolName: schoolName,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class SchoolSetupPanel extends StatelessWidget {
  final String schoolId;
  final String schoolName;

  const SchoolSetupPanel({Key? key, required this.schoolId, required this.schoolName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final steps = [
      {
        'title': 'Staff Setup',
        'icon': Icons.people,
        'screen': StaffSetupScreen(schoolId: schoolId),
      },
      {
        'title': 'Class Setup',
        'icon': Icons.class_,
        'screen': ClassSetupScreen(schoolId: schoolId),
      },
      {
        'title': 'Subject Setup',
        'icon': Icons.book,
        'screen': SubjectSetupScreen(schoolId: schoolId),
      },
      {
        'title': 'Student Setup',
        'icon': Icons.person,
        'screen': StudentSetupScreen(schoolId: schoolId),
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('$schoolName Setup'),
        backgroundColor: Colors.teal,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: steps.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final step = steps[index];
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: ListTile(
              leading: Icon(step['icon'] as IconData, color: Colors.teal, size: 32),
              title: Text(
                step['title'] as String,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Click to continue setup'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => step['screen'] as Widget),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// Placeholder Screens - Replace with actual screen implementations
class StaffSetupScreen extends StatelessWidget {
  final String schoolId;
  const StaffSetupScreen({super.key, required this.schoolId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff Setup')),
      body: Center(child: Text('Staff setup for $schoolId')),
    );
  }
}

class ClassSetupScreen extends StatelessWidget {
  final String schoolId;
  const ClassSetupScreen({super.key, required this.schoolId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Class Setup')),
      body: Center(child: Text('Class setup for $schoolId')),
    );
  }
}

class SubjectSetupScreen extends StatelessWidget {
  final String schoolId;
  const SubjectSetupScreen({super.key, required this.schoolId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subject Setup')),
      body: Center(child: Text('Subject setup for $schoolId')),
    );
  }
}

class StudentSetupScreen extends StatelessWidget {
  final String schoolId;
  const StudentSetupScreen({super.key, required this.schoolId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Setup')),
      body: Center(child: Text('Student setup for $schoolId')),
    );
  }
}
