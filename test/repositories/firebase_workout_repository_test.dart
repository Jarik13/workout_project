import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:workout_app_new/repositories/firebase_workout_repository.dart';
import 'package:workout_app_new/models/workout_model.dart';

@GenerateMocks([
  FirebaseFirestore,
  CollectionReference,
  DocumentReference,
  QuerySnapshot,
  Query,
  QueryDocumentSnapshot,
  DocumentSnapshot,
  FirebaseAuth,
  User,
])
import 'firebase_workout_repository_test.mocks.dart';

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockCollectionReference<Map<String, dynamic>> mockCollection;
  late MockDocumentReference<Map<String, dynamic>> mockDocument;
  late FirebaseWorkoutRepository repository;

  const testUserId = 'user123';
  const testWorkoutId = 'workout456';

  final testWorkout = Workout(
    id: testWorkoutId,
    title: 'Test Workout',
    description: 'Test Description',
    type: 'Strength',
    duration: 30,
    date: DateTime(2024, 1, 1),
    completed: false,
    userId: testUserId,
  );

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockCollection = MockCollectionReference<Map<String, dynamic>>();
    mockDocument = MockDocumentReference<Map<String, dynamic>>();

    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn(testUserId);
    when(mockFirestore.collection('user_workouts')).thenReturn(mockCollection);

    repository = FirebaseWorkoutRepository(
      firestore: mockFirestore,
      auth: mockAuth,
    );
  });

  group('FirebaseWorkoutRepository - Authentication', () {
    test(
      'getWorkouts throws exception when user is not authenticated',
      () async {
        when(mockAuth.currentUser).thenReturn(null);

        expect(() => repository.getWorkouts(), throwsA(isA<Exception>()));
      },
    );

    test(
      'addWorkout throws exception when user is not authenticated',
      () async {
        when(mockAuth.currentUser).thenReturn(null);

        expect(
          () => repository.addWorkout(testWorkout),
          throwsA(isA<Exception>()),
        );
      },
    );
  });

  group('FirebaseWorkoutRepository - CRUD Operations', () {
    test('getWorkouts returns sorted workouts', () async {
      final mockQuery = MockQuery<Map<String, dynamic>>();
      final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      final mockDoc1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
      final mockDoc2 = MockQueryDocumentSnapshot<Map<String, dynamic>>();

      when(
        mockCollection.where('userId', isEqualTo: testUserId),
      ).thenReturn(mockQuery);
      when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);

      when(mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);

      when(mockDoc1.id).thenReturn('1');
      when(mockDoc1.data()).thenReturn({
        'title': 'Workout 1',
        'description': 'Description 1',
        'type': 'Cardio',
        'duration': 20,
        'date': Timestamp.fromDate(DateTime(2024, 1, 2)),
        'completed': false,
        'userId': testUserId,
      });

      when(mockDoc2.id).thenReturn('2');
      when(mockDoc2.data()).thenReturn({
        'title': 'Workout 2',
        'description': 'Description 2',
        'type': 'Strength',
        'duration': 30,
        'date': Timestamp.fromDate(DateTime(2024, 1, 1)),
        'completed': true,
        'userId': testUserId,
      });

      final workouts = await repository.getWorkouts();

      expect(workouts, hasLength(2));
      expect(workouts[0].id, '1');
      expect(workouts[1].id, '2');
      expect(workouts[0].title, 'Workout 1');
    });

    test('addWorkout adds workout with userId', () async {
      when(mockCollection.add(any)).thenAnswer((_) async => mockDocument);

      await repository.addWorkout(testWorkout.copyWith(id: null, userId: null));

      verify(
        mockCollection.add(
          argThat(
            predicate((Map<String, dynamic> map) {
              return map['userId'] == testUserId &&
                  map['title'] == 'Test Workout';
            }),
          ),
        ),
      ).called(1);
    });

    test('updateWorkout updates existing workout', () async {
      when(mockCollection.doc(testWorkoutId)).thenReturn(mockDocument);
      when(mockDocument.update(any)).thenAnswer((_) async => {});

      await repository.updateWorkout(testWorkout);

      verify(mockCollection.doc(testWorkoutId)).called(1);
      verify(mockDocument.update(testWorkout.toMap())).called(1);
    });

    test('updateWorkout throws exception when id is null', () async {
      final workoutWithoutId = testWorkout.copyWith(id: null);

      expect(
        () => repository.updateWorkout(workoutWithoutId),
        throwsA(isA<Exception>()),
      );
    });

    test('deleteWorkout deletes workout', () async {
      when(mockCollection.doc(testWorkoutId)).thenReturn(mockDocument);
      when(mockDocument.delete()).thenAnswer((_) async => {});

      await repository.deleteWorkout(testWorkoutId);

      verify(mockCollection.doc(testWorkoutId)).called(1);
      verify(mockDocument.delete()).called(1);
    });
  });

  group('FirebaseWorkoutRepository - Completion Operations', () {
    test('completeWorkout sets completed to true', () async {
      when(mockCollection.doc(testWorkoutId)).thenReturn(mockDocument);

      when(
        mockDocument.update(
          argThat(
            isMap
                .having((m) => m['completed'], 'completed', true)
                .having((m) => m.containsKey('date'), 'has date field', true),
          ),
        ),
      ).thenAnswer((_) async => {});

      await repository.completeWorkout(testWorkoutId);

      verify(mockCollection.doc(testWorkoutId)).called(1);
      verify(
        mockDocument.update(
          argThat(
            isMap
                .having((m) => m['completed'], 'completed', true)
                .having((m) => m.containsKey('date'), 'has date field', true),
          ),
        ),
      ).called(1);
    });

    test('toggleWorkoutCompletion toggles completion status', () async {
      when(mockCollection.doc(testWorkoutId)).thenReturn(mockDocument);

      when(
        mockDocument.update(
          argThat(
            isMap
                .having((m) => m['completed'], 'completed', true)
                .having((m) => m.containsKey('date'), 'has date field', true),
          ),
        ),
      ).thenAnswer((_) async => {});

      await repository.toggleWorkoutCompletion(testWorkoutId, true);

      verify(mockCollection.doc(testWorkoutId)).called(1);
      verify(
        mockDocument.update(
          argThat(
            isMap
                .having((m) => m['completed'], 'completed', true)
                .having((m) => m.containsKey('date'), 'has date field', true),
          ),
        ),
      ).called(1);
    });
  });

  group('FirebaseWorkoutRepository - Additional Methods', () {
    test('getWorkoutById returns workout when exists', () async {
      final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();

      when(mockCollection.doc(testWorkoutId)).thenReturn(mockDocument);
      when(mockDocument.get()).thenAnswer((_) async => mockSnapshot);

      when(mockSnapshot.exists).thenReturn(true);
      when(mockSnapshot.id).thenReturn(testWorkoutId);
      when(mockSnapshot.data()).thenReturn(testWorkout.toMap());

      final workout = await repository.getWorkoutById(testWorkoutId);

      expect(workout, isNotNull);
      expect(workout!.id, testWorkoutId);
      expect(workout.title, 'Test Workout');
    });

    test('getWorkoutById returns null when not exists', () async {
      final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();

      when(mockCollection.doc(testWorkoutId)).thenReturn(mockDocument);
      when(mockDocument.get()).thenAnswer((_) async => mockSnapshot);

      when(mockSnapshot.exists).thenReturn(false);

      final workout = await repository.getWorkoutById(testWorkoutId);

      expect(workout, isNull);
    });

    test('getWorkoutsByType returns filtered workouts', () async {
      final mockQuery = MockQuery<Map<String, dynamic>>();
      final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      final mockDoc1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
      final mockDoc2 = MockQueryDocumentSnapshot<Map<String, dynamic>>();

      when(
        mockCollection.where('userId', isEqualTo: testUserId),
      ).thenReturn(mockQuery);
      when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);

      when(mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);

      when(mockDoc1.id).thenReturn('1');
      when(mockDoc1.data()).thenReturn({
        'title': 'Cardio Workout',
        'description': 'Cardio Description',
        'type': 'Cardio',
        'duration': 30,
        'date': Timestamp.fromDate(DateTime(2024, 1, 1)),
        'completed': false,
        'userId': testUserId,
      });

      when(mockDoc2.id).thenReturn('2');
      when(mockDoc2.data()).thenReturn({
        'title': 'Strength Workout',
        'description': 'Strength Description',
        'type': 'Strength',
        'duration': 45,
        'date': Timestamp.fromDate(DateTime(2024, 1, 2)),
        'completed': true,
        'userId': testUserId,
      });

      final cardioWorkouts = await repository.getWorkoutsByType('Cardio');

      expect(cardioWorkouts, hasLength(1));
      expect(cardioWorkouts[0].type, 'Cardio');
      expect(cardioWorkouts[0].title, 'Cardio Workout');
    });

    test('getCompletedWorkouts returns only completed workouts', () async {
      final mockQuery = MockQuery<Map<String, dynamic>>();
      final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      final mockDoc1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
      final mockDoc2 = MockQueryDocumentSnapshot<Map<String, dynamic>>();

      when(
        mockCollection.where('userId', isEqualTo: testUserId),
      ).thenReturn(mockQuery);
      when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);

      when(mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);

      when(mockDoc1.id).thenReturn('1');
      when(mockDoc1.data()).thenReturn({
        'title': 'Workout 1',
        'description': 'Description 1',
        'type': 'Cardio',
        'duration': 20,
        'date': Timestamp.fromDate(DateTime(2024, 1, 1)),
        'completed': true,
        'userId': testUserId,
      });

      when(mockDoc2.id).thenReturn('2');
      when(mockDoc2.data()).thenReturn({
        'title': 'Workout 2',
        'description': 'Description 2',
        'type': 'Strength',
        'duration': 30,
        'date': Timestamp.fromDate(DateTime(2024, 1, 2)),
        'completed': false,
        'userId': testUserId,
      });

      final completedWorkouts = await repository.getCompletedWorkouts();

      expect(completedWorkouts, hasLength(1));
      expect(completedWorkouts[0].completed, true);
      expect(completedWorkouts[0].title, 'Workout 1');
    });

    test('getWorkoutsByDateRange returns workouts in date range', () async {
      final mockQuery = MockQuery<Map<String, dynamic>>();
      final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      final mockDoc1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
      final mockDoc2 = MockQueryDocumentSnapshot<Map<String, dynamic>>();

      when(
        mockCollection.where('userId', isEqualTo: testUserId),
      ).thenReturn(mockQuery);
      when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);

      when(mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);

      when(mockDoc1.id).thenReturn('1');
      when(mockDoc1.data()).thenReturn({
        'title': 'Workout 1',
        'description': 'Description 1',
        'type': 'Cardio',
        'duration': 25,
        'date': Timestamp.fromDate(DateTime(2024, 1, 15)),
        'completed': false,
        'userId': testUserId,
      });

      when(mockDoc2.id).thenReturn('2');
      when(mockDoc2.data()).thenReturn({
        'title': 'Workout 2',
        'description': 'Description 2',
        'type': 'Strength',
        'duration': 40,
        'date': Timestamp.fromDate(DateTime(2024, 2, 1)),
        'completed': true,
        'userId': testUserId,
      });

      final startDate = DateTime(2024, 1, 1);
      final endDate = DateTime(2024, 1, 31);
      final workouts = await repository.getWorkoutsByDateRange(
        startDate,
        endDate,
      );

      expect(workouts, hasLength(1));
      expect(workouts[0].id, '1');
      expect(workouts[0].date!.year, 2024);
      expect(workouts[0].date!.month, 1);
      expect(workouts[0].title, 'Workout 1');
    });
  });

  group('FirebaseWorkoutRepository - Error Handling', () {
    test('getWorkouts throws exception on Firebase error', () async {
      final mockQuery = MockQuery<Map<String, dynamic>>();
      when(
        mockCollection.where('userId', isEqualTo: testUserId),
      ).thenReturn(mockQuery);
      when(mockQuery.get()).thenThrow(FirebaseException(plugin: 'firestore'));

      expect(() => repository.getWorkouts(), throwsA(isA<Exception>()));
    });

    test('addWorkout throws exception on Firebase error', () async {
      when(
        mockCollection.add(any),
      ).thenThrow(FirebaseException(plugin: 'firestore'));

      expect(
        () => repository.addWorkout(testWorkout),
        throwsA(isA<Exception>()),
      );
    });
  });
}
