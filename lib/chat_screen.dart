import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'secrets.dart'; // Ensure this file contains your API key
import 'package:clipboard/clipboard.dart'; // Clipboard package for copying text
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class Message {
  final String text;
  final List<FoodItem> foodItems;
  final DateTime timestamp; // Add a timestamp field

  Message(this.text, this.foodItems, this.timestamp);
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Message> _messages = [];

  bool _isLoading = false;
  List<FoodItem> foodItems = []; // List to store parsed food items
  int totalCalories = 0; // Define totalCalories here

  void _sendMessage(String message) async {
    setState(() {
      _isLoading = true;
    });

    final apiResponse = await _fetchResponse(message);
    print('API Response: $apiResponse'); // Debugging message

    final foodItems = parseResponse(apiResponse); // Parse the response

    print('Parsed food items: ${foodItems}'); // Debugging message

    setState(() {
      _messages.insert(
          0,
          Message("You: $message", foodItems,
              DateTime.now())); // Prepend the new message
      _isLoading = false;
    });

    _controller.clear();
  }

  Future<Map<String, dynamic>> _fetchResponse(String message) async {
    final url = 'https://api.openai.com/v1/chat/completions';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${Secrets.chatGPTApiKey}',
    };

    final instruction = '''
For each food item mentioned, provide a detailed calorie estimate in a structured JSON format. Include the name, estimated portion size, and calorie count for each item in an array called "items". Then, provide the total calorie count as a separate key called "totalCalories". Ensure the response follows this exact structure for seamless parsing:

{
  "items": [
    {"food": "item1", "portion": "size1", "calories": count1},
    {"food": "item2", "portion": "size2", "calories": count2},
    ...
  ],
  "totalCalories": sum_of_calories
}

''';
    final data = {
      'model': 'gpt-3.5-turbo',
      'messages': [
        {'role': 'system', 'content': instruction},
        {'role': 'user', 'content': message},
      ],
    };

    try {
      final response = await http.post(Uri.parse(url),
          headers: headers, body: jsonEncode(data));

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);

        if (responseBody != null &&
            responseBody['choices'] != null &&
            responseBody['choices'].isNotEmpty &&
            responseBody['choices'][0]['message'] != null &&
            responseBody['choices'][0]['message']['content'] != null) {
          Map<String, dynamic> content =
              jsonDecode(responseBody['choices'][0]['message']['content']);
          return content; // Return the decoded content directly
        } else {
          return {'error': 'Error: Unexpected API response structure'};
        }
      } else {
        return {'error': 'Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'error': 'Error: $e'};
    }
  }

  List<FoodItem> parseResponse(Map<String, dynamic> response) {
    try {
      final List<dynamic> itemsList = response['items'];
      totalCalories = int.tryParse(response['totalCalories'].toString()) ?? 0;
      final parsedItems =
          itemsList.map<FoodItem>((item) => FoodItem.fromJson(item)).toList();

      print('Parsed items: ${response}'); // Debugging message
      print('Parsed items: ${parsedItems}'); // Debugging message

      return parsedItems;
    } catch (e) {
      print("Error parsing response: $e");
      return [];
    }
  }

  Widget _buildMessage(String message, bool isUser) {
    bool hasCalories = message.contains("kcal");
    return ListTile(
      title: Text(message),
      trailing: hasCalories
          ? IconButton(
              icon: Icon(Icons.content_copy),
              onPressed: () {
                final calorieMatch =
                    RegExp(r'\b\d+ kcal\b').firstMatch(message);
                if (calorieMatch != null) {
                  FlutterClipboard.copy(calorieMatch.group(0) ?? '')
                      .then((value) => print('Calories copied to clipboard'));
                }
              },
            )
          : null,
    );
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Calorie Estimator Chat')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Enter your request',
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () => _controller.clear(),
                ),
              ),
              onSubmitted: (value) => _sendMessage(value),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(message.text),
                        subtitle: Text(DateFormat('yyyy-MM-dd – kk:mm').format(
                            message.timestamp)), // Display the timestamp
                      ),
                      if (message.foodItems
                          .isNotEmpty) // Check if foodItems is not empty
                        SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Food')),
                              DataColumn(label: Text('Portion')),
                              DataColumn(label: Text('Calories')),
                            ],
                            rows: buildDataTableRows(message.foodItems) +
                                [
                                  DataRow(
                                    cells: [
                                      DataCell(Text('Total')),
                                      DataCell(Text('')),
                                      DataCell(
                                        Row(
                                          children: [
                                            Text(
                                              getTotalCalories(
                                                      message.foodItems)
                                                  .toString(),
                                              style: TextStyle(
                                                  fontWeight: FontWeight
                                                      .bold), // Highlight the total calories
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.content_copy),
                                              onPressed: () {
                                                Clipboard.setData(ClipboardData(
                                                  text: getTotalCalories(
                                                          message.foodItems)
                                                      .toString(),
                                                )); // Copy the total calories to the clipboard
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  int getTotalCalories(List<FoodItem> foodItems) {
    int total = 0;
    for (var item in foodItems) {
      total += item.calories;
    }
    return total;
  }

  List<DataRow> buildDataTableRows(List<FoodItem> foodItems) {
    List<DataRow> rows = foodItems
        .map((foodItem) => DataRow(
              cells: [
                DataCell(Text(foodItem.food)),
                DataCell(Text(foodItem.portion)),
                DataCell(Text('${foodItem.calories}')),
              ],
            ))
        .toList();

    // Adding a row for total calories
    rows.add(
      DataRow(
        cells: [
          DataCell(Text('Total Calories')),
          DataCell(Text('')),
          DataCell(Text('$totalCalories')),
        ],
      ),
    );

    print('Number of food items: ${foodItems.length}'); // Debugging message
    print(
        'Number of rows in the data table: ${rows.length}'); // Debugging message

    return rows;
  }
}

class FoodItem {
  final String food;
  final String portion; // Added estimated food portion
  final int calories;

  FoodItem({required this.food, required this.portion, required this.calories});

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      food: json['food'],
      portion: json['portion'], // Assuming portion is part of the response
      calories: json['calories'],
    );
  }
}
