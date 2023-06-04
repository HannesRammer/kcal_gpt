import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

class KcalGPTApp extends StatefulWidget {
  @override
  _KcalGPTAppState createState() => _KcalGPTAppState();
}

class _KcalGPTAppState extends State<KcalGPTApp> {
  String _mealDescription = '';
  int _calorieCount = 0;

  Future<void> _calculateCalories() async {
    try {
      // Call ChatGPT API to calculate calorie count based on meal description
      final response = await http.post(
        Uri.parse('https://api.chatgpt.com/calorie-count'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'meal_description': _mealDescription}),
      );

      if (response.statusCode == 200) {
        // Set _calorieCount to the calculated value
        setState(() {
          _calorieCount = jsonDecode(response.body)['calorie_count'];
        });
      } else {
        throw Exception('Failed to calculate calorie count');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to calculate calorie count'),
        ),
      );
    }
  }

  Future<void> _saveCalorieData() async {
    try {
      // Save _calorieCount to a database
      final calorieCount = _calorieCount.toString();
      final mealDescription = _mealDescription;
      final dateTime = DateTime.now().toString();

      // Save the data in the app's local database
      final database = await openDatabase('kcal_gpt.db', version: 1,
          onCreate: (Database db, int version) async {
        await db.execute(
            'CREATE TABLE calorie_data (id INTEGER PRIMARY KEY, calorie_count TEXT, meal_description TEXT, date_time TEXT)');
      });

      await database.transaction((txn) async {
        await txn.rawInsert(
            'INSERT INTO calorie_data(calorie_count, meal_description, date_time) VALUES("$calorieCount", "$mealDescription", "$dateTime")');
      });

      // Display a snackbar to confirm that data was saved
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Calorie data saved'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save calorie data'),
        ),
      );
    }
  }

  Future<void> _connectToFitnesApps() async {
    try {
      // Open settings menu and prompt user to connect to fitness app
      final result = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Connect to Fitness App'),
          content: Text(
              'Would you like to connect to a fitness app to sync your calorie data?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Yes'),
            ),
          ],
        ),
      );

      if (result == true) {
        // Once connected, sync calorie data with fitness app
        final response = await http.post(
          Uri.parse('https://api.fitnesapp.com/sync-calorie-data'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'calorie_count': _calorieCount,
            'meal_description': _mealDescription,
            'date_time': DateTime.now().toString(),
          }),
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Calorie data synced with fitness app'),
            ),
          );
        } else {
          throw Exception('Failed to sync calorie data with fitness app');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect to fitness app'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('KcalGPT'),
      ),
      body: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              labelText:
                  'Enter your meal, like  "I ate a cheeseburger with a large diet coke and fries and a salad with ranch dressing"',
              counterText: '',
              hintText: 'Limit to 140 characters',
              hintStyle: TextStyle(fontSize: 12),
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              counterStyle: TextStyle(fontSize: 0),
              counter: SizedBox.shrink(),
              helperText: '',
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  '${_mealDescription.length}/140',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
            maxLength: 140,
            onChanged: (value) {
              setState(() {
                _mealDescription = value;
              });
            },
          ),
          ElevatedButton(
            onPressed: _calculateCalories,
            child: Text('Calculate'),
          ),
          Text('Calorie Count: $_calorieCount'),
          ElevatedButton(
            onPressed: _saveCalorieData,
            child: Text('Save'),
          ),
          ElevatedButton(
            onPressed: _connectToFitnesApps,
            child: Text('Connect to Fitness App'),
          ),
        ],
      ),
    );
  }
}
