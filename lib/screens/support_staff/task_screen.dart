import 'package:flutter/material.dart';

class TaskScreen extends StatelessWidget {
  final String role;
  const TaskScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    List<String> tasks = [];

    if (role == 'Security') {
      tasks = ['Gate Monitoring', 'Visitor Logs', 'Incident Reporting'];
    } else if (role == 'Assistant') {
      tasks = ['Classroom Setup', 'Material Handling', 'Support Teachers'];
    }

    return Scaffold(
      appBar: AppBar(title: Text('$role Tasks')),
      body: ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.task),
            title: Text(tasks[index]),
          );
        },
      ),
    );
  }
}
