import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // 1. استيراد المكتبة

void main() {
  // تهيئة الإعلانات قبل تشغيل التطبيق
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  
  runApp(MaterialApp(home: SnakeIoPro(), debugShowCheckedModeBanner: false));
}

// ... كلاس Snake يبقى كما هو بدون تغيير ...

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
  
  // 2. تعريف متغير الإعلان
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  final List<String> botNames = ["Dragon", "Killer", "Alpha", "Shadow", "Neon", "Hunter", "Zoro", "Speedy", "Titan", "Viper"];

  @override
  void initState() {
    super.initState();
    _loadBannerAd(); // تحميل الإعلان عند البدء
    
    player = Snake(name: "You", startPos: Offset(1500, 1500), color: Colors.cyanAccent);
   
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

  // دالة تحميل الإعلان
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // معرف تجريبي
      request: AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() { _isBannerAdReady = true; });
        },
        onAdFailedToLoad: (ad, err) {
          print('فشل تحميل الإعلان: ${err.message}');
          ad.dispose();
        },
      ),
    );
    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose(); // تنظيف الذاكرة
    gameLoop?.cancel();
    super.dispose();
  }

  // ... الدوال الأخرى (updateGame, moveSnake, إلخ) تبقى كما هي ...

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // ... إعدادات التحكم باللمس ...
        child: Stack(
          children: [
            CustomPaint(
              size: Size.infinite,
              painter: WorldPainter(player: player, bots: bots, food: food, screenSize: screenSize),
            ),
            
            // لوحة الصدارة
            Positioned(
              top: 40, right: 20,
              child: Container( /* ... كود اللوحة ... */ ),
            ),

            // معلومات اللاعب
            Positioned(bottom: 80, left: 20, child: Text("الطول: ${player.length}", style: TextStyle(color: Colors.white, fontSize: 18))),

            // 3. عرض إعلان البنر في الأسفل
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
      ),
    );
  }
}

// ... كلاس WorldPainter يبقى كما هو بدون تغيير ...
