import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../services/notification_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final NotificationService _notificationService = NotificationService();
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  @override
  void initState() {
    super.initState();
    _setupCrashlytics();
    _loadUserData();
    _loadNotificationSettings();
  }

  void _setupCrashlytics() {
    if (_currentUser != null) {
      _crashlytics.setUserIdentifier(_currentUser.uid);
    }
    
    _crashlytics.setCustomKey('screen', 'profile_screen');
    _crashlytics.setCustomKey('user_has_data', _userData != null);
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

      await _firestore
          .collection('user_metrics')
          .doc(_currentUser.uid)
          .get();

      setState(() {
        _userData = userDoc.data();
        _isLoading = false;
      });

      _crashlytics.setCustomKey('user_has_data', _userData != null);
      _crashlytics.setCustomKey('user_goal', _userData?['goal'] ?? 'not_set');

      _notificationService.createNotification(
        title: "Checking your profile information",
        image: "assets/images/profile_view.png",
      );

    } catch (e, stackTrace) {
      await _crashlytics.recordError(
        e,
        stackTrace,
        reason: 'Failed to load user data',
        fatal: false,
      );
      
      print('Error loading profile data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNotificationSettings() async {
    if (_currentUser == null) return;

    try {
      final settingsDoc = await _firestore
          .collection('user_settings')
          .doc(_currentUser.uid)
          .get();

      if (settingsDoc.exists) {
        setState(() {
          _notificationsEnabled = settingsDoc.data()?['notificationsEnabled'] ?? true;
        });
        
        _crashlytics.setCustomKey('notifications_enabled', _notificationsEnabled);
      }
    } catch (e, stackTrace) {
      await _crashlytics.recordError(
        e,
        stackTrace,
        reason: 'Failed to load notification settings',
        fatal: false,
      );
      
      print('Error loading notification settings: $e');
    }
  }

  Future<void> _updateNotificationSettings(bool enabled) async {
    if (_currentUser == null) return;

    try {
      await _firestore
          .collection('user_settings')
          .doc(_currentUser.uid)
          .set({
            'notificationsEnabled': enabled,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      setState(() {
        _notificationsEnabled = enabled;
      });

      _crashlytics.setCustomKey('notifications_enabled', enabled);
      _crashlytics.log('User ${enabled ? 'enabled' : 'disabled'} notifications');

      _notificationService.createNotification(
        title: enabled ? "Notifications enabled 🔔" : "Notifications disabled 🔕",
        image: "assets/images/notification_settings.png",
      );

      _showSnackBar(enabled ? "Notifications enabled" : "Notifications disabled");

    } catch (e, stackTrace) {
      await _crashlytics.recordError(
        e,
        stackTrace,
        reason: 'Failed to update notification settings',
        fatal: false,
      );
      
      print('Error updating notification settings: $e');
      _showSnackBar("Error updating settings");
    }
  }

  Future<void> _updateProfileField(String field, dynamic value) async {
    if (_currentUser == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_currentUser.uid)
          .update({
            field: value,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

      setState(() {
        _userData?[field] = value;
      });

      _crashlytics.setCustomKey('user_$field', value.toString());
      _crashlytics.log('User updated $field to $value');

      _notificationService.createNotification(
        title: "Profile updated: $field",
        image: "assets/images/profile_updated.png",
      );

      _showSnackBar("Profile updated successfully!");
    } catch (e, stackTrace) {
      await _crashlytics.recordError(
        e,
        stackTrace,
        reason: 'Failed to update profile field: $field',
        fatal: false,
      );
      
      print('Error updating profile: $e');
      _showSnackBar("Error updating profile");
    }
  }

  Future<void> _testCrashlytics() async {
    try {
      throw Exception('This is a test exception for Crashlytics from ProfileScreen');
    } catch (e, stackTrace) {
      await _crashlytics.recordError(
        e,
        stackTrace,
        reason: 'Test exception from profile screen',
        fatal: false,
      );
      
      _showSnackBar('Test error logged to Crashlytics!');
    }
  }

  void _testFatalError() {
    _crashlytics.crash();
  }

  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final nameController = TextEditingController(text: _userData?['name'] ?? '');
        final heightController = TextEditingController(text: _userData?['height']?.toString() ?? '');
        final weightController = TextEditingController(text: _userData?['weight']?.toString() ?? '');
        final ageController = TextEditingController(text: _userData?['age']?.toString() ?? '');

        return AlertDialog(
          title: Text("Edit Profile"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Name'),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: heightController,
                  decoration: InputDecoration(labelText: 'Height (cm)'),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 10),
                TextField(
                  controller: weightController,
                  decoration: InputDecoration(labelText: 'Weight (kg)'),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 10),
                TextField(
                  controller: ageController,
                  decoration: InputDecoration(labelText: 'Age'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                
                try {
                  // Оновлення даних
                  if (nameController.text.isNotEmpty) {
                    await _updateProfileField('name', nameController.text);
                  }
                  if (heightController.text.isNotEmpty) {
                    await _updateProfileField('height', double.parse(heightController.text));
                  }
                  if (weightController.text.isNotEmpty) {
                    await _updateProfileField('weight', double.parse(weightController.text));
                  }
                  if (ageController.text.isNotEmpty) {
                    await _updateProfileField('age', int.parse(ageController.text));
                  }
                } catch (e, stackTrace) {
                  await _crashlytics.recordError(
                    e,
                    stackTrace,
                    reason: 'Failed to parse profile data',
                    fatal: false,
                  );
                  
                  _showSnackBar("Error: Invalid data format");
                }
              },
              child: Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _showGoalSelectionDialog() {
    String? selectedGoal = _userData?['goal'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Select Your Goal"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text("Improve Shape"),
                value: "improve_shape",
                groupValue: selectedGoal,
                onChanged: (value) => setState(() => selectedGoal = value),
              ),
              RadioListTile<String>(
                title: Text("Learn & Tone"),
                value: "learn_tone",
                groupValue: selectedGoal,
                onChanged: (value) => setState(() => selectedGoal = value),
              ),
              RadioListTile<String>(
                title: Text("Lose Fat"),
                value: "lose_fat",
                groupValue: selectedGoal,
                onChanged: (value) => setState(() => selectedGoal = value),
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
                if (selectedGoal != null) {
                  _updateProfileField('goal', selectedGoal);
                  _notificationService.createNotification(
                    title: "Goal updated: ${_getGoalDisplayName(selectedGoal!)}",
                    image: "assets/images/goal_updated.png",
                  );
                }
              },
              child: Text("Save"),
            ),
          ],
        );
      },
    );
  }

  String _getGoalDisplayName(String goal) {
    switch (goal) {
      case 'improve_shape': return 'Improve Shape';
      case 'learn_tone': return 'Learn & Tone';
      case 'lose_fat': return 'Lose Fat';
      default: return 'Set Your Goal';
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String get _userName {
    if (_isLoading) return 'Loading...';
    return _userData?['name'] ?? 'User';
  }

  String get _userGoal {
    if (_isLoading) return 'Set Your Goal';
    return _getGoalDisplayName(_userData?['goal'] ?? '');
  }

  String get _userHeight {
    if (_isLoading) return '--';
    final height = _userData?['height'];
    return height != null ? '${height}cm' : '--';
  }

  String get _userWeight {
    if (_isLoading) return '--';
    final weight = _userData?['weight'];
    return weight != null ? '${weight}kg' : '--';
  }

  String get _userAge {
    if (_isLoading) return '--';
    final age = _userData?['age'];
    return age != null ? '${age}yo' : '--';
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
          'Profile',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.bug_report, color: Colors.red),
            onPressed: _testCrashlytics,
            tooltip: 'Test Crashlytics',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingScreen()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _buildUserProfile(),
                  SizedBox(height: 30),
                  _buildAccountSection(),
                  SizedBox(height: 20),
                  _buildNotificationSection(),
                  SizedBox(height: 20),
                  _buildOtherSection(),
                  _buildCrashlyticsTestSection(),
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
          Text('Loading your profile...'),
        ],
      ),
    );
  }

  Widget _buildUserProfile() {
    return Column(
      children: [
        GestureDetector(
          onTap: _showEditProfileDialog,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF92A3FD), Color(0xFF9DCEFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(Icons.person, color: Colors.white, size: 50),
          ),
        ),
        SizedBox(height: 20),
        Text(
          _userName,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 5),
        GestureDetector(
          onTap: _showGoalSelectionDialog,
          child: Text(
            _userGoal,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildProfileInfo(_userHeight, 'Height'),
            _buildProfileInfo(_userWeight, 'Weight'),
            _buildProfileInfo(_userAge, 'Age'),
          ],
        ),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: _showEditProfileDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF92A3FD),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: Text("Edit Profile"),
        ),
      ],
    );
  }

  Widget _buildProfileInfo(String value, String title) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF92A3FD),
              ),
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildAccountSection() {
    return _buildSection(
      title: 'Account',
      children: [
        _buildListTile(
          title: 'Personal Data',
          icon: Icons.person_outline,
          onTap: _showEditProfileDialog,
        ),
        _buildListTile(
          title: 'Achievement',
          icon: Icons.emoji_events_outlined,
          onTap: () {
            _showSnackBar("Viewing achievements");
            _notificationService.createNotification(
              title: "Checking your achievements",
              image: "assets/images/achievements.png",
            );
          },
        ),
        _buildListTile(
          title: 'Activity History',
          icon: Icons.history_outlined,
          onTap: () {
            _showSnackBar("Viewing activity history");
            _notificationService.createNotification(
              title: "Viewing activity history",
              image: "assets/images/activity_history.png",
            );
          },
        ),
        _buildListTile(
          title: 'Workout Progress',
          icon: Icons.trending_up_outlined,
          onTap: () {
            _showSnackBar("Viewing workout progress");
            _notificationService.createNotification(
              title: "Checking workout progress",
              image: "assets/images/workout_progress.png",
            );
          },
        ),
      ],
    );
  }

  Widget _buildNotificationSection() {
    return _buildSection(
      title: 'Notification',
      children: [
        Row(
          children: [
            Icon(Icons.notifications_outlined, color: Colors.grey[600]),
            SizedBox(width: 15),
            Expanded(
              child: Text(
                'Pop-up Notification',
                style: TextStyle(fontSize: 16, color: Colors.black),
              ),
            ),
            Switch(
              value: _notificationsEnabled,
              onChanged: _updateNotificationSettings,
              activeColor: Color(0xFF92A3FD),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOtherSection() {
    return _buildSection(
      title: 'Other',
      children: [
        _buildListTile(
          title: 'Contact Us',
          icon: Icons.mail_outline,
          onTap: () {
            _showSnackBar("Contact us at support@fitnessapp.com");
            _notificationService.createNotification(
              title: "Contacting support team",
              image: "assets/images/contact_support.png",
            );
          },
        ),
        _buildListTile(
          title: 'Privacy Policy',
          icon: Icons.privacy_tip_outlined,
          onTap: () {
            _showSnackBar("Opening privacy policy");
            _notificationService.createNotification(
              title: "Viewing privacy policy",
              image: "assets/images/privacy_policy.png",
            );
          },
        ),
        _buildListTile(
          title: 'Settings',
          icon: Icons.settings_outlined,
          onTap: () {
            _showSnackBar("Opening settings");
            _notificationService.createNotification(
              title: "Accessing app settings",
              image: "assets/images/app_settings.png",
            );
          },
        ),
      ],
    );
  }

  // Нова секція для тестування Crashlytics (тимчасово)
  Widget _buildCrashlyticsTestSection() {
    return _buildSection(
      title: 'Developer Tools',
      children: [
        _buildListTile(
          title: 'Test Non-Fatal Error',
          icon: Icons.warning_amber,
          onTap: _testCrashlytics,
        ),
        _buildListTile(
          title: 'Test Fatal Crash (Danger!)',
          icon: Icons.error_outline,
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Warning!'),
                content: Text('This will crash the app for testing purposes. Continue?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _testFatalError();
                    },
                    child: Text('Crash App', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 15),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildListTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: Colors.grey[600]),
          title: Text(
            title,
            style: TextStyle(fontSize: 16, color: Colors.black),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            color: Colors.grey[400],
            size: 16,
          ),
          onTap: onTap,
        ),
        if (title != 'Settings' && title != 'Test Fatal Crash (Danger!)')
          Divider(height: 20, color: Colors.grey[300]),
      ],
    );
  }
}