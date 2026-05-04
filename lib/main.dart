import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as g_ads;
import 'package:yandex_mobileads/yandex_mobileads.dart' as y_ads;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

// --- شاشة البداية (Home) ---
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
            const Text(
              "SNAKE PRO",
              style: TextStyle(fontSize: 40, color: Colors.orange, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const Game()));
              },
              child: const Text("PLAY"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const Shop()));
              },
              child: const Text("SHOP"),
            ),
          ],
        ),
      ),
    );
  }
}

// --- شاشة اللعبة (Game) ---
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
    food = List.generate(120, (_) => Offset(Random().nextDouble() * 300, Random().nextDouble() * 600));
    bots = List.generate(5, (_) => Offset(Random().nextDouble() * 300, Random().nextDouble() * 600));
    loadAds();
    loop = Timer.periodic(const Duration(milliseconds: 16), (_) => update());
  }

  void loadAds() {
    // إعدادات إعلانات جوجل (كما هي دون تغيير)
    g_ads.InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const g_ads.AdRequest(),
      adLoadCallback: g_ads.InterstitialAdLoadCallback(
        onAdLoaded: (ad) => googleAd = ad,
        onAdFailedToLoad: (_) => googleAd = null,
      ),
    );

    // إعدادات إعلانات ياندكس (كما هي دون تغيير)
    y_ads.InterstitialAd.create(
      adUnitId: 'R-M-DEMO-interstitial',
      onAdLoaded: (ad) => yandexAd = ad,
      onAdFailedToLoad: (_) => yandexAd = null,
    );
  }

  void update() {
    if (!mounted) return;
    setState(() {
      level = (score ~/ 100) + 1;
      for (int i = 0; i < bots.length; i++) {
        final dir = (player - bots[i]);
        bots[i] += Offset(dir.dx * 0.005, dir.dy * 0.005);
      }
      food.removeWhere((f) {
        if ((f - player).distance < 20) {
          score += 10;
          return true;
        }
        return false;
      });
    });
  }

  void gameOver() async {
    loop?.cancel();
    final prefs = await SharedPreferences.getInstance();
    int currentCoins = prefs.getInt("coins") ?? 0;
    await prefs.setInt("coins", currentCoins + score);

    // Leaderboard
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

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    loop?.cancel();
    googleAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[900],
      body: GestureDetector(
        onPanUpdate: (d) => setState(() => player += d.delta),
        child: Stack(
          children: [
            // الطعام
            ...food.map((f) => Positioned(left: f.dx, top: f.dy, child: const CircleAvatar(radius: 5, backgroundColor: Colors.yellow))),
            // البوتات
            ...bots.map((b) => Positioned(left: b.dx, top: b.dy, child: const CircleAvatar(radius: 10, backgroundColor: Colors.red))),
            // اللاعب
            Positioned(left: player.dx, top: player.dy, child: const CircleAvatar(radius: 12, backgroundColor: Colors.orange)),
            // السكور
            Positioned(top: 40, left: 20, child: Text("Score: $score", style: const TextStyle(color: Colors.white, fontSize: 20))),
            Positioned(top: 10, right: 10, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: gameOver)),
          ],
        ),
      ),
    );
  }
}

// --- شاشة المتجر (Shop) ---
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
      appBar: AppBar(title: const Text("SHOP"), backgroundColor: Colors.orange),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Coins: $coins", style: const TextStyle(color: Colors.white, fontSize: 25)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (coins >= 500) {
                  final p = await SharedPreferences.getInstance();
                  await p.setInt("coins", coins - 500);
                  await p.setString("skin", "red");
                  load();
                }
              },
              child: const Text("Buy Red Skin (500)"),
            ),
          ],
        ),
      ),
    );
  }
}
