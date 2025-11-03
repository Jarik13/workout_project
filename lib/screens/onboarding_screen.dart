import 'package:flutter/material.dart';
import '../widgets/onboard_page.dart';
import '../data/onboarding_data.dart';
import 'register_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> onboardingData = OnboardingData.data;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildPageView(),
              ],
            ),
            Positioned(
              right: 20,
              bottom: 20,
              child: _buildNavigationButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageView() {
    return Expanded(
      child: PageView.builder(
        controller: _controller,
        itemCount: onboardingData.length,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        itemBuilder: (context, index) => Column(
          children: [
            Expanded(
              child: OnboardPage(
                title: onboardingData[index]["title"]!,
                description: onboardingData[index]["description"]!,
                imagePath: onboardingData[index]["image"]!,
              ),
            ),
            _buildPageIndicator(),
            SizedBox(height: 60), 
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${_currentPage + 1}/${onboardingData.length}',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildNavigationButton() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF92A3FD), Color(0xFF9DCEFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF92A3FD).withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: _onButtonPressed,
          child: Icon(
            _currentPage == onboardingData.length - 1
                ? Icons.check
                : Icons.arrow_forward_ios,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  void _onButtonPressed() {
    if (_currentPage == onboardingData.length - 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => RegisterScreen()),
      );
    } else {
      _controller.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }
}