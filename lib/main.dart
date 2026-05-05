import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint("Init Error: $e");
  }
  runApp(MaterialApp(
    home: StartScreen(),
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
  ));
}

// --- نموذج الثعبان ---
class Snake {
  List<Offset> body = [];
  double angle = 0.0;
  double speed = 5.0;
  int length = 20;
  Color color;
  bool isInvisible = false;
  bool hasMagnet = false;

  Snake({required Offset startPos, required this.color}) {
    body = List.generate(length, (i) => startPos);
  }

  void move(double worldSize) {
    Offset head = body.first;
    Offset next = Offset(
      (head.dx + cos(angle) * speed).clamp(0, worldSize),
      (head.dy + sin(angle) * speed).clamp(0, worldSize),
    );
    body.insert(0, next);
    if (body.length > length) body.removeLast();
  }
}

// --- شاشة البداية ---
class StartScreen extends StatefulWidget {
  @override
  _StartScreenState createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  int totalCoins = 0;
  double sensitivity = 0.5;
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadBanner();
  }

  _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      totalCoins = prefs.getInt('coins') ?? 0;
      sensitivity = prefs.getDouble('sensitivity') ?? 0.5;
    });
  }

  void _loadBanner() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
          onAdLoaded: (_) => setState(() => _isBannerAdLoaded = true),
          onAdFailedToLoad: (ad, e) => ad.dispose()),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("SNAKE IO PRO",
                    style: TextStyle(
                        color: Colors.orange,
                        fontSize: 60,
                        fontWeight: FontWeight.bold)),
                Text("Total Coins: $totalCoins 💰",
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 60, vertical: 20)),
                  onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (c) =>
                                  GameScreen(sensitivity: sensitivity)))
                      .then((_) => _loadData()),
                  child: const Text("PLAY NOW",
                      style: TextStyle(fontSize: 25, color: Colors.white)),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (c) => LeaderboardScreen())),
                  icon: const Icon(Icons.leaderboard),
                  label: const Text("GLOBAL LEADERBOARD"),
                ),
              ],
            ),
          ),
          Positioned(
              top: 50,
              right: 20,
              child: IconButton(
                  icon: const Icon(Icons.settings, size: 35),
                  onPressed: _showSettings)),
          if (_isBannerAdLoaded)
            Positioned(
                bottom: 0,
                width: MediaQuery.of(context).size.width,
                height: 50,
                child: AdWidget(ad: _bannerAd!)),
        ],
      ),
    );
  }

  void _showSettings() {
    showDialog(
        context: context,
        builder: (c) => StatefulBuilder(
            builder: (c, setST) => AlertDialog(
                  title: const Text("Settings"),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text("Control Sensitivity"),
                    Slider(
                        value: sensitivity,
                        onChanged: (v) {
                          setST(() => sensitivity = v);
                          setState(() => sensitivity = v);
                          SharedPreferences.getInstance()
                              .then((p) => p.setDouble('sensitivity', v));
                        }),
                  ]),
                )));
  }
}

// --- شاشة لوحة الصدارة ---
class LeaderboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Global Top 10")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('leaderboard')
            .orderBy('score', descending: true)
            .limit(10)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snap.data!.docs.length,
            itemBuilder: (c, i) => ListTile(
              leading: Text("#${i + 1}",
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              title: Text(snap.data!.docs[i]['name'] ?? "Player"),
              trailing: Text("${snap.data!.docs[i]['score']} pts",
                  style: const TextStyle(color: Colors.orange, fontSize: 18)),
            ),
          );
        },
      ),
    );
  }
}

// --- شاشة اللعبة ---
class GameScreen extends StatefulWidget {
  final double sensitivity;
  GameScreen({required this.sensitivity});
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late Snake player;
  List<Snake> bots = [];
  List<Offset> food = [];
  List<Offset> powerUps = [];
  final double worldSize = 5000.0;
  Timer? timer;
  int score = 0;
  final AudioPlayer fxPlayer = AudioPlayer();
  InterstitialAd? _interstitialAd;

  @override
  void initState() {
    super.initState();
    player = Snake(startPos: const Offset(2500, 2500), color: Colors.orange);
    bots = List.generate(
        15,
        (i) => Snake(
            startPos: Offset(Random().nextDouble() * worldSize,
                Random().nextDouble() * worldSize),
            color: Colors.redAccent));
    food = List.generate(
        200,
        (i) => Offset(Random().nextDouble() * worldSize,
            Random().nextDouble() * worldSize));
    powerUps = List.generate(
        5,
        (i) => Offset(Random().nextDouble() * worldSize,
            Random().nextDouble() * worldSize));

    _loadInterstitial();
    timer =
        Timer.periodic(const Duration(milliseconds: 16), (t) => _gameLoop());
  }

  void _loadInterstitial() {
    InterstitialAd.load(
        adUnitId: 'ca-app-pub-3940256099942544/1033173712',
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
            onAdLoaded: (ad) => _interstitialAd = ad,
            onAdFailedToLoad: (e) => _interstitialAd = null));
  }

  void _gameLoop() {
    if (!mounted) return;
    setState(() {
      player.move(worldSize);

      for (var bot in bots) {
        if (food.isNotEmpty) {
          Offset target = food.first;
          bot.angle = atan2(target.dy - bot.body.first.dy,
              target.dx - bot.body.first.dx);
        }
        bot.move(worldSize);
      }

      if (player.hasMagnet) {
        for (int i = 0; i < food.length; i++) {
          if ((food[i] - player.body.first).distance < 300) {
            food[i] = Offset.lerp(food[i], player.body.first, 0.15)!;
          }
        }
      }

      _checkCollisions();
      _eatLogic();
    });
  }

  void _eatLogic() {
    food.removeWhere((f) {
      if ((f - player.body.first).distance < 30) {
        player.length += 2;
        score += 10;
        return true;
      }
      return false;
    });

    powerUps.removeWhere((p) {
      if ((p - player.body.first).distance < 40) {
        _activatePower();
        return true;
      }
      return false;
    });

    if (food.length < 200)
      food.add(Offset(Random().nextDouble() * worldSize,
          Random().nextDouble() * worldSize));
  }

  void _activatePower() {
    if (Random().nextBool()) {
      player.hasMagnet = true;
      Future.delayed(const Duration(seconds: 10),
          () => setState(() => player.hasMagnet = false));
    } else {
      player.isInvisible = true;
      Future.delayed(const Duration(seconds: 10),
          () => setState(() => player.isInvisible = false));
    }
  }

  void _checkCollisions() {
    for (var bot in bots) {
      if (player.isInvisible) continue;
      if ((player.body.first - bot.body.first).distance < 40) {
        if (player.length > bot.length) {
          bot.body = [
            Offset(Random().nextDouble() * worldSize,
                Random().nextDouble() * worldSize)
          ];
          player.length += 10;
          score += 50;
        } else {
          _gameOver();
        }
      }
    }
  }

  void _gameOver() async {
    timer?.cancel();
    if (score > 0) {
      FirebaseFirestore.instance.collection('leaderboard').add({
        'name': 'Player_${Random().nextInt(100)}',
        'score': score,
        'time': FieldValue.serverTimestamp()
      });
    }
    final p = await SharedPreferences.getInstance();
    await p.setInt('coins', (p.getInt('coins') ?? 0) + (score ~/ 10));

    if (_interstitialAd != null) _interstitialAd!.show();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GestureDetector(
            onPanUpdate: (d) => setState(() =>
                player.angle += d.delta.dx * 0.02 * (widget.sensitivity * 2)),
            child: CustomPaint(
              size: Size.infinite,
              painter: GamePainter(
                  player: player,
                  bots: bots,
                  food: food,
                  worldSize: worldSize,
                  powerUps: powerUps),
            ),
          ),
          Positioned(
              top: 50,
              right: 20,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                    color: Colors.black54,
                    border: Border.all(color: Colors.white24)),
                child: CustomPaint(
                    painter: MiniMapPainter(
                        player: player, bots: bots, worldSize: worldSize)),
              )),
          Positioned(
              top: 50,
              left: 20,
              child: Text("SCORE: $score",
                  style: const TextStyle(
                      fontSize: 25, fontWeight: FontWeight.bold))),
          
          // --- إصلاح زر السرعة المسبب للخطأ ---
          Positioned(
            bottom: 50,
            right: 30,
            child: GestureDetector(
              onLongPress: () => setState(() => player.speed = 10),
              onLongPressEnd: (_) => setState(() => player.speed = 5),
              child: FloatingActionButton(
                backgroundColor: Colors.orange.withOpacity(0.6),
                onPressed: () {}, // يتم التعامل مع الحركة عبر GestureDetector
                child: const Icon(Icons.bolt, size: 35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
}

class GamePainter extends CustomPainter {
  final Snake player;
  final List<Snake> bots;
  final List<Offset> food;
  final List<Offset> powerUps;
  final double worldSize;
  GamePainter(
      {required this.player,
      required this.bots,
      required this.food,
      required this.worldSize,
      required this.powerUps});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2 - player.body.first.dx,
        size.height / 2 - player.body.first.dy);
    canvas.drawRect(
        Rect.fromLTWH(0, 0, worldSize, worldSize),
        Paint()..color = Colors.green.shade900);

    for (var f in food)
      canvas.drawCircle(f, 10, Paint()..color = Colors.yellowAccent);
    for (var p in powerUps)
      canvas.drawCircle(
          p,
          25,
          Paint()
            ..color = Colors.purpleAccent
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    for (var bot in bots) {
      for (var segment in bot.body)
        canvas.drawCircle(segment, 18, Paint()..color = bot.color);
    }
    for (var segment in player.body) {
      canvas.drawCircle(
          segment, 22, Paint()..color = player.color.withOpacity(player.isInvisible ? 0.4 : 1.0));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class MiniMapPainter extends CustomPainter {
  final Snake player;
  final List<Snake> bots;
  final double worldSize;
  MiniMapPainter(
      {required this.player, required this.bots, required this.worldSize});
  @override
  void paint(Canvas canvas, Size size) {
    double scale = size.width / worldSize;
    canvas.drawCircle(
        player.body.first * scale, 5, Paint()..color = Colors.white);
    for (var bot in bots)
      canvas.drawCircle(
          bot.body.first * scale, 3, Paint()..color = Colors.red);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
