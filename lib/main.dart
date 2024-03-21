import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'chat_screen.dart'; // Import the ChatScreen file
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CalorieGPT',
      theme: ThemeData(
        primaryColor: Color(0xFF56C7A5), // Deep teal/cyan color
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: Color(0xFF56C7A5), // Used to be called accentColor
          // Add other custom colors if needed
        ),
        // Define other theme properties as needed
      ),
      home: ChatScreen(),
    );
  }
}