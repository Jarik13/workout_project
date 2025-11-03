import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> createNotification({
    required String title,
    required String image,
    bool read = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('user_notifications')
          .doc(user.uid)
          .collection('notifications')
          .add({
        'title': title,
        'image': image,
        'timestamp': FieldValue.serverTimestamp(),
        'read': read,
      });
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  Future<void> createWorkoutCompletionNotification(String workoutName) async {
    await createNotification(
      title: "Congratulations! You've completed $workoutName",
      image: "assets/images/workout_complete.png",
    );
  }

  Future<void> createMissedWorkoutNotification(String workoutName) async {
    await createNotification(
      title: "Don't forget your $workoutName",
      image: "assets/images/missed_workout.png",
    );
  }

  Future<void> createGoalAchievementNotification(String goal) async {
    await createNotification(
      title: "Awesome! You've achieved your $goal goal!",
      image: "assets/images/goal_achieved.png",
    );
  }

  Future<void> createMealTimeNotification() async {
    await createNotification(
      title: "Hey, it's time for lunch!",
      image: "assets/images/lunch_notification.png",
    );
  }

  Future<void> createProgressNotification(String progress) async {
    await createNotification(
      title: "Great progress! $progress",
      image: "assets/images/progress_notification.png",
    );
  }
}