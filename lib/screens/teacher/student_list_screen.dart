import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentListScreen extends StatelessWidget {
  final String classId;
  const StudentListScreen({super.key, required this.classId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Students'), backgroundColor: Colors.blue.shade900),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('classess').doc(classId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final List studentIds = data['studentIds'] ?? [];

          if (studentIds.isEmpty) return const Center(child: Text('No students assigned'));

          return ListView.builder(
            itemCount: studentIds.length,
            itemBuilder: (ctx, i) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('students').doc(studentIds[i]).get(),
                builder: (ctx, snap) {
                  if (!snap.hasData) return const ListTile(title: Text('Loading...'));
                  final student = snap.data!.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(student['name']),
                    subtitle: Text(student['email']),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
