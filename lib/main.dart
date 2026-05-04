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

// كلاس الجزيئات (الانفجار عند الأكل)
class Particle {
  Offset position; Offset velocity; Color color; double life = 1.0;
  Particle({required this.position, required this.velocity, required this.color});
  void update() { position += velocity; life -= 0.05; }
}

// كلاس الثعبان
class Snake {
  List<Offset> body = []; double angle = 0.0; Color color; int length = 20;
  Snake({required Offset startPos, required this.color}) {
    body = [startPos];
    angle = Random().nextDouble() * 2 * pi;
  }
}

// شاشة البداية
class StartScreen extends StatefulWidget {
  @override
  _StartScreenState createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  int highScore = 0; Color selectedColor = Colors.orangeAccent;
  bool isMuted = false; bool useArrows = false;

  @override
  void initState() { super.initState(); _loadData(); }
  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() { highScore = prefs.getInt('highScore') ?? 0; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("SNAKE IO PRO", style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
            Text("🏆 High Score: $highScore", style: TextStyle(color: Colors.amber, fontSize: 18)),
            SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _iconSetting("Sound", isMuted ? Icons.volume_off : Icons.volume_up, () => setState(() => isMuted = !isMuted)),
                SizedBox(width: 40),
                _iconSetting("Control", useArrows ? Icons.ads_click : Icons.touch_app, () => setState(() => useArrows = !useArrows)),
              ],
            ),
            SizedBox(height: 50),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: EdgeInsets.symmetric(horizontal: 60, vertical: 20)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (c) => SnakeIoPro(color: selectedColor, isMuted: isMuted, highScore: highScore, useArrows: useArrows)
              )),
              child: Text("PLAY NOW", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconSetting(String label, IconData icon, VoidCallback onTap) {
    return Column(children: [
      Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
      IconButton(icon: Icon(icon, color: Colors.white, size: 30), onPressed: onTap),
    ]);
  }
}

// شاشة اللعبة الأساسية
class SnakeIoPro extends StatefulWidget {
  final Color color; final bool isMuted; final int highScore; final bool useArrows;
  SnakeIoPro({required this.color, required this.isMuted, required this.highScore, required this.useArrows});
  @override
  _SnakeIoProState createState() => _SnakeIoProState();
}

class _SnakeIoProState extends State<SnakeIoPro> {
  late Snake player; List<Snake> bots = []; List<Offset> food = []; List<Particle> particles = [];
  final double worldSize = 3000.0; Timer? gameLoop;
  final AudioPlayer bgMusicPlayer = AudioPlayer(); final AudioPlayer effectPlayer = AudioPlayer();
  
  // متغيرات الصور والإعلانات والمستويات
  ui.Image? headImg; ui.Image? bodyImg; ui.Image? tailImg;
  InterstitialAd? _interstitialAd;
  int currentLevel = 1;
  String currentBg = 'assets/forest.png';

  @override
  void initState() {
    super.initState();
    player = Snake(startPos: Offset(1500, 1500), color: widget.color);
    bots = List.generate(5, (i) => Snake(startPos: Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize), color: Colors.redAccent));
    food = List.generate(150, (i) => Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize));
    
    _loadSnakeImages();
    _loadInterstitialAd();
    
    gameLoop = Timer.periodic(Duration(milliseconds: 16), (t) => updateGame());
    if (!widget.isMuted) _playBackgroundMusic();
  }

  // تحميل صور الثعبان
  Future<void> _loadSnakeImages() async {
    headImg = await _loadUiImage('assets/head.png');
    bodyImg = await _loadUiImage('assets/body.png');
    tailImg = await _loadUiImage('assets/tail.png');
    if(mounted) setState(() {});
  }

  Future<ui.Image> _loadUiImage(String path) async {
    final data = await DefaultAssetBundle.of(context).load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  // تحميل الإعلان البيني
  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712', // تجريبي
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (err) => _interstitialAd = null,
      ),
    );
  }

  void _playBackgroundMusic() async {
    await bgMusicPlayer.setReleaseMode(ReleaseMode.loop);
    await bgMusicPlayer.play(AssetSource('audio/music.mp3'));
    await bgMusicPlayer.setVolume(0.2);
  }

  void updateGame() {
    if (!mounted) return;
    setState(() {
      moveSnake(player); 
      checkFood(player);
      _checkLevelProgress();
      for (var p in particles) p.update();
      particles.removeWhere((p) => p.life <= 0);
      
      for (var bot in bots) {
        if (Random().nextInt(100) < 5) bot.angle += (Random().nextDouble() - 0.5);
        moveSnake(bot);
        checkFood(bot);
        if ((player.body.first - bot.body.first).distance < 30) _gameOver();
      }
    });
  }

  void _checkLevelProgress() {
    if (player.length > 50 && currentLevel == 1) {
      currentLevel = 2; currentBg = 'assets/desert.jpg';
    } else if (player.length > 100 && currentLevel == 2) {
      currentLevel = 3; currentBg = 'assets/snow.jpg';
    }
  }

  void moveSnake(Snake s) {
    double speed = 4.0 + (currentLevel * 0.5);
    Offset newHead = Offset((s.body.first.dx + cos(s.angle)*speed).clamp(0, worldSize), (s.body.first.dy + sin(s.angle)*speed).clamp(0, worldSize));
    s.body.insert(0, newHead);
    if (s.body.length > s.length) s.body.removeLast();
  }

  void checkFood(Snake s) {
    food.removeWhere((f) {
      if ((f - s.body.first).distance < 35) {
        s.length += 3;
        if (s == player) {
          _createExplosion(f, Colors.orange);
          if (!widget.isMuted) effectPlayer.play(AssetSource('audio/eat.mp3'));
        }
        return true;
      }
      return false;
    });
    if (food.length < 150) food.add(Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize));
  }

  void _createExplosion(Offset pos, Color color) {
    for (int i = 0; i < 10; i++) {
      double angle = Random().nextDouble() * 2 * pi;
      particles.add(Particle(position: pos, velocity: Offset(cos(angle)*3, sin(angle)*3), color: color));
    }
  }

  void _gameOver() {
    gameLoop?.cancel();
    if (!widget.isMuted) effectPlayer.play(AssetSource('audio/die.wav'));
    
    // إظهار الإعلان
    if (_interstitialAd != null) _interstitialAd!.show();

    if (player.length > widget.highScore) {
      SharedPreferences.getInstance().then((p) => p.setInt('highScore', player.length));
    }
    
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
      title: Text("GAME OVER"),
      content: Text("Level Reached: $currentLevel\nScore: ${player.length}"),
      actions: [TextButton(onPressed: () { bgMusicPlayer.stop(); Navigator.pop(context); Navigator.pop(context); }, child: Text("EXIT"))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    Size sz = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          // الخلفية المتغيرة حسب المستوى
          Positioned.fill(child: Image.asset(currentBg, fit: BoxFit.cover)),
          
          GestureDetector(
            onPanUpdate: widget.useArrows ? null : (d) => setState(() {
              player.angle = atan2(d.localPosition.dy - sz.height/2, d.localPosition.dx - sz.width/2);
            }),
            child: CustomPaint(
              size: Size.infinite, 
              painter: WorldPainter(
                player: player, bots: bots, food: food, particles: particles, 
                sz: sz, head: headImg, body: bodyImg, tail: tailImg
              )
            ),
          ),
          if (widget.useArrows) _buildArrows(),
          Positioned(top: 50, left: 20, child: Container(
            padding: EdgeInsets.all(8), color: Colors.black54,
            child: Text("Score: ${player.length} | Level: $currentLevel", style: TextStyle(color: Colors.white, fontSize: 16))
          )),
        ],
      ),
    );
  }

  Widget _buildArrows() {
    return Positioned(bottom: 50, right: 30, child: Column(children: [
      _arrowBtn(Icons.arrow_upward, -pi/2),
      Row(children: [_arrowBtn(Icons.arrow_back, pi), SizedBox(width: 40), _arrowBtn(Icons.arrow_forward, 0)]),
      _arrowBtn(Icons.arrow_downward, pi/2),
    ]));
  }

  Widget _arrowBtn(IconData icon, double angle) {
    return GestureDetector(
      onTap: () => setState(() => player.angle = angle),
      child: Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 35)),
    );
  }

  @override
  void dispose() { bgMusicPlayer.dispose(); effectPlayer.dispose(); gameLoop?.cancel(); _interstitialAd?.dispose(); super.dispose(); }
}

// الرسام المسؤول عن عرض صور الثعبان
class WorldPainter extends CustomPainter {
  final Snake player; final List<Snake> bots; final List<Offset> food;
  final List<Particle> particles; final Size sz;
  final ui.Image? head; final ui.Image? body; final ui.Image? tail;

  WorldPainter({required this.player, required this.bots, required this.food, required this.particles, required this.sz, this.head, this.body, this.tail});

  @override
  void paint(Canvas canvas, Size size) {
    Offset center = sz.center(Offset.zero);
    canvas.translate(center.dx - player.body.first.dx, center.dy - player.body.first.dy);

    // رسم الطعام
    for (var f in food) canvas.drawCircle(f, 8, Paint()..color = Colors.yellowAccent);

    // رسم البوتات
    for (var b in bots) {
      for (var pos in b.body) canvas.drawCircle(pos, 12, Paint()..color = b.color);
    }

    // رسم اللاعب بالصور
    if (head != null && body != null && tail != null) {
      for (int i = player.body.length - 1; i >= 0; i--) {
        canvas.save();
        canvas.translate(player.body[i].dx, player.body[i].dy);
        
        if (i == 0) {
          canvas.rotate(player.angle + pi/2);
          _drawImg(canvas, head!, 45);
        } else if (i == player.body.length - 1) {
          _drawImg(canvas, tail!, 35);
        } else if (i % 6 == 0) {
          _drawImg(canvas, body!, 32);
        }
        canvas.restore();
      }
    }

    for (var p in particles) canvas.drawCircle(p.position, 3, Paint()..color = p.color.withOpacity(p.life));
  }

  void _drawImg(Canvas canvas, ui.Image img, double size) {
    paintImage(canvas: canvas, rect: Rect.fromCenter(center: Offset.zero, width: size, height: size), image: img, fit: BoxFit.contain);
  }

  @override
  bool shouldRepaint(CustomPainter old) => true;
}
