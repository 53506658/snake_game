import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // إضافة مكتبة لوحة الصدارة

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(MaterialApp(home: StartScreen(), debugShowCheckedModeBanner: false));
}

// كلاس الثعبان والبيانات... (نفس الكود السابق مع تعديلات بسيطة)
class Snake {
  List<Offset> body = []; List<double> angles = [];
  double angle = 0.0, targetAngle = 0.0;
  int length; bool isBoosting = false; Color? skinColor;
  Snake({required Offset startPos, this.skinColor, this.length = 60}) {
    body = List.generate(length, (i) => Offset(startPos.dx - i * 2, startPos.dy));
    angles = List.generate(length, (i) => 0.0);
  }
}

class StartScreen extends StatefulWidget {
  @override
  _StartScreenState createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  int highScore = 0, totalPoints = 0;
  String playerName = "Player";
  
  @override
  void initState() { super.initState(); _loadData(); }

  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      highScore = prefs.getInt('highScore') ?? 0;
      totalPoints = prefs.getInt('totalPoints') ?? 0;
      playerName = prefs.getString('playerName') ?? "Player_${Random().nextInt(1000)}";
    });
  }

  // دالة لعرض لوحة الصدارة العالمية
  void _showLeaderboard() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (ctx) => StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('leaderboard').orderBy('score', descending: true).limit(10).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (c, i) {
              var data = snapshot.data!.docs[i];
              return ListTile(
                leading: Text("#${i + 1}", style: TextStyle(color: Colors.amber)),
                title: Text(data['name'], style: TextStyle(color: Colors.white)),
                trailing: Text("${data['score']}", style: TextStyle(color: Colors.orange)),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("SNAKE", style: TextStyle(color: Colors.orangeAccent, fontSize: 80, fontWeight: FontWeight.bold)),
            Text("🏆 BEST: $highScore", style: TextStyle(color: Colors.white70)),
            SizedBox(height: 20),
            ElevatedButton(onPressed: _showLeaderboard, child: Text("GLOBAL LEADERBOARD")),
            SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: EdgeInsets.symmetric(horizontal: 80, vertical: 20)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => SnakeIoPro())),
              child: Text("PLAY", style: TextStyle(color: Colors.white, fontSize: 25)),
            ),
          ],
        ),
      ),
    );
  }
}

// ... كود اللعبة (SnakeIoPro) يبقى كما هو مع إضافة دالة رفع السكور عند الخسارة
void _uploadScore(int score, String name) async {
  await FirebaseFirestore.instance.collection('leaderboard').doc(name).set({
    'name': name,
    'score': score,
    'timestamp': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
