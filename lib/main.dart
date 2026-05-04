import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart'; // مكتبة فيربيز

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // تهيئة فيربيز للوحة الصدارة
  MobileAds.instance.initialize();
  runApp(MaterialApp(home: StartScreen(), debugShowCheckedModeBanner: false));
}

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
  int highScore = 0, totalPoints = 0, speedLevel = 1, lengthLevel = 1;
  Color selectedColor = Colors.orange;
  bool isMuted = false;

  @override
  void initState() { super.initState(); _loadData(); }
  
  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      highScore = prefs.getInt('highScore') ?? 0;
      totalPoints = prefs.getInt('totalPoints') ?? 0;
      speedLevel = prefs.getInt('speedLevel') ?? 1;
      lengthLevel = prefs.getInt('lengthLevel') ?? 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: Main => MainAxisAlignment.center,
          children: [
            const Text("SNAKE", style: TextStyle(color: Colors.orangeAccent, fontSize: 80, fontWeight: FontWeight.bold)),
            Text("💰 Points: $totalPoints", style: const TextStyle(color: Colors.amber, fontSize: 20)),
            const SizedBox(height: 50),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 20), shape: const StadiumBorder()),
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (c) => SnakeIoPro(
                  color: selectedColor, 
                  speedLvl: speedLevel, 
                  lengthLvl: lengthLevel,
                  isMuted: isMuted,
                )
              )).then((_) => _loadData()),
              child: const Text("PLAY", style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class SnakeIoPro extends StatefulWidget {
  final Color color; final int speedLvl; final int lengthLvl; final bool isMuted;
  SnakeIoPro({required this.color, required this.speedLvl, required this.lengthLvl, required this.isMuted});
  @override
  _SnakeIoProState createState() => _SnakeIoProState();
}

class _SnakeIoProState extends State<SnakeIoPro> {
  late Snake player; List<Snake> bots = []; List<Offset> food = [];
  final double worldSize = 5000.0; Timer? gameLoop;
  ui.Image? head, body; InterstitialAd? _interstitialAd;

  @override
  void initState() {
    super.initState();
    player = Snake(startPos: const Offset(2500, 2500), skinColor: widget.color, length: 60 + (widget.lengthLvl * 5));
    bots = List.generate(6, (i) => Snake(startPos: Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize), skinColor: Colors.blue));
    food = List.generate(200, (i) => Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize));
    _loadAssets();
    gameLoop = Timer.periodic(const Duration(milliseconds: 16), (t) => updateGame());
  }

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
      _moveSnake(player, true);
      for (var b in bots) {
        if (Random().nextInt(100) < 5) b.angle += (Random().nextDouble() - 0.5);
        _moveSnake(b, false);
      }
      food.removeWhere((f) => (f - player.body.first).distance < 60);
      if (food.length < 200) food.add(Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize));
    });
  }

  void _moveSnake(Snake s, bool isPlayer) {
    double spd = (isPlayer ? 6.0 + (widget.speedLvl * 0.2) : 6.0) * (s.isBoosting ? 2.0 : 1.0);
    s.body.insert(0, Offset((s.body.first.dx + cos(s.angle)*spd).clamp(0, worldSize), (s.body.first.dy + sin(s.angle)*spd).clamp(0, worldSize)));
    s.angles.insert(0, s.angle);
    if (s.body.length > s.length) { s.body.removeLast(); s.angles.removeLast(); }
  }

  @override
  Widget build(BuildContext context) {
    Size s = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          CustomPaint(size: Size.infinite, painter: GamePainter(player: player, bots: bots, food: food, sz: s, head: head, body: body, worldSize: worldSize)),
          Positioned(bottom: 40, right: 40, child: _buildArrows()),
          Positioned(bottom: 40, left: 40, child: _buildBoostBtn()),
        ],
      ),
    );
  }

  Widget _buildBoostBtn() => GestureDetector(
    onTapDown: (_) => setState(() => player.isBoosting = true),
    onTapUp: (_) => setState(() => player.isBoosting = false),
    child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.6), shape: BoxShape.circle), child: const Icon(Icons.bolt, color: Colors.white, size: 45)),
  );

  Widget _buildArrows() => Column(children: [_arrowBtn(Icons.arrow_upward, -pi/2), Row(children: [_arrowBtn(Icons.arrow_back, pi), const SizedBox(width: 40), _arrowBtn(Icons.arrow_forward, 0)]), _arrowBtn(Icons.arrow_downward, pi/2)]);

  Widget _arrowBtn(IconData i, double a) => GestureDetector(onTap: () => setState(() => player.targetAngle = a), child: Container(margin: const EdgeInsets.all(5), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: Icon(i, color: Colors.white, size: 35)));

  @override
  void dispose() { gameLoop?.cancel(); super.dispose(); }
}

class GamePainter extends CustomPainter {
  final Snake player; final List<Snake> bots; final List<Offset> food;
  final Size sz; final ui.Image? head, body; final double worldSize;
  GamePainter({required this.player, required this.bots, required this.food, required this.sz, this.head, this.body, required this.worldSize});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(sz.width / 2 - player.body.first.dx, sz.height / 2 - player.body.first.dy);
    canvas.drawRect(Rect.fromLTWH(0, 0, worldSize, worldSize), Paint()..color = Colors.green.shade900);
    for (var f in food) canvas.drawCircle(f, 10, Paint()..color = Colors.yellowAccent);
    if (head != null && body != null) {
      for (var b in bots) _drawSnake(canvas, b, Colors.blue);
      _drawSnake(canvas, player, null);
    }
  }
  void _drawSnake(Canvas canvas, Snake s, Color? filter) {
    int gap = 4;
    for (int i = s.body.length - 1; i >= 0; i--) {
      if (i % gap != 0 && i != 0) continue;
      canvas.save(); canvas.translate(s.body[i].dx, s.body[i].dy); canvas.rotate(s.angles[i] + 1.57);
      Paint p = Paint(); if (filter != null) p.colorFilter = ColorFilter.mode(filter, BlendMode.modulate);
      paintImage(canvas: canvas, rect: Rect.fromCenter(center: Offset.zero, width: i==0?75:55, height: i==0?75:55), image: i==0?head!:body!, colorFilter: p.colorFilter);
      canvas.restore();
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
