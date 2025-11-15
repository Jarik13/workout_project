import 'package:flutter_bloc/flutter_bloc.dart';

abstract class WorkoutState {}

class WorkoutLoadingState extends WorkoutState {
  final List<Map<String, dynamic>>? data;
  WorkoutLoadingState({this.data});
}

class WorkoutDataState extends WorkoutState {
  final List<Map<String, dynamic>> data;
  WorkoutDataState({required this.data});
}

class WorkoutErrorState extends WorkoutState {
  final String error;
  final List<Map<String, dynamic>>? data;
  WorkoutErrorState({required this.error, this.data});
}

abstract class WorkoutEvent {}

class RefreshWorkoutsEvent extends WorkoutEvent {}

class WorkoutBloc extends Bloc<WorkoutEvent, WorkoutState> {
  WorkoutBloc() : super(WorkoutLoadingState()) {
    on<RefreshWorkoutsEvent>(_onRefreshWorkoutsEvent);
  }

  Future<void> _onRefreshWorkoutsEvent(
    RefreshWorkoutsEvent event,
    Emitter<WorkoutState> emit,
  ) async {
    emit(WorkoutLoadingState(data: state is WorkoutDataState ? (state as WorkoutDataState).data : null));
    
    try {
      await Future.delayed(Duration(seconds: 2));
      
      final result = [
        {
          'title': "Fullbody Workout",
          'description': "11 Exercises | 32mins",
          'type': "strength",
          'duration': 32,
          'completed': true,
        },
        {
          'title': "Lowerbody Workout",
          'description': "12 Exercises | 40mins", 
          'type': "strength",
          'duration': 40,
          'completed': false,
        },
        {
          'title': "AB Workout",
          'description': "14 Exercises | 20mins",
          'type': "core",
          'duration': 20, 
          'completed': false,
        }
      ];
      
      emit(WorkoutDataState(data: result));
    } catch (e) {
      emit(WorkoutErrorState(
        error: 'An unexpected error occurred: $e',
        data: state is WorkoutDataState ? (state as WorkoutDataState).data : null,
      ));
    }
  }
}