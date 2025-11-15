import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../blocs/notifications_bloc.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NotificationsBloc()..add(LoadNotificationsEvent()),
      child: const _NotificationsScreenContent(),
    );
  }
}

class _NotificationsScreenContent extends StatelessWidget {
  const _NotificationsScreenContent();

  void _showClearAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Clear All Notifications"),
          content: const Text("Are you sure you want to clear all notifications?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text("Cancel", style: TextStyle(color: Colors.grey[600])),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.read<NotificationsBloc>().add(ClearAllNotificationsEvent());
              },
              child: const Text("Clear All", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notification',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          BlocBuilder<NotificationsBloc, NotificationsState>(
            builder: (context, state) {
              if (state is NotificationsLoaded && state.notifications.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: GestureDetector(
                    onTap: () => _showClearAllDialog(context),
                    child: const Text(
                      "Clear All",
                      style: TextStyle(
                        color: Color(0xFF92A3FD),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocConsumer<NotificationsBloc, NotificationsState>(
        listener: (context, state) {
          if (state is NotificationsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is NotificationsCleared) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("All notifications cleared"),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is NotificationsLoading) {
            return _buildLoadingState(state.oldNotifications, context);
          } else if (state is NotificationsError) {
            return _buildErrorState(state, context);
          } else if (state is NotificationsLoaded) {
            return _buildNotificationsList(state.notifications, context);
          } else {
            return _buildLoadingState(null, context);
          }
        },
      ),
    );
  }

  Widget _buildLoadingState(List<Map<String, dynamic>>? oldNotifications, BuildContext context) {
    if (oldNotifications != null && oldNotifications.isNotEmpty) {
      return _buildNotificationsList(oldNotifications, context);
    }
    
    return const Center(
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

  Widget _buildErrorState(NotificationsError state, BuildContext context) {
    final notifications = state.oldNotifications;
    
    if (notifications != null && notifications.isNotEmpty) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.red[50],
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    state.message,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: () => context.read<NotificationsBloc>().add(LoadNotificationsEvent()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          Expanded(child: _buildNotificationsList(notifications, context)),
        ],
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 20),
          const Text(
            "Error Loading Notifications",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(state.message, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.read<NotificationsBloc>().add(LoadNotificationsEvent()),
            child: const Text("Try Again"),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(List<Map<String, dynamic>> notifications, BuildContext context) {
    final groupedNotifications = _groupNotificationsByDate(notifications);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notifications.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 20),
              child: ElevatedButton(
                onPressed: () => _showClearAllDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF92A3FD).withOpacity(0.1),
                  foregroundColor: const Color(0xFF92A3FD),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Row(
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

          if (notifications.isEmpty)
            _buildEmptyState()
          else
            ...groupedNotifications.entries.map((entry) {
              return Column(
                children: [
                  _buildNotificationSection(
                    context,
                    entry.key,
                    entry.value.map((notification) {
                      return _buildNotificationItem(notification, context);
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            }),
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
          const SizedBox(height: 20),
          const Text(
            "No Notifications",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "You're all caught up!",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupNotificationsByDate(List<Map<String, dynamic>> notifications) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    
    for (final notification in notifications) {
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

  Widget _buildNotificationSection(BuildContext context, String title, List<Widget> notifications) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 15),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
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

  Widget _buildNotificationItem(Map<String, dynamic> notification, BuildContext context) {
    return Dismissible(
      key: Key(notification['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        context.read<NotificationsBloc>().add(DeleteNotificationEvent(notification['id']));
      },
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
                const SizedBox(width: 15),
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
                      const SizedBox(height: 5),
                      Text(
                        notification['time'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!notification['read'])
                  GestureDetector(
                    onTap: () => context.read<NotificationsBloc>().add(MarkAsReadEvent(notification['id'])),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
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