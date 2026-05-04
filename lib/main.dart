import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(MaterialApp(home: StartScreen(), debugShowCheckedModeBanner: false));
}

// كلاس الجزيئات للتأثير البصري عند الأكل
class Particle {
  Offset position;
  Offset velocity;
  Color color;
  double life = 1.0; 
  Particle({required this.position, required this.velocity, required this.color});
  void update() {
    position += velocity;
    life -= 0.05;
  }
}

// كلاس الثعبان
class Snake {
  String name;
  List<Offset> body = [];
  double angle = 0.0;
  Color color;
  int length = 20;
  Snake({required this.name, required Offset startPos, required this.color}) {
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
  int highScore = 0;
  Color selectedColor = Colors.cyanAccent;
  bool isMuted = false;
  bool useArrows = false;

  @override
  void initState() {
    super.initState();
    _loadHighScore();
  }

  void _loadHighScore() async {
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
            Text("SNAKE IO PRO", style: TextStyle(color: Colors.white, fontSize: 35, fontWeight: FontWeight.bold)),
            Text("🏆 High Score: $highScore", style: TextStyle(color: Colors.amber, fontSize: 18)),
            SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _iconSetting("Sound", isMuted ? Icons.volume_off : Icons.volume_up, () => setState(() => isMuted = !isMuted)),
                SizedBox(width: 40),
                _iconSetting("Control", useArrows ? Icons.ads_click : Icons.touch_app, () => setState(() => useArrows = !useArrows)),
              ],
            ),
            SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: selectedColor, padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (c) => SnakeIoPro(color: selectedColor, isMuted: isMuted, highScore: highScore, useArrows: useArrows)
              )),
              child: Text("START GAME", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconSetting(String label, IconData icon, VoidCallback onTap) {
    return Column(children: [
      Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
      IconButton(icon: Icon(icon, color: Colors.white), onPressed: onTap),
    ]);
  }
}

// شاشة اللعبة الرئيسية
class SnakeIoPro extends StatefulWidget {
  final Color color;
  final bool isMuted;
  final int highScore;
  final bool useArrows;
  SnakeIoPro({required this.color, required this.isMuted, required this.highScore, required this.useArrows});

  @override
  _SnakeIoProState createState() => _SnakeIoProState();
}

class _SnakeIoProState extends State<SnakeIoPro> {
  late Snake player;
  List<Snake> bots = [];
  List<Offset> food = [];
  List<Particle> particles = [];
  final double worldSize = 3000.0;
  Timer? gameLoop;
  final AudioPlayer bgMusicPlayer = AudioPlayer();
  final AudioPlayer effectPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    player = Snake(name: "You", startPos: Offset(1500, 1500), color: widget.color);
    _initBots();
    food = List.generate(150, (i) => Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize));
    gameLoop = Timer.periodic(Duration(milliseconds: 16), (t) => updateGame());
    if (!widget.isMuted) _playBackgroundMusic();
  }

  void _initBots() {
    bots = List.generate(6, (i) => Snake(name: "Bot", startPos: Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize), color: Colors.redAccent));
  }

  void _playBackgroundMusic() async {
    await bgMusicPlayer.setReleaseMode(ReleaseMode.loop);
    await bgMusicPlayer.play(AssetSource('audio/music.mp3'));
    await bgMusicPlayer.setVolume(0.3);
  }

  void updateGame() {
    if (!mounted) return;
    setState(() {
      moveSnake(player);
      checkFood(player);
      for (var p in particles) p.update();
      particles.removeWhere((p) => p.life <= 0);
      for (var bot in bots) {
        if (Random().nextInt(100) < 5) bot.angle += (Random().nextDouble() - 0.5);
        moveSnake(bot);
        checkFood(bot);
        if ((player.body.first - bot.body.first).distance < 25) _gameOver();
      }
    });
  }

  void moveSnake(Snake s) {
    Offset newHead = Offset((s.body.first.dx + cos(s.angle)*4).clamp(0, worldSize), (s.body.first.dy + sin(s.angle)*4).clamp(0, worldSize));
    s.body.insert(0, newHead);
    if (s.body.length > s.length) s.body.removeLast();
  }

  void checkFood(Snake s) {
    food.removeWhere((f) {
      if ((f - s.body.first).distance < 30) {
        s.length += 2;
        if (s == player) {
          _createExplosion(f, s.color);
          if (!widget.isMuted) effectPlayer.play(AssetSource('audio/eat.mp3'));
        }
        return true;
      }
      return false;
    });
    if (food.length < 150) food.add(Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize));
  }

  void _createExplosion(Offset pos, Color color) {
    for (int i = 0; i < 8; i++) {
      double angle = Random().nextDouble() * 2 * pi;
      particles.add(Particle(position: pos, velocity: Offset(cos(angle)*2, sin(angle)*2), color: color));
    }
  }

  void _gameOver() async {
    gameLoop?.cancel();
    if (!widget.isMuted) effectPlayer.play(AssetSource('audio/die.wav'));
    if (player.length > widget.highScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('highScore', player.length);
    }
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
      title: Text("Game Over"),
      actions: [TextButton(onPressed: () { bgMusicPlayer.stop(); Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => StartScreen())); }, child: Text("Menu"))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onPanUpdate: widget.useArrows ? null : (d) => setState(() {
              player.angle = atan2(d.localPosition.dy - screenSize.height/2, d.localPosition.dx - screenSize.width/2);
            }),
            child: CustomPaint(size: Size.infinite, painter: WorldPainter(player: player, bots: bots, food: food, particles: particles, screenSize: screenSize, worldSize: worldSize)),
          ),
          if (widget.useArrows) _buildArrows(),
          Positioned(top: 40, left: 20, child: Text("Score: ${player.length}", style: TextStyle(color: Colors.white, fontSize: 18))),
        ],
      ),
    );
  }

  Widget _buildArrows() {
    return Positioned(bottom: 40, right: 20, child: Column(children: [
      _arrowBtn(Icons.arrow_upward, -pi/2),
      Row(children: [_arrowBtn(Icons.arrow_back, pi), SizedBox(width: 40), _arrowBtn(Icons.arrow_forward, 0)]),
      _arrowBtn(Icons.arrow_downward, pi/2),
    ]));
  }

  Widget _arrowBtn(IconData icon, double angle) {
    return GestureDetector(
      onTap: () => setState(() => player.angle = angle),
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }

  @override
  void dispose() { bgMusicPlayer.dispose(); effectPlayer.dispose(); gameLoop?.cancel(); super.dispose(); }
}

// كلاس الرسام
class WorldPainter extends CustomPainter {
  final Snake player; final List<Snake> bots; final List<Offset> food; final List<Particle> particles; final Size screenSize; final double worldSize;
  WorldPainter({required this.player, required this.bots, required this.food, required this.particles, required this.screenSize, required this.worldSize});
  
  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(screenSize.width/2 - player.body.first.dx, screenSize.height/2 - player.body.first.dy);
    Paint gridPaint = Paint()..color = Colors.white.withOpacity(0.05);
    for (double i = 0; i <= worldSize; i += 100) { canvas.drawLine(Offset(i, 0), Offset(i, worldSize), gridPaint); canvas.drawLine(Offset(0, i), Offset(worldSize, i), gridPaint); }
    for (var f in food) canvas.drawCircle(f, 8, Paint()..color = Colors.amber);
    for (var p in particles) canvas.drawCircle(p.position, 3, Paint()..color = p.color.withOpacity(p.life));
    for (var bot in bots) _drawSnake(canvas, bot);
    _drawSnake(canvas, player);
  }

  void _drawSnake(Canvas canvas, Snake s) {
    Paint p = Paint()..color = s.color..strokeWidth = 22..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    Path path = Path()..moveTo(s.body.first.dx, s.body.first.dy);
    for (var i = 0; i < s.body.length; i += 2) path.lineTo(s.body[i].dx, s.body[i].dy);
    canvas.drawPath(path, p);
    canvas.drawCircle(s.body.first, 15, Paint()..color = s.color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
