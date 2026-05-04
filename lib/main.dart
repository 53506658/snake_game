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
  try {
    await Firebase.initializeApp();
    await g_ads.MobileAds.instance.initialize();
    y_ads.MobileAds.initialize();
  } catch (e) {
    debugPrint("Initialization Error: $e");
  }

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Home(),
  ));
}

// --- شاشة البداية ---
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
              style: TextStyle(fontSize: 40, color: Colors.orange, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Game())),
              child: const Text("PLAY"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Shop())),
              child: const Text("SHOP"),
            ),
          ],
        ),
      ),
    );
  }
}

// --- شاشة اللعبة ---
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
  y_ads.InterstitialAd? yandexAd; // تم تصحيح النوع هنا

  @override
  void initState() {
    super.initState();
    food = List.generate(120, (_) => Offset(Random().nextDouble() * 300, Random().nextDouble() * 600));
    bots = List.generate(5, (_) => Offset(Random().nextDouble() * 300, Random().nextDouble() * 600));
    loadAds();
    loop = Timer.periodic(const Duration(milliseconds: 16), (_) => update());
  }

  void loadAds() {
    // إعلان جوجل
    g_ads.InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const g_ads.AdRequest(),
      adLoadCallback: g_ads.InterstitialAdLoadCallback(
        onAdLoaded: (ad) => googleAd = ad,
        onAdFailedToLoad: (_) => googleAd = null,
      ),
    );

    // إعلان ياندكس - تم تصحيحه ليتوافق مع نسخة 7+
    final adLoader = y_ads.InterstitialAdLoader(
      onAdLoaded: (ad) => setState(() => yandexAd = ad),
      onAdFailedToLoad: (error) => yandexAd = null,
    );
    adLoader.loadAd(adRequestConfiguration: y_ads.AdRequestConfiguration(adUnitId: 'R-M-DEMO-interstitial'));
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
      backgroundColor: Colors.green,
      body: GestureDetector(
        onPanUpdate: (d) => setState(() => player += d.delta),
        child: Stack(
          children: [
            ...food.map((f) => Positioned(left: f.dx, top: f.dy, child: const CircleAvatar(radius: 5, backgroundColor: Colors.yellow))),
            ...bots.map((b) => Positioned(left: b.dx, top: b.dy, child: const CircleAvatar(radius: 10, backgroundColor: Colors.red))),
            Positioned(left: player.dx, top: player.dy, child: const CircleAvatar(radius: 12, backgroundColor: Colors.orange)),
            Positioned(top: 40, left: 20, child: Text("Score: $score", style: const TextStyle(color: Colors.white, fontSize: 20))),
            Positioned(top: 10, right: 10, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: gameOver)),
          ],
        ),
      ),
    );
  }
}

// --- شاشة المتجر ---
class Shop extends StatefulWidget {
  const Shop({super.key});
  @override
  State<Shop> createState() => _ShopState();
}

class _ShopState extends State<Shop> {
  int coins = 0;
  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    setState(() => coins = p.getInt("coins") ?? 0);
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