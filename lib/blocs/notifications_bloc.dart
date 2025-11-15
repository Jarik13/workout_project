import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class NotificationsEvent {}

class LoadNotificationsEvent extends NotificationsEvent {}

class ClearAllNotificationsEvent extends NotificationsEvent {}

class DeleteNotificationEvent extends NotificationsEvent {
  final String notificationId;
  DeleteNotificationEvent(this.notificationId);
}

class MarkAsReadEvent extends NotificationsEvent {
  final String notificationId;
  MarkAsReadEvent(this.notificationId);
}


abstract class NotificationsState {}

class NotificationsLoading extends NotificationsState {
  final List<Map<String, dynamic>>? oldNotifications;
  NotificationsLoading({this.oldNotifications});
}

class NotificationsLoaded extends NotificationsState {
  final List<Map<String, dynamic>> notifications;
  NotificationsLoaded(this.notifications);
}

class NotificationsError extends NotificationsState {
  final String message;
  final List<Map<String, dynamic>>? oldNotifications;
  NotificationsError({required this.message, this.oldNotifications});
}

class NotificationsCleared extends NotificationsState {
  NotificationsCleared();
}


class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  NotificationsBloc() : super(NotificationsLoading()) {
    on<LoadNotificationsEvent>(_onLoadNotifications);
    on<ClearAllNotificationsEvent>(_onClearAllNotifications);
    on<DeleteNotificationEvent>(_onDeleteNotification);
    on<MarkAsReadEvent>(_onMarkAsRead);
  }

  Future<void> _onLoadNotifications(
    LoadNotificationsEvent event,
    Emitter<NotificationsState> emit,
  ) async {
    try {
      emit(NotificationsLoading(
        oldNotifications: state is NotificationsLoaded 
            ? (state as NotificationsLoaded).notifications 
            : null,
      ));

      if (_currentUser == null) {
        emit(NotificationsLoaded([]));
        return;
      }

      final snapshot = await _firestore
          .collection('user_notifications')
          .doc(_currentUser.uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .get();

      final notifications = snapshot.docs.map((doc) {
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

      emit(NotificationsLoaded(notifications));
    } catch (e) {
      emit(NotificationsError(
        message: 'Failed to load notifications: $e',
        oldNotifications: state is NotificationsLoaded 
            ? (state as NotificationsLoaded).notifications 
            : null,
      ));
    }
  }

  Future<void> _onClearAllNotifications(
    ClearAllNotificationsEvent event,
    Emitter<NotificationsState> emit,
  ) async {
    try {
      if (_currentUser == null) return;

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

      emit(NotificationsCleared());
      add(LoadNotificationsEvent());
    } catch (e) {
      emit(NotificationsError(
        message: 'Failed to clear notifications: $e',
        oldNotifications: state is NotificationsLoaded 
            ? (state as NotificationsLoaded).notifications 
            : null,
      ));
    }
  }

  Future<void> _onDeleteNotification(
    DeleteNotificationEvent event,
    Emitter<NotificationsState> emit,
  ) async {
    try {
      if (_currentUser == null) return;

      await _firestore
          .collection('user_notifications')
          .doc(_currentUser.uid)
          .collection('notifications')
          .doc(event.notificationId)
          .delete();

      add(LoadNotificationsEvent());
    } catch (e) {
      emit(NotificationsError(
        message: 'Failed to delete notification: $e',
        oldNotifications: state is NotificationsLoaded 
            ? (state as NotificationsLoaded).notifications 
            : null,
      ));
    }
  }

  Future<void> _onMarkAsRead(
    MarkAsReadEvent event,
    Emitter<NotificationsState> emit,
  ) async {
    try {
      if (_currentUser == null) return;

      await _firestore
          .collection('user_notifications')
          .doc(_currentUser.uid)
          .collection('notifications')
          .doc(event.notificationId)
          .update({'read': true});

      add(LoadNotificationsEvent());
    } catch (e) {
      emit(NotificationsError(
        message: 'Failed to mark as read: $e',
        oldNotifications: state is NotificationsLoaded 
            ? (state as NotificationsLoaded).notifications 
            : null,
      ));
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
}