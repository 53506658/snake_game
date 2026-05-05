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
  } catch (e) { debugPrint("Firebase/Ads Error: $e"); }
  runApp(MaterialApp(home: StartScreen(), debugShowCheckedModeBanner: false, theme: ThemeData.dark()));
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

  void move(double worldSize) {
    double speed = isBoosting ? 9.0 : 4.5;
    Offset head = body.first;
    Offset next = Offset(
      (head.dx + cos(angle) * speed).clamp(0, worldSize),
      (head.dy + sin(angle) * speed).clamp(0, worldSize),
    );
    body.insert(0, next);
    angles.insert(0, angle);
    if (body.length > length) { body.removeLast(); angles.removeLast(); }
  }
}

// --- شاشة البداية ---
class StartScreen extends StatefulWidget {
  @override _StartScreenState createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  int totalPoints = 0;
  bool isMuted = false;
  Color selectedColor = Colors.orange;

  @override void initState() { super.initState(); _loadData(); }

  _loadData() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      totalPoints = p.getInt('totalPoints') ?? 0;
      isMuted = p.getBool('muted') ?? false;
      String colorName = p.getString('selectedSkin') ?? 'orange';
      if(colorName == 'blue') selectedColor = Colors.blue;
      else if(colorName == 'green') selectedColor = Colors.green;
      else selectedColor = Colors.orange;
    });
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: SingleChildScrollView(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text("SNAKE PRO", style: TextStyle(color: Colors.orange, fontSize: 60, fontWeight: FontWeight.bold)),
        Text("💰 Points: $totalPoints", style: TextStyle(fontSize: 20, color: Colors.amber)),
        SizedBox(height: 30),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton.icon(onPressed: () => _showShop(), icon: Icon(Icons.shopping_bag), label: Text("SHOP")),
          SizedBox(width: 10),
          ElevatedButton.icon(onPressed: () => _showLeaderboard(), icon: Icon(Icons.leaderboard), label: Text("RANKS")),
        ]),
        SizedBox(height: 20),
        IconButton(icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up, size: 45, color: Colors.orange), onPressed: () async {
          setState(() => isMuted = !isMuted); (await SharedPreferences.getInstance()).setBool('muted', isMuted);
        }),
        SizedBox(height: 40),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: EdgeInsets.symmetric(horizontal: 100, vertical: 20)),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => SnakeIoPro(color: selectedColor, isMuted: isMuted))).then((_) => _loadData()),
          child: Text("PLAY GAME", style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ]))),
    );
  }

  void _showShop() { /* كود المتجر المختصر */ }
  void _showLeaderboard() { /* كود عرض لوحة الصدارة */ }
}

// --- شاشة اللعبة ---
class SnakeIoPro extends StatefulWidget {
  final Color color; final bool isMuted;
  SnakeIoPro({required this.color, required this.isMuted});
  @override _SnakeIoProState createState() => _SnakeIoProState();
}

class _SnakeIoProState extends State<SnakeIoPro> {
  late Snake player; List<Snake> bots = []; List<Offset> food = [];
  final double worldSize = 8000.0;
  Timer? gameLoop;
  ui.Image? headImg, bodyImg, tailImg, bgImg;
  final AudioPlayer bgMusic = AudioPlayer(), fxPlayer = AudioPlayer();

  @override void initState() {
    super.initState();
    player = Snake(startPos: Offset(4000, 4000), skinColor: widget.color);
    bots = List.generate(20, (i) => Snake(startPos: Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize), skinColor: Colors.accents[i % Colors.accents.length]));
    food = List.generate(300, (i) => Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize));
    _loadAssets();
    if (!widget.isMuted) _startMusic();
    gameLoop = Timer.periodic(Duration(milliseconds: 16), (t) => _update());
  }

  _startMusic() async { await bgMusic.setReleaseMode(ReleaseMode.loop); await bgMusic.play(AssetSource('audio/music.mp3'), volume: 0.3); }

  _loadAssets() async {
    headImg = await _img('assets/head.png'); bodyImg = await _img('assets/body.png');
    tailImg = await _img('assets/tail.png'); bgImg = await _img('assets/forest.png');
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
      player.move(worldSize);
      _checkFood(player);

      for (var b in bots) {
        if (food.isNotEmpty) {
          Offset target = food.first;
          b.angle = atan2(target.dy - b.body.first.dy, target.dx - b.body.first.dx);
        }
        b.move(worldSize);
        _checkFood(b);
        _checkCombat(b);
      }
    });
  }

  void _checkFood(Snake s) {
    food.removeWhere((f) {
      if ((f - s.body.first).distance < 50) {
        s.length += 3;
        if (s == player && !widget.isMuted) fxPlayer.play(AssetSource('audio/eat.mp3'), mode: PlayerMode.lowLatency);
        return true;
      } return false;
    });
    if (food.length < 300) food.add(Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize));
  }

  void _checkCombat(Snake bot) {
    if ((player.body.first - bot.body.first).distance < 50) {
      if (player.length > bot.length) {
        bot.body = [Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize)];
        bot.length = 40;
        player.length += 20;
      } else { _gameOver(); }
    }
  }

  _gameOver() async {
    gameLoop?.cancel(); bgMusic.stop();
    if (!widget.isMuted) await fxPlayer.play(AssetSource('audio/die.wav'), mode: PlayerMode.lowLatency);
    final p = await SharedPreferences.getInstance();
    await p.setInt('totalPoints', (p.getInt('totalPoints') ?? 0) + (player.length ~/ 2));
    Navigator.pop(context);
  }

  @override Widget build(BuildContext context) {
    Size s = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(children: [
        CustomPaint(size: Size.infinite, painter: GamePainter(player: player, bots: bots, food: food, sz: s, head: headImg, body: bodyImg, tail: tailImg, bg: bgImg, worldSize: worldSize)),
        
        // رادار الخريطة
        Positioned(top: 50, right: 20, child: Container(
          width: 130, height: 130, decoration: BoxDecoration(color: Colors.black54, border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(10)),
          child: CustomPaint(painter: RadarPainter(player: player, bots: bots, worldSize: worldSize)),
        )),

        // التحكم
        Positioned(bottom: 40, left: 30, child: _joystick()),
        Positioned(bottom: 50, right: 30, child: GestureDetector(onLongPress: () => setState(() => player.isBoosting = true), onLongPressEnd: (_) => setState(() => player.isBoosting = false), child: FloatingActionButton(onPressed: (){}, backgroundColor: Colors.orange, child: Icon(Icons.bolt)))),
        Positioned(top: 40, left: 20, child: Text("Length: ${player.length}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
      ]),
    );
  }

  Widget _joystick() => Column(children: [
    _btn(Icons.arrow_upward, -pi/2), Row(children: [_btn(Icons.arrow_back, pi), SizedBox(width: 40), _btn(Icons.arrow_forward, 0)]), _btn(Icons.arrow_downward, pi/2),
  ]);
  Widget _btn(IconData i, double a) => GestureDetector(onTap: () => setState(() => player.angle = a), child: Container(padding: EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: Icon(i, color: Colors.white)));
  @override void dispose() { gameLoop?.cancel(); bgPlayer.dispose(); fxPlayer.dispose(); super.dispose(); }
}

// --- رسام اللعبة الاحترافي ---
class GamePainter extends CustomPainter {
  final Snake player; final List<Snake> bots; final List<Offset> food; final Size sz;
  final ui.Image? head, body, tail, bg; final double worldSize;
  GamePainter({required this.player, required this.bots, required this.food, required this.sz, this.head, this.body, this.tail, this.bg, required this.worldSize});

  @override void paint(Canvas canvas, Size size) {
    canvas.translate(sz.width / 2 - player.body.first.dx, sz.height / 2 - player.body.first.dy);
    
    // رسم الخلفية لتغطي كامل المساحة
    if (bg != null) {
       canvas.drawImageRect(bg!, Rect.fromLTWH(0,0, bg!.width.toDouble(), bg!.height.toDouble()), Rect.fromLTWH(0,0, worldSize, worldSize), Paint());
    } else {
       canvas.drawRect(Rect.fromLTWH(0,0, worldSize, worldSize), Paint()..color = Colors.green.shade900);
    }

    for (var f in food) canvas.drawCircle(f, 15, Paint()..color = Colors.yellowAccent);
    for (var b in bots) _drawSnake(canvas, b);
    _drawSnake(canvas, player);
  }

  void _drawSnake(Canvas canvas, Snake s) {
    if (head == null || body == null) return;
    for (int i = s.body.length - 1; i >= 0; i--) {
      if (i % 6 != 0 && i != 0 && i != s.body.length - 1) continue;
      canvas.save();
      canvas.translate(s.body[i].dx, s.body[i].dy);
      canvas.rotate(s.angles[i] + pi / 2);
      ui.Image img = (i == 0) ? head! : (i == s.body.length - 1 ? (tail ?? body!) : body!);
      paintImage(canvas: canvas, rect: Rect.fromCenter(center: Offset.zero, width: i==0?90:70, height: i==0?90:70), image: img);
      canvas.restore();
    }
  }
  @override bool shouldRepaint(covariant CustomPainter old) => true;
}

// --- رسام الرادار ---
class RadarPainter extends CustomPainter {
  final Snake player; final List<Snake> bots; final double worldSize;
  RadarPainter({required this.player, required this.bots, required this.worldSize});
  @override void paint(Canvas canvas, Size size) {
    double scale = size.width / worldSize;
    canvas.drawCircle(player.body.first * scale, 5, Paint()..color = Colors.white);
    for (var b in bots) canvas.drawCircle(b.body.first * scale, 3, Paint()..color = Colors.red);
  }
  @override bool shouldRepaint(covariant CustomPainter old) => true;
}
