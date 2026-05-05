import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as google;
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    await google.MobileAds.instance.initialize();
  } catch (e) {
    debugPrint("Init Error: $e");
  }
  runApp(MaterialApp(home: StartScreen(), debugShowCheckedModeBanner: false, theme: ThemeData.dark()));
}

class Snake {
  List<Offset> body = [];
  List<double> angles = [];
  double angle = 0.0, targetAngle = 0.0;
  int length;
  bool isBoosting = false;
  Color? skinColor; // لون الثعبان

  Snake({required Offset startPos, this.skinColor, this.length = 60}) {
    body = List.generate(length, (i) => startPos);
    angles = List.generate(length, (i) => 0.0);
  }
}

class StartScreen extends StatefulWidget {
  @override
  _StartScreenState createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  int highScore = 0, totalPoints = 0;
  String selectedMap = 'assets/forest.png';
  Color selectedColor = Colors.orange;
  List<String> unlockedSkins = ['orange'];
  bool isMuted = false;

  final Map<String, Color> skinLibrary = {
    'orange': Colors.orange, 'blue': Colors.blue, 'green': Colors.green, 'purple': Colors.purple, 'red': Colors.red,
  };

  @override
  void initState() { super.initState(); _loadData(); }

  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      highScore = prefs.getInt('highScore') ?? 0;
      totalPoints = prefs.getInt('totalPoints') ?? 0;
      unlockedSkins = prefs.getStringList('unlockedSkins') ?? ['orange'];
      selectedColor = skinLibrary[prefs.getString('selectedSkin') ?? 'orange']!;
      isMuted = prefs.getBool('muted') ?? false;
    });
  }

  void _buySkin(String name) async {
    final prefs = await SharedPreferences.getInstance();
    if (unlockedSkins.contains(name)) {
      setState(() => selectedColor = skinLibrary[name]!);
      await prefs.setString('selectedSkin', name);
    } else if (totalPoints >= 500) {
      setState(() {
        totalPoints -= 500;
        unlockedSkins.add(name);
        selectedColor = skinLibrary[name]!;
      });
      await prefs.setInt('totalPoints', totalPoints);
      await prefs.setStringList('unlockedSkins', unlockedSkins);
      await prefs.setString('selectedSkin', name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("SNAKE PRO", style: TextStyle(color: Colors.orangeAccent, fontSize: 60, fontWeight: FontWeight.bold)),
              Text("💰 Points: $totalPoints", style: const TextStyle(color: Colors.amber, fontSize: 20)),
              const SizedBox(height: 20),
              
              // قسم اختيار الخريطة
              const Text("SELECT MAP"),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _mapBtn('Forest', 'assets/forest.png'),
                _mapBtn('Desert', 'assets/desert.jpg'),
                _mapBtn('Snow', 'assets/snow.jpg'),
              ]),
              
              const SizedBox(height: 20),
              // متجر الجلود
              const Text("SKINS SHOP (500 pts each)"),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: skinLibrary.keys.map((name) => _skinCircle(name)).toList()),
              
              const SizedBox(height: 30),
              // التحكم بالصوت
              IconButton(
                icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up, size: 40),
                onPressed: () async {
                  setState(() => isMuted = !isMuted);
                  (await SharedPreferences.getInstance()).setBool('muted', isMuted);
                },
              ),

              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 20), shape: const StadiumBorder()),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => SnakeIoPro(
                  color: selectedColor, map: selectedMap, isMuted: isMuted,
                ))).then((_) => _loadData()),
                child: const Text("PLAY", style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold)),
              ),
              
              TextButton(
                onPressed: () => _showLeaderboard(),
                child: const Text("Global Leaderboard", style: TextStyle(color: Colors.white70)),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _mapBtn(String name, String path) => Padding(
    padding: const EdgeInsets.all(8.0),
    child: ChoiceChip(label: Text(name), selected: selectedMap == path, onSelected: (s) => setState(() => selectedMap = path)),
  );

  Widget _skinCircle(String name) {
    bool unlocked = unlockedSkins.contains(name);
    return GestureDetector(
      onTap: () => _buySkin(name),
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selectedColor == skinLibrary[name] ? Colors.white : Colors.transparent, width: 3)),
        child: CircleAvatar(backgroundColor: skinLibrary[name], radius: 20, child: unlocked ? null : const Icon(Icons.lock, size: 15, color: Colors.white)),
      ),
    );
  }

  void _showLeaderboard() {
    showModalBottomSheet(context: context, builder: (c) => StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('leaderboard').orderBy('score', descending: true).limit(10).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return ListView(children: snap.data!.docs.map((d) => ListTile(title: Text(d['name']), trailing: Text("${d['score']} pts"))).toList());
      },
    ));
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
  final List<Color> botColors = [Colors.blue, Colors.red, Colors.purple, Colors.green, Colors.yellow];

  @override
  void initState() {
    super.initState();
    player = Snake(startPos: const Offset(2500, 2500), skinColor: widget.color);
    // توليد بوتات بألوان عشوائية
    bots = List.generate(15, (i) => Snake(
      startPos: Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize),
      skinColor: botColors[Random().nextInt(botColors.length)]
    ));
    food = List.generate(200, (i) => Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize));
    
    _loadAssets();
    if (!widget.isMuted) _playMusic();
    gameLoop = Timer.periodic(const Duration(milliseconds: 16), (t) => updateGame());
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

    final dBg = await DefaultAssetBundle.of(context).load(widget.map);
    final cBg = await ui.instantiateImageCodec(dBg.buffer.asUint8List());
    bg = (await cBg.getNextFrame()).image;
    if (mounted) setState(() {});
  }

  void updateGame() {
    if (!mounted) return;
    setState(() {
      double diff = player.targetAngle - player.angle;
      while (diff < -pi) diff += 2 * pi;
      while (diff > pi) diff -= 2 * pi;
      player.angle += diff * 0.15;

      _move(player);
      _checkFood(player);

      for (var b in bots) {
        if (Random().nextInt(100) < 5) b.angle += (Random().nextDouble() - 0.5);
        _move(b);
        _checkFood(b);
        if ((player.body.first - b.body.first).distance < 45) _end();
      }
    });
  }

  void _move(Snake s) {
    // تم تخفيف السرعة هنا (4.0 للمشي الطبيعي و 8.0 للسرعة)
    double spd = (s.isBoosting ? 8.0 : 4.0); 
    Offset next = Offset((s.body.first.dx + cos(s.angle)*spd).clamp(0, worldSize), (s.body.first.dy + sin(s.angle)*spd).clamp(0, worldSize));
    s.body.insert(0, next);
    s.angles.insert(0, s.angle);
    if (s.body.length > s.length) { s.body.removeLast(); s.angles.removeLast(); }
  }

  void _checkFood(Snake s) {
    food.removeWhere((f) {
      if ((f - s.body.first).distance < 60) {
        s.length += 5;
        if (s == player && !widget.isMuted) fxPlayer.play(AssetSource('audio/eat.mp3'));
        return true;
      }
      return false;
    });
    if (food.length < 200) food.add(Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize));
  }

  void _end() async {
    gameLoop?.cancel(); bgPlayer.stop();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('totalPoints', (prefs.getInt('totalPoints') ?? 0) + player.length);
    
    // رفع النتيجة لـ Firebase
    FirebaseFirestore.instance.collection('leaderboard').add({
      'name': 'Player_${Random().nextInt(100)}',
      'score': player.length,
    });

    if (!widget.isMuted) await fxPlayer.play(AssetSource('audio/die.wav'));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    Size s = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          CustomPaint(size: Size.infinite, painter: GamePainter(player: player, bots: bots, food: food, sz: s, head: head, body: body, bg: bg, worldSize: worldSize)),
          // أزرار التحكم
          Positioned(bottom: 50, left: 50, child: _boostBtn()),
          Positioned(bottom: 50, right: 50, child: _controls()),
          Positioned(top: 40, left: 20, child: Text("Length: ${player.length}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _boostBtn() => GestureDetector(
    onTapDown: (_) => setState(() => player.isBoosting = true), 
    onTapUp: (_) => setState(() => player.isBoosting = false), 
    child: CircleAvatar(radius: 35, backgroundColor: Colors.orange.withOpacity(0.6), child: const Icon(Icons.bolt, color: Colors.white, size: 40))
  );

  Widget _controls() => Column(children: [
    _btn(Icons.arrow_upward, -pi/2),
    Row(children: [_btn(Icons.arrow_back, pi), const SizedBox(width: 40), _btn(Icons.arrow_forward, 0)]),
    _btn(Icons.arrow_downward, pi/2)
  ]);

  Widget _btn(IconData i, double a) => GestureDetector(onTap: () => setState(() => player.targetAngle = a), child: Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: Icon(i, color: Colors.white, size: 35)));

  @override
  void dispose() { gameLoop?.cancel(); bgPlayer.dispose(); fxPlayer.dispose(); super.dispose(); }
}

class GamePainter extends CustomPainter {
  final Snake player; final List<Snake> bots; final List<Offset> food; final Size sz; final ui.Image? head, body, bg; final double worldSize;
  GamePainter({required this.player, required this.bots, required this.food, required this.sz, this.head, this.body, this.bg, required this.worldSize});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(sz.width / 2 - player.body.first.dx, sz.height / 2 - player.body.first.dy);
    
    // رسم الخلفية المختارة (غابة، صحراء، ثلج)
    if (bg != null) {
      canvas.drawImageRect(bg!, Rect.fromLTWH(0, 0, bg!.width.toDouble(), bg!.height.toDouble()), Rect.fromLTWH(0, 0, worldSize, worldSize), Paint());
    }

    for (var f in food) canvas.drawCircle(f, 12, Paint()..color = Colors.yellowAccent);
    if (head != null && body != null) {
      for (var b in bots) _drawSnake(canvas, b, b.skinColor);
      _drawSnake(canvas, player, player.skinColor);
    }
  }

  void _drawSnake(Canvas canvas, Snake s, Color? filter) {
    int gap = 3; 
    for (int i = s.body.length - 1; i >= 0; i--) {
      if (i % gap != 0 && i != 0) continue;
      canvas.save(); canvas.translate(s.body[i].dx, s.body[i].dy); canvas.rotate(s.angles[i] + pi/2);
      Paint p = Paint();
      if (filter != null) p.colorFilter = ColorFilter.mode(filter, BlendMode.modulate);
      paintImage(canvas: canvas, rect: Rect.fromCenter(center: Offset.zero, width: i==0?80:60, height: i==0?80:60), image: i==0?head!:body!, colorFilter: p.colorFilter);
      canvas.restore();
    }
  }
  @override bool shouldRepaint(covariant CustomPainter old) => true;
}
