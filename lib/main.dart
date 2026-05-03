
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() => runApp(MaterialApp(home: SnakeIoPro(), debugShowCheckedModeBanner: false));

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

  final List<String> botNames = ["Dragon", "Killer", "Alpha", "Shadow", "Neon", "Hunter", "Zoro", "Speedy", "Titan", "Viper"];

  @override
  void initState() {
    super.initState();
    player = Snake(name: "You", startPos: Offset(1500, 1500), color: Colors.cyanAccent);
   
    // إنشاء البوتات بأسماء عشوائية
    for (int i = 0; i < 12; i++) {
      bots.add(Snake(
        name: botNames[i % botNames.length] + " ${Random().nextInt(99)}",
        startPos: Offset(Random().nextDouble() * worldSize, Random().nextDouble() * worldSize),
        color: Colors.primaries[Random().nextInt(Colors.primaries.length)],
      ));
    }
    food = List.generate(200, (i) => Offset(Random().nextDouble() * worldSize, Random().nextDouble() * worldSize));
    gameLoop = Timer.periodic(Duration(milliseconds: 16), (t) => updateGame());
  }

  void updateGame() {
    if (!mounted) return;
    setState(() {
      handleTurbo(player);
      moveSnake(player);
      checkFood(player);

      for (var bot in bots) {
        if (Random().nextInt(200) < 2) bot.isTurbo = !bot.isTurbo;
        if (Random().nextInt(100) < 5) bot.angle += (Random().nextDouble() - 0.5);
        handleTurbo(bot);
        moveSnake(bot);
        checkFood(bot);
      }

      // تحديث لوحة الصدارة
      leaderBoard = [player, ...bots];
      leaderBoard.sort((a, b) => b.length.compareTo(a.length));

      // التحقق من التصادم
      for (var bot in bots) {
        for (var segment in bot.body.skip(10)) {
          if ((player.body.first - segment).distance < 15) {
            gameOver();
            return;
          }
        }
      }
    });
  }

  void handleTurbo(Snake s) {
    if (s.isTurbo && s.length > 10) {
      if (Random().nextInt(5) == 0) {
        s.length--;
        food.add(s.body.last);
      }
    }
  }

  void moveSnake(Snake s) {
    double currentSpeed = s.isTurbo ? 8.0 : 4.0;
    Offset newHead = Offset(
      (s.body.first.dx + cos(s.angle) * currentSpeed).clamp(0, worldSize),
      (s.body.first.dy + sin(s.angle) * currentSpeed).clamp(0, worldSize),
    );
    s.body.insert(0, newHead);
    if (s.body.length > s.length) s.body.removeLast();
  }

  void checkFood(Snake s) {
    food.removeWhere((f) {
      if ((f - s.body.first).distance < 25) {
        s.length += 2;
        return true;
      }
      return false;
    });
    if (food.length < 200) food.add(Offset(Random().nextDouble() * worldSize, Random().nextDouble() * worldSize));
  }

  void gameOver() {
    gameLoop?.cancel();
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Text("انتهت اللعبة!", style: TextStyle(color: Colors.white)),
      content: Text("ترتيبك كان: #${leaderBoard.indexOf(player) + 1}", style: TextStyle(color: Colors.white70)),
      actions: [TextButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => SnakeIoPro())), child: Text("إعادة المحاولة"))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) => player.isTurbo = true,
        onLongPressEnd: (_) => player.isTurbo = false,
        onPanUpdate: (details) {
          player.angle = atan2(details.localPosition.dy - screenSize.height/2, details.localPosition.dx - screenSize.width/2);
        },
        child: Stack(
          children: [
            CustomPaint(
              size: Size.infinite,
              painter: WorldPainter(player: player, bots: bots, food: food, screenSize: screenSize),
            ),
            // لوحة الصدارة
            Positioned(
              top: 40, right: 20,
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Leaderboard", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                    ...leaderBoard.take(5).map((s) => Text(
                      "${leaderBoard.indexOf(s) + 1}. ${s.name}: ${s.length}",
                      style: TextStyle(color: s == player ? Colors.cyanAccent : Colors.white, fontSize: 12),
                    )).toList(),
                  ],
                ),
              ),
            ),
            // معلومات اللاعب
            Positioned(bottom: 30, left: 20, child: Text("الطول: ${player.length}", style: TextStyle(color: Colors.white, fontSize: 18))),
          ],
        ),
      ),
    );
  }
}

class WorldPainter extends CustomPainter {
  final Snake player;
  final List<Snake> bots;
  final List<Offset> food;
  final Size screenSize;

  WorldPainter({required this.player, required this.bots, required this.food, required this.screenSize});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(screenSize.width/2 - player.body.first.dx, screenSize.height/2 - player.body.first.dy);

    // رسم خلفية الشبكة
    Paint gridPaint = Paint()..color = Colors.white.withOpacity(0.05)..style = PaintingStyle.stroke;
    for (double i = 0; i <= 3000; i += 150) {
      canvas.drawLine(Offset(i, 0), Offset(i, 3000), gridPaint);
      canvas.drawLine(Offset(0, i), Offset(3000, i), gridPaint);
    }

    for (var f in food) canvas.drawCircle(f, 6, Paint()..color = Colors.amberAccent);
    for (var bot in bots) drawSnake(canvas, bot);
    drawSnake(canvas, player);
  }

  void drawSnake(Canvas canvas, Snake s) {
    if (s.body.isEmpty) return;
    Paint p = Paint()..color = s.color..strokeWidth = 22..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
   
    Path path = Path()..moveTo(s.body.first.dx, s.body.first.dy);
    for (int i = 0; i < s.body.length; i += 2) path.lineTo(s.body[i].dx, s.body[i].dy);
    canvas.drawPath(path, p);

    // رسم اسم الثعبان فوق رأسه
    TextPainter(
      text: TextSpan(text: s.name, style: TextStyle(color: Colors.white, fontSize: 12)),
      textDirection: TextDirection.ltr,
    )..layout()..paint(canvas, Offset(s.body.first.dx - 20, s.body.first.dy - 35));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

