import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';

class GoalSelectionScreen extends StatefulWidget {
  const GoalSelectionScreen({super.key});

  @override
  _GoalSelectionScreenState createState() => _GoalSelectionScreenState();
}

class _GoalSelectionScreenState extends State<GoalSelectionScreen> {
  String? _selectedGoal;
  bool _isLoading = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  final List<Map<String, dynamic>> _goals = [
    {
      'title': 'Improve Shape',
      'description': 'I have a low amount of body fat and need / want to build more muscle',
      'value': 'improve_shape',
    },
    {
      'title': 'Learn & Tone',
      'description': 'I\'m "skinny fat" look thin but have no shape. I want to add lean muscle in the right way.',
      'value': 'learn_tone',
    },
    {
      'title': 'Lose a Fat',
      'description': 'I have over 20% fat to lose. I want to drop all fat and gain muscle mass.',
      'value': 'lose_fat',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              SizedBox(height: 30),
              _buildGoalOptions(),
              SizedBox(height: 40),
              _buildConfirmButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(Icons.arrow_back, color: Colors.black),
        ),
        SizedBox(height: 20),
        Text(
          "What is your goal?",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 10),
        Text(
          "It will help us to choose a best program for you",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildGoalOptions() {
    return Column(
      children: _goals.map((goal) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 15.0),
          child: _buildGoalOption(
            goal['title'] as String,
            goal['description'] as String,
            goal['value'] as String,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGoalOption(String title, String description, String value) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGoal = value;
        });
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _selectedGoal == value ? Color(0xFF92A3FD).withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _selectedGoal == value ? Color(0xFF92A3FD) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _selectedGoal == value ? Color(0xFF92A3FD) : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: _selectedGoal == value
                  ? Container(
                      margin: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF92A3FD),
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 15),
            Expanded(
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
                  SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: (_selectedGoal != null && !_isLoading) ? _onConfirmPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF92A3FD),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          disabledBackgroundColor: Colors.grey[300],
        ),
        child: _isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                "Confirm",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Future<void> _onConfirmPressed() async {
    if (_selectedGoal != null) {
      if (_currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("User not authenticated")),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        await _saveUserGoal(_selectedGoal!);
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving goal: $e"),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveUserGoal(String goal) async {
    final goalData = {
      'goal': goal,
      'goalSetAt': FieldValue.serverTimestamp(),
      'onboardingCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .update(goalData);
  }
}