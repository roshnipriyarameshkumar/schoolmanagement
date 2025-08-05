
// FILE: lib/screens/teacher/mark_attendance_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'attendance_screen.dart';

class MarkAttendanceScreen extends StatefulWidget {
  final ClassInfo classInfo;
  final String teacherId;

  const MarkAttendanceScreen({
    Key? key,
    required this.classInfo,
    required this.teacherId,
  }) : super(key: key);

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  List<String> studentIds = [];
  Map<String, String> forenoon = {};
  Map<String, String> afternoon = {};

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  void _loadStudents() async {
    final classDoc = await FirebaseFirestore.instance.collection('classess').doc(widget.classInfo.id).get();
    final data = classDoc.data() ?? {};
    final List<dynamic> ids = data['studentIds'] ?? [];
    setState(() {
      studentIds = ids.cast<String>();
      for (var id in studentIds) {
        forenoon[id] = 'Present';
        afternoon[id] = 'Present';
      }
    });
  }

  void _submitAttendance() async {
    final today = DateTime.now();
    final docId = "${widget.classInfo.id}_${today.year}-${today.month}-${today.day}";

    await FirebaseFirestore.instance.collection('attendance').doc(docId).set({
      'classId': widget.classInfo.id,
      'date': today,
      'markedBy': widget.teacherId,
      'forenoon': forenoon,
      'afternoon': afternoon,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attendance submitted')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        backgroundColor: Colors.blue.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _submitAttendance,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: studentIds.length,
        itemBuilder: (ctx, index) {
          final id = studentIds[index];
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('students').doc(id).get(),
            builder: (ctx, snap) {
              if (!snap.hasData) return const ListTile(title: Text('Loading...'));
              final data = snap.data!.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.all(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['name'] ?? 'Student', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Forenoon:'),
                          DropdownButton<String>(
                            value: forenoon[id],
                            items: ['Present', 'Absent', 'On Duty']
                                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                forenoon[id] = val!;
                              });
                            },
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Afternoon:'),
                          DropdownButton<String>(
                            value: afternoon[id],
                            items: ['Present', 'Absent', 'On Duty']
                                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                afternoon[id] = val!;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
