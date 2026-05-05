import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(MaterialApp(home: StartScreen(), debugShowCheckedModeBanner: false));
}

class Snake {
  List<Offset> body = [];
  List<double> angles = [];
  double angle = 0.0;
  int length;
  Color skinFilter; 
  bool isBoosting = false;

  Snake({required Offset startPos, required this.skinFilter, this.length = 40}) {
    body = List.generate(length, (i) => startPos);
    angles = List.generate(length, (i) => 0.0);
  }
}

class StartScreen extends StatefulWidget {
  @override _StartScreenState createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  bool isMuted = false;
  int totalCoins = 0;

  @override
  void initState() { super.initState(); _loadSettings(); }

  _loadSettings() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      isMuted = p.getBool('mute') ?? false;
      totalCoins = p.getInt('coins') ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("SNAKE PRO", style: TextStyle(color: Colors.orange, fontSize: 60, fontWeight: FontWeight.bold)),
            Text("Coins: $totalCoins 💰", style: TextStyle(color: Colors.white, fontSize: 20)),
            SizedBox(height: 40),
            IconButton(
              icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 50),
              onPressed: () async {
                setState(() => isMuted = !isMuted);
                (await SharedPreferences.getInstance()).setBool('mute', isMuted);
              },
            ),
            SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: EdgeInsets.symmetric(horizontal: 60, vertical: 20)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => SnakeIoPro(isMuted: isMuted))).then((_) => _loadSettings()),
              child: Text("PLAY GAME", style: TextStyle(fontSize: 25, color: Colors.white)),
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
  @override _SnakeIoProState createState() => _SnakeIoProState();
}

class _SnakeIoProState extends State<SnakeIoPro> {
  late Snake player;
  List<Snake> bots = [];
  List<Offset> food = [];
  final double worldSize = 5000.0;
  Timer? gameLoop;
  ui.Image? headImg, bodyImg, bgImg;
  final AudioPlayer bgMusic = AudioPlayer(), fxPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    player = Snake(startPos: Offset(2500, 2500), skinFilter: Colors.white);
    bots = List.generate(15, (i) => Snake(startPos: Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize), skinFilter: Colors.blue));
    food = List.generate(200, (i) => Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize));
    
    _loadAssets();
    if (!widget.isMuted) _startMusic();
    gameLoop = Timer.periodic(Duration(milliseconds: 16), (t) => updateGame());
  }

  _startMusic() async {
    await bgMusic.setReleaseMode(ReleaseMode.loop);
    await bgMusic.play(AssetSource('audio/music.mp3'), volume: 0.3);
  }

  Future<void> _loadAssets() async {
    headImg = await _loadImage('assets/head.png');
    bodyImg = await _loadImage('assets/body.png');
    bgImg = await _loadImage('assets/forest.png');
    setState(() {});
  }

  Future<ui.Image> _loadImage(String path) async {
    final data = await DefaultAssetBundle.of(context).load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }

  void updateGame() {
    if (!mounted) return;
    setState(() {
      _move(player);
      _checkFood(player);

      for (var b in bots) {
        // ذكاء الأعداء: الاتجاه نحو أقرب طعام
        if (food.isNotEmpty) {
          Offset target = food.first;
          b.angle = atan2(target.dy - b.body.first.dy, target.dx - b.body.first.dx);
        }
        _move(b);
        _checkFood(b);
        // قتل اللاعب إذا لمس بوت
        if ((player.body.first - b.body.first).distance < 50) _end();
      }
    });
  }

  void _move(Snake s) {
    double speed = s.isBoosting ? 12.0 : 6.0;
    Offset next = Offset(
      (s.body.first.dx + cos(s.angle) * speed).clamp(0, worldSize),
      (s.body.first.dy + sin(s.angle) * speed).clamp(0, worldSize)
    );
    s.body.insert(0, next);
    s.angles.insert(0, s.angle);
    if (s.body.length > s.length) { s.body.removeLast(); s.angles.removeLast(); }
  }

  void _checkFood(Snake s) {
    food.removeWhere((f) {
      if ((f - s.body.first).distance < 40) {
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
    bgMusic.stop();
    if (!widget.isMuted) await fxPlayer.play(AssetSource('audio/die.wav'), mode: PlayerMode.lowLatency);
    final p = await SharedPreferences.getInstance();
    await p.setInt('coins', (p.getInt('coins') ?? 0) + (player.length ~/ 5));
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
            painter: GamePainter(player: player, bots: bots, food: food, sz: s, head: headImg, body: bodyImg, bg: bgImg, worldSize: worldSize),
          ),
          // تحكم الأسهم
          Positioned(
            bottom: 40, left: 30,
            child: Column(
              children: [
                _btn(Icons.arrow_upward, -pi/2),
                Row(children: [_btn(Icons.arrow_back, pi), SizedBox(width: 40), _btn(Icons.arrow_forward, 0)]),
                _btn(Icons.arrow_downward, pi/2),
              ],
            ),
          ),
          // زر السرعة
          Positioned(bottom: 50, right: 30, child: GestureDetector(
            onLongPress: () => setState(() => player.isBoosting = true),
            onLongPressEnd: (_) => setState(() => player.isBoosting = false),
            child: FloatingActionButton(onPressed: (){}, child: Icon(Icons.bolt), backgroundColor: Colors.orange),
          )),
        ],
      ),
    );
  }

  Widget _btn(IconData i, double a) => GestureDetector(
    onTap: () => setState(() => player.angle = a),
    child: Container(padding: EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: Icon(i, color: Colors.white)),
  );
}

class GamePainter extends CustomPainter {
  final Snake player; final List<Snake> bots; final List<Offset> food; final Size sz;
  final ui.Image? head, body, bg; final double worldSize;
  GamePainter({required this.player, required this.bots, required this.food, required this.sz, this.head, this.body, this.bg, required this.worldSize});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(sz.width / 2 - player.body.first.dx, sz.height / 2 - player.body.first.dy);
    
    // رسم الخلفية (تتكرر أو تغطي العالم)
    if (bg != null) {
      canvas.drawImageRect(bg!, Rect.fromLTWH(0, 0, bg!.width.toDouble(), bg!.height.toDouble()), Rect.fromLTWH(0, 0, worldSize, worldSize), Paint());
    } else {
      canvas.drawRect(Rect.fromLTWH(0, 0, worldSize, worldSize), Paint()..color = Colors.green.shade900);
    }

    for (var f in food) canvas.drawCircle(f, 10, Paint()..color = Colors.yellowAccent);

    for (var b in bots) _drawSnake(canvas, b);
    _drawSnake(canvas, player);
  }

  void _drawSnake(Canvas canvas, Snake s) {
    if (head == null || body == null) return;
    for (int i = s.body.length - 1; i >= 0; i--) {
      if (i % 4 != 0 && i != 0) continue;
      canvas.save();
      canvas.translate(s.body[i].dx, s.body[i].dy);
      canvas.rotate(s.angles[i] + pi / 2);
      ui.Image img = (i == 0) ? head! : body!;
      paintImage(canvas: canvas, rect: Rect.fromCenter(center: Offset.zero, width: i==0?80:60, height: i==0?80:60), image: img);
      canvas.restore();
    }
  }
  @override bool shouldRepaint(CustomPainter old) => true;
}
