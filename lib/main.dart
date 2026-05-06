import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(home: StartScreen(), debugShowCheckedModeBanner: false, theme: ThemeData.dark()));
}

class SnakeSkin {
  final String id; final String name; final Color color; final int price;
  SnakeSkin({required this.id, required this.name, required this.color, required this.price});
}

class Snake {
  List<Offset> body = []; List<double> angles = [];
  double angle = 0.0; int length; Color color; bool isBoosting = false;
  Snake({required Offset startPos, required this.color, this.length = 60}) {
    body = List.generate(length, (i) => startPos);
    angles = List.generate(length, (i) => 0.0);
  }
}

class StartScreen extends StatefulWidget {
  @override _StartScreenState createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  int totalPoints = 0;
  String selectedSkinId = 'orange';
  List<String> unlockedSkins = ['orange'];

  final List<SnakeSkin> shopSkins = [
    SnakeSkin(id: 'orange', name: 'Classic', color: Colors.orange, price: 0),
    SnakeSkin(id: 'blue', name: 'Ocean', color: Colors.blue, price: 200),
    SnakeSkin(id: 'green', name: 'Forest', color: Colors.green, price: 500),
    SnakeSkin(id: 'purple', name: 'Royal', color: Colors.purple, price: 800),
    SnakeSkin(id: 'red', name: 'Fire', color: Colors.red, price: 1200),
  ];

  @override void initState() { super.initState(); _loadData(); }

  _loadData() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      totalPoints = p.getInt('totalPoints') ?? 0;
      unlockedSkins = p.getStringList('unlockedSkins') ?? ['orange'];
      selectedSkinId = p.getString('selectedSkinId') ?? 'orange';
    });
  }

  void _openShop() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(builder: (context, setShopState) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text("SHOP", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.orange)),
              Text("Balance: $totalPoints 💰", style: const TextStyle(fontSize: 18, color: Colors.amber)),
              const Divider(color: Colors.white24, height: 30),
              Expanded(
                child: ListView.builder(
                  itemCount: shopSkins.length,
                  itemBuilder: (context, index) {
                    final skin = shopSkins[index];
                    bool isUnlocked = unlockedSkins.contains(skin.id);
                    bool isSelected = selectedSkinId == skin.id;
                    return Card(
                      color: isSelected ? Colors.orange.withOpacity(0.1) : Colors.white10,
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: skin.color, radius: 15),
                        title: Text(skin.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: _buildShopBtn(skin, isUnlocked, isSelected, setShopState),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildShopBtn(SnakeSkin skin, bool isUnlocked, bool isSelected, Function setState) {
    if (isSelected) return const Text("SELECTED", style: TextStyle(color: Colors.green));
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: isUnlocked ? Colors.blueGrey : Colors.orange),
      onPressed: () async {
        final p = await SharedPreferences.getInstance();
        if (isUnlocked) {
          await p.setString('selectedSkinId', skin.id);
          _loadData(); Navigator.pop(context);
        } else if (totalPoints >= skin.price) {
          totalPoints -= skin.price; unlockedSkins.add(skin.id);
          await p.setInt('totalPoints', totalPoints);
          await p.setStringList('unlockedSkins', unlockedSkins);
          setState(() {}); _loadData();
        }
      },
      child: Text(isUnlocked ? "EQUIP" : "BUY"),
    );
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("SNAKE", style: TextStyle(color: Colors.orange, fontSize: 80, fontWeight: FontWeight.bold)),
            Text("💰 Points: $totalPoints", style: const TextStyle(fontSize: 22, color: Colors.amber)),
            const SizedBox(height: 50),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 20)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => SnakeIoPro(color: shopSkins.firstWhere((s) => s.id == selectedSkinId).color))).then((_) => _loadData()),
              child: const Text("PLAY", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(height: 20),
            IconButton(icon: const Icon(Icons.shopping_cart, size: 40, color: Colors.orange), onPressed: _openShop),
          ],
        ),
      ),
    );
  }
}

class SnakeIoPro extends StatefulWidget {
  final Color color;
  SnakeIoPro({required this.color});
  @override _SnakeIoProState createState() => _SnakeIoProState();
}

class _SnakeIoProState extends State<SnakeIoPro> {
  late Snake player; List<Snake> bots = []; List<Offset> food = [];
  final double worldSize = 8000.0; Timer? gameLoop;
  ui.Image? headImg, bodyImg, tailImg, bgImg;
  final AudioPlayer fxPlayer = AudioPlayer();

  @override void initState() {
    super.initState();
    player = Snake(startPos: const Offset(4000, 4000), color: widget.color);
    bots = List.generate(15, (i) => Snake(startPos: Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize), color: Colors.accents[i % Colors.accents.length]));
    food = List.generate(200, (i) => Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize));
    _loadAssets();
    gameLoop = Timer.periodic(const Duration(milliseconds: 16), (t) => _update());
  }

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
      _move(player);
      for (var b in bots) {
        if (food.isNotEmpty) {
          Offset t = food.first; b.angle = atan2(t.dy - b.body.first.dy, t.dx - b.body.first.dx);
        }
        _move(b);
        if ((player.body.first - b.body.first).distance < 50) _gameOver();
      }
      _checkFood();
    });
  }

  void _move(Snake s) {
    double spd = s.isBoosting ? 10.0 : 5.0;
    Offset n = Offset((s.body.first.dx + cos(s.angle)*spd).clamp(0, worldSize), (s.body.first.dy + sin(s.angle)*spd).clamp(0, worldSize));
    s.body.insert(0, n); s.angles.insert(0, s.angle);
    if (s.body.length > s.length) { s.body.removeLast(); s.angles.removeLast(); }
  }

  void _checkFood() {
    food.removeWhere((f) {
      if ((f - player.body.first).distance < 60) {
        player.length += 3;
        fxPlayer.play(AssetSource('audio/eat.mp3'), mode: PlayerMode.lowLatency);
        return true;
      } return false;
    });
    if (food.length < 200) food.add(Offset(Random().nextDouble()*worldSize, Random().nextDouble()*worldSize));
  }

  _gameOver() async {
    gameLoop?.cancel();
    final p = await SharedPreferences.getInstance();
    await p.setInt('totalPoints', (p.getInt('totalPoints') ?? 0) + (player.length ~/ 2));
    Navigator.pop(context);
  }

  @override Widget build(BuildContext context) {
    Size s = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(children: [
        CustomPaint(size: Size.infinite, painter: GamePainter(player: player, bots: bots, food: food, sz: s, head: headImg, body: bodyImg, tail: tailImg, bg: bgImg, worldSize: worldSize)),
        Positioned(bottom: 40, left: 30, child: Column(children: [_btn(Icons.arrow_upward, -pi/2), Row(children: [_btn(Icons.arrow_back, pi), const SizedBox(width: 30), _btn(Icons.arrow_forward, 0)]), _btn(Icons.arrow_downward, pi/2)])),
        Positioned(bottom: 50, right: 30, child: GestureDetector(onLongPress: () => setState(() => player.isBoosting = true), onLongPressEnd: (_) => setState(() => player.isBoosting = false), child: FloatingActionButton(onPressed: (){}, backgroundColor: Colors.orange, child: const Icon(Icons.bolt)))),
      ]),
    );
  }

  Widget _btn(IconData i, double a) => GestureDetector(onTap: () => setState(() => player.angle = a), child: Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: Icon(i, color: Colors.white, size: 30)));
}

class GamePainter extends CustomPainter {
  final Snake player; final List<Snake> bots; final List<Offset> food; final Size sz;
  final ui.Image? head, body, tail, bg; final double worldSize;
  GamePainter({required this.player, required this.bots, required this.food, required this.sz, this.head, this.body, this.tail, this.bg, required this.worldSize});

  @override void paint(Canvas canvas, Size size) {
    canvas.translate(sz.width / 2 - player.body.first.dx, sz.height / 2 - player.body.first.dy);
    if (bg != null) canvas.drawImageRect(bg!, Rect.fromLTWH(0,0, bg!.width.toDouble(), bg!.height.toDouble()), Rect.fromLTWH(0,0, worldSize, worldSize), Paint());
    for (var f in food) canvas.drawCircle(f, 15, Paint()..color = Colors.yellowAccent);
    for (var b in bots) _draw(canvas, b, null);
    _draw(canvas, player, player.color);
  }

  void _draw(Canvas canvas, Snake s, Color? t) {
    if (head == null || body == null) return;
    int gap = 5;
    for (int i = 0; i < s.body.length; i++) {
      if (i % gap != 0 && i != 0 && i != s.body.length - 1) continue;
      canvas.save(); canvas.translate(s.body[i].dx, s.body[i].dy); canvas.rotate(s.angles[i] + pi/2);
      ui.Image img = (i == 0) ? head! : (i == s.body.length - 1 ? (tail ?? body!) : body!);
      Paint p = Paint(); if (t != null) p.colorFilter = ColorFilter.mode(t, BlendMode.modulate);
      paintImage(canvas: canvas, rect: Rect.fromCenter(center: Offset.zero, width: i==0?90:70, height: i==0?90:70), image: img, colorFilter: p.colorFilter);
      canvas.restore();
    }
  }
  @override bool shouldRepaint(CustomPainter old) => true;
}
