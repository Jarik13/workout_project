import '../models/workout_model.dart';

abstract class WorkoutRepository {
  Future<List<Workout>> getWorkouts();
  Future<void> addWorkout(Workout workout);
  Future<void> updateWorkout(Workout workout);
  Future<void> deleteWorkout(String id);
  Future<void> completeWorkout(String id);
  Future<void> toggleWorkoutCompletion(String id, bool completed);
}