import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';

class ActivityTrackerScreen extends StatefulWidget {
  const ActivityTrackerScreen({super.key});

  @override
  _ActivityTrackerScreenState createState() => _ActivityTrackerScreenState();
}

class _ActivityTrackerScreenState extends State<ActivityTrackerScreen> {
  String _selectedPeriod = 'Week';
  final List<String> _periods = ['Day', 'Week', 'Month', '3 Months', '6 Months', '1 Year'];
  
  Map<String, dynamic>? _userMetrics;
  List<Map<String, dynamic>> _recentActivities = [];
  bool _isLoading = true;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(_currentUser.uid)
          .get();

      final metricsDoc = await _firestore
          .collection('user_metrics')
          .doc(_currentUser.uid)
          .get();

      final activitiesSnapshot = await _firestore
          .collection('user_activities')
          .doc(_currentUser.uid)
          .collection('activities')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      setState(() {
        _userMetrics = metricsDoc.data();
        _recentActivities = activitiesSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'type': data['type'] ?? '',
            'title': data['title'] ?? '',
            'value': data['value'] ?? '',
            'timestamp': data['timestamp'],
            'description': data['description'] ?? '',
          };
        }).toList();
        _isLoading = false;
      });

      // Сповіщення про відкриття трекера активності
      _notificationService.createNotification(
        title: "Checking your activity progress",
        image: "assets/images/activity_tracker.png",
      );

    } catch (e) {
      print('Error loading activity data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logActivity(String type, String title, String value, String description) async {
    if (_currentUser == null) return;

    try {
      await _firestore
          .collection('user_activities')
          .doc(_currentUser.uid)
          .collection('activities')
          .add({
            'type': type,
            'title': title,
            'value': value,
            'description': description,
            'timestamp': FieldValue.serverTimestamp(),
          });

      // Оновлюємо метрики
      await _updateMetrics(type, value);

      // Перезавантажуємо дані
      await _loadUserData();

      // Сповіщення про успішне логування
      _notificationService.createNotification(
        title: "Activity logged: $title",
        image: _getActivityImage(type),
      );

      _showSnackBar("Activity logged successfully!");

    } catch (e) {
      print('Error logging activity: $e');
      _showSnackBar("Error logging activity");
    }
  }

  Future<void> _updateMetrics(String type, String value) async {
    if (_currentUser == null) return;

    try {
      final metricsRef = _firestore.collection('user_metrics').doc(_currentUser.uid);
      final metricsDoc = await metricsRef.get();
      
      if (!metricsDoc.exists) return;

      final currentMetrics = metricsDoc.data()?['daily_metrics'] ?? {};
      final numValue = double.tryParse(value) ?? 0;

      Map<String, dynamic> updates = {};

      switch (type) {
        case 'water':
          updates['waterIntake'] = (currentMetrics['waterIntake'] ?? 0.0) + (numValue / 1000); // Convert ml to liters
          break;
        case 'steps':
          updates['steps'] = (currentMetrics['steps'] ?? 0) + numValue.toInt();
          break;
        case 'calories':
          updates['caloriesBurned'] = (currentMetrics['caloriesBurned'] ?? 0) + numValue.toInt();
          break;
        case 'sleep':
          updates['sleep'] = numValue;
          break;
      }

      if (updates.isNotEmpty) {
        await metricsRef.update({
          'daily_metrics': {...currentMetrics, ...updates},
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // Перевірка досягнення цілей
        _checkGoalAchievements(updates);
      }

    } catch (e) {
      print('Error updating metrics: $e');
    }
  }

  void _checkGoalAchievements(Map<String, dynamic> updates) {
    final dailyMetrics = _userMetrics?['daily_metrics'] ?? {};
    
    // Перевірка цілі води
    if (updates.containsKey('waterIntake')) {
      final waterIntake = updates['waterIntake'] ?? dailyMetrics['waterIntake'] ?? 0.0;
      if (waterIntake >= 2.0) {
        _notificationService.createNotification(
          title: "🎉 Water goal achieved! You've drunk ${waterIntake.toStringAsFixed(1)}L today",
          image: "assets/images/water_goal.png",
        );
      }
    }

    // Перевірка цілі кроків
    if (updates.containsKey('steps')) {
      final steps = updates['steps'] ?? dailyMetrics['steps'] ?? 0;
      if (steps >= 10000) {
        _notificationService.createNotification(
          title: "🏆 10,000 steps reached! Amazing job!",
          image: "assets/images/steps_goal.png",
        );
      } else if (steps >= 5000) {
        _notificationService.createNotification(
          title: "Great progress! You've taken $steps steps today",
          image: "assets/images/steps_progress.png",
        );
      }
    }

    // Перевірка цілі калорій
    if (updates.containsKey('caloriesBurned')) {
      final calories = updates['caloriesBurned'] ?? dailyMetrics['caloriesBurned'] ?? 0;
      if (calories >= 500) {
        _notificationService.createNotification(
          title: "🔥 You've burned $calories calories today!",
          image: "assets/images/calories_goal.png",
        );
      }
    }
  }

  String _getActivityImage(String type) {
    switch (type) {
      case 'water': return "assets/images/water_tracking.png";
      case 'steps': return "assets/images/steps_tracking.png";
      case 'calories': return "assets/images/calories_tracking.png";
      case 'sleep': return "assets/images/sleep_tracking.png";
      default: return "assets/images/activity_tracker.png";
    }
  }

  void _showWaterIntakeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        double waterAmount = 250;
        return AlertDialog(
          title: Text("Log Water Intake"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("How much water did you drink?"),
              SizedBox(height: 20),
              Text(
                "${waterAmount}ml",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF92A3FD)),
              ),
              SizedBox(height: 20),
              Slider(
                value: waterAmount,
                min: 100,
                max: 1000,
                divisions: 9,
                onChanged: (value) {
                  setState(() {
                    waterAmount = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logActivity(
                  'water',
                  'Drinking ${waterAmount}ml Water',
                  waterAmount.toString(),
                  'Added ${waterAmount}ml to your daily water intake',
                );
              },
              child: Text("Log Water"),
            ),
          ],
        );
      },
    );
  }

  void _showStepsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        int steps = 1000;
        return AlertDialog(
          title: Text("Log Steps"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("How many steps did you take?"),
              SizedBox(height: 20),
              Text(
                "$steps",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF92A3FD)),
              ),
              SizedBox(height: 20),
              Slider(
                value: steps.toDouble(),
                min: 100,
                max: 20000,
                divisions: 199,
                onChanged: (value) {
                  setState(() {
                    steps = value.toInt();
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logActivity(
                  'steps',
                  'Walked $steps Steps',
                  steps.toString(),
                  'Added $steps steps to your daily count',
                );
              },
              child: Text("Log Steps"),
            ),
          ],
        );
      },
    );
  }

  Map<String, dynamic> get _dailyMetrics {
    return _userMetrics?['daily_metrics'] ?? {
      'waterIntake': 0.0,
      'steps': 0,
      'caloriesBurned': 0,
      'sleep': 0.0,
      'heartRate': 0,
    };
  }

  List<dynamic> get _weeklyProgress {
    return _userMetrics?['weeklyProgress'] ?? [60, 75, 50, 85, 65, 70, 80];
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
                    setState(() {
                      _selectedPeriod = period;
                    });
                    Navigator.of(context).pop();
                    _showSnackBar("Period changed to $period");
                    _notificationService.createNotification(
                      title: "Viewing $period activity progress",
                      image: "assets/images/progress_view.png",
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Activity Tracker',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? _buildLoadingScreen()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTodayTarget(),
                  SizedBox(height: 20),
                  _buildWaterIntake(),
                  SizedBox(height: 20),
                  _buildFootSteps(),
                  SizedBox(height: 20),
                  _buildActivityProgress(),
                  SizedBox(height: 20),
                  _buildLatestActivity(),
                ],
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
          Text('Loading your activity data...'),
        ],
      ),
    );
  }

  Widget _buildTodayTarget() {
    final metrics = _dailyMetrics;
    final waterIntake = metrics['waterIntake'] ?? 0.0;
    final steps = metrics['steps'] ?? 0;
    final calories = metrics['caloriesBurned'] ?? 0;

    final waterGoal = waterIntake >= 2.0;
    final stepsGoal = steps >= 10000;
    final caloriesGoal = calories >= 500;

    final completedGoals = [waterGoal, stepsGoal, caloriesGoal].where((goal) => goal).length;
    final totalGoals = 3;

    return GestureDetector(
      onTap: () {
        _showSnackBar("Daily progress: $completedGoals/$totalGoals goals completed");
        _notificationService.createNotification(
          title: "Daily progress: $completedGoals/$totalGoals goals completed",
          image: "assets/images/daily_progress.png",
        );
      },
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF92A3FD), Color(0xFF9DCEFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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
                    "Today Target",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    completedGoals == totalGoals 
                        ? "All daily targets completed! 🎉"
                        : "Complete your daily targets!",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      _buildGoalIndicator("💧", waterGoal),
                      SizedBox(width: 10),
                      _buildGoalIndicator("👟", stepsGoal),
                      SizedBox(width: 10),
                      _buildGoalIndicator("🔥", caloriesGoal),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 20),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
              ),
              child: Center(
                child: Text(
                  "$completedGoals/$totalGoals",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalIndicator(String emoji, bool completed) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: completed ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Text(
        emoji,
        style: TextStyle(
          color: completed ? Colors.white : Colors.white.withOpacity(0.5),
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildWaterIntake() {
    final waterIntake = _dailyMetrics['waterIntake'] ?? 0.0;
    final goal = 2.0; // 2 liters daily goal
    final progress = waterIntake / goal;

    return GestureDetector(
      onTap: _showWaterIntakeDialog,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Water Intake",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "${waterIntake.toStringAsFixed(1)} Liters",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF92A3FD),
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "${(progress * 100).toInt()}% of daily goal",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFC58BF2), Color(0xFFEEA4CE)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.local_drink, color: Colors.white),
                ),
                if (progress >= 1.0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check, color: Colors.white, size: 12),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFootSteps() {
    final steps = _dailyMetrics['steps'] ?? 0;
    final goal = 10000; // 10,000 steps daily goal
    final progress = steps / goal;

    return GestureDetector(
      onTap: _showStepsDialog,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Foot Steps",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "$steps",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF92A3FD),
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "${(progress * 100).toInt()}% of daily goal",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFC58BF2), Color(0xFFEEA4CE)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.directions_walk, color: Colors.white),
                ),
                if (progress >= 1.0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check, color: Colors.white, size: 12),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityProgress() {
    final progressData = _weeklyProgress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Activity Progress",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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
        GestureDetector(
          onTap: () {
            _showSnackBar("$_selectedPeriod progress chart");
            _notificationService.createNotification(
              title: "Viewing $_selectedPeriod activity progress",
              image: "assets/images/activity_progress.png",
            );
          },
          child: SizedBox(
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
                          return GestureDetector(
                            onTap: () {
                              _showSnackBar("${labels[value.toInt()]}'s progress");
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                labels[value.toInt()],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          );
                        }
                        return Container();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
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
      return BarChartGroupData(
        x: index,
        barRods: [BarChartRodData(toY: value, color: Color(0xFF92A3FD))],
      );
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

  Widget _buildLatestActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Recent Activities",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              onTap: () {
                _showSnackBar("Viewing all activities");
                _notificationService.createNotification(
                  title: "Viewing all activity history",
                  image: "assets/images/activity_history.png",
                );
              },
              child: Text(
                "See more",
                style: TextStyle(
                  color: Color(0xFF92A3FD),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 15),
        if (_recentActivities.isEmpty)
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                Icon(Icons.track_changes, size: 50, color: Colors.grey[400]),
                SizedBox(height: 10),
                Text(
                  "No activities yet",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "Start logging your activities to see them here",
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ..._recentActivities.map((activity) => Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: _buildActivityItem(
              type: activity['type'] ?? '',
              title: activity['title'] ?? '',
              subtitle: activity['description'] ?? '',
              value: activity['value'] ?? '',
            ),
          )),
      ],
    );
  }

  Widget _buildActivityItem({
    required String type,
    required String title,
    required String subtitle,
    required String value,
  }) {
    Color color;
    IconData icon;

    switch (type) {
      case 'water':
        color = Color(0xFF92A3FD);
        icon = Icons.local_drink;
        break;
      case 'steps':
        color = Color(0xFFEEA4CE);
        icon = Icons.directions_walk;
        break;
      case 'calories':
        color = Color(0xFFFFA500);
        icon = Icons.local_fire_department;
        break;
      case 'sleep':
        color = Color(0xFF9DCEFF);
        icon = Icons.bedtime;
        break;
      default:
        color = Color(0xFF92A3FD);
        icon = Icons.fitness_center;
    }

    return Container(
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
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}