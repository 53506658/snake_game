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
  int length = 40; 
  bool isBoosting = false;

  Snake({required Offset startPos}) {
    // البدء بمواقع متفرقة قليلاً لمنع التكدس في البداية
    body = List.generate(length, (i) => Offset(startPos.dx - i * 5, startPos.dy));
    angles = List.generate(length, (i) => 0.0);
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
  late Snake player;
  List<Snake> bots = [];
  List<Offset> food = [];
  final double worldSize = 4000.0;
  Timer? gameLoop;
  ui.Image? head, body, tail;

  @override
  void initState() {
    super.initState();
    player = Snake(startPos: Offset(2000, 2000));
    bots = List.generate(5, (i) => Snake(startPos: Offset(Random().nextDouble() * worldSize, Random().nextDouble() * worldSize)));
    food = List.generate(200, (i) => Offset(Random().nextDouble() * worldSize, Random().nextDouble() * worldSize));
    _loadAssets();
    // تفعيل حلقة اللعبة
    gameLoop = Timer.periodic(Duration(milliseconds: 20), (t) => updateGame());
  }

  Future<void> _loadAssets() async {
    head = await _getImg('assets/head.png');
    body = await _getImg('assets/body.png');
    tail = await _getImg('assets/tail.png');
    if (mounted) setState(() {});
  }

  Future<ui.Image> _getImg(String p) async {
    final d = await DefaultAssetBundle.of(context).load(p);
    final c = await ui.instantiateImageCodec(d.buffer.asUint8List(), targetWidth: 100);
    return (await c.getNextFrame()).image;
  }

  void updateGame() {
    if (!mounted) return;
    setState(() {
      _moveSnake(player);
      _checkFood(player);
      for (var b in bots) {
        if (Random().nextInt(100) < 5) b.angle += (Random().nextDouble() - 0.5);
        _moveSnake(b);
        _checkFood(b);
      }
    });
  }

  void _moveSnake(Snake s) {
    // زيادة السرعة قليلاً لضمان وضوح الحركة
    double spd = (s.isBoosting ? 12.0 : 6.0);
    
    // 1. حساب موقع الرأس الجديد
    Offset newHead = Offset(
      (s.body.first.dx + cos(s.angle) * spd).clamp(0, worldSize),
      (s.body.first.dy + sin(s.angle) * spd).clamp(0, worldSize),
    );

    // 2. تحديث قائمة الجسم (الزحف)
    s.body.insert(0, newHead);
    s.angles.insert(0, s.angle);

    // 3. الحفاظ على الطول (إزالة الذيل القديم)
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
    if (food.length < 200) food.add(Offset(Random().nextDouble() * worldSize, Random().nextDouble() * worldSize));
  }

  @override
  Widget build(BuildContext context) {
    Size s = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          // رسم العالم مع تثبيت الكاميرا على اللاعب
          CustomPaint(
            size: Size.infinite,
            painter: GamePainter(player: player, bots: bots, food: food, sz: s, head: head, body: body, tail: tail, worldSize: worldSize),
          ),
          // زر السرعة
          Positioned(
            bottom: 40, left: 40,
            child: GestureDetector(
              onTapDown: (_) => setState(() => player.isBoosting = true),
              onTapUp: (_) => setState(() => player.isBoosting = false),
              child: Container(padding: EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.6), shape: BoxShape.circle), child: Icon(Icons.bolt, color: Colors.white, size: 40)),
            ),
          ),
          // أزرار التحكم
          Positioned(
            bottom: 40, right: 40,
            child: Column(
              children: [
                _arrowBtn(Icons.arrow_upward, -pi / 2),
                Row(children: [_arrowBtn(Icons.arrow_back, pi), SizedBox(width: 40), _arrowBtn(Icons.arrow_forward, 0)]),
                _arrowBtn(Icons.arrow_downward, pi / 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrowBtn(IconData i, double a) => GestureDetector(
        onTap: () => setState(() => player.angle = a),
        child: Container(margin: EdgeInsets.all(5), padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: Icon(i, color: Colors.white, size: 35)),
      );

  @override
  void dispose() { gameLoop?.cancel(); super.dispose(); }
}

class GamePainter extends CustomPainter {
  final Snake player; final List<Snake> bots; final List<Offset> food;
  final Size sz; final ui.Image? head, body, tail; final double worldSize;
  GamePainter({required this.player, required this.bots, required this.food, required this.sz, this.head, this.body, this.tail, required this.worldSize});

  @override
  void paint(Canvas canvas, Size size) {
    // الكاميرا تتبع رأس اللاعب لضمان أن الثعبان يتحرك في مركز الشاشة
    canvas.translate(sz.width / 2 - player.body.first.dx, sz.height / 2 - player.body.first.dy);

    // رسم مستطيل يمثل حدود العالم (اختياري للتوضيح)
    canvas.drawRect(Rect.fromLTWH(0, 0, worldSize, worldSize), Paint()..color = Colors.green.shade900);

    // رسم الطعام
    for (var f in food) canvas.drawCircle(f, 10, Paint()..color = Colors.yellowAccent);

    // رسم الثعابين
    if (head != null && body != null) {
      for (var b in bots) _drawSnake(canvas, b, Colors.blue);
      _drawSnake(canvas, player, null);
    }
  }

  void _drawSnake(Canvas canvas, Snake s, Color? filter) {
    for (int i = s.body.length - 1; i >= 0; i--) {
      // تعديل المسافة: رسم قطعة كل 10 نقاط لضمان التمدد وعدم التكدس
      if (i % 10 != 0 && i != 0) continue;

      canvas.save();
      canvas.translate(s.body[i].dx, s.body[i].dy);
      canvas.rotate(s.angles[i] + pi / 2);

      Paint p = Paint();
      if (filter != null) p.colorFilter = ColorFilter.mode(filter, BlendMode.modulate);

      if (i == 0) {
        _draw(canvas, head!, 70, p);
      } else {
        _draw(canvas, body!, 50, p);
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
