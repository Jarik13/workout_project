import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'profile_screen.dart';
import 'activity_tracker_screen.dart';
import 'notifications_screen.dart';
import '../services/notification_service.dart';
import '../blocs/workouts_bloc.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasNotifications = true;
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

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _scheduleDailyNotifications();
    _trackScreenView();
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

      _trackDataLoaded(userDoc.exists, metricsDoc.exists);

      if (!metricsDoc.exists) {
        await _createDefaultMetrics();
      }

      _notificationService.createNotification(
        title: "Welcome back! Your fitness data is ready.",
        image: "assets/images/welcome_back.png",
      );

    } catch (e) {
      setState(() => _isLoading = false);
      _notificationService.createNotification(
        title: "Error loading your data. Please check connection.",
        image: "assets/images/error_notification.png",
      );
    }
  }

  void _trackDataLoaded(bool userExists, bool metricsExists) {
    try {
      _analytics.logEvent(
        name: 'user_data_loaded',
        parameters: {
          'user_exists': userExists.toString(),
          'metrics_exists': metricsExists.toString(),
        },
      );
    } catch (e) {
      print('Analytics error: $e');
    }
  }

  void _scheduleDailyNotifications() {
    Future.delayed(Duration(seconds: 5), () {
      _notificationService.createNotification(
        title: "Good morning! Time to start your day with a workout! 🌞",
        image: "assets/images/morning_workout.png",
      );
    });

    Future.delayed(Duration(seconds: 10), () {
      _checkProgressAndNotify();
    });
  }

  void _checkProgressAndNotify() {
    final metrics = _dailyMetrics;
    final steps = metrics['steps'] ?? 0;
    if (steps < 3000) {
      _notificationService.createNotification(
        title: "Let's get moving! You've only taken $steps steps today.",
        image: "assets/images/low_activity.png",
      );
    }

    final waterIntake = metrics['waterIntake'] ?? 0.0;
    if (waterIntake >= 2.0) {
      _notificationService.createNotification(
        title: "Great job! You've reached your water intake goal! 💧",
        image: "assets/images/water_goal.png",
      );
    }
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

    _notificationService.createNotification(
      title: "Your fitness metrics have been set up!",
      image: "assets/images/metrics_created.png",
    );
  }

  Future<void> _completeWorkout(int index, BuildContext context) async {
    try {
      final workoutBloc = context.read<WorkoutBloc>();
      final currentState = workoutBloc.state;
      
      if (currentState is WorkoutDataState) {
        final updatedWorkouts = List<Map<String, dynamic>>.from(currentState.data);
        final workout = updatedWorkouts[index];
        final workoutName = workout['title'] ?? 'Workout';
        
        updatedWorkouts[index] = {
          ...workout,
          'completed': true,
        };

        workoutBloc.add(RefreshWorkoutsEvent());

        _trackWorkoutCompleted(workoutName, workout['type'], workout['duration']);

        await _notificationService.createWorkoutCompletionNotification(workoutName);

        final completedWorkouts = updatedWorkouts.where((w) => w['completed'] == true).length;
        if (completedWorkouts % 3 == 0) {
          _notificationService.createNotification(
            title: "Amazing! You've completed $completedWorkouts workouts! 🎉",
            image: "assets/images/milestone.png",
          );
        }
      }
    } catch (e) {
      print('Error completing workout: $e');
    }
  }

  void _trackWorkoutCompleted(String name, String type, int duration) {
    try {
      _analytics.logEvent(
        name: 'workout_completed',
        parameters: {
          'workout_name': name,
          'workout_type': type,
          'duration': duration,
        },
      );
    } catch (e) {
      print('Analytics error: $e');
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

  void _trackNavigation(String screen) {
    try {
      _analytics.logEvent(
        name: 'navigation',
        parameters: {'to_screen': screen},
      );
    } catch (e) {
      print('Analytics error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => WorkoutBloc()..add(RefreshWorkoutsEvent()),
      child: Scaffold(
        backgroundColor: Colors.white,
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
                      _buildLatestWorkout(),
                    ],
                  ),
                ),
        ),
      ),
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
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Stack(
              children: [
                IconButton(
                  icon: Icon(Icons.notifications_outlined, color: Colors.grey[600], size: 28),
                  onPressed: () {
                    _trackNavigation('NotificationsScreen');
                    Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationsScreen()));
                    setState(() => _hasNotifications = false);
                  },
                ),
                if (_hasNotifications)
                  Positioned(
                    right: 8, top: 8,
                    child: Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                _trackNavigation('ProfileScreen');
                Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen()));
              },
              child: Container(
                width: 50, height: 50,
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
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("BMI (Body Mass Index)", style: TextStyle(color: Colors.white, fontSize: 14)),
                SizedBox(height: 10),
                Text(
                  bmi == 0.0 ? "Complete your profile" : "You have a $status",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 15),
                GestureDetector(
                  onTap: () {
                    _trackNavigation('ActivityTrackerScreen');
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ActivityTrackerScreen()));
                    _notificationService.createNotification(
                      title: "Checking your activity tracker",
                      image: "assets/images/activity_tracker.png",
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFFEEA4CE), Color(0xFFC58BF2)]),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text("View More", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 20),
          GestureDetector(
            onTap: () {
              _showSnackBar(bmi == 0.0 ? "Complete your profile to see BMI" : "Your BMI is ${bmi.toStringAsFixed(1)} - $status");
              _notificationService.createNotification(
                title: "Your BMI is ${bmi.toStringAsFixed(1)} - $status",
                image: "assets/images/bmi_info.png",
              );
            },
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.2)),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      bmi == 0.0 ? "?" : bmi.toStringAsFixed(1),
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text("BMI", style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
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

    return GestureDetector(
      onTap: () {
        _showSnackBar("Today's targets: $targetMessage");
        _notificationService.createNotification(
          title: "Daily target: $targetMessage",
          image: "assets/images/daily_target.png",
        );
      },
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Today Target - $_userGoal", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Text(targetMessage, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                _showSnackBar("Working on: $_userGoal");
                _notificationService.createNotification(
                  title: "Working on your $_userGoal goal! Keep it up!",
                  image: "assets/images/goal_progress.png",
                );
              },
              child: Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF92A3FD), Color(0xFF9DCEFF)]),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityStatus() {
    final metrics = _dailyMetrics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Activity Status", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 15),
        Row(
          children: [
            _buildActivityItem(
              icon: Icons.favorite,
              title: "Heart Rate",
              value: "${metrics['heartRate'] ?? 0} BPM",
              color: Color(0xFF92A3FD),
              onTap: () {
                _showSnackBar("Heart Rate: ${metrics['heartRate'] ?? 0} BPM");
                _notificationService.createNotification(
                  title: "Heart rate: ${metrics['heartRate'] ?? 0} BPM",
                  image: "assets/images/heart_rate.png",
                );
              },
            ),
            SizedBox(width: 15),
            _buildActivityItem(
              icon: Icons.local_drink,
              title: "Water Intake",
              value: "${metrics['waterIntake']?.toStringAsFixed(1) ?? '0'} Liters",
              color: Color(0xFF9DCEFF),
              onTap: () {
                _showSnackBar("Water Intake: ${metrics['waterIntake']?.toStringAsFixed(1) ?? '0'}L");
                _notificationService.createNotification(
                  title: "Water intake: ${metrics['waterIntake']?.toStringAsFixed(1) ?? '0'}L",
                  image: "assets/images/water_tracking.png",
                );
              },
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
              onTap: () {
                _showSnackBar("Sleep: ${metrics['sleep']?.toStringAsFixed(1) ?? '0'} hours");
                _notificationService.createNotification(
                  title: "Sleep: ${metrics['sleep']?.toStringAsFixed(1) ?? '0'} hours",
                  image: "assets/images/sleep_tracking.png",
                );
              },
            ),
            SizedBox(width: 15),
            _buildActivityItem(
              icon: Icons.local_fire_department,
              title: "Calories",
              value: "${metrics['caloriesBurned'] ?? 0} kCal",
              color: Color(0xFFFFA500),
              onTap: () {
                _showSnackBar("Calories burned: ${metrics['caloriesBurned'] ?? 0} kCal");
                _notificationService.createNotification(
                  title: "Calories burned: ${metrics['caloriesBurned'] ?? 0} kCal",
                  image: "assets/images/calories_tracking.png",
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActivityItem({required IconData icon, required String title, required String value, required Color color, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(15),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 20)),
              SizedBox(height: 10),
              Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              SizedBox(height: 5),
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
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
            Text("Workout Progress - $_userGoal", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            GestureDetector(
              onTap: () {
                _showSnackBar("Switching to monthly view...");
                _notificationService.createNotification(
                  title: "Viewing monthly workout progress",
                  image: "assets/images/progress_view.png",
                );
              },
              child: Text("Weekly", style: TextStyle(color: Color(0xFF92A3FD), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        SizedBox(height: 15),
        GestureDetector(
          onTap: () {
            _showSnackBar("$_userGoal progress chart");
            _notificationService.createNotification(
              title: "Checking your $_userGoal progress chart",
              image: "assets/images/progress_chart.png",
            );
          },
          child: Container(
            height: 200, padding: EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(20)),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(progressData.length, (index) => FlSpot(index.toDouble(), (progressData[index] as num).toDouble())),
                    isCurved: true, color: Color(0xFF92A3FD), barWidth: 3,
                    belowBarData: BarAreaData(show: true, color: Color(0xFF92A3FD).withOpacity(0.2)),
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
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
            Text("Weekly Progress", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            GestureDetector(
              onTap: _showPeriodSelectionDialog,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Color(0xFF92A3FD).withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_selectedPeriod, style: TextStyle(color: Color(0xFF92A3FD), fontWeight: FontWeight.bold, fontSize: 14)),
                  SizedBox(width: 4), Icon(Icons.arrow_drop_down, color: Color(0xFF92A3FD), size: 18),
                ]),
              ),
            ),
          ],
        ),
        SizedBox(height: 15),
        GestureDetector(
          onTap: () {
            _showSnackBar("$_selectedPeriod progress chart");
            _notificationService.createNotification(
              title: "Viewing $_selectedPeriod progress chart",
              image: "assets/images/weekly_progress.png",
            );
          },
          child: SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround, maxY: 100,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      List<String> labels = _getPeriodLabels();
                      if (value.toInt() < labels.length) {
                        return Padding(padding: EdgeInsets.only(top: 8.0), child: Text(labels[value.toInt()], style: TextStyle(fontSize: 10, color: Colors.grey[600])));
                      }
                      return Container();
                    },
                  )),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: false), borderData: FlBorderData(show: false),
                barGroups: _generateBarGroups(progressData),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<String> _getPeriodLabels() {
    switch (_selectedPeriod) {
      case 'Day': return ['00', '04', '08', '12', '16', '20', '24'];
      case 'Week': return ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      case 'Month': return ['W1', 'W2', 'W3', 'W4'];
      case '3 Months': return ['M1', 'M2', 'M3'];
      case '6 Months': return ['M1', 'M2', 'M3', 'M4', 'M5', 'M6'];
      case '1 Year': return ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
      default: return ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    }
  }

  List<BarChartGroupData> _generateBarGroups(List<dynamic> progressData) {
    int barCount = _getBarCount();
    return List.generate(barCount, (index) {
      final value = index < progressData.length ? (progressData[index] as num).toDouble() : 50.0;
      return BarChartGroupData(x: index, barRods: [BarChartRodData(toY: value, color: Color(0xFF92A3FD))]);
    });
  }

  int _getBarCount() {
    switch (_selectedPeriod) {
      case 'Day': return 7;
      case 'Week': return 7;
      case 'Month': return 4;
      case '3 Months': return 3;
      case '6 Months': return 6;
      case '1 Year': return 12;
      default: return 7;
    }
  }

  Widget _buildLatestWorkout() {
    return BlocBuilder<WorkoutBloc, WorkoutState>(
      builder: (context, state) {
        if (state is WorkoutLoadingState) {
          return _buildWorkoutLoading();
        } else if (state is WorkoutErrorState) {
          return _buildWorkoutError(state.error, context);
        } else if (state is WorkoutDataState) {
          return _buildWorkoutList(state.data, context);
        } else {
          return _buildWorkoutLoading();
        }
      },
    );
  }

  Widget _buildWorkoutLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Recommended Workouts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            GestureDetector(
              onTap: () {
                context.read<WorkoutBloc>().add(RefreshWorkoutsEvent());
              },
              child: Text("Refresh", style: TextStyle(color: Color(0xFF92A3FD), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        SizedBox(height: 15),
        Center(
          child: CircularProgressIndicator(color: Color(0xFF92A3FD)),
        ),
      ],
    );
  }

  Widget _buildWorkoutError(String error, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Recommended Workouts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            GestureDetector(
              onTap: () {
                context.read<WorkoutBloc>().add(RefreshWorkoutsEvent());
              },
              child: Text("Retry", style: TextStyle(color: Color(0xFF92A3FD), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        SizedBox(height: 15),
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 40),
              SizedBox(height: 10),
              Text("Error loading workouts", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              Text(error, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkoutList(List<Map<String, dynamic>> workouts, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Recommended Workouts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            GestureDetector(
              onTap: () {
                _showSnackBar("Viewing all workouts for $_userGoal...");
                _notificationService.createNotification(
                  title: "Exploring all workout options for $_userGoal",
                  image: "assets/images/explore_workouts.png",
                );
              },
              child: Text("See more", style: TextStyle(color: Color(0xFF92A3FD), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        SizedBox(height: 15),
        ...workouts.asMap().entries.map((entry) {
          final index = entry.key;
          final workout = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: _buildWorkoutItem(
              title: workout['title'] ?? "Workout",
              subtitle: workout['description'] ?? "Exercises",
              imageAsset: _getWorkoutImage(workout['type'] ?? "strength"),
              isCompleted: workout['completed'] == true,
              index: workout['completed'] == true ? null : index,
              onTap: () {
                _showSnackBar("Starting ${workout['title'] ?? 'Workout'}");
                _notificationService.createNotification(
                  title: "Starting ${workout['title'] ?? 'Workout'} - Let's do this! 💪",
                  image: "assets/images/workout_started.png",
                );
              },
              onComplete: workout['completed'] == true ? null : () => _completeWorkout(index, context),
            ),
          );
        }),
      ],
    );
  }

  String _getWorkoutImage(String type) {
    switch (type) {
      case 'strength': return "assets/images/fullbody_workout.png";
      case 'core': return "assets/images/ab_workout.png";
      case 'cardio': return "assets/images/cardio_workout.png";
      default: return "assets/images/fullbody_workout.png";
    }
  }

  Widget _buildWorkoutItem({
    required String title,
    required String subtitle,
    required String imageAsset,
    required VoidCallback onTap,
    bool isCompleted = false,
    int? index,
    VoidCallback? onComplete,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: Offset(0, 5))],
        ),
        child: Row(
          children: [
            Container(
              width: 50, 
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10), 
                image: DecorationImage(image: AssetImage(imageAsset), fit: BoxFit.contain)
              ),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 5), 
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  if (isCompleted) ...[
                    SizedBox(height: 5),
                    Text("Completed ✓", style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ],
              ),
            ),
            if (!isCompleted && index != null && onComplete != null)
              GestureDetector(
                onTap: onComplete,
                child: Container(
                  padding: EdgeInsets.all(8), 
                  decoration: BoxDecoration(
                    color: Color(0xFF92A3FD).withOpacity(0.2), 
                    shape: BoxShape.circle
                  ),
                  child: Icon(Icons.check, color: Color(0xFF92A3FD), size: 16),
                ),
              ),
            SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showSnackBar("More options for $title"),
              child: Container(
                padding: EdgeInsets.all(8), 
                decoration: BoxDecoration(
                  color: Color(0xFF92A3FD).withOpacity(0.1), 
                  shape: BoxShape.circle
                ),
                child: Icon(Icons.arrow_forward_ios, color: Color(0xFF92A3FD), size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}