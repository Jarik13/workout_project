import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'workout_repository.dart';
import '../models/workout_model.dart';

class FirebaseWorkoutRepository implements WorkoutRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirebaseWorkoutRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String get _collectionPath => 'user_workouts';

  String? get _currentUserId => _auth.currentUser?.uid;

  @override
  Future<List<Workout>> getWorkouts() async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    try {
      final snapshot = await _firestore
          .collection(_collectionPath)
          .where('userId', isEqualTo: userId)
          .get();

      final workouts = snapshot.docs
          .map((doc) => Workout.fromMap(doc.id, doc.data()))
          .toList();
      
      workouts.sort((a, b) {
        final dateA = a.date ?? DateTime(0);
        final dateB = b.date ?? DateTime(0);
        return dateB.compareTo(dateA);
      });

      return workouts;
    } catch (e) {
      throw Exception('Failed to load workouts: $e');
    }
  }

  @override
  Future<void> addWorkout(Workout workout) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    try {
      final workoutWithUserId = workout.copyWith(userId: userId);
      await _firestore
          .collection(_collectionPath)
          .add(workoutWithUserId.toMap());
    } catch (e) {
      throw Exception('Failed to add workout: $e');
    }
  }

  @override
  Future<void> updateWorkout(Workout workout) async {
    if (workout.id == null) throw Exception('Workout ID is null');

    try {
      await _firestore
          .collection(_collectionPath)
          .doc(workout.id!)
          .update(workout.toMap());
    } catch (e) {
      throw Exception('Failed to update workout: $e');
    }
  }

  @override
  Future<void> deleteWorkout(String id) async {
    try {
      await _firestore
          .collection(_collectionPath)
          .doc(id)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete workout: $e');
    }
  }

  @override
  Future<void> completeWorkout(String id) async {
    try {
      await _firestore
          .collection(_collectionPath)
          .doc(id)
          .update({
            'completed': true,
            'date': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw Exception('Failed to complete workout: $e');
    }
  }

  @override
  Future<void> toggleWorkoutCompletion(String id, bool completed) async {
    try {
      await _firestore
          .collection(_collectionPath)
          .doc(id)
          .update({
            'completed': completed,
            'date': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw Exception('Failed to toggle workout completion: $e');
    }
  }

  Future<Workout?> getWorkoutById(String id) async {
    try {
      final doc = await _firestore
          .collection(_collectionPath)
          .doc(id)
          .get();

      if (doc.exists) {
        return Workout.fromMap(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get workout: $e');
    }
  }

  Future<List<Workout>> getWorkoutsByType(String type) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    try {
      final snapshot = await _firestore
          .collection(_collectionPath)
          .where('userId', isEqualTo: userId)
          .get();

      final workouts = snapshot.docs
          .map((doc) => Workout.fromMap(doc.id, doc.data()))
          .where((workout) => workout.type == type)
          .toList();
      
      workouts.sort((a, b) {
        final dateA = a.date ?? DateTime(0);
        final dateB = b.date ?? DateTime(0);
        return dateB.compareTo(dateA);
      });

      return workouts;
    } catch (e) {
      throw Exception('Failed to load workouts by type: $e');
    }
  }

  Future<List<Workout>> getCompletedWorkouts() async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    try {
      final snapshot = await _firestore
          .collection(_collectionPath)
          .where('userId', isEqualTo: userId)
          .get();

      final workouts = snapshot.docs
          .map((doc) => Workout.fromMap(doc.id, doc.data()))
          .where((workout) => workout.completed)
          .toList();
      
      workouts.sort((a, b) {
        final dateA = a.date ?? DateTime(0);
        final dateB = b.date ?? DateTime(0);
        return dateB.compareTo(dateA);
      });

      return workouts;
    } catch (e) {
      throw Exception('Failed to load completed workouts: $e');
    }
  }

  Future<List<Workout>> getWorkoutsByDateRange(DateTime start, DateTime end) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    try {
      final snapshot = await _firestore
          .collection(_collectionPath)
          .where('userId', isEqualTo: userId)
          .get();

      final workouts = snapshot.docs
          .map((doc) => Workout.fromMap(doc.id, doc.data()))
          .where((workout) {
            if (workout.date == null) return false;
            return workout.date!.isAfter(start) && workout.date!.isBefore(end);
          })
          .toList();
      
      workouts.sort((a, b) {
        final dateA = a.date ?? DateTime(0);
        final dateB = b.date ?? DateTime(0);
        return dateB.compareTo(dateA);
      });

      return workouts;
    } catch (e) {
      throw Exception('Failed to load workouts by date range: $e');
    }
  }
}