import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SelfAttendanceScreen extends StatefulWidget {
  final String staffId;

  const SelfAttendanceScreen({
    Key? key,
    required this.staffId,
  }) : super(key: key);

  @override
  State<SelfAttendanceScreen> createState() => _SelfAttendanceScreenState();
}

class _SelfAttendanceScreenState extends State<SelfAttendanceScreen> {
  DateTime selectedDate = DateTime.now();
  String forenoonStatus = 'Present';
  String afternoonStatus = 'Present';

  List<Map<String, dynamic>> attendanceList = [];
  int totalDays = 0;
  int presentDays = 0;
  double attendancePercentage = 0.0;

  String? schoolId;
  bool isLoading = true;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _fetchSchoolId();
    await fetchAttendanceData();
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _fetchSchoolId() async {
    final staffDoc = await FirebaseFirestore.instance
        .collection('supportstaff')
        .doc(widget.staffId)
        .get();

    if (staffDoc.exists && staffDoc.data()!.containsKey('schoolId')) {
      schoolId = staffDoc['schoolId'];
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('School ID not found for staff', Colors.red),
      );
      Navigator.pop(context);
    }
  }

  Future<void> fetchAttendanceData() async {
    if (schoolId == null) return;
    final docId = "${schoolId!}_${widget.staffId}";

    final doc = await FirebaseFirestore.instance
        .collection('support_staff_attendance')
        .doc(docId)
        .get();

    if (doc.exists) {
      List<dynamic> data = doc['attendance'] ?? [];
      attendanceList = data.cast<Map<String, dynamic>>();

      totalDays = attendanceList.length;
      presentDays = attendanceList
          .where((entry) =>
      entry['forenoon'] == 'Present' || entry['afternoon'] == 'Present')
          .length;
      attendancePercentage = totalDays > 0 ? (presentDays / totalDays) * 100 : 0;
    }
  }

  Future<void> markAttendance() async {
    if (schoolId == null) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
      final docId = "${schoolId!}_${widget.staffId}";

      final newEntry = {
        'date': formattedDate,
        'forenoon': forenoonStatus,
        'afternoon': afternoonStatus,
      };

      final docRef = FirebaseFirestore.instance
          .collection('support_staff_attendance')
          .doc(docId);

      final doc = await docRef.get();

      if (doc.exists) {
        List<dynamic> attendance = doc['attendance'] ?? [];
        attendance.removeWhere((entry) => entry['date'] == formattedDate);
        attendance.add(newEntry);

        await docRef.update({'attendance': attendance});
      } else {
        await docRef.set({
          'schoolId': schoolId,
          'staffId': widget.staffId,
          'attendance': [newEntry]
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar("Attendance marked successfully", Colors.green),
      );

      await fetchAttendanceData();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar("Error marking attendance", Colors.red),
      );
    } finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }

  SnackBar _buildSnackBar(String message, Color color) {
    return SnackBar(
      content: Row(
        children: [
          Icon(
            color == Colors.green ? Icons.check_circle : Icons.error,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      backgroundColor: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),

      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.blue.shade600,
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade600,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Color _getAttendanceColor() {
    if (attendancePercentage >= 90) {
      return Colors.green.shade600;
    } else if (attendancePercentage >= 75) {
      return Colors.orange.shade600;
    } else {
      return Colors.red.shade600;
    }
  }

  IconData _getAttendanceIcon() {
    if (attendancePercentage >= 90) {
      return Icons.sentiment_very_satisfied;
    } else if (attendancePercentage >= 75) {
      return Icons.sentiment_neutral;
    } else {
      return Icons.sentiment_dissatisfied;
    }
  }

  Widget _buildStatusDropdown(String label, String value, Function(String?) onChanged, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.blue.shade100,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.blue.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: value == 'Present'
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: value == 'Present'
                    ? Colors.green.shade300
                    : Colors.red.shade300,
                width: 1,
              ),
            ),
            child: DropdownButton<String>(
              value: value,
              underline: const SizedBox(),
              icon: Icon(
                Icons.arrow_drop_down,
                color: value == 'Present'
                    ? Colors.green.shade600
                    : Colors.red.shade600,
              ),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: value == 'Present'
                    ? Colors.green.shade700
                    : Colors.red.shade700,
              ),
              items: ['Present', 'Absent']
                  .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e),
              ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('MMM dd, yyyy').format(selectedDate);

    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              Text(
                'Loading attendance data...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'My Attendance',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() {
                isLoading = true;
              });
              await fetchAttendanceData();
              setState(() {
                isLoading = false;
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await fetchAttendanceData();
        },
        color: Colors.blue.shade600,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Attendance Statistics Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade200.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getAttendanceIcon(),
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Attendance Overview',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Track your daily attendance',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '$totalDays',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Text(
                                  'Total Days',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '$presentDays',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Text(
                                  'Present Days',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${attendancePercentage.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Text(
                                  'Percentage',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Mark Attendance Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade100.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.blue.shade100,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.edit_calendar,
                            color: Colors.blue.shade600,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Mark Attendance',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Date Selection
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.shade200,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.calendar_today,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selected Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _selectDate(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Change',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Forenoon Status
                    _buildStatusDropdown(
                      'Forenoon Session',
                      forenoonStatus,
                          (val) {
                        setState(() {
                          forenoonStatus = val!;
                        });
                      },
                      Icons.wb_sunny,
                    ),

                    const SizedBox(height: 12),

                    // Afternoon Status
                    _buildStatusDropdown(
                      'Afternoon Session',
                      afternoonStatus,
                          (val) {
                        setState(() {
                          afternoonStatus = val!;
                        });
                      },
                      Icons.wb_sunny_outlined,
                    ),

                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : markAttendance,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: isSubmitting
                            ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Marking Attendance...',
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
                            Icon(Icons.check_circle, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Mark Attendance',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}