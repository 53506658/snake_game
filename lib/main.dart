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
  List<Offset> body = []; double angle = 0.0; Color color; int length = 50;
  bool isBoosting = false;
  Snake({required Offset startPos, required this.color}) {
    body = List.generate(length, (index) => startPos);
    angle = Random().nextDouble() * 2 * pi;
  }
}

class StartScreen extends StatefulWidget {
  @override
  _StartScreenState createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  int highScore = 0;
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("SNAKE", style: TextStyle(color: Colors.orangeAccent, fontSize: 80, fontWeight: FontWeight.bold, letterSpacing: 10)),
            Text("🏆 BEST: $highScore", style: TextStyle(color: Colors.white70, fontSize: 18)),
            SizedBox(height: 60),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: EdgeInsets.symmetric(horizontal: 80, vertical: 20), shape: StadiumBorder()),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => SnakeIoPro())),
              child: Text("PLAY", style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class SnakeIoPro extends StatefulWidget {
  @override
  _SnakeIoProState createState() => _SnakeIoProState();
}

class _SnakeIoProState extends State<SnakeIoPro> {
  late Snake player; List<Snake> bots = []; List<Offset> food = [];
  final double worldSize = 3000.0; Timer? gameLoop;
  ui.Image? head, body, tail;
  int level = 1;

  @override
  void initState() {
    super.initState();
    player = Snake(startPos: Offset(1500, 1500), color: Colors.transparent);
    bots = List.generate(5, (i) => Snake(startPos: Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize), color: [Colors.blue, Colors.green, Colors.purple][i%3]));
    food = List.generate(150, (i) => Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize));
    _loadAssets();
    gameLoop = Timer.periodic(Duration(milliseconds: 16), (t) => updateGame());
  }

  Future<void> _loadAssets() async {
    head = await _getImg('assets/head.png');
    body = await _getImg('assets/body.png');
    tail = await _getImg('assets/tail.png');
    if(mounted) setState(() {});
  }

  Future<ui.Image> _getImg(String p) async {
    final d = await DefaultAssetBundle.of(context).load(p);
    final c = await ui.instantiateImageCodec(d.buffer.asUint8List(), targetWidth: 100);
    return (await c.getNextFrame()).image;
  }

  void updateGame() {
    if (!mounted) return;
    setState(() {
      _move(player); _checkFood(player);
      for (var b in bots) {
        if (Random().nextInt(100) < 5) b.angle += (Random().nextDouble() - 0.5);
        _move(b); _checkFood(b);
        if ((player.body.first - b.body.first).distance < 45) _end();
      }
    });
  }

  void _move(Snake s) {
    double spd = (s.isBoosting ? 8.0 : 4.0) + (level * 0.5);
    Offset next = Offset((s.body.first.dx + cos(s.angle)*spd).clamp(0, worldSize), (s.body.first.dy + sin(s.angle)*spd).clamp(0, worldSize));
    s.body.insert(0, next);
    if (s.body.length > s.length) s.body.removeLast();
  }

  void _checkFood(Snake s) {
    food.removeWhere((f) {
      if ((f - s.body.first).distance < 50) { s.length += 2; return true; }
      return false;
    });
    if (food.length < 150) food.add(Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize));
  }

  void _end() { gameLoop?.cancel(); Navigator.pop(context); }

  @override
  Widget build(BuildContext context) {
    Size s = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/forest.png', fit: BoxFit.cover)),
          GestureDetector(
            onPanUpdate: (d) => setState(() => player.angle = atan2(d.localPosition.dy - s.height/2, d.localPosition.dx - s.width/2)),
            child: CustomPaint(size: Size.infinite, painter: GamePainter(player: player, bots: bots, food: food, sz: s, head: head, body: body, tail: tail)),
          ),
          // زر السرعة (Boost)
          Positioned(
            bottom: 50, left: 30,
            child: GestureDetector(
              onTapDown: (_) => setState(() => player.isBoosting = true),
              onTapUp: (_) => setState(() => player.isBoosting = false),
              child: Container(padding: EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.5), shape: BoxShape.circle), child: Icon(Icons.bolt, color: Colors.white, size: 40)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() { gameLoop?.cancel(); super.dispose(); }
}

class GamePainter extends CustomPainter {
  final Snake player; final List<Snake> bots; final List<Offset> food;
  final Size sz; final ui.Image? head, body, tail;
  GamePainter({required this.player, required this.bots, required this.food, required this.sz, this.head, this.body, this.tail});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(sz.width/2 - player.body.first.dx, sz.height/2 - player.body.first.dy);
    for (var f in food) canvas.drawCircle(f, 10, Paint()..color = Colors.yellowAccent);

    if (head != null && body != null && tail != null) {
      for (var b in bots) _drawSnake(canvas, b, b.color);
      _drawSnake(canvas, player, null);
    }
  }

  void _drawSnake(Canvas canvas, Snake s, Color? color) {
    for (int i = s.body.length - 1; i >= 0; i--) {
      if (i % 12 != 0 && i != 0) continue; // زيادة التباعد لجعل الحركة انسيابية
      canvas.save();
      canvas.translate(s.body[i].dx, s.body[i].dy);
      Paint p = Paint();
      if (color != null) p.colorFilter = ColorFilter.mode(color, BlendMode.modulate);
      
      if (i == 0) {
        canvas.rotate(s.angle + pi/2);
        _draw(canvas, head!, 65, p);
      } else {
        _draw(canvas, body!, 50, p);
      }
      canvas.restore();
    }
  }

  void _draw(Canvas c, ui.Image i, double s, Paint p) => paintImage(canvas: c, rect: Rect.fromCenter(center: Offset.zero, width: s, height: s), image: i, paint: p);
  @override
  bool shouldRepaint(CustomPainter old) => true;
}
