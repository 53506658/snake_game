import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

void main() {
  runApp(const SnakeGame());
}

class SnakeGame extends StatelessWidget {
  const SnakeGame({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snake',
      theme: ThemeData.dark(),
      home: const SnakeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SnakeScreen extends StatefulWidget {
  const SnakeScreen({super.key});

  @override
  State<SnakeScreen> createState() => _SnakeScreenState();
}

class _SnakeScreenState extends State<SnakeScreen> {
  // إعدادات اللعبة
  static const int columns = 20;
  static const int rows = 35;
  
  List<List<int>> snake = [
    [10, 17],
    [9, 17],
    [8, 17],
    [7, 17]
  ];
  List<int> food = [15, 17];
  String direction = 'RIGHT';
  String nextDirection = 'RIGHT';
  bool isGameActive = true;
  int currentScore = 0;
  Timer? gameTimer;
  final Random random = Random();

  @override
  void initState() {
    super.initState();
    startGame();
  }

  void startGame() {
    // إعادة تعيين كل شيء
    snake = [
      [10, 17],
      [9, 17],
      [8, 17],
      [7, 17]
    ];
    direction = 'RIGHT';
    nextDirection = 'RIGHT';
    currentScore = 0;
    isGameActive = true;
    _generateFood();
    _startTimer();
  }

  void _startTimer() {
    gameTimer?.cancel();
    gameTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (isGameActive && mounted) {
        _moveSnake();
        setState(() {});
      }
    });
  }

  void _generateFood() {
    bool foodOnSnake = true;
    while (foodOnSnake) {
      food = [random.nextInt(columns), random.nextInt(rows)];
      foodOnSnake = false;
      for (var segment in snake) {
        if (segment[0] == food[0] && segment[1] == food[1]) {
          foodOnSnake = true;
          break;
        }
      }
    }
  }

  void _moveSnake() {
    if (!isGameActive) return;
    
    direction = nextDirection;
    List<int> newHead = List.from(snake.first);
    
    switch (direction) {
      case 'UP':
        newHead[1]--;
        break;
      case 'DOWN':
        newHead[1]++;
        break;
      case 'LEFT':
        newHead[0]--;
        break;
      case 'RIGHT':
        newHead[0]++;
        break;
    }
    
    // فحص حدود الشاشة
    if (newHead[0] < 0 || newHead[0] >= columns || newHead[1] < 0 || newHead[1] >= rows) {
      _endGame();
      return;
    }
    
    // فحص أكل الطعام
    bool ate = (newHead[0] == food[0] && newHead[1] == food[1]);
    
    // إضافة الرأس الجديد
    snake.insert(0, newHead);
    
    if (ate) {
      currentScore++;
      _generateFood();
    } else {
      snake.removeLast();
    }
    
    // فحص التصادم مع الذات
    for (int i = 1; i < snake.length; i++) {
      if (snake[i][0] == snake[0][0] && snake[i][1] == snake[0][1]) {
        _endGame();
        return;
      }
    }
  }

  void _endGame() {
    if (!isGameActive) return;
    isGameActive = false;
    gameTimer?.cancel();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over!'),
        content: Text('Your score: $currentScore\nPlay again?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              startGame();
              setState(() {});
            },
            child: const Text('Yes'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
        ],
      ),
    );
  }

  void _changeDirection(String newDirection) {
    if ((direction == 'UP' && newDirection == 'DOWN') ||
        (direction == 'DOWN' && newDirection == 'UP') ||
        (direction == 'LEFT' && newDirection == 'RIGHT') ||
        (direction == 'RIGHT' && newDirection == 'LEFT')) {
      return;
    }
    nextDirection = newDirection;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // شريط النقاط
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade900,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SNAKE',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  'Score: $currentScore',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
          
          // شبكة اللعبة
          Expanded(
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                if (details.delta.dy > 0) {
                  _changeDirection('DOWN');
                } else if (details.delta.dy < 0) {
                  _changeDirection('UP');
                }
              },
              onHorizontalDragUpdate: (details) {
                if (details.delta.dx > 0) {
                  _changeDirection('RIGHT');
                } else if (details.delta.dx < 0) {
                  _changeDirection('LEFT');
                }
              },
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  childAspectRatio: 1,
                ),
                itemCount: columns * rows,
                itemBuilder: (context, index) {
                  int x = index % columns;
                  int y = index ~/ columns;
                  
                  bool isSnake = false;
                  for (var segment in snake) {
                    if (segment[0] == x && segment[1] == y) {
                      isSnake = true;
                      break;
                    }
                  }
                  
                  bool isFood = (food[0] == x && food[1] == y);
                  
                  return Container(
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: isSnake
                          ? Colors.green
                          : (isFood ? Colors.red : Colors.grey.shade800),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                },
              ),
            ),
          ),
          
          // الأزرار
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade900,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [_buildButton('↑', 'UP')],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildButton('←', 'LEFT'),
                    const SizedBox(width: 50),
                    _buildButton('→', 'RIGHT'),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [_buildButton('↓', 'DOWN')],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Use arrows or swipe',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String icon, String dir) {
    return Container(
      margin: const EdgeInsets.all(5),
      child: ElevatedButton(
        onPressed: isGameActive ? () => _changeDirection(dir) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          minimumSize: const Size(60, 60),
        ),
        child: Text(
          icon,
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    super.dispose();
  }
}