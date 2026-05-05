import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as ads;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    ads.MobileAds.instance.initialize();
  } catch (e) { debugPrint("Init Error: $e"); }
  runApp(MaterialApp(home: StartScreen(), debugShowCheckedModeBanner: false, theme: ThemeData.dark()));
}

class Snake {
  List<Offset> body = []; List<double> angles = [];
  double angle = 0.0; int length; Color skinColor; bool isBoosting = false;
  Snake({required Offset startPos, required this.skinColor, this.length = 60}) {
    body = List.generate(length, (i) => startPos);
    angles = List.generate(length, (i) => 0.0);
  }
}

class StartScreen extends StatefulWidget {
  @override _StartScreenState createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  int totalPoints = 0; bool isMuted = false;
  String selectedMap = 'assets/forest.png';
  Color selectedColor = Colors.orange;
  final Map<String, Color> skins = {'orange': Colors.orange, 'blue': Colors.blue, 'green': Colors.green, 'purple': Colors.purple, 'red': Colors.red};

  @override void initState() { super.initState(); _loadData(); }

  _loadData() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      totalPoints = p.getInt('totalPoints') ?? 0;
      isMuted = p.getBool('muted') ?? false;
      selectedColor = skins[p.getString('selectedSkin') ?? 'orange']!;
    });
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text("SNAKE PRO", style: TextStyle(color: Colors.orange, fontSize: 60, fontWeight: FontWeight.bold)),
        Text("💰 Points: $totalPoints", style: TextStyle(fontSize: 20, color: Colors.amber)),
        SizedBox(height: 30),
        IconButton(icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up, size: 50, color: Colors.orange), onPressed: () async {
          setState(() => isMuted = !isMuted); (await SharedPreferences.getInstance()).setBool('muted', isMuted);
        }),
        SizedBox(height: 30),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: EdgeInsets.symmetric(horizontal: 80, vertical: 20)),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => SnakeIoPro(color: selectedColor, map: selectedMap, isMuted: isMuted))).then((_) => _loadData()),
          child: Text("PLAY GAME", style: TextStyle(fontSize: 25, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ])),
    );
  }
}

class SnakeIoPro extends StatefulWidget {
  final Color color; final String map; final bool isMuted;
  SnakeIoPro({required this.color, required this.map, required this.isMuted});
  @override _SnakeIoProState createState() => _SnakeIoProState();
}

class _SnakeIoProState extends State<SnakeIoPro> {
  late Snake player; List<Snake> bots = []; List<Offset> food = [];
  final double worldSize = 5000.0; Timer? gameLoop;
  ui.Image? head, body, bg;
  final AudioPlayer bgPlayer = AudioPlayer(), fxPlayer = AudioPlayer();

  @override void initState() {
    super.initState();
    player = Snake(startPos: Offset(2500, 2500), skinColor: widget.color);
    bots = List.generate(12, (i) => Snake(startPos: Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize), skinColor: Colors.blue));
    food = List.generate(150, (i) => Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize));
    _loadAssets(); if (!widget.isMuted) _startMusic();
    gameLoop = Timer.periodic(Duration(milliseconds: 16), (t) => _update());
  }

  _startMusic() async { await bgPlayer.setReleaseMode(ReleaseMode.loop); await bgPlayer.play(AssetSource('audio/music.mp3'), volume: 0.3); }

  _loadAssets() async {
    head = await _img('assets/head.png'); body = await _img('assets/body.png'); bg = await _img(widget.map);
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
      _move(player);
      for (var b in bots) {
        if (food.isNotEmpty) { Offset t = food.first; b.angle = atan2(t.dy - b.body.first.dy, t.dx - b.body.first.dx); }
        _move(b);
        if ((player.body.first - b.body.first).distance < 45) _gameOver();
      }
      _checkFood(player);
    });
  }

  void _move(Snake s) {
    double speed = s.isBoosting ? 10.0 : 5.0;
    Offset next = Offset((s.body.first.dx + cos(s.angle)*speed).clamp(0, worldSize), (s.body.first.dy + sin(s.angle)*speed).clamp(0, worldSize));
    s.body.insert(0, next); s.angles.insert(0, s.angle);
    if (s.body.length > s.length) { s.body.removeLast(); s.angles.removeLast(); }
  }

  void _checkFood(Snake s) {
    food.removeWhere((f) {
      if ((f - s.body.first).distance < 50) {
        s.length += 3; if (s == player && !widget.isMuted) fxPlayer.play(AssetSource('audio/eat.mp3'), mode: PlayerMode.lowLatency);
        return true;
      } return false;
    });
    if (food.length < 150) food.add(Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize));
  }

  _gameOver() async {
    gameLoop?.cancel(); bgPlayer.stop();
    if (!widget.isMuted) await fxPlayer.play(AssetSource('audio/die.wav'), mode: PlayerMode.lowLatency);
    final p = await SharedPreferences.getInstance();
    await p.setInt('totalPoints', (p.getInt('totalPoints') ?? 0) + (player.length ~/ 5));
    Navigator.pop(context);
  }

  @override Widget build(BuildContext context) {
    Size s = MediaQuery.of(context).size;
    return Scaffold(body: Stack(children: [
      CustomPaint(size: Size.infinite, painter: GamePainter(player: player, bots: bots, food: food, sz: s, head: head, body: body, bg: bg, worldSize: worldSize)),
      Positioned(bottom: 40, left: 30, child: _joystick()),
      Positioned(bottom: 50, right: 30, child: GestureDetector(onLongPress: () => setState(() => player.isBoosting = true), onLongPressEnd: (_) => setState(() => player.isBoosting = false), child: FloatingActionButton(onPressed: (){}, backgroundColor: Colors.orange, child: Icon(Icons.bolt)))),
      Positioned(top: 40, left: 20, child: Text("Length: ${player.length}", style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold))),
    ]));
  }

  Widget _joystick() => Column(children: [
    _btn(Icons.arrow_upward, -pi/2), Row(children: [_btn(Icons.arrow_back, pi), SizedBox(width: 40), _btn(Icons.arrow_forward, 0)]), _btn(Icons.arrow_downward, pi/2),
  ]);
  Widget _btn(IconData i, double a) => GestureDetector(onTap: () => setState(() => player.angle = a), child: Container(padding: EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: Icon(i, color: Colors.white)));
  @override void dispose() { gameLoop?.cancel(); bgPlayer.dispose(); fxPlayer.dispose(); super.dispose(); }
}

class GamePainter extends CustomPainter {
  final Snake player; final List<Snake> bots; final List<Offset> food; final Size sz; final ui.Image? head, body, bg; final double worldSize;
  GamePainter({required this.player, required this.bots, required this.food, required this.sz, this.head, this.body, this.bg, required this.worldSize});

  @override void paint(Canvas canvas, Size size) {
    // 1. تثبيت الكاميرا في المنتصف لمنع الشاشة السوداء
    canvas.translate(sz.width / 2 - player.body.first.dx, sz.height / 2 - player.body.first.dy);
    
    // 2. رسم لون أخضر ثابت كخلفية أساسية تحت الصورة لملء الفراغات
    canvas.drawRect(Rect.fromLTWH(-1000, -1000, worldSize + 2000, worldSize + 2000), Paint()..color = Color(0xFF1B5E20));

    if (bg != null) {
      // رسم الصورة لتغطي مساحة العالم
      canvas.drawImageRect(bg!, Rect.fromLTWH(0, 0, bg!.width.toDouble(), bg!.height.toDouble()), Rect.fromLTWH(0, 0, worldSize, worldSize), Paint());
    }

    // 3. رسم الطعام
    for (var f in food) canvas.drawCircle(f, 12, Paint()..color = Colors.yellowAccent);

    // 4. رسم الثعابين (مع فلتر اللون المختار)
    for (var b in bots) _drawSnake(canvas, b, b.skinColor);
    _drawSnake(canvas, player, player.skinColor);
  }

  void _drawSnake(Canvas canvas, Snake s, Color filter) {
    if (head == null || body == null) return;
    int gap = 4; // الفجوة بين قطع الجسم لمنع الاندماج في خط واحد
    for (int i = s.body.length - 1; i >= 0; i--) {
      if (i % gap != 0 && i != 0) continue;
      canvas.save();
      canvas.translate(s.body[i].dx, s.body[i].dy);
      canvas.rotate(s.angles[i] + pi / 2);
      ui.Image img = (i == 0) ? head! : body!;
      Paint p = Paint()..colorFilter = ColorFilter.mode(filter, BlendMode.modulate);
      paintImage(canvas: canvas, rect: Rect.fromCenter(center: Offset.zero, width: i==0?85:65, height: i==0?85:65), image: img, colorFilter: p.colorFilter);
      canvas.restore();
    }
  }
  @override bool shouldRepaint(covariant CustomPainter old) => true;
}
