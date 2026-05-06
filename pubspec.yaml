import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle; // للتحميل الآمن بدون context
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // تشغيل آمن لـ Firebase مع مهلة زمنية
    await Firebase.initializeApp().timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint("Firebase skip: $e");
  }
  runApp(const MaterialApp(
    home: StartScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

// --- نموذج الثعبان ---
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
  const StartScreen({super.key});
  @override _StartScreenState createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  int totalPoints = 0;
  bool isMuted = false;

  @override void initState() { 
    super.initState(); 
    _loadData(); 
  }

  _loadData() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      totalPoints = p.getInt('totalPoints') ?? 0;
      isMuted = p.getBool('muted') ?? false;
    });
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("SNAKE", style: TextStyle(color: Colors.orange, fontSize: 80, fontWeight: FontWeight.bold)),
            Text("💰 Points: $totalPoints", style: const TextStyle(fontSize: 22, color: Colors.amber)),
            const SizedBox(height: 50),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 20)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => SnakeIoPro(isMuted: isMuted))).then((_) => _loadData()),
              child: const Text("PLAY", style: TextStyle(fontSize: 25, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- شاشة اللعبة ---
class SnakeIoPro extends StatefulWidget {
  final bool isMuted;
  const SnakeIoPro({super.key, required this.isMuted});
  @override _SnakeIoProState createState() => _SnakeIoProState();
}

class _SnakeIoProState extends State<SnakeIoPro> {
  late Snake player;
  List<Snake> bots = [];
  List<Offset> food = [];
  final double worldSize = 8000.0;
  Timer? gameLoop;
  ui.Image? headImg, bodyImg, tailImg, bgImg;
  final AudioPlayer bgMusic = AudioPlayer();
  final AudioPlayer fxPlayer = AudioPlayer();

  @override void initState() {
    super.initState();
    player = Snake(startPos: const Offset(4000, 4000), skinColor: Colors.orange);
    bots = List.generate(15, (i) => Snake(startPos: Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize), skinColor: Colors.blue));
    food = List.generate(200, (i) => Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize));
    
    _loadAssets();
    if (!widget.isMuted) _startMusic();
    gameLoop = Timer.periodic(const Duration(milliseconds: 16), (t) => _update());
  }

  // استخدام rootBundle بدلاً من DefaultAssetBundle.of(context) لمنع الانهيار
  Future<ui.Image> _img(String p) async {
    final d = await rootBundle.load(p);
    final c = await ui.instantiateImageCodec(d.buffer.asUint8List());
    return (await c.getNextFrame()).image;
  }

  _loadAssets() async {
    try {
      headImg = await _img('assets/head.png');
      bodyImg = await _img('assets/body.png');
      tailImg = await _img('assets/tail.png');
      bgImg = await _img('assets/forest.png');
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Asset load error: $e");
    }
  }

  _startMusic() async {
    try {
      await bgMusic.setReleaseMode(ReleaseMode.loop);
      await bgMusic.play(AssetSource('audio/music.mp3'), volume: 0.3);
    } catch (e) { debugPrint("Music error: $e"); }
  }

  void _update() {
    if (!mounted) return;
    setState(() {
      _moveSnake(player);
      for (var b in bots) {
        if (food.isNotEmpty) {
          Offset target = food.first;
          b.angle = atan2(target.dy - b.body.first.dy, target.dx - b.body.first.dx);
        }
        _moveSnake(b);
        if ((player.body.first - b.body.first).distance < 50) _gameOver();
      }
      _checkFood();
    });
  }

  void _moveSnake(Snake s) {
    double speed = s.isBoosting ? 9.0 : 4.5;
    Offset next = Offset((s.body.first.dx + cos(s.angle)*speed).clamp(0, worldSize), (s.body.first.dy + sin(s.angle)*speed).clamp(0, worldSize));
    s.body.insert(0, next);
    s.angles.insert(0, s.angle);
    if (s.body.length > s.length) { s.body.removeLast(); s.angles.removeLast(); }
  }

  void _checkFood() {
    food.removeWhere((f) {
      if ((f - player.body.first).distance < 60) {
        player.length += 3;
        if (!widget.isMuted) {
          try { fxPlayer.play(AssetSource('audio/eat.mp3'), mode: PlayerMode.lowLatency); } catch(e) {}
        }
        return true;
      } return false;
    });
    if (food.length < 200) food.add(Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize));
  }

  _gameOver() async {
    gameLoop?.cancel();
    bgMusic.stop();
    if (!widget.isMuted) {
      try { await fxPlayer.play(AssetSource('audio/die.wav')); } catch(e) {}
    }
    final p = await SharedPreferences.getInstance();
    await p.setInt('totalPoints', (p.getInt('totalPoints') ?? 0) + (player.length ~/ 2));
    if (mounted) Navigator.pop(context);
  }

  @override Widget build(BuildContext context) {
    Size s = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(children: [
        CustomPaint(size: Size.infinite, painter: GamePainter(player: player, bots: bots, food: food, sz: s, head: headImg, body: bodyImg, bg: bgImg, worldSize: worldSize)),
        Positioned(bottom: 40, left: 30, child: _joystick()),
        Positioned(bottom: 50, right: 30, child: GestureDetector(
          onLongPress: () => setState(() => player.isBoosting = true),
          onLongPressEnd: (_) => setState(() => player.isBoosting = false),
          child: FloatingActionButton(onPressed: (){}, backgroundColor: Colors.orange, child: const Icon(Icons.bolt)))),
      ]),
    );
  }

  Widget _joystick() => Column(children: [
    _btn(Icons.arrow_upward, -pi/2),
    Row(children: [_btn(Icons.arrow_back, pi), const SizedBox(width: 40), _btn(Icons.arrow_forward, 0)]),
    _btn(Icons.arrow_downward, pi/2),
  ]);
  Widget _btn(IconData i, double a) => GestureDetector(onTap: () => setState(() => player.angle = a), child: Container(padding: const EdgeInsets.all(15), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: Icon(i, color: Colors.white)));
  
  @override void dispose() { gameLoop?.cancel(); bgMusic.dispose(); fxPlayer.dispose(); super.dispose(); }
}

class GamePainter extends CustomPainter {
  final Snake player; final List<Snake> bots; final List<Offset> food; final Size sz;
  final ui.Image? head, body, bg; final double worldSize;
  GamePainter({required this.player, required this.bots, required this.food, required this.sz, this.head, this.body, this.bg, required this.worldSize});

  @override void paint(Canvas canvas, Size size) {
    canvas.translate(sz.width / 2 - player.body.first.dx, sz.height / 2 - player.body.first.dy);
    if (bg != null) {
      canvas.drawImageRect(bg!, Rect.fromLTWH(0, 0, bg!.width.toDouble(), bg!.height.toDouble()), Rect.fromLTWH(0, 0, worldSize, worldSize), Paint());
    } else {
      canvas.drawRect(Rect.fromLTWH(0,0, worldSize, worldSize), Paint()..color = Colors.green.shade900);
    }
    for (var f in food) canvas.drawCircle(f, 15, Paint()..color = Colors.yellowAccent);
    for (var b in bots) _drawSnake(canvas, b);
    _drawSnake(canvas, player);
  }

  void _drawSnake(Canvas canvas, Snake s) {
    if (head == null || body == null) return;
    for (int i = 0; i < s.body.length; i++) {
      if (i % 6 != 0 && i != 0) continue;
      canvas.save();
      canvas.translate(s.body[i].dx, s.body[i].dy);
      canvas.rotate(s.angles[i] + pi/2);
      ui.Image img = (i == 0) ? head! : body!;
      paintImage(canvas: canvas, rect: Rect.fromCenter(center: Offset.zero, width: i==0?90:70, height: i==0?90:70), image: img);
      canvas.restore();
    }
  }
  @override bool shouldRepaint(covariant CustomPainter old) => true;
}
