import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'secrets.dart'; // Ensure this file contains your API key
import 'package:clipboard/clipboard.dart'; // Clipboard package for copying text
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';


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
  int _messageCount = 0;
  bool _isLoading = false;
  List<FoodItem> foodItems = []; // List to store parsed food items
  int totalCalories = 0; // Define totalCalories here

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  final String _adUnitIdBanner = 'ca-app-pub-5196890855321116/6756985584';

  final String _adUnitIdInterstitial = 'ca-app-pub-5196890855321116/1182839671';


 /* final String _adUnitIdBanner = TargetPlatform.android == true
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-3940256099942544/2934735716';

  final String _adUnitIdInterstitial = TargetPlatform.android == true
      ? 'ca-app-pub-3940256099942544/1033173712'
      : 'ca-app-pub-3940256099942544/4411468910';
*/
  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _loadInterstitialAd();
  }

  /// Loads and shows a banner ad.
  ///
  /// Dimensions of the ad are determined by the AdSize class.
  void _loadBannerAd() async {
    BannerAd(
      adUnitId: _adUnitIdBanner,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        // Called when an ad is successfully received.
        onAdLoaded: (ad) {
          setState(() {
            _bannerAd = ad as BannerAd;
          });
        },
        // Called when an ad request failed.
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
        },
        // Called when an ad opens an overlay that covers the screen.
        onAdOpened: (Ad ad) {},
        // Called when an ad removes an overlay that covers the screen.
        onAdClosed: (Ad ad) {},
        // Called when an impression occurs on the ad.
        onAdImpression: (Ad ad) {},
      ),
    ).load();
  }

  /// Loads an interstitial ad.
  void _loadInterstitialAd() {
    InterstitialAd.load(
        adUnitId: _adUnitIdInterstitial,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          // Called when an ad is successfully received.
          onAdLoaded: (InterstitialAd ad) {
            ad.fullScreenContentCallback = FullScreenContentCallback(
                // Called when the ad showed the full screen content.
                onAdShowedFullScreenContent: (ad) {},
                // Called when an impression occurs on the ad.
                onAdImpression: (ad) {},
                // Called when the ad failed to show full screen content.
                onAdFailedToShowFullScreenContent: (ad, err) {
                  ad.dispose();
                },
                // Called when the ad dismissed full screen content.
                onAdDismissedFullScreenContent: (ad) {
                  ad.dispose();
                },
                // Called when a click is recorded for an ad.
                onAdClicked: (ad) {});

            // Keep a reference to the ad so you can show it later.
            _interstitialAd = ad;
          },
          // Called when an ad request failed.
          onAdFailedToLoad: (LoadAdError error) {
            // ignore: avoid_print
            print('InterstitialAd failed to load: $error');
          },
        ));
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

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
          Message("$message", foodItems,
              DateTime.now())); // Prepend the new message
      _isLoading = false;
    });
    _messageCount++;

    if (_messageCount % 3 == 0) {
      //_showInterstitialAd(); // Show the ad
      //_showAdWhenReady();
      _interstitialAd?.show();
      _loadInterstitialAd();
    }
    _controller.clear();
  }

  Future<Map<String, dynamic>> _fetchResponse(String message) async {
    final url = 'https://api.openai.com/v1/chat/completions';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${Secrets.chatGPTApiKey}',
    };

    final instruction = '''
For each food item mentioned, provide a detailed calorie estimate in a structured JSON format. 
Include the name, estimated portion size in descriptive terms (e.g., "handful", "slice", "bowl"), 
and an approximate weight in grams for each item. Also include the calorie count for each item 
in an array called "items". Then, provide the total calorie count as a separate key called 
"totalCalories". Ensure the response follows this exact structure for seamless parsing:

{
  "items": [
    {"food": "item1", "portion_description": "description1", "portion_grams": grams1, "calories": count1},
    {"food": "item2", "portion_description": "description2", "portion_grams": grams2, "calories": count2},
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: Text('Calorie Estimator Chat', style: TextStyle(color: Colors.white)),
      ),
      body:Container(
        color: Colors.grey[100], // Light background color for the whole screen
        child: Column(
          children: [
            _buildInputField(),
            Expanded(child: _buildMessageList()),
            _buildTotalCalories(),
            // Banner-Widget
            if (_bannerAd != null)
              Container(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),

      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
    );
  }

  Widget _buildInputField() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: "Enter your request",
          fillColor: Colors.white,
          filled: true,
          suffixIcon: Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: (value) => _sendMessage(value),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageCard(message, index);
      },
    );
  }

  Widget _buildMessageCard(Message message, int messageIndex) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 2.0,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('yyyy-MM-dd – kk:mm').format(message.timestamp),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            SizedBox(height: 8.0),
            Text(
              message.text,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            for (int i = 0; i < message.foodItems.length; i++)
              _buildFoodItemRow(message.foodItems[i], messageIndex, i),
          ],
        ),
      ),
    );
  }
  Widget _buildFoodItemRow(FoodItem item, int messageIndex, int foodItemIndex) {
    return Dismissible(
      key: Key('${item.hashCode}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        _removeFoodItem(messageIndex, foodItemIndex);
      },
      background: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Colors.red, Colors.white],
            stops: [0.5, 1], // Gradient stops at 50%
          ),
        ),
      ),
      child: Stack(
        children: [
          ListTile(
            title: Text(item.food, style: TextStyle(fontSize: 14)),
            subtitle: Text('${item.portionDescription}, ${item.portionGrams} g',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            trailing: _buildCaloriesWithCopy(item.calories.toString()),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            right: 0, // Adjust the right padding as needed
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.white, Colors.red, Colors.blue],
                  stops: [0.35,  0.60, 1], // Adjust the stops to change how the gradient is applied
                ).createShader(bounds);
              },
              child: Icon(Icons.delete, color: Colors.white), // The icon color will be overridden by the shader
            ),
          ),


        ],
      ),
    );
  }



  Widget _buildFloatingActionButton() {
    return  Padding(
        padding: EdgeInsets.only(bottom: _bannerAd != null ? 150.0 : 90.0),
    child: FloatingActionButton(
      onPressed: () => _sendMessage(_controller.text),
      child: Icon(Icons.send),
      backgroundColor: Theme.of(context).primaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16.0)), // Rounded corners
      ),
      ),
    );
  }


  Widget buildCustomFoodItemRow(FoodItem item) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: Colors.transparent, // Set the color to transparent
        border: Border(
          bottom: BorderSide(width: 1.0, color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
              child: Text(
                item.food,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          buildDivider(),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
              child: Text(
                item.portionDescription,
                style: TextStyle(fontSize: 12), // Half the normal size for portion description
                textAlign: TextAlign.center,
              ),
            ),
          ),
          buildDivider(),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
              child: Text(
                '${item.portionGrams} g',
                style: TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          buildDivider(),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
              child: InkWell(
                onTap: () {
                  FlutterClipboard.copy('${item.calories} kcal')
                      .then((value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Calories copied to clipboard'))));
                },
                child: Text(
                  '${item.calories} kcal',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDivider() {
    return VerticalDivider(thickness: 1, width: 1, color: Colors.grey.shade300);
  }


  Widget buildCell(String text, {bool isTitle = false, TextAlign textAlign = TextAlign.left}) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isTitle ? FontWeight.bold : FontWeight.normal,
          ),
          textAlign: textAlign,
        ),
      ),
    );
  }




  Widget _buildTotalCalories() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 1,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total Calories',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          _buildCaloriesWithCopy(getTotalCalories().toString()),
        ],
      ),
    );
  }

  int getTotalCalories() {
    return _messages.fold(0, (sum, currentMessage) =>
    sum + currentMessage.foodItems.fold(0, (sum, item) => sum + item.calories));
  }

  Widget _buildCaloriesWithCopy(String calories) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          calories,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: Icon(Icons.content_copy, size: 20.0),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: calories));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Total calories copied to clipboard')));
          },
        ),
      ],
    );
  }

 List<Widget> buildCustomDataTable(List<FoodItem> foodItems) {
    List<Widget> rows = foodItems.map((foodItem) => buildCustomFoodItemRow(foodItem)).toList();

    // Add a row for total calories
    rows.add(
      Container(
        padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.5), spreadRadius: 1, blurRadius: 6, offset: Offset(0, 3))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total Calories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
            Row(
              children: [
                Text(
                  '$totalCalories',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF30D5C8)),
                ),
                IconButton(
                  icon: Icon(Icons.copy, size: 16.0),
                  onPressed: () {
                    FlutterClipboard.copy('$totalCalories')
                        .then((value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Total calories copied to clipboard'))));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return rows;
  }

  void _removeFoodItem(int messageIndex, int foodItemIndex) {
    setState(() {
      // Remove the food item from the message
      _messages[messageIndex].foodItems.removeAt(foodItemIndex);

      // If all food items are removed, remove the message itself
      if (_messages[messageIndex].foodItems.isEmpty) {
        _messages.removeAt(messageIndex);
      }

      // Recalculate total calories
      totalCalories = getTotalCalories();
    });
  }
}
class FoodItem {
  final String food;
  final String portionDescription; // Descriptive portion size (e.g., "handful")
  final int portionGrams; // Portion size in grams
  final int calories;

  FoodItem({
    required this.food,
    required this.portionDescription,
    required this.portionGrams,
    required this.calories,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      food: json['food'],
      portionDescription: json['portion_description'], // Key as per new instruction set
      portionGrams: json['portion_grams'], // Key as per new instruction set
      calories: json['calories'],
    );
  }
}
