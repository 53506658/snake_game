import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // مكتبة الإعلانات
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

void main() async {
  // 1. ربط المحرك بنظام التشغيل
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 2. تهيئة Firebase
    await Firebase.initializeApp();
    
    // 3. 🔥 تهيئة الإعلانات (السطر المهم الذي طلبته)
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint("Initialization Error: $e");
  }

  runApp(MaterialApp(
    home: StartScreen(),
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
  ));
}

// --- نموذج الثعبان المتطور ---
class Snake {
  List<Offset> body = [];
  List<double> angles = [];
  double angle = 0.0;
  int length;
  Color skinColor;
  bool isBoosting = false;

  Snake({required Offset startPos, required this.skinColor, this.length = 60}) {
    body = List.generate(length, (i) => startPos);
    angles = List.generate(length, (i) => 0.0);
  }
}

// --- شاشة البداية ---
class StartScreen extends StatefulWidget {
  @override
  _StartScreenState createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  int totalPoints = 0;
  bool isMuted = false;
  Color selectedColor = Colors.orange;
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // معرف تجريبي
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerAdLoaded = true),
        onAdFailedToLoad: (ad, e) => ad.dispose(),
      ),
    )..load();
  }

  _loadData() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      totalPoints = p.getInt('totalPoints') ?? 0;
      isMuted = p.getBool('muted') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("SNAKE IO PRO", style: TextStyle(color: Colors.orange, fontSize: 55, fontWeight: FontWeight.bold)),
                  Text("💰 Points: $totalPoints", style: TextStyle(fontSize: 22, color: Colors.amber)),
                  SizedBox(height: 40),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: EdgeInsets.symmetric(horizontal: 100, vertical: 20)),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => SnakeIoPro(color: selectedColor, isMuted: isMuted))).then((_) => _loadData()),
                    child: Text("PLAY GAME", style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  SizedBox(height: 20),
                  IconButton(
                      icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up, size: 45, color: Colors.orange),
                      onPressed: () async {
                        setState(() => isMuted = !isMuted);
                        (await SharedPreferences.getInstance()).setBool('muted', isMuted);
                      }),
                ],
              ),
            ),
          ),
          if (_isBannerAdLoaded)
            Positioned(bottom: 0, width: MediaQuery.of(context).size.width, height: 50, child: AdWidget(ad: _bannerAd!)),
        ],
      ),
    );
  }
}

// --- شاشة اللعبة ---
class SnakeIoPro extends StatefulWidget {
  final Color color;
  final bool isMuted;
  SnakeIoPro({required this.color, required this.isMuted});
  @override
  _SnakeIoProState createState() => _SnakeIoProState();
}

class _SnakeIoProState extends State<SnakeIoPro> {
  late Snake player;
  List<Snake> bots = [];
  List<Offset> food = [];
  final double worldSize = 8000.0;
  Timer? gameLoop;
  ui.Image? headImg, bodyImg, bgImg;
  final AudioPlayer bgMusic = AudioPlayer();
  final AudioPlayer fxPlayer = AudioPlayer();
  InterstitialAd? _interstitialAd;

  @override
  void initState() {
    super.initState();
    player = Snake(startPos: Offset(4000, 4000), skinColor: widget.color);
    bots = List.generate(20, (i) => Snake(startPos: Offset(Random().nextDouble() * worldSize, Random().nextDouble() * worldSize), skinColor: Colors.accents[i % Colors.accents.length]));
    food = List.generate(250, (i) => Offset(Random().nextDouble() * worldSize, Random().nextDouble() * worldSize));
    
    _loadAssets();
    _loadInterstitialAd();
    if (!widget.isMuted) _startMusic();
    gameLoop = Timer.periodic(Duration(milliseconds: 16), (t) => _update());
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (e) => _interstitialAd = null,
      ),
    );
  }

  _startMusic() async {
    await bgMusic.setReleaseMode(ReleaseMode.loop);
    await bgMusic.play(AssetSource('audio/music.mp3'), volume: 0.3);
  }

  _loadAssets() async {
    headImg = await _img('assets/head.png');
    bodyImg = await _img('assets/body.png');
    bgImg = await _img('assets/forest.png');
    setState(() {});
  }

  Future<ui.Image> _img(String p) async {
    final d = await DefaultAssetBundle.of(context).load(p);
    final c = await ui.instantiateImageCodec(d.buffer.asUint8List());
    return (await c.getNextFrame()).image;
  }

  void _update() {
    if (!mounted) return;
    setState(() {
      _moveSnake(player);
      _checkFood(player);

      for (var b in bots) {
        if (food.isNotEmpty) {
          Offset target = food.first;
          b.angle = atan2(target.dy - b.body.first.dy, target.dx - b.body.first.dx);
        }
        _moveSnake(b);
        _checkFood(b);
        _checkCombat(b);
      }
    });
  }

  void _moveSnake(Snake s) {
    double speed = s.isBoosting ? 9.0 : 4.5;
    Offset next = Offset((s.body.first.dx + cos(s.angle) * speed).clamp(0, worldSize), (s.body.first.dy + sin(s.angle) * speed).clamp(0, worldSize));
    s.body.insert(0, next);
    s.angles.insert(0, s.angle);
    if (s.body.length > s.length) {
      s.body.removeLast();
      s.angles.removeLast();
    }
  }

  void _checkFood(Snake s) {
    food.removeWhere((f) {
      if ((f - s.body.first).distance < 60) {
        s.length += 3;
        if (s == player && !widget.isMuted) fxPlayer.play(AssetSource('audio/eat.mp3'), mode: PlayerMode.lowLatency);
        return true;
      }
      return false;
    });
    if (food.length < 250) food.add(Offset(Random().nextDouble() * worldSize, Random().nextDouble() * worldSize));
  }

  void _checkCombat(Snake bot) {
    if ((player.body.first - bot.body.first).distance < 50) {
      if (player.length > bot.length) {
        bot.body = [Offset(Random().nextDouble() * worldSize, Random().nextDouble() * worldSize)];
        player.length += 15;
      } else {
        _gameOver();
      }
    }
  }

  _gameOver() async {
    gameLoop?.cancel();
    bgMusic.stop();
    if (!widget.isMuted) await fxPlayer.play(AssetSource('audio/die.wav'));
    
    final p = await SharedPreferences.getInstance();
    await p.setInt('totalPoints', (p.getInt('totalPoints') ?? 0) + (player.length ~/ 2));
    
    if (_interstitialAd != null) _interstitialAd!.show();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    Size s = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(children: [
        CustomPaint(
            size: Size.infinite,
            painter: GamePainter(player: player, bots: bots, food: food, sz: s, head: headImg, body: bodyImg, bg: bgImg, worldSize: worldSize)),
        Positioned(top: 50, right: 20, child: Container(
          width: 120, height: 120, decoration: BoxDecoration(color: Colors.black54, border: Border.all(color: Colors.white24)),
          child: CustomPaint(painter: MiniMapPainter(player: player, bots: bots, worldSize: worldSize)),
        )),
        Positioned(bottom: 40, left: 30, child: _joystick()),
        Positioned(bottom: 50, right: 30, child: GestureDetector(
          onLongPress: () => setState(() => player.isBoosting = true),
          onLongPressEnd: (_) => setState(() => player.isBoosting = false),
          child: FloatingActionButton(onPressed: (){}, backgroundColor: Colors.orange, child: Icon(Icons.bolt)),
        )),
        Positioned(top: 40, left: 20, child: Text("Score: ${player.length}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
      ]),
    );
  }

  Widget _joystick() => Column(children: [
        _btn(Icons.arrow_upward, -pi / 2),
        Row(children: [_btn(Icons.arrow_back, pi), SizedBox(width: 40), _btn(Icons.arrow_forward, 0)]),
        _btn(Icons.arrow_downward, pi / 2),
      ]);

  Widget _btn(IconData i, double a) => GestureDetector(
      onTap: () => setState(() => player.angle = a),
      child: Container(padding: EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: Icon(i, color: Colors.white)));

  @override
  void dispose() {
    gameLoop?.cancel();
    bgMusic.dispose();
    fxPlayer.dispose();
    super.dispose();
  }
}

class GamePainter extends CustomPainter {
  final Snake player; final List<Snake> bots; final List<Offset> food; final Size sz;
  final ui.Image? head, body, bg; final double worldSize;
  GamePainter({required this.player, required this.bots, required this.food, required this.sz, this.head, this.body, this.bg, required this.worldSize});

  @override
  void paint(Canvas canvas, Size size) {
    // توسيط الكاميرا على رأس اللاعب
    canvas.translate(sz.width / 2 - player.body.first.dx, sz.height / 2 - player.body.first.dy);
    
    if (bg != null) {
      canvas.drawImageRect(bg!, Rect.fromLTWH(0,0, bg!.width.toDouble(), bg!.height.toDouble()), Rect.fromLTWH(0,0, worldSize, worldSize), Paint());
    } else {
      canvas.drawRect(Rect.fromLTWH(0,0, worldSize, worldSize), Paint()..color = Colors.green.shade900);
    }

    for (var f in food) canvas.drawCircle(f, 12, Paint()..color = Colors.yellowAccent);
    for (var b in bots) _drawSnake(canvas, b);
    _drawSnake(canvas, player);
  }

  void _drawSnake(Canvas canvas, Snake s) {
    if (head == null || body == null) return;
    for (int i = s.body.length - 1; i >= 0; i--) {
      if (i % 6 != 0 && i != 0) continue;
      canvas.save();
      canvas.translate(s.body[i].dx, s.body[i].dy);
      canvas.rotate(s.angles[i] + pi / 2);
      ui.Image img = (i == 0) ? head! : body!;
      paintImage(canvas: canvas, rect: Rect.fromCenter(center: Offset.zero, width: i == 0 ? 90 : 70, height: i == 0 ? 90 : 70), image: img);
      canvas.restore();
    }
  }
  @override bool shouldRepaint(covariant CustomPainter old) => true;
}

class MiniMapPainter extends CustomPainter {
  final Snake player; final List<Snake> bots; final double worldSize;
  MiniMapPainter({required this.player, required this.bots, required this.worldSize});
  @override
  void paint(Canvas canvas, Size size) {
    double s = size.width / worldSize;
    canvas.drawCircle(player.body.first * s, 4, Paint()..color = Colors.white);
    for (var b in bots) canvas.drawCircle(b.body.first * s, 2, Paint()..color = Colors.red);
  }
  @override bool shouldRepaint(covariant CustomPainter old) => true;
}
