import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(MaterialApp(home: StartScreen(), debugShowCheckedModeBanner: false));
}

class Snake {
  List<Offset> body = [];
  List<double> angles = [];
  double angle = 0.0;
  double targetAngle = 0.0;
  int length = 60;
  bool isBoosting = false;
  Color color;

  Snake({required Offset startPos, required this.color}) {
    body = List.generate(length, (i) => Offset(startPos.dx - i * 2, startPos.dy));
    angles = List.generate(length, (i) => 0.0);
  }
}

class StartScreen extends StatefulWidget {
  @override
  _StartScreenState createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  int highScore = 0;
  bool isMuted = false;

  @override
  void initState() { super.initState(); _loadData(); }
  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() { highScore = prefs.getInt('highScore') ?? 0; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/forest.png', fit: BoxFit.cover, opacity: const AlwaysStoppedAnimation(0.5))),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("SNAKE", style: TextStyle(color: Colors.orangeAccent, fontSize: 80, fontWeight: FontWeight.bold, letterSpacing: 10)),
                Text("🏆 BEST: $highScore", style: const TextStyle(color: Colors.white70, fontSize: 18)),
                const SizedBox(height: 20),
                IconButton(
                  icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 40),
                  onPressed: () => setState(() => isMuted = !isMuted),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 20), shape: const StadiumBorder()),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => SnakeIoPro(isMuted: isMuted))),
                  child: const Text("PLAY", style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SnakeIoPro extends StatefulWidget {
  final bool isMuted;
  SnakeIoPro({required this.isMuted});
  @override
  _SnakeIoProState createState() => _SnakeIoProState();
}

class _SnakeIoProState extends State<SnakeIoPro> {
  late Snake player;
  List<Snake> bots = [];
  List<Offset> food = [];
  final double worldSize = 5000.0;
  Timer? gameLoop;
  ui.Image? head, body, tail;

  @override
  void initState() {
    super.initState();
    player = Snake(startPos: const Offset(2500, 2500), color: Colors.transparent);
    bots = List.generate(6, (i) => Snake(startPos: Offset(Random().nextDouble() * worldSize, Random().nextDouble() * worldSize), color: [Colors.blue, Colors.green, Colors.purple, Colors.red][i % 4]));
    food = List.generate(250, (i) => Offset(Random().nextDouble() * worldSize, Random().nextDouble() * worldSize));
    _loadAssets();
    gameLoop = Timer.periodic(const Duration(milliseconds: 16), (t) => updateGame());
  }

  Future<void> _loadAssets() async {
    head = await _getImg('assets/head.png');
    body = await _getImg('assets/body.png');
    tail = await _getImg('assets/tail.png');
    if (mounted) setState(() {});
  }

  Future<ui.Image> _getImg(String p) async {
    final d = await DefaultAssetBundle.of(context).load(p);
    final c = await ui.instantiateImageCodec(d.buffer.asUint8List(), targetWidth: 120);
    return (await c.getNextFrame()).image;
  }

  void updateGame() {
    if (!mounted) return;
    setState(() {
      // تنعيم دوران اللاعب
      double diff = player.targetAngle - player.angle;
      while (diff < -pi) diff += 2 * pi;
      while (diff > pi) diff -= 2 * pi;
      player.angle += diff * 0.15;

      _moveSnake(player);
      _checkFood(player);

      for (var b in bots) {
        // ذكاء اصطناعي: البوتات تطارد اللاعب إذا اقترب
        double distToPlayer = (player.body.first - b.body.first).distance;
        if (distToPlayer < 600) {
          b.angle = atan2(player.body.first.dy - b.body.first.dy, player.body.first.dx - b.body.first.dx);
        } else if (Random().nextInt(100) < 3) {
          b.angle += (Random().nextDouble() - 0.5);
        }
        
        _moveSnake(b);
        _checkFood(b);
        
        // التحقق من التصادم
        if (distToPlayer < 45) _end();
      }
    });
  }

  void _moveSnake(Snake s) {
    double spd = (s.isBoosting ? 12.0 : 6.0);
    Offset nextHead = Offset(
      (s.body.first.dx + cos(s.angle) * spd).clamp(0, worldSize),
      (s.body.first.dy + sin(s.angle) * spd).clamp(0, worldSize),
    );
    s.body.insert(0, nextHead);
    s.angles.insert(0, s.angle);
    if (s.body.length > s.length) {
      s.body.removeLast();
      s.angles.removeLast();
    }
  }

  void _checkFood(Snake s) {
    food.removeWhere((f) {
      if ((f - s.body.first).distance < 60) {
        s.length += 2;
        return true;
      }
      return false;
    });
    if (food.length < 250) food.add(Offset(Random().nextDouble() * worldSize, Random().nextDouble() * worldSize));
  }

  void _end() {
    gameLoop?.cancel();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    Size s = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: GamePainter(player: player, bots: bots, food: food, sz: s, head: head, body: body, worldSize: worldSize),
          ),
          // أزرار التحكم
          Positioned(
            bottom: 40, right: 40,
            child: Column(
              children: [
                _arrowBtn(Icons.arrow_upward, -pi / 2),
                Row(children: [_arrowBtn(Icons.arrow_back, pi), const SizedBox(width: 40), _arrowBtn(Icons.arrow_forward, 0)]),
                _arrowBtn(Icons.arrow_downward, pi / 2),
              ],
            ),
          ),
          // زر السرعة
          Positioned(
            bottom: 40, left: 40,
            child: GestureDetector(
              onTapDown: (_) => setState(() => player.isBoosting = true),
              onTapUp: (_) => setState(() => player.isBoosting = false),
              child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.6), shape: BoxShape.circle), child: const Icon(Icons.bolt, color: Colors.white, size: 45)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrowBtn(IconData i, double a) => GestureDetector(
        onTap: () => setState(() => player.targetAngle = a),
        child: Container(margin: const EdgeInsets.all(5), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: Icon(i, color: Colors.white, size: 35)),
      );

  @override
  void dispose() { gameLoop?.cancel(); super.dispose(); }
}

class GamePainter extends CustomPainter {
  final Snake player; final List<Snake> bots; final List<Offset> food;
  final Size sz; final ui.Image? head, body; final double worldSize;

  GamePainter({required this.player, required this.bots, required this.food, required this.sz, this.head, this.body, required this.worldSize});

  @override
  void paint(Canvas canvas, Size size) {
    // الكاميرا تتبع اللاعب
    canvas.translate(sz.width / 2 - player.body.first.dx, sz.height / 2 - player.body.first.dy);

    // رسم الأرضية وتكرارها لتغطية العالم
    Paint bgPaint = Paint()..color = Colors.green.shade900;
    canvas.drawRect(Rect.fromLTWH(0, 0, worldSize, worldSize), bgPaint);

    // رسم الطعام
    for (var f in food) canvas.drawCircle(f, 10, Paint()..color = Colors.yellowAccent);

    // رسم الثعابين
    if (head != null && body != null) {
      for (var b in bots) _drawSnake(canvas, b, b.color);
      _drawSnake(canvas, player, null);
    }
  }

  void _drawSnake(Canvas canvas, Snake s, Color? filter) {
    int gap = 3;
    for (int i = s.body.length - 1; i >= 0; i--) {
      if (i % gap != 0 && i != 0) continue;
      canvas.save();
      canvas.translate(s.body[i].dx, s.body[i].dy);
      canvas.rotate(s.angles[i] + pi / 2);
      Paint p = Paint();
      if (filter != null) p.colorFilter = ColorFilter.mode(filter, BlendMode.modulate);
      
      if (i == 0) {
        paintImage(canvas: canvas, rect: Rect.fromCenter(center: Offset.zero, width: 75, height: 75), image: head!, colorFilter: p.colorFilter, fit: BoxFit.contain);
      } else {
        paintImage(canvas: canvas, rect: Rect.fromCenter(center: Offset.zero, width: 55, height: 55), image: body!, colorFilter: p.colorFilter, fit: BoxFit.contain);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
