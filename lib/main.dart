import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as g_ads;
import 'package:yandex_mobileads/yandex_mobileads.dart' as y_ads;
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    await g_ads.MobileAds.instance.initialize();
    y_ads.MobileAds.initialize();
  } catch (e) {
    debugPrint("Init Error: $e");
  }
  runApp(MaterialApp(home: StartScreen(), debugShowCheckedModeBanner: false));
}

class Snake {
  List<Offset> body = []; List<double> angles = [];
  double angle = 0.0, targetAngle = 0.0;
  int length; bool isBoosting = false; Color? skinColor;
  Snake({required Offset startPos, this.skinColor, this.length = 60}) {
    body = List.generate(length, (i) => startPos);
    angles = List.generate(length, (i) => 0.0);
  }
}

class StartScreen extends StatefulWidget {
  @override
  _StartScreenState createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  int highScore = 0, totalPoints = 0;
  Color selectedColor = Colors.orange;
  List<String> unlockedSkins = ['orange'];
  g_ads.BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  final Map<String, Color> skinLibrary = {
    'orange': Colors.orange, 'blue': Colors.blue, 'green': Colors.green, 'purple': Colors.purple, 'red': Colors.red,
  };

  @override
  void initState() { super.initState(); _loadData(); _loadBannerAd(); }

  void _loadBannerAd() {
    _bannerAd = g_ads.BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: g_ads.AdSize.banner,
      request: const g_ads.AdRequest(),
      listener: g_ads.BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerAdLoaded = true),
        onAdFailedToLoad: (ad, e) => ad.dispose(),
      ),
    )..load();
  }

  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      highScore = prefs.getInt('highScore') ?? 0;
      totalPoints = prefs.getInt('totalPoints') ?? 0;
      unlockedSkins = prefs.getStringList('unlockedSkins') ?? ['orange'];
      selectedColor = skinLibrary[prefs.getString('selectedSkin') ?? 'orange']!;
    });
  }

  @override
  Widget build(BuildContext context) {
    Size s = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("SNAKE PRO", style: TextStyle(color: Colors.orangeAccent, fontSize: 60, fontWeight: FontWeight.bold)),
                Text("💰 Points: $totalPoints", style: const TextStyle(color: Colors.amber, fontSize: 20)),
                const SizedBox(height: 30),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: skinLibrary.keys.map((name) => _skinCircle(name)).toList()),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 20), shape: const StadiumBorder()),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => SnakeIoPro(color: selectedColor, highScore: highScore))).then((_) => _loadData()),
                  child: const Text("PLAY", style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          if (_isBannerAdLoaded) Positioned(bottom: 0, width: s.width, height: 50, child: g_ads.AdWidget(ad: _bannerAd!)),
        ],
      ),
    );
  }

  Widget _skinCircle(String name) {
    bool unlocked = unlockedSkins.contains(name);
    return GestureDetector(
      onTap: () async {
        final prefs = await SharedPreferences.getInstance();
        if (unlocked) { setState(() => selectedColor = skinLibrary[name]!); await prefs.setString('selectedSkin', name); }
        else if (totalPoints >= 500) { setState(() { totalPoints -= 500; unlockedSkins.add(name); }); await prefs.setInt('totalPoints', totalPoints); await prefs.setStringList('unlockedSkins', unlockedSkins); }
      },
      child: Container(margin: const EdgeInsets.all(8), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selectedColor == skinLibrary[name] ? Colors.white : Colors.transparent, width: 3)), child: CircleAvatar(backgroundColor: skinLibrary[name], radius: 20, child: unlocked ? null : const Icon(Icons.lock, size: 15, color: Colors.white))),
    );
  }
  @override void dispose() { _bannerAd?.dispose(); super.dispose(); }
}

class SnakeIoPro extends StatefulWidget {
  final Color color; final int highScore;
  SnakeIoPro({required this.color, required this.highScore});
  @override _SnakeIoProState createState() => _SnakeIoProState();
}

class _SnakeIoProState extends State<SnakeIoPro> {
  late Snake player; List<Snake> bots = []; List<Offset> food = [];
  final double worldSize = 5000.0; Timer? gameLoop;
  ui.Image? head, body;
  final AudioPlayer bgPlayer = AudioPlayer(), fxPlayer = AudioPlayer();
  g_ads.InterstitialAd? _googleAd;
  y_ads.InterstitialAd? _yandexAd;

  @override
  void initState() {
    super.initState();
    player = Snake(startPos: const Offset(2500, 2500), skinColor: widget.color);
    bots = List.generate(5, (i) => Snake(startPos: Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize), skinColor: Colors.blue));
    food = List.generate(200, (i) => Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize));
    _loadAssets(); _loadDualAds();
    _playMusic();
    gameLoop = Timer.periodic(const Duration(milliseconds: 16), (t) => updateGame());
  }

  void _loadDualAds() {
    g_ads.InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const g_ads.AdRequest(),
      adLoadCallback: g_ads.InterstitialAdLoadCallback(onAdLoaded: (ad) => _googleAd = ad, onAdFailedToLoad: (e) => _googleAd = null),
    );
    // تم إصلاح استدعاء ياندكس 7.11.0 (السينتكس المستقر)
    final loader = y_ads.InterstitialAdLoader(
      onAdLoaded: (ad) => setState(() => _yandexAd = ad),
      onAdFailedToLoad: (error) => _yandexAd = null,
    );
    loader.loadAd(adRequestConfiguration: y_ads.AdRequestConfiguration(adUnitId: 'R-M-DEMO-interstitial'));
  }

  void _playMusic() async { await bgPlayer.setReleaseMode(ReleaseMode.loop); await bgPlayer.play(AssetSource('audio/music.mp3')); await bgPlayer.setVolume(0.3); }

  Future<void> _loadAssets() async {
    final dHead = await DefaultAssetBundle.of(context).load('assets/head.png');
    final cHead = await ui.instantiateImageCodec(dHead.buffer.asUint8List(), targetWidth: 120);
    head = (await cHead.getNextFrame()).image;
    final dBody = await DefaultAssetBundle.of(context).load('assets/body.png');
    final cBody = await ui.instantiateImageCodec(dBody.buffer.asUint8List(), targetWidth: 100);
    body = (await cBody.getNextFrame()).image;
    if (mounted) setState(() {});
  }

  void updateGame() {
    if (!mounted) return;
    setState(() {
      double diff = player.targetAngle - player.angle;
      while (diff < -pi) diff += 2 * pi;
      while (diff > pi) diff -= 2 * pi;
      player.angle += diff * 0.15;
      _move(player); _checkFood(player);
      for (var b in bots) {
        if (Random().nextInt(100) < 5) b.angle += (Random().nextDouble() - 0.5);
        _move(b);
        if ((player.body.first - b.body.first).distance < 45) _end();
      }
    });
  }

  void _move(Snake s) {
    double spd = (s.isBoosting ? 12.0 : 6.0);
    s.body.insert(0, Offset((s.body.first.dx + cos(s.angle)*spd).clamp(0, worldSize), (s.body.first.dy + sin(s.angle)*spd).clamp(0, worldSize)));
    s.angles.insert(0, s.angle);
    if (s.body.length > s.length) { s.body.removeLast(); s.angles.removeLast(); }
  }

  void _checkFood(Snake s) {
    food.removeWhere((f) {
      if ((f - s.body.first).distance < 60) {
        s.length += 5;
        if (s == player) fxPlayer.play(AssetSource('audio/eat.mp3'));
        return true;
      }
      return false;
    });
    if (food.length < 200) food.add(Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize));
  }

  void _end() async {
    gameLoop?.cancel(); bgPlayer.stop();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('totalPoints', (prefs.getInt('totalPoints') ?? 0) + player.length);
    if (player.length > widget.highScore) {
      await prefs.setInt('highScore', player.length);
      try { FirebaseFirestore.instance.collection('leaderboard').add({'name': 'Player', 'score': player.length}); } catch (e) {}
    }
    if (_googleAd != null) _googleAd!.show(); else if (_yandexAd != null) _yandexAd!.show();
    await fxPlayer.play(AssetSource('audio/die.wav'));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    Size s = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          CustomPaint(size: Size.infinite, painter: GamePainter(player: player, bots: bots, food: food, sz: s, head: head, body: body, worldSize: worldSize)),
          Positioned(bottom: 50, left: 50, child: _boostBtn()),
          Positioned(bottom: 50, right: 50, child: _controls()),
          Positioned(top: 40, left: 20, child: Text("Score: ${player.length}", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, backgroundColor: Colors.black45))),
        ],
      ),
    );
  }

  Widget _boostBtn() => GestureDetector(onTapDown: (_) => setState(() => player.isBoosting = true), onTapUp: (_) => setState(() => player.isBoosting = false), child: CircleAvatar(radius: 35, backgroundColor: Colors.orange.withOpacity(0.6), child: const Icon(Icons.bolt, color: Colors.white, size: 40)));
  Widget _controls() => Column(children: [_btn(Icons.arrow_upward, -pi/2), Row(children: [_btn(Icons.arrow_back, pi), const SizedBox(width: 40), _btn(Icons.arrow_forward, 0)]), _btn(Icons.arrow_downward, pi/2)]);
  Widget _btn(IconData i, double a) => GestureDetector(onTap: () => setState(() => player.targetAngle = a), child: Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: Icon(i, color: Colors.white, size: 35)));

  @override
  void dispose() { gameLoop?.cancel(); bgPlayer.dispose(); fxPlayer.dispose(); _googleAd?.dispose(); super.dispose(); }
}

class GamePainter extends CustomPainter {
  final Snake player; final List<Snake> bots; final List<Offset> food; final Size sz; final ui.Image? head, body; final double worldSize;
  GamePainter({required this.player, required this.bots, required this.food, required this.sz, this.head, this.body, required this.worldSize});

  @override
  void paint(Canvas canvas, Size size) {
    // الكاميرا تتبع اللاعب وتمنع اللون الأبيض
    canvas.translate(sz.width / 2 - player.body.first.dx, sz.height / 2 - player.body.first.dy);
    canvas.drawRect(Rect.fromLTWH(0, 0, worldSize, worldSize), Paint()..color = Colors.green.shade900);
    for (var f in food) canvas.drawCircle(f, 10, Paint()..color = Colors.yellowAccent);
    if (head != null && body != null) {
      for (var b in bots) _drawSnake(canvas, b, b.skinColor);
      _drawSnake(canvas, player, player.skinColor);
    }
  }

  void _drawSnake(Canvas canvas, Snake s, Color? filter) {
    int gap = 3; 
    for (int i = s.body.length - 1; i >= 0; i--) {
      if (i % gap != 0 && i != 0) continue;
      canvas.save(); canvas.translate(s.body[i].dx, s.body[i].dy); canvas.rotate(s.angles[i] + pi/2);
      Paint p = Paint(); if (filter != null) p.colorFilter = ColorFilter.mode(filter, BlendMode.modulate);
      paintImage(canvas: canvas, rect: Rect.fromCenter(center: Offset.zero, width: i==0?80:60, height: i==0?80:60), image: i==0?head!:body!, colorFilter: p.colorFilter, fit: BoxFit.contain);
      canvas.restore();
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
