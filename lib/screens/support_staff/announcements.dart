import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SupportStaffAnnouncementsScreen extends StatefulWidget {
  final String supportStaffId;
  const SupportStaffAnnouncementsScreen({Key? key, required this.supportStaffId}) : super(key: key);

  @override
  State<SupportStaffAnnouncementsScreen> createState() => _SupportStaffAnnouncementsScreenState();
}

class _SupportStaffAnnouncementsScreenState extends State<SupportStaffAnnouncementsScreen> {
  String? schoolId;
  bool isLoading = true;
  String? errorMessage;
  List<DocumentSnapshot> announcements = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Get the support staff's school ID from 'supportstaff' collection
      DocumentSnapshot supportStaffDoc = await FirebaseFirestore.instance
          .collection('supportstaff')
          .doc(widget.supportStaffId)
          .get();

      if (!supportStaffDoc.exists) {
        setState(() {
          isLoading = false;
          errorMessage = 'Support staff record not found';
        });
        return;
      }

      final supportStaffData = supportStaffDoc.data() as Map<String, dynamic>?;
      final fetchedSchoolId = supportStaffData?['schoolId'] as String?;

      if (fetchedSchoolId == null || fetchedSchoolId.isEmpty) {
        setState(() {
          isLoading = false;
          errorMessage = 'School ID not found for support staff';
        });
        return;
      }

      // Now get announcements for this school
      QuerySnapshot announcementsSnapshot = await FirebaseFirestore.instance
          .collection('announcements')
          .where('schoolId', isEqualTo: fetchedSchoolId)
          .get();

      // Filter announcements for support staff and sort by timestamp
      List<DocumentSnapshot> filteredAnnouncements = announcementsSnapshot.docs
          .where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return false;

        final audience = data['audience']?.toString().toLowerCase() ?? '';
        return audience == 'all' || audience == 'supportstaff' || audience == 'support staff';
      })
          .toList();

      // Sort by timestamp (newest first)
      filteredAnnouncements.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>?;
        final bData = b.data() as Map<String, dynamic>?;

        final aTimestamp = aData?['timestamp'];
        final bTimestamp = bData?['timestamp'];

        if (aTimestamp is Timestamp && bTimestamp is Timestamp) {
          return bTimestamp.compareTo(aTimestamp);
        }
        return 0;
      });

      setState(() {
        schoolId = fetchedSchoolId;
        announcements = filteredAnnouncements;
        isLoading = false;
      });

    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Error loading announcements: ${e.toString()}';
      });
    }
  }

  // Method to determine the color based on event date proximity
  Color _getEventDateColor(dynamic eventDate) {
    if (eventDate == null) {
      return Colors.grey.shade600;
    }

    DateTime? date;
    if (eventDate is Timestamp) {
      date = eventDate.toDate();
    } else if (eventDate is String) {
      date = DateTime.tryParse(eventDate);
    } else if (eventDate is DateTime) {
      date = eventDate;
    }

    if (date == null) {
      return Colors.grey.shade600;
    }

    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (difference <= 3) {
      return Colors.red.shade600; // Very close
    } else if (difference <= 14) {
      return Colors.orange.shade600; // A bit further
    } else {
      return Colors.green.shade600; // Far in the future
    }
  }

  String _formatEventDate(dynamic eventDate) {
    try {
      if (eventDate == null) {
        return 'No event date';
      }

      DateTime? dateTime;

      if (eventDate is Timestamp) {
        dateTime = eventDate.toDate();
      } else if (eventDate is String) {
        dateTime = DateTime.tryParse(eventDate);
      } else if (eventDate is DateTime) {
        dateTime = eventDate;
      } else {
        return 'Unknown date format';
      }

      if (dateTime == null || dateTime.year < 2000) {
        return 'No event date';
      }

      return DateFormat('MMM dd, yyyy').format(dateTime);

    } catch (e) {
      print('Error formatting eventDate: $e');
      return 'Error formatting date';
    }
  }

  Color _getPriorityColor(String? priority) {
    if (priority == null) return Colors.blue.shade600;

    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red.shade600;
      case 'medium':
        return Colors.orange.shade600;
      case 'low':
        return Colors.green.shade600;
      default:
        return Colors.blue.shade600;
    }
  }

  IconData _getPriorityIcon(String? priority) {
    if (priority == null) return Icons.announcement;

    switch (priority.toLowerCase()) {
      case 'high':
        return Icons.priority_high;
      case 'medium':
        return Icons.warning;
      case 'low':
        return Icons.info;
      default:
        return Icons.announcement;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Staff Announcements',
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
            onPressed: _loadData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (errorMessage != null) {
      return _buildErrorState(errorMessage!);
    }

    if (announcements.isEmpty) {
      return _buildEmptyState();
    }

    return _buildAnnouncementsList();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            'Loading announcements...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to load announcements',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 2,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Try Again',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                Icons.announcement_outlined,
                size: 80,
                color: Colors.blue.shade300,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Announcements',
              style: TextStyle(
                fontSize: 24,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'There are no announcements available for support staff at this time.\nCheck back later for updates from your school.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: _loadData,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue.shade600,
                side: BorderSide(color: Colors.blue.shade600),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 18),
                  SizedBox(width: 8),
                  Text('Refresh'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementsList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: Colors.blue.shade600,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: announcements.length,
        itemBuilder: (context, index) {
          DocumentSnapshot doc = announcements[index];
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return _buildAnnouncementCard(data);
        },
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> data) {
    String title = data['title']?.toString() ?? 'No Title';
    String message = data['message']?.toString() ?? 'No Message';
    String audience = data['audience']?.toString() ?? 'All';
    String? priority = data['priority']?.toString();
    dynamic eventDate = data['eventDate'];

    final eventDateColor = _getEventDateColor(eventDate);
    final formattedEventDate = _formatEventDate(eventDate);

    // Format audience display for support staff
    String displayAudience = audience.toLowerCase() == 'supportstaff' || audience.toLowerCase() == 'support staff'
        ? 'STAFF'
        : audience.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.blue.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(priority).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getPriorityIcon(priority),
                    color: _getPriorityColor(priority),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: audience.toLowerCase() == 'all'
                        ? Colors.green.shade100
                        : Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: audience.toLowerCase() == 'all'
                          ? Colors.green.shade300
                          : Colors.purple.shade300,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    displayAudience,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: audience.toLowerCase() == 'all'
                          ? Colors.green.shade700
                          : Colors.purple.shade700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade700,
                    height: 1.6,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 16),

                // Event Date display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: eventDateColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: eventDateColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event,
                        size: 16,
                        color: eventDateColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formattedEventDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: eventDateColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}