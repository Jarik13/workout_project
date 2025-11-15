import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'goal_selection_screen.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _CompleteProfileScreenState createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  String? _selectedGender;
  DateTime? _selectedDate;
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  bool _useMetric = true;
  bool _isLoading = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

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
              _buildGenderSection(),
              SizedBox(height: 25),
              _buildDateOfBirthSection(),
              SizedBox(height: 25),
              _buildWeightSection(),
              SizedBox(height: 25),
              _buildHeightSection(),
              SizedBox(height: 40),
              _buildNextButton(),
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
          "Let's complete your profile",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 10),
        Text(
          "It will help us to know more about you!",
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildGenderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Choose Gender",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 15),
        Row(
          children: [
            _buildGenderOption("Male", "male"),
            SizedBox(width: 15),
            _buildGenderOption("Female", "female"),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderOption(String text, String value) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedGender = value;
          });
        },
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: _selectedGender == value
                ? Color(0xFF92A3FD)
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: _selectedGender == value
                  ? Color(0xFF92A3FD)
                  : Colors.grey[300]!,
            ),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: _selectedGender == value
                    ? Colors.white
                    : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateOfBirthSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Date of Birth",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 15),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            height: 50,
            padding: EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.grey[600]),
                SizedBox(width: 10),
                Text(
                  _selectedDate == null
                      ? "Select your date of birth"
                      : "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}",
                  style: TextStyle(
                    color: _selectedDate == null
                        ? Colors.grey[500]
                        : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeightSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Your Weight",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _weightController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: _useMetric ? "Weight in kg" : "Weight in lbs",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
            ),
            SizedBox(width: 10),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_useMetric ? "KG" : "LBS"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeightSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Your Height",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 10),
        Row(
          children: [
            _buildUnitOption("CM", true),
            SizedBox(width: 10),
            _buildUnitOption("FT", false),
          ],
        ),
        SizedBox(height: 15),
        TextFormField(
          controller: _heightController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: _useMetric ? "Height in cm" : "Height in feet",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
      ],
    );
  }

  Widget _buildUnitOption(String text, bool isMetric) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _useMetric = isMetric;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: _useMetric == isMetric ? Color(0xFF92A3FD) : Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _useMetric == isMetric
                ? Color(0xFF92A3FD)
                : Colors.grey[300]!,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: _useMetric == isMetric ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _onNextPressed,
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
                "Next >",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _onNextPressed() async {
    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select your gender")),
      );
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select your date of birth")),
      );
      return;
    }

    if (_weightController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter your weight")),
      );
      return;
    }

    if (_heightController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter your height")),
      );
      return;
    }

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
      await _saveProfileData();

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GoalSelectionScreen()),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving profile: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfileData() async {
    final userData = {
      'gender': _selectedGender,
      'dateOfBirth': _selectedDate!.toIso8601String(),
      'weight': _weightController.text,
      'height': _heightController.text,
      'useMetric': _useMetric,
      'profileCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .update(userData);
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }
}