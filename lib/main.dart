import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(MaterialApp(home: SnakeIoPro(), debugShowCheckedModeBanner: false));
}

// كلاس الثعبان
class Snake {
  String name;
  List<Offset> body = [];
  double angle = 0.0;
  Color color;
  int length = 20;
  bool isTurbo = false;

  Snake({required this.name, required Offset startPos, required this.color}) {
    body = [startPos];
    angle = Random().nextDouble() * 2 * pi;
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
  final double worldSize = 3000.0;
  Timer? gameLoop;
  List<Snake> leaderBoard = [];

  // متغيرات الإعلانات
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  RewardedAd? _rewardedAd;

  final List<String> botNames = ["Dragon", "Killer", "Alpha", "Shadow", "Neon", "Hunter", "Zoro", "Speedy", "Titan", "Viper"];

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _loadRewardedAd();
    _initGame();
  }

  void _initGame() {
    player = Snake(name: "You", startPos: Offset(1500, 1500), color: Colors.cyanAccent);
    bots = List.generate(10, (i) => Snake(
      name: botNames[i % botNames.length] + " ${Random().nextInt(99)}",
      startPos: Offset(Random().nextDouble() * worldSize, Random().nextDouble() * worldSize),
      color: Colors.primaries[Random().nextInt(Colors.primaries.length)],
    ));
    food = List.generate(200, (i) => Offset(Random().nextDouble() * worldSize, Random().nextDouble() * worldSize));
    gameLoop = Timer.periodic(Duration(milliseconds: 16), (t) => updateGame());
  }

  // تحميل إعلان البنر
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // تجريبي
      request: AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerAdReady = true),
        onAdFailedToLoad: (ad, err) => ad.dispose(),
      ),
    )..load();
  }

  // تحميل إعلان الفيديو
  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917', // تجريبي
      request: AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => setState(() => _rewardedAd = ad),
        onAdFailedToLoad: (err) => _rewardedAd = null,
      ),
    );
  }

  void updateGame() {
    if (!mounted) return;
    setState(() {
      moveSnake(player);
      for (var bot in bots) moveSnake(bot);
      
      // التحقق من الاصطدام (بسيط)
      for (var bot in bots) {
        if ((player.body.first - bot.body.first).distance < 20) {
          _gameOver();
          break;
        }
      }
    });
  }

  void moveSnake(Snake s) {
    double speed = s.isTurbo ? 8.0 : 4.0;
    Offset newHead = Offset(
      (s.body.first.dx + cos(s.angle) * speed).clamp(0, worldSize),
      (s.body.first.dy + sin(s.angle) * speed).clamp(0, worldSize),
    );
    s.body.insert(0, newHead);
    if (s.body.length > s.length) s.body.removeLast();
  }

  void _gameOver() {
    gameLoop?.cancel();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text("انتهت اللعبة!", style: TextStyle(color: Colors.white)),
        actions: [
          if (_rewardedAd != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
                  setState(() {
                    player.length = 20;
                    gameLoop = Timer.periodic(Duration(milliseconds: 16), (t) => updateGame());
                  });
                  _loadRewardedAd();
                });
              },
              child: Text("🎥 فيديو للعودة"),
            ),
          TextButton(
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => SnakeIoPro())),
            child: Text("إعادة"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onPanUpdate: (d) => setState(() {
              player.angle = atan2(d.localPosition.dy - screenSize.height/2, d.localPosition.dx - screenSize.width/2);
            }),
            child: CustomPaint(
              size: Size.infinite,
              painter: WorldPainter(player: player, bots: bots, food: food, screenSize: screenSize),
            ),
          ),
          if (_isBannerAdReady)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _rewardedAd?.dispose();
    gameLoop?.cancel();
    super.dispose();
  }
}

// كلاس الرسام
class WorldPainter extends CustomPainter {
  final Snake player;
  final List<Snake> bots;
  final List<Offset> food;
  final Size screenSize;

  WorldPainter({required this.player, required this.bots, required this.food, required this.screenSize});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(screenSize.width/2 - player.body.first.dx, screenSize.height/2 - player.body.first.dy);
    for (var f in food) canvas.drawCircle(f, 6, Paint()..color = Colors.amberAccent);
    for (var bot in bots) _drawSnake(canvas, bot);
    _drawSnake(canvas, player);
  }

  void _drawSnake(Canvas canvas, Snake s) {
    if (s.body.isEmpty) return;
    Paint p = Paint()..color = s.color..strokeWidth = 20..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    Path path = Path()..moveTo(s.body.first.dx, s.body.first.dy);
    for (var i = 0; i < s.body.length; i += 2) path.lineTo(s.body[i].dx, s.body[i].dy);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
