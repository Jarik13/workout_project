import 'package:cloud_firestore/cloud_firestore.dart';

class Workout {
  final String? id;
  final String title;
  final String description;
  final String type;
  final int duration;
  final bool completed;
  final DateTime? date;
  final String? userId;
  final String? imageUrl;

  Workout({
    this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.duration,
    this.completed = false,
    this.date,
    this.userId,
    this.imageUrl,
  });

  factory Workout.fromMap(String id, Map<String, dynamic> map) {
    DateTime? date;
    
    if (map['date'] != null) {
      if (map['date'] is Timestamp) {
        date = (map['date'] as Timestamp).toDate();
      } else if (map['date'] is int) {
        date = DateTime.fromMillisecondsSinceEpoch(map['date'] as int);
      } else if (map['date'] is String) {
        date = DateTime.tryParse(map['date'] as String);
      }
    }

    return Workout(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      type: map['type'] as String? ?? 'strength',
      duration: (map['duration'] as num?)?.toInt() ?? 0,
      completed: map['completed'] as bool? ?? false,
      date: date,
      userId: map['userId'] as String?,
      imageUrl: map['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'type': type,
      'duration': duration,
      'completed': completed,
      'date': date ?? DateTime.now(),
      'userId': userId,
      'imageUrl': imageUrl,
    };
  }

  Workout copyWith({
    String? id,
    String? title,
    String? description,
    String? type,
    int? duration,
    bool? completed,
    DateTime? date,
    String? userId,
    String? imageUrl, 
  }) {
    return Workout(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      duration: duration ?? this.duration,
      completed: completed ?? this.completed,
      date: date ?? this.date,
      userId: userId ?? this.userId,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}