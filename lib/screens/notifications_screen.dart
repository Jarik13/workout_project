import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (_currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('user_notifications')
          .doc(_currentUser.uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        _notifications = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'title': data['title'] ?? '',
            'time': _formatTime(data['timestamp']),
            'image': data['image'] ?? 'assets/images/default_notification.png',
            'timestamp': data['timestamp'],
            'read': data['read'] ?? false,
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearAllNotifications() async {
    if (_currentUser == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Clear All Notifications"),
          content: Text("Are you sure you want to clear all notifications?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancel", style: TextStyle(color: Colors.grey[600])),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                
                try {
                  final snapshot = await _firestore
                      .collection('user_notifications')
                      .doc(_currentUser.uid)
                      .collection('notifications')
                      .get();

                  final batch = _firestore.batch();
                  for (final doc in snapshot.docs) {
                    batch.delete(doc.reference);
                  }
                  await batch.commit();

                  setState(() {
                    _notifications.clear();
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("All notifications cleared"),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  print('Error clearing notifications: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error clearing notifications"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text("Clear All", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await _firestore
          .collection('user_notifications')
          .doc(_currentUser!.uid)
          .collection('notifications')
          .doc(notificationId)
          .delete();

      setState(() {
        _notifications.removeWhere((notification) => notification['id'] == notificationId);
      });
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('user_notifications')
          .doc(_currentUser!.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});

      setState(() {
        final index = _notifications.indexWhere((n) => n['id'] == notificationId);
        if (index != -1) {
          _notifications[index]['read'] = true;
        }
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return 'Unknown time';
    
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return 'Unknown time';
    }

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupNotificationsByDate() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    
    for (final notification in _notifications) {
      final timestamp = notification['timestamp'];
      DateTime date;
      
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else {
        continue;
      }

      final now = DateTime.now();
      final String sectionTitle;
      
      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        sectionTitle = 'Today';
      } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
        sectionTitle = 'Yesterday';
      } else {
        sectionTitle = '${_getMonthName(date.month)} ${date.year}';
      }
      
      if (!grouped.containsKey(sectionTitle)) {
        grouped[sectionTitle] = [];
      }
      grouped[sectionTitle]!.add(notification);
    }
    
    return grouped;
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final groupedNotifications = _groupNotificationsByDate();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notification',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_notifications.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: GestureDetector(
                onTap: _clearAllNotifications,
                child: Text(
                  "Clear All",
                  style: TextStyle(
                    color: Color(0xFF92A3FD),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _notifications.isEmpty
              ? _buildEmptyState()
              : _buildNotificationsList(groupedNotifications),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF92A3FD)),
          SizedBox(height: 20),
          Text('Loading notifications...'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 50,
              color: Colors.grey[400],
            ),
          ),
          SizedBox(height: 20),
          Text(
            "No Notifications",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 10),
          Text(
            "You're all caught up!",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(Map<String, List<Map<String, dynamic>>> groupedNotifications) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: 20),
            child: ElevatedButton(
              onPressed: _clearAllNotifications,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF92A3FD).withOpacity(0.1),
                foregroundColor: Color(0xFF92A3FD),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.clear_all, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Clear All Notifications",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          ...groupedNotifications.entries.map((entry) {
            return Column(
              children: [
                _buildNotificationSection(
                  entry.key,
                  entry.value.map((notification) {
                    return _buildNotificationItem(notification);
                  }).toList(),
                ),
                SizedBox(height: 20),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNotificationSection(String title, List<Widget> notifications) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 15),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: notifications,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    return Dismissible(
      key: Key(notification['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) => _deleteNotification(notification['id']),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: AssetImage(notification['image']),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification['title'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: notification['read'] ? Colors.grey[600] : Colors.black,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        notification['time'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!notification['read'])
                  GestureDetector(
                    onTap: () => _markAsRead(notification['id']),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Color(0xFF92A3FD),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: Colors.grey[300],
            indent: 20,
            endIndent: 20,
          ),
        ],
      ),
    );
  }
}