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
  List<double> angles = []; // تخزين زاوية كل قطعة لمنع التقطع
  double angle = 0.0; Color color; int length = 40;
  bool isBoosting = false;
  Snake({required Offset startPos, required this.color}) {
    body = List.generate(length, (index) => startPos);
    angles = List.generate(length, (index) => 0.0);
    angle = 0.0;
  }
}

class StartScreen extends StatefulWidget {
  @override
  _StartScreenState createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  int highScore = 0;
  bool isMuted = false; // إعادة متغير الصوت

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
            SizedBox(height: 20),
            IconButton(
              icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 30),
              onPressed: () => setState(() => isMuted = !isMuted),
            ),
            SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: EdgeInsets.symmetric(horizontal: 80, vertical: 20), shape: StadiumBorder()),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => SnakeIoPro(isMuted: isMuted))),
              child: Text("PLAY", style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
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
  late Snake player; List<Snake> bots = []; List<Offset> food = [];
  final double worldSize = 3000.0; Timer? gameLoop;
  ui.Image? head, body, tail;

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
    double spd = (s.isBoosting ? 8.0 : 4.0);
    Offset next = Offset((s.body.first.dx + cos(s.angle)*spd).clamp(0, worldSize), (s.body.first.dy + sin(s.angle)*spd).clamp(0, worldSize));
    s.body.insert(0, next);
    s.angles.insert(0, s.angle); // حفظ زاوية الرأس للقطع التي خلفه
    if (s.body.length > s.length) {
      s.body.removeLast();
      s.angles.removeLast();
    }
  }

  void _checkFood(Snake s) {
    food.removeWhere((f) {
      if ((f - s.body.first).distance < 50) { s.length += 3; return true; }
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
          // زر السرعة
          Positioned(
            bottom: 30, left: 30,
            child: GestureDetector(
              onTapDown: (_) => setState(() => player.isBoosting = true),
              onTapUp: (_) => setState(() => player.isBoosting = false),
              child: Container(padding: EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.7), shape: BoxShape.circle), child: Icon(Icons.bolt, color: Colors.white, size: 40)),
            ),
          ),
          // أزرار التحكم (الأسهم)
          Positioned(
            bottom: 30, right: 30,
            child: Column(
              children: [
                _arrowBtn(Icons.arrow_upward, -pi/2),
                Row(children: [
                  _arrowBtn(Icons.arrow_back, pi),
                  SizedBox(width: 40),
                  _arrowBtn(Icons.arrow_forward, 0),
                ]),
                _arrowBtn(Icons.arrow_downward, pi/2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrowBtn(IconData icon, double ang) => GestureDetector(
    onTap: () => setState(() => player.angle = ang),
    child: Container(margin: EdgeInsets.all(5), padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 30)),
  );

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

  void _drawSnake(Canvas canvas, Snake s, Color? colorFilter) {
    // رسم الجسم من الذيل للرأس ليكون الرأس في المقدمة
    for (int i = s.body.length - 1; i >= 0; i--) {
      // تعديل المسافة: رسم قطعة كل 6 نقاط لضمان الاتصال وعدم التقطع
      if (i % 6 != 0 && i != 0) continue; 
      
      canvas.save();
      canvas.translate(s.body[i].dx, s.body[i].dy);
      
      // تدوير كل قطعة بناءً على زاويتها الخاصة المسجلة
      canvas.rotate(s.angles[i] + pi/2);

      Paint p = Paint();
      if (colorFilter != null) p.colorFilter = ColorFilter.mode(colorFilter, BlendMode.modulate);
      
      if (i == 0) {
        _draw(canvas, head!, 60, p);
      } else {
        _draw(canvas, body!, 45, p);
      }
      canvas.restore();
    }
  }

  void _draw(Canvas c, ui.Image i, double s, Paint p) {
    paintImage(canvas: c, rect: Rect.fromCenter(center: Offset.zero, width: s, height: s), image: i, colorFilter: p.colorFilter, fit: BoxFit.contain);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
