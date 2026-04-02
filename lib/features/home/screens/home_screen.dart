import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import '../../trip/screens/trip_history_screen.dart';
import '../../matching/screens/find_trip_screen.dart';
import '../../profile/screens/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DashboardScreen(),
    const FindTripScreen(),
    const TripHistoryScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: _pages[_currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index){
          setState(() {
            _currentIndex = index;
          });
        },

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home"
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: "Find Ride"
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: "Trips"
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile"
          ),
        ],
      ),
    );
  }
}