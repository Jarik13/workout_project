import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../repositories/workout_repository.dart';
import '../models/workout_model.dart';

abstract class WorkoutEvent extends Equatable {
  const WorkoutEvent();

  @override
  List<Object?> get props => [];
}

class LoadWorkoutsEvent extends WorkoutEvent {}

class AddWorkoutEvent extends WorkoutEvent {
  final Workout workout;

  const AddWorkoutEvent(this.workout);

  @override
  List<Object?> get props => [workout];
}

class UpdateWorkoutEvent extends WorkoutEvent {
  final Workout workout;

  const UpdateWorkoutEvent(this.workout);

  @override
  List<Object?> get props => [workout];
}

class DeleteWorkoutEvent extends WorkoutEvent {
  final String workoutId;

  const DeleteWorkoutEvent(this.workoutId);

  @override
  List<Object?> get props => [workoutId];
}

class CompleteWorkoutEvent extends WorkoutEvent {
  final String workoutId;

  const CompleteWorkoutEvent(this.workoutId);

  @override
  List<Object?> get props => [workoutId];
}

class ToggleWorkoutCompletionEvent extends WorkoutEvent {
  final String workoutId;
  final bool completed;

  const ToggleWorkoutCompletionEvent(this.workoutId, this.completed);

  @override
  List<Object?> get props => [workoutId, completed];
}


abstract class WorkoutState extends Equatable {
  const WorkoutState();

  @override
  List<Object?> get props => [];
}

class WorkoutLoadingState extends WorkoutState {
  final List<Workout>? workouts;

  const WorkoutLoadingState({this.workouts});

  @override
  List<Object?> get props => [workouts];
}

class WorkoutDataState extends WorkoutState {
  final List<Workout> workouts;

  const WorkoutDataState(this.workouts);

  @override
  List<Object?> get props => [workouts];
}

class WorkoutErrorState extends WorkoutState {
  final String error;
  final List<Workout>? workouts;

  const WorkoutErrorState({required this.error, this.workouts});

  @override
  List<Object?> get props => [error, workouts];
}

class WorkoutOperationSuccessState extends WorkoutState {
  final String message;
  final List<Workout> workouts;

  const WorkoutOperationSuccessState({required this.message, required this.workouts});

  @override
  List<Object?> get props => [message, workouts];
}


class WorkoutBloc extends Bloc<WorkoutEvent, WorkoutState> {
  final WorkoutRepository _workoutRepository;

  WorkoutBloc(this._workoutRepository) : super(WorkoutLoadingState()) {
    on<LoadWorkoutsEvent>(_onLoadWorkouts);
    on<AddWorkoutEvent>(_onAddWorkout);
    on<UpdateWorkoutEvent>(_onUpdateWorkout);
    on<DeleteWorkoutEvent>(_onDeleteWorkout);
    on<CompleteWorkoutEvent>(_onCompleteWorkout);
    on<ToggleWorkoutCompletionEvent>(_onToggleWorkoutCompletion);
  }

  Future<void> _onLoadWorkouts(
    LoadWorkoutsEvent event,
    Emitter<WorkoutState> emit,
  ) async {
    emit(WorkoutLoadingState(workouts: _getCurrentWorkouts()));
    
    try {
      final workouts = await _workoutRepository.getWorkouts();
      emit(WorkoutDataState(workouts));
    } catch (e) {
      emit(WorkoutErrorState(
        error: 'Failed to load workouts: $e',
        workouts: _getCurrentWorkouts(),
      ));
    }
  }

  Future<void> _onAddWorkout(
    AddWorkoutEvent event,
    Emitter<WorkoutState> emit,
  ) async {
    emit(WorkoutLoadingState(workouts: _getCurrentWorkouts()));
    
    try {
      await _workoutRepository.addWorkout(event.workout);
      final workouts = await _workoutRepository.getWorkouts();
      emit(WorkoutOperationSuccessState(
        message: 'Workout added successfully!',
        workouts: workouts,
      ));
    } catch (e) {
      emit(WorkoutErrorState(
        error: 'Failed to add workout: $e',
        workouts: _getCurrentWorkouts(),
      ));
    }
  }

  Future<void> _onUpdateWorkout(
    UpdateWorkoutEvent event,
    Emitter<WorkoutState> emit,
  ) async {
    emit(WorkoutLoadingState(workouts: _getCurrentWorkouts()));
    
    try {
      await _workoutRepository.updateWorkout(event.workout);
      final workouts = await _workoutRepository.getWorkouts();
      emit(WorkoutOperationSuccessState(
        message: 'Workout updated successfully!',
        workouts: workouts,
      ));
    } catch (e) {
      emit(WorkoutErrorState(
        error: 'Failed to update workout: $e',
        workouts: _getCurrentWorkouts(),
      ));
    }
  }

  Future<void> _onDeleteWorkout(
    DeleteWorkoutEvent event,
    Emitter<WorkoutState> emit,
  ) async {
    emit(WorkoutLoadingState(workouts: _getCurrentWorkouts()));
    
    try {
      await _workoutRepository.deleteWorkout(event.workoutId);
      final workouts = await _workoutRepository.getWorkouts();
      emit(WorkoutOperationSuccessState(
        message: 'Workout deleted successfully!',
        workouts: workouts,
      ));
    } catch (e) {
      emit(WorkoutErrorState(
        error: 'Failed to delete workout: $e',
        workouts: _getCurrentWorkouts(),
      ));
    }
  }

  Future<void> _onCompleteWorkout(
    CompleteWorkoutEvent event,
    Emitter<WorkoutState> emit,
  ) async {
    emit(WorkoutLoadingState(workouts: _getCurrentWorkouts()));
    
    try {
      await _workoutRepository.completeWorkout(event.workoutId);
      final workouts = await _workoutRepository.getWorkouts();
      emit(WorkoutOperationSuccessState(
        message: 'Workout completed! Great job! 🎉',
        workouts: workouts,
      ));
    } catch (e) {
      emit(WorkoutErrorState(
        error: 'Failed to complete workout: $e',
        workouts: _getCurrentWorkouts(),
      ));
    }
  }

  Future<void> _onToggleWorkoutCompletion(
    ToggleWorkoutCompletionEvent event,
    Emitter<WorkoutState> emit,
  ) async {
    emit(WorkoutLoadingState(workouts: _getCurrentWorkouts()));
    
    try {
      await _workoutRepository.toggleWorkoutCompletion(
        event.workoutId, 
        event.completed,
      );
      final workouts = await _workoutRepository.getWorkouts();
      final message = event.completed 
          ? 'Workout completed! Great job! 🎉'
          : 'Workout marked as incomplete';
      
      emit(WorkoutOperationSuccessState(
        message: message,
        workouts: workouts,
      ));
    } catch (e) {
      emit(WorkoutErrorState(
        error: 'Failed to toggle workout completion: $e',
        workouts: _getCurrentWorkouts(),
      ));
    }
  }

  List<Workout> _getCurrentWorkouts() {
    return state is WorkoutDataState 
        ? (state as WorkoutDataState).workouts
        : state is WorkoutOperationSuccessState
            ? (state as WorkoutOperationSuccessState).workouts
            : [];
  }
}