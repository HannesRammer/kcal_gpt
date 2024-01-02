import 'package:flutter/material.dart';
import 'chat_screen.dart'; // Import the ChatScreen file

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KcalGPT',
      theme: ThemeData(
        primarySwatch: Colors.blue, // Adjust the theme as needed
      ),
      home: ChatScreen(), // Display the ChatScreen as the home screen
    );
  }
}
