import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snake.io',
      theme: ThemeData.dark(),
      home: const SnakeIOStyle(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SnakeIOStyle extends StatefulWidget {
  const SnakeIOStyle({super.key});

  @override
  State<SnakeIOStyle> createState() => _SnakeIOStyleState();
}

class _SnakeIOStyleState extends State<SnakeIOStyle> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  // أجزاء الثعبان (دوائر)
  List<Offset> snakeParts = [];
  List<Offset> foodItems = [];
  
  Offset? targetDirection;
  Offset currentDirection = const Offset(1, 0);
  
  double snakeRadius = 12.0;
  int score = 0;
  
  bool isGameRunning = true;
  bool isGameOver = false;
  
  final Random random = Random();
  late Size screenSize;
  
  double currentSpeed = 3.0;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(() {
      if (isGameRunning && mounted) {
        _updateGame();
        setState(() {});
      }
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      screenSize = MediaQuery.of(context).size;
      _startNewGame();
    });
  }
  
  void _startNewGame() {
    // بداية الثعبان في منتصف الشاشة
    snakeParts = [];
    Offset center = Offset(screenSize.width / 2, screenSize.height / 2);
    for (int i = 0; i < 20; i++) {
      snakeParts.add(center - Offset(i * snakeRadius * 1.2, 0));
    }
    
    currentDirection = const Offset(1, 0);
    targetDirection = null;
    score = 0;
    isGameRunning = true;
    isGameOver = false;
    currentSpeed = 3.0;
    
    _generateFood(50);
    
    _animationController.repeat();
  }
  
  void _generateFood(int count) {
    foodItems.clear();
    for (int i = 0; i < count; i++) {
      foodItems.add(Offset(
        random.nextDouble() * screenSize.width,
        random.nextDouble() * screenSize.height,
      ));
    }
  }
  
  void _updateGame() {
    if (!isGameRunning) return;
    
    // تحديث الاتجاه
    if (targetDirection != null) {
      currentDirection = targetDirection!;
      targetDirection = null;
    }
    
    // حساب موقع الرأس الجديد
    Offset newHead = snakeParts.first + currentDirection * currentSpeed;
    
    // الالتفاف حول الشاشة (ميزة Snake.io)
    if (newHead.dx < 0) newHead = Offset(screenSize.width, newHead.dy);
    if (newHead.dx > screenSize.width) newHead = Offset(0, newHead.dy);
    if (newHead.dy < 0) newHead = Offset(newHead.dx, screenSize.height);
    if (newHead.dy > screenSize.height) newHead = Offset(newHead.dx, 0);
    
    // إضافة الرأس الجديد
    snakeParts.insert(0, newHead);
    
    // التحقق من أكل الطعام
    bool ateFood = false;
    for (int i = 0; i < foodItems.length; i++) {
      if ((newHead - foodItems[i]).distance < snakeRadius) {
        foodItems.removeAt(i);
        score++;
        currentSpeed += 0.03;
        ateFood = true;
        break;
      }
    }
    
    if (ateFood) {
      foodItems.add(Offset(
        random.nextDouble() * screenSize.width,
        random.nextDouble() * screenSize.height,
      ));
    } else {
      snakeParts.removeLast();
    }
    
    // التحقق من التصادم مع الذات
    for (int i = 3; i < snakeParts.length; i++) {
      if ((snakeParts.first - snakeParts[i]).distance < snakeRadius) {
        _gameOver();
        return;
      }
    }
  }
  
  void _gameOver() {
    if (!isGameRunning) return;
    isGameRunning = false;
    isGameOver = true;
    _animationController.stop();
  }
  
  @override
  Widget build(BuildContext context) {
    screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // منطقة اللعب
          GestureDetector(
            onPanUpdate: (details) {
              double dx = details.delta.dx;
              double dy = details.delta.dy;
              if (dx.abs() > dy.abs()) {
                if (dx > 0) targetDirection = const Offset(1, 0);
                else targetDirection = const Offset(-1, 0);
              } else {
                if (dy > 0) targetDirection = const Offset(0, 1);
                else targetDirection = const Offset(0, -1);
              }
            },
            child: CustomPaint(
              painter: _SnakePainter(
                snakeParts: snakeParts,
                foodItems: foodItems,
                snakeRadius: snakeRadius,
              ),
              size: screenSize,
            ),
          ),
          
          // شريط النقاط
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SNAKE.IO',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.green.shade900,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Score: $score',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // رسالة Game Over
          if (isGameOver)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'GAME OVER',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Score: $score',
                      style: const TextStyle(fontSize: 24, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        _startNewGame();
                        setState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      ),
                      child: const Text('PLAY AGAIN', style: TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
              ),
            ),
          
          // تعليمات السحب
          if (isGameRunning && !isGameOver)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(10),
                child: const Text(
                  '👆 Swipe anywhere to control snake direction',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

// رسم اللعبة
class _SnakePainter extends CustomPainter {
  final List<Offset> snakeParts;
  final List<Offset> foodItems;
  final double snakeRadius;
  
  _SnakePainter({
    required this.snakeParts,
    required this.foodItems,
    required this.snakeRadius,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // رسم الطعام (نقاط صغيرة ذهبية)
    final foodPaint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.fill;
    
    for (Offset food in foodItems) {
      canvas.drawCircle(food, 5, foodPaint);
      // تأثير توهج
      final glowPaint = Paint()
        ..color = Colors.amber.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(food, 8, glowPaint);
    }
    
    // رسم الثعبان (دوائر متصلة)
    for (int i = 0; i < snakeParts.length; i++) {
      Offset part = snakeParts[i];
      
      // لون متدرج: الرأس فاتح، الذيل غامق
      double ratio = i / snakeParts.length;
      Color snakeColor = Color.lerp(Colors.lightGreen, Colors.green.shade900, ratio)!;
      
      final snakePaint = Paint()
        ..color = snakeColor
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(part, snakeRadius, snakePaint);
      
      // رسم العيون للرأس
      if (i == 0) {
        final eyeWhite = Paint()..color = Colors.white;
        final eyeBlack = Paint()..color = Colors.black;
        
        double eyeOffset = snakeRadius * 0.6;
        canvas.drawCircle(Offset(part.dx - eyeOffset, part.dy - eyeOffset), 4, eyeWhite);
        canvas.drawCircle(Offset(part.dx - eyeOffset, part.dy - eyeOffset), 2, eyeBlack);
        canvas.drawCircle(Offset(part.dx + eyeOffset, part.dy - eyeOffset), 4, eyeWhite);
        canvas.drawCircle(Offset(part.dx + eyeOffset, part.dy - eyeOffset), 2, eyeBlack);
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant _SnakePainter oldDelegate) {
    return oldDelegate.snakeParts != snakeParts || oldDelegate.foodItems != foodItems;
  }
}