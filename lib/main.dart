import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(MaterialApp(home: StartScreen(), debugShowCheckedModeBanner: false));
}

class Snake {
  List<Offset> body = []; List<double> angles = [];
  double angle = 0.0, targetAngle = 0.0;
  int length = 60; bool isBoosting = false;
  Snake({required Offset startPos}) {
    body = List.generate(length, (i) => startPos);
    angles = List.generate(length, (i) => 0.0);
  }
}

class StartScreen extends StatefulWidget {
  @override
  _StartScreenState createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  int highScore = 0; bool isMuted = false;
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
            IconButton(
              icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 40),
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
  final double worldSize = 5000.0; Timer? gameLoop;
  ui.Image? head, body;
  final AudioPlayer bgPlayer = AudioPlayer(); // مشغل موسيقى الخلفية
  final AudioPlayer fxPlayer = AudioPlayer(); // مشغل المؤثرات

  @override
  void initState() {
    super.initState();
    player = Snake(startPos: Offset(2500, 2500));
    bots = List.generate(5, (i) => Snake(startPos: Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize)));
    food = List.generate(200, (i) => Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize));
    _loadAssets();
    if (!widget.isMuted) _playMusic();
    gameLoop = Timer.periodic(Duration(milliseconds: 16), (t) => updateGame());
  }

  void _playMusic() async {
    await bgPlayer.setReleaseMode(ReleaseMode.loop);
    await bgPlayer.play(AssetSource('audio/music.mp3'));
    await bgPlayer.setVolume(0.3);
  }

  Future<void> _loadAssets() async {
    final dHead = await DefaultAssetBundle.of(context).load('assets/head.png');
    final cHead = await ui.instantiateImageCodec(dHead.buffer.asUint8List(), targetWidth: 120);
    head = (await cHead.getNextFrame()).image;
    final dBody = await DefaultAssetBundle.of(context).load('assets/body.png');
    final cBody = await ui.instantiateImageCodec(dBody.buffer.asUint8List(), targetWidth: 100);
    body = (await cBody.getNextFrame()).image;
    if(mounted) setState(() {});
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
        if ((player.body.first - b.body.first).distance < 50) _end();
      }
    });
  }

  void _move(Snake s) {
    double spd = (s.isBoosting ? 12.0 : 6.0);
    Offset next = Offset((s.body.first.dx + cos(s.angle)*spd).clamp(0, worldSize), (s.body.first.dy + sin(s.angle)*spd).clamp(0, worldSize));
    s.body.insert(0, next);
    s.angles.insert(0, s.angle);
    if (s.body.length > s.length) { s.body.removeLast(); s.angles.removeLast(); }
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
    if (food.length < 200) food.add(Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize));
  }

  void _end() async {
    gameLoop?.cancel();
    bgPlayer.stop();
    if (!widget.isMuted) await fxPlayer.play(AssetSource('audio/die.wav'), mode: PlayerMode.lowLatency);
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
          Positioned(bottom: 40, left: 40, child: _boost()),
          Positioned(bottom: 40, right: 40, child: _controls()),
        ],
      ),
    );
  }

  Widget _boost() => GestureDetector(
    onTapDown: (_) => setState(() => player.isBoosting = true),
    onTapUp: (_) => setState(() => player.isBoosting = false),
    child: CircleAvatar(radius: 35, backgroundColor: Colors.orange.withOpacity(0.6), child: Icon(Icons.bolt, color: Colors.white, size: 40)),
  );

  Widget _controls() => Column(children: [
    _btn(Icons.arrow_upward, -pi/2),
    Row(children: [_btn(Icons.arrow_back, pi), SizedBox(width: 40), _btn(Icons.arrow_forward, 0)]),
    _btn(Icons.arrow_downward, pi/2),
  ]);

  Widget _btn(IconData i, double a) => GestureDetector(
    onTap: () => setState(() => player.targetAngle = a),
    child: Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: Icon(i, color: Colors.white, size: 30)),
  );

  @override
  void dispose() { gameLoop?.cancel(); bgPlayer.dispose(); fxPlayer.dispose(); super.dispose(); }
}

class GamePainter extends CustomPainter {
  final Snake player; final List<Snake> bots; final List<Offset> food;
  final Size sz; final ui.Image? head, body; final double worldSize;
  GamePainter({required this.player, required this.bots, required this.food, required this.sz, this.head, this.body, required this.worldSize});

  @override
  void paint(Canvas canvas, Size size) {
    // الكاميرا تتبع اللاعب بدقة تامة
    canvas.translate(sz.width/2 - player.body.first.dx, sz.height/2 - player.body.first.dy);
    
    // رسم الخلفية لتغطي كامل عالم اللعبة 5000x5000
    canvas.drawRect(Rect.fromLTWH(0, 0, worldSize, worldSize), Paint()..color = Colors.green.shade900);
    
    // رسم شبكة بسيطة لتعزيز الشعور بالحركة
    Paint gridPaint = Paint()..color = Colors.white10..strokeWidth = 2;
    for (double i = 0; i <= worldSize; i += 200) {
      canvas.drawLine(Offset(i, 0), Offset(i, worldSize), gridPaint);
      canvas.drawLine(Offset(0, i), Offset(worldSize, i), gridPaint);
    }

    for (var f in food) canvas.drawCircle(f, 10, Paint()..color = Colors.yellowAccent);

    if (head != null && body != null) {
      for (var b in bots) _drawSnake(canvas, b, Colors.blue);
      _drawSnake(canvas, player, null);
    }
  }

  void _drawSnake(Canvas canvas, Snake s, Color? filter) {
    int gap = 3; // تقليل الفجوة لجسم ملتحم
    for (int i = s.body.length - 1; i >= 0; i--) {
      if (i % gap != 0 && i != 0) continue;
      canvas.save();
      canvas.translate(s.body[i].dx, s.body[i].dy);
      canvas.rotate(s.angles[i] + pi/2);
      Paint p = Paint();
      if (filter != null) p.colorFilter = ColorFilter.mode(filter, BlendMode.modulate);
      paintImage(canvas: canvas, rect: Rect.fromCenter(center: Offset.zero, width: i==0?75:55, height: i==0?75:55), image: i==0?head!:body!, colorFilter: p.colorFilter, fit: BoxFit.contain);
      canvas.restore();
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
