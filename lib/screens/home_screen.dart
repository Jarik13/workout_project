import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'package:workout_app_new/repositories/firebase_workout_repository.dart';
import 'profile_screen.dart';
import 'activity_tracker_screen.dart';
import 'notifications_screen.dart';
import '../services/notification_service.dart';
import '../blocs/workouts_bloc.dart';
import '../models/workout_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          WorkoutBloc(FirebaseWorkoutRepository())..add(LoadWorkoutsEvent()),
      child: const _HomeScreenContent(),
    );
  }
}

class _HomeScreenContent extends StatefulWidget {
  const _HomeScreenContent();

  @override
  _HomeScreenContentState createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<_HomeScreenContent> {
  String _selectedPeriod = 'Week';
  final List<String> _periods = [
    'Day',
    'Week',
    'Month',
    '3 Months',
    '6 Months',
    '1 Year',
  ];

  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _userMetrics;
  bool _isLoading = true;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final NotificationService _notificationService = NotificationService();
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedImage;
  bool _isUploadingImage = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  String _selectedType = 'strength';
  final List<String> _workoutTypes = [
    'strength',
    'cardio',
    'core',
    'flexibility',
  ];

  Workout? _editingWorkout;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _scheduleDailyNotifications();
    _trackScreenView();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _trackScreenView() async {
    try {
      await _analytics.logEvent(
        name: 'screen_view',
        parameters: {
          'firebase_screen': 'HomeScreen',
          'user_id': _currentUser?.uid ?? 'anonymous',
        },
      );
    } catch (e) {
      print('Analytics error: $e');
    }
  }

  Future<void> _loadUserData() async {
    if (_currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(_currentUser.uid)
          .get();

      final metricsDoc = await _firestore
          .collection('user_metrics')
          .doc(_currentUser.uid)
          .get();

      setState(() {
        _userData = userDoc.data();
        _userMetrics = metricsDoc.data();
        _isLoading = false;
      });

      if (!metricsDoc.exists) {
        await _createDefaultMetrics();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading user data: $e');
    }
  }

  void _scheduleDailyNotifications() {
    Future.delayed(Duration(seconds: 5), () {
      _notificationService.createNotification(
        title: "Good morning! Time to start your day with a workout! 🌞",
        image: "assets/images/morning_workout.png",
      );
    });
  }

  Future<void> _createDefaultMetrics() async {
    final defaultMetrics = {
      'daily_metrics': {
        'heartRate': 72,
        'waterIntake': 2.0,
        'sleep': 7.0,
        'caloriesBurned': 450,
        'steps': 5000,
        'date': DateTime.now().toIso8601String(),
      },
      'weeklyProgress': [60, 75, 50, 85, 65, 70, 80],
      'workoutProgress': [2, 3, 1, 4, 2, 3, 5],
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection('user_metrics')
        .doc(_currentUser!.uid)
        .set(defaultMetrics);
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    try {
      setState(() {
        _isUploadingImage = true;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnackBar('User not authenticated');
        return null;
      }

      final String fileName =
          'workout_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = _storage.ref().child(
        'workout_images/${user.uid}/$fileName',
      );

      final UploadTask uploadTask = storageRef.putFile(
        File(_selectedImage!.path),
      );
      final TaskSnapshot snapshot = await uploadTask;

      final String downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _isUploadingImage = false;
      });

      return downloadUrl;
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
      });
      _showSnackBar('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _addWorkout(WorkoutBloc bloc) async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final duration = int.tryParse(_durationController.text) ?? 0;

    if (title.isEmpty || duration <= 0) {
      _showSnackBar('Please fill all fields correctly');
      return;
    }

    String? imageUrl;
    if (_selectedImage != null) {
      imageUrl = await _uploadImage();
      if (imageUrl == null) {
        _showSnackBar('Failed to upload image');
        return;
      }
    }

    final newWorkout = Workout(
      title: title,
      description: description,
      type: _selectedType,
      duration: duration,
      completed: false,
      date: DateTime.now(),
      userId: _currentUser?.uid,
      imageUrl: imageUrl,
    );

    bloc.add(AddWorkoutEvent(newWorkout));
    _clearForm();
    Navigator.of(context).pop();
  }

  Future<void> _updateWorkout(WorkoutBloc bloc) async {
    if (_editingWorkout == null) return;

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final duration = int.tryParse(_durationController.text) ?? 0;

    if (title.isEmpty || duration <= 0) {
      _showSnackBar('Please fill all fields correctly');
      return;
    }

    String? imageUrl = _editingWorkout!.imageUrl;
    if (_selectedImage != null) {
      imageUrl = await _uploadImage();
      if (imageUrl == null) {
        _showSnackBar('Failed to upload image');
        return;
      }
    }

    final updatedWorkout = _editingWorkout!.copyWith(
      title: title,
      description: description,
      type: _selectedType,
      duration: duration,
      imageUrl: imageUrl,
    );

    bloc.add(UpdateWorkoutEvent(updatedWorkout));
    _clearForm();
    Navigator.of(context).pop();
  }

  void _toggleWorkoutCompletion(
    String workoutId,
    bool completed,
    WorkoutBloc bloc,
  ) {
    bloc.add(ToggleWorkoutCompletionEvent(workoutId, completed));
  }

  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    _durationController.clear();
    _selectedType = 'strength';
    _editingWorkout = null;
    _selectedImage = null;
    _isUploadingImage = false;
  }

  void _showWorkoutDialog(WorkoutBloc bloc, [Workout? workout]) {
    if (workout != null) {
      _editingWorkout = workout;
      _titleController.text = workout.title;
      _descriptionController.text = workout.description;
      _durationController.text = workout.duration.toString();
      _selectedType = workout.type;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickImage() async {
              try {
                final XFile? image = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1024,
                  maxHeight: 1024,
                  imageQuality: 80,
                );

                if (image != null) {
                  setDialogState(() {
                    _selectedImage = image;
                  });
                }
              } catch (e) {
                _showSnackBar('Error picking image: $e');
              }
            }

            return AlertDialog(
              title: Text(workout == null ? 'Add New Workout' : 'Edit Workout'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _isUploadingImage
                          ? null
                          : pickImage,
                      child: Container(
                        width: double.infinity,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: _isUploadingImage
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      color: Color(0xFF92A3FD),
                                    ),
                                    SizedBox(height: 10),
                                    Text('Uploading image...'),
                                  ],
                                ),
                              )
                            : _selectedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 150,
                                  child: Image.file(
                                    File(_selectedImage!.path),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                            : workout?.imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 150,
                                  child: Image.network(
                                    workout!.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return _buildPlaceholderImage();
                                    },
                                  ),
                                ),
                              )
                            : _buildPlaceholderImage(),
                      ),
                    ),
                    SizedBox(height: 10),
                    if (_selectedImage != null || workout?.imageUrl != null)
                      Text(
                        _selectedImage != null
                            ? 'New image selected'
                            : 'Current workout image',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    SizedBox(height: 15),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Workout Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _durationController,
                      decoration: InputDecoration(
                        labelText: 'Duration (minutes)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: InputDecoration(
                        labelText: 'Workout Type',
                        border: OutlineInputBorder(),
                      ),
                      items: _workoutTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(
                            type[0].toUpperCase() + type.substring(1),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          _selectedType = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _clearForm();
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isUploadingImage
                      ? null
                      : () => workout == null
                            ? _addWorkout(bloc)
                            : _updateWorkout(bloc),
                  child: _isUploadingImage
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(workout == null ? 'Add' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPlaceholderImage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate, color: Colors.grey[400], size: 40),
        SizedBox(height: 8),
        Text(
          'Add Workout Photo',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        SizedBox(height: 4),
        Text(
          '(Optional)',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
      ],
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: Duration(seconds: 2)),
    );
  }

  void _showPeriodSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Select Period"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _periods.length,
              itemBuilder: (BuildContext context, int index) {
                final period = _periods[index];
                return ListTile(
                  title: Text(period),
                  trailing: _selectedPeriod == period
                      ? Icon(Icons.check, color: Color(0xFF92A3FD))
                      : null,
                  onTap: () {
                    setState(() => _selectedPeriod = period);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  double get _calculateBMI {
    if (_userData == null) return 0.0;
    final weight = double.tryParse(_userData!['weight']?.toString() ?? '');
    final height = double.tryParse(_userData!['height']?.toString() ?? '');
    if (weight == null || height == null) return 0.0;

    final heightInMeters = (_userData!['useMetric'] ?? true)
        ? height / 100
        : height * 0.3048;

    final weightInKg = (_userData!['useMetric'] ?? true)
        ? weight
        : weight * 0.453592;

    if (heightInMeters == 0) return 0.0;

    return weightInKg / (heightInMeters * heightInMeters);
  }

  String get _bmiStatus {
    final bmi = _calculateBMI;
    if (bmi == 0.0) return 'Calculate your BMI';
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal weight';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  String get _userName {
    if (_isLoading) return 'Loading...';
    return _userData?['name']?.split(' ').first ?? 'User';
  }

  String get _userGoal {
    if (_isLoading) return 'Set Your Goal';
    final goal = _userData?['goal'];
    switch (goal) {
      case 'improve_shape':
        return 'Improve Shape';
      case 'learn_tone':
        return 'Learn & Tone';
      case 'lose_fat':
        return 'Lose Fat';
      default:
        return 'Set Your Goal';
    }
  }

  Map<String, dynamic> get _dailyMetrics {
    return _userMetrics?['daily_metrics'] ?? {};
  }

  List<dynamic> get _weeklyProgress {
    final data = _userMetrics?['weeklyProgress'];
    if (data is List) return data;
    if (data is Map) return data.values.toList();
    return [50, 60, 70, 80, 65, 75, 85];
  }

  List<dynamic> get _workoutProgress {
    final data = _userMetrics?['workoutProgress'];
    if (data is List) return data;
    if (data is Map) return data.values.toList();
    return [3, 4, 2, 5, 3, 4, 6];
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WorkoutBloc, WorkoutState>(
      listener: (context, state) {
        if (state is WorkoutOperationSuccessState) {
          _showSnackBar(state.message);
        } else if (state is WorkoutErrorState) {
          _showSnackBar(state.error);
        }
      },
      builder: (context, state) {
        final bloc = context.read<WorkoutBloc>();

        return Scaffold(
          backgroundColor: Colors.white,
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showWorkoutDialog(bloc),
            backgroundColor: Color(0xFF92A3FD),
            child: Icon(Icons.add, color: Colors.white),
          ),
          body: SafeArea(
            child: _isLoading
                ? _buildLoadingScreen()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        SizedBox(height: 30),
                        _buildBMICard(),
                        SizedBox(height: 20),
                        _buildTodayTarget(),
                        SizedBox(height: 20),
                        _buildActivityStatus(),
                        SizedBox(height: 20),
                        _buildWorkoutProgress(),
                        SizedBox(height: 20),
                        _buildWeeklyProgress(),
                        SizedBox(height: 20),
                        _buildLatestWorkout(state, bloc),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF92A3FD)),
          SizedBox(height: 20),
          Text('Loading your fitness data...'),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome",
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            SizedBox(height: 5),
            Text(
              "$_userName!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.notifications_outlined,
                color: Colors.grey[600],
                size: 28,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NotificationsScreen(),
                  ),
                );
              },
            ),
            SizedBox(width: 10),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              ),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[300],
                ),
                child: Icon(Icons.person, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBMICard() {
    final bmi = _calculateBMI;
    final status = _bmiStatus;
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF92A3FD), Color(0xFF9DCEFF)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "BMI (Body Mass Index)",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                SizedBox(height: 10),
                Text(
                  bmi == 0.0 ? "Complete your profile" : "You have a $status",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 15),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ActivityTrackerScreen(),
                    ),
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFEEA4CE), Color(0xFFC58BF2)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      "View More",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 20),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    bmi == 0.0 ? "?" : bmi.toStringAsFixed(1),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "BMI",
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayTarget() {
    String targetMessage = "Complete your daily workout routine";
    switch (_userData?['goal']) {
      case 'improve_shape':
        targetMessage = "Focus on strength training today! 💪";
        break;
      case 'learn_tone':
        targetMessage = "Time for functional training! 🏃‍♂️";
        break;
      case 'lose_fat':
        targetMessage = "Cardio and healthy eating today! 🥗";
        break;
    }
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today Target - $_userGoal",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  targetMessage,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF92A3FD), Color(0xFF9DCEFF)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityStatus() {
    final metrics = _dailyMetrics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Activity Status",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 15),
        Row(
          children: [
            _buildActivityItem(
              icon: Icons.favorite,
              title: "Heart Rate",
              value: "${metrics['heartRate'] ?? 0} BPM",
              color: Color(0xFF92A3FD),
            ),
            SizedBox(width: 15),
            _buildActivityItem(
              icon: Icons.local_drink,
              title: "Water Intake",
              value:
                  "${metrics['waterIntake']?.toStringAsFixed(1) ?? '0'} Liters",
              color: Color(0xFF9DCEFF),
            ),
          ],
        ),
        SizedBox(height: 15),
        Row(
          children: [
            _buildActivityItem(
              icon: Icons.bedtime,
              title: "Sleep",
              value: "${metrics['sleep']?.toStringAsFixed(1) ?? '0'} hours",
              color: Color(0xFFEEA4CE),
            ),
            SizedBox(width: 15),
            _buildActivityItem(
              icon: Icons.local_fire_department,
              title: "Calories",
              value: "${metrics['caloriesBurned'] ?? 0} kCal",
              color: Color(0xFFFFA500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutProgress() {
    final progressData = _workoutProgress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Workout Progress - $_userGoal",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "Weekly",
              style: TextStyle(
                color: Color(0xFF92A3FD),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 15),
        Container(
          height: 200,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(20),
          ),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(
                    progressData.length,
                    (index) => FlSpot(
                      index.toDouble(),
                      (progressData[index] as num).toDouble(),
                    ),
                  ),
                  isCurved: true,
                  color: Color(0xFF92A3FD),
                  barWidth: 3,
                  belowBarData: BarAreaData(
                    show: true,
                    color: Color(0xFF92A3FD).withOpacity(0.2),
                  ),
                  dotData: FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyProgress() {
    final progressData = _weeklyProgress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Weekly Progress",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            GestureDetector(
              onTap: _showPeriodSelectionDialog,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(0xFF92A3FD).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedPeriod,
                      style: TextStyle(
                        color: Color(0xFF92A3FD),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      color: Color(0xFF92A3FD),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 15),
        SizedBox(
          height: 150,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 100,
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      List<String> labels = _getPeriodLabels();
                      if (value.toInt() < labels.length) {
                        return Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            labels[value.toInt()],
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        );
                      }
                      return Container();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: _generateBarGroups(progressData),
            ),
          ),
        ),
      ],
    );
  }

  List<String> _getPeriodLabels() {
    switch (_selectedPeriod) {
      case 'Day':
        return ['00', '04', '08', '12', '16', '20', '24'];
      case 'Week':
        return ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      case 'Month':
        return ['W1', 'W2', 'W3', 'W4'];
      case '3 Months':
        return ['M1', 'M2', 'M3'];
      case '6 Months':
        return ['M1', 'M2', 'M3', 'M4', 'M5', 'M6'];
      case '1 Year':
        return ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
      default:
        return ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    }
  }

  List<BarChartGroupData> _generateBarGroups(List<dynamic> progressData) {
    int barCount = _getBarCount();
    return List.generate(barCount, (index) {
      final value = index < progressData.length
          ? (progressData[index] as num).toDouble()
          : 50.0;
      return BarChartGroupData(
        x: index,
        barRods: [BarChartRodData(toY: value, color: Color(0xFF92A3FD))],
      );
    });
  }

  int _getBarCount() {
    switch (_selectedPeriod) {
      case 'Day':
        return 7;
      case 'Week':
        return 7;
      case 'Month':
        return 4;
      case '3 Months':
        return 3;
      case '6 Months':
        return 6;
      case '1 Year':
        return 12;
      default:
        return 7;
    }
  }

  Widget _buildLatestWorkout(WorkoutState state, WorkoutBloc bloc) {
    List<Workout> workouts = [];

    if (state is WorkoutDataState) {
      workouts = state.workouts;
    } else if (state is WorkoutOperationSuccessState) {
      workouts = state.workouts;
    } else if (state is WorkoutLoadingState) {
      workouts = state.workouts ?? [];
    }

    workouts.sort(
      (a, b) => (b.date ?? DateTime.now()).compareTo(a.date ?? DateTime.now()),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Latest Workouts",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: Icon(Icons.refresh, color: Color(0xFF92A3FD)),
              onPressed: () => bloc.add(LoadWorkoutsEvent()),
            ),
          ],
        ),
        SizedBox(height: 15),
        ...workouts.take(5).map((workout) => _buildWorkoutItem(workout, bloc)),
        if (workouts.isEmpty) _buildNoWorkouts(),
      ],
    );
  }

  Widget _buildWorkoutItem(Workout workout, WorkoutBloc bloc) {
    return Dismissible(
      key: Key(workout.id ?? DateTime.now().millisecondsSinceEpoch.toString()),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(left: 20),
          child: Icon(Icons.delete, color: Colors.white),
        ),
      ),
      secondaryBackground: Container(
        color: Colors.blue,
        alignment: Alignment.centerRight,
        child: Padding(
          padding: EdgeInsets.only(right: 20),
          child: Icon(Icons.edit, color: Colors.white),
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          _showWorkoutDialog(bloc, workout);
          return false;
        } else {
          return await showDialog(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              title: Text('Delete Workout'),
              content: Text('Are you sure you want to delete this workout?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          bloc.add(DeleteWorkoutEvent(workout.id!));
        }
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Container(
          padding: EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Color(0xFF92A3FD).withOpacity(0.1),
                ),
                child: workout.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          workout.imageUrl!,
                          fit: BoxFit.cover,
                          width: 60,
                          height: 60,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              _getWorkoutIcon(workout.type),
                              color: Color(0xFF92A3FD),
                              size: 24,
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                                color: Color(0xFF92A3FD),
                              ),
                            );
                          },
                        ),
                      )
                    : Icon(
                        _getWorkoutIcon(workout.type),
                        color: Color(0xFF92A3FD),
                        size: 24,
                      ),
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workout.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      workout.description,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "${workout.duration} min • ${workout.type}",
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                    if (workout.completed) ...[
                      SizedBox(height: 5),
                      Text(
                        "Completed ✓",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  workout.completed
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: workout.completed ? Colors.green : Colors.grey,
                ),
                onPressed: () => _toggleWorkoutCompletion(
                  workout.id!,
                  !workout.completed,
                  bloc,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoWorkouts() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(Icons.fitness_center, color: Colors.grey[400], size: 40),
          SizedBox(height: 10),
          Text(
            "No workouts yet",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 5),
          Text(
            "Tap the + button to add your first workout!",
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  IconData _getWorkoutIcon(String type) {
    switch (type.toLowerCase()) {
      case 'strength':
        return Icons.fitness_center;
      case 'cardio':
        return Icons.directions_run;
      case 'core':
        return Icons.self_improvement;
      case 'flexibility':
        return Icons.accessible_forward;
      default:
        return Icons.fitness_center;
    }
  }
}
