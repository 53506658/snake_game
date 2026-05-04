import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as g_ads;
import 'package:yandex_mobileads/yandex_mobileads.dart' as y_ads;
import 'package:firebase_core/firebase_core.dart';

import 'home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await g_ads.MobileAds.instance.initialize();
  y_ads.MobileAds.initialize();

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Home(),
  ));
}
import 'package:flutter/material.dart';
import 'game.dart';
import 'shop.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            const Text("SNAKE PRO",
              style: TextStyle(fontSize: 40, color: Colors.orange),
            ),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: () {
                Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const Game()));
              },
              child: const Text("PLAY"),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const Shop()));
              },
              child: const Text("SHOP"),
            ),
          ],
        ),
      ),
    );
  }
}
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as g_ads;
import 'package:yandex_mobileads/yandex_mobileads.dart' as y_ads;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Game extends StatefulWidget {
  const Game({super.key});

  @override
  State<Game> createState() => _GameState();
}

class _GameState extends State<Game> {

  Offset player = const Offset(200, 200);
  List<Offset> food = [];
  List<Offset> bots = [];

  Timer? loop;

  int score = 0;
  int level = 1;

  g_ads.InterstitialAd? googleAd;
  y_ads.InterstitialAd? yandexAd;

  @override
  void initState() {
    super.initState();

    food = List.generate(120,
      (_) => Offset(Random().nextDouble()*500, Random().nextDouble()*800));

    bots = List.generate(5,
      (_) => Offset(Random().nextDouble()*500, Random().nextDouble()*800));

    loadAds();

    loop = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => update(),
    );
  }
    void update() {
    setState(() {

      // player level
      level = (score ~/ 100) + 1;

      // bots AI (يتبع اللاعب)
      for (int i = 0; i < bots.length; i++) {
        final dir = (player - bots[i]);
        bots[i] += Offset(dir.dx * 0.01, dir.dy * 0.01);
      }

      // eating food
      food.removeWhere((f) {
        if ((f - player).distance < 20) {
          score += 10;
          return true;
        }
        return false;
      });
    });
  }
    void loadAds() {

    g_ads.InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const g_ads.AdRequest(),
      adLoadCallback: g_ads.InterstitialAdLoadCallback(
        onAdLoaded: (ad) => googleAd = ad,
        onAdFailedToLoad: (_) => googleAd = null,
      ),
    );

    y_ads.InterstitialAd.create(
      adUnitId: 'R-M-DEMO-interstitial',
      onAdLoaded: (ad) => yandexAd = ad,
      onAdFailedToLoad: (_) => yandexAd = null,
    );
  }  void gameOver() async {
    loop?.cancel();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("coins", score);

    // leaderboard
    FirebaseFirestore.instance.collection("leaderboard").add({
      "score": score,
      "level": level,
      "time": DateTime.now(),
    });

    if (googleAd != null) {
      googleAd!.show();
    } else if (yandexAd != null) {
      yandexAd!.show();
    }

    Navigator.pop(context);
  }
  import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Shop extends StatefulWidget {
  const Shop({super.key});

  @override
  State<Shop> createState() => _ShopState();
}

class _ShopState extends State<Shop> {

  int coins = 0;
  String skin = "orange";

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      coins = p.getInt("coins") ?? 0;
      skin = p.getString("skin") ?? "orange";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [

          Text("Coins: $coins",
            style: const TextStyle(color: Colors.white),
          ),

          ElevatedButton(
            onPressed: () async {
              if (coins >= 500) {
                final p = await SharedPreferences.getInstance();
                await p.setString("skin", "red");
              }
            },
            child: const Text("Buy Red Skin (500)"),
          ),

        ],
      ),
    );
  }
}
