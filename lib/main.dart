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
      title: 'Snake Game',
      theme: ThemeData.dark(),
      home: const GameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const int gridSize = 20;
  late List<List<int>> snake;
  late List<int> food;
  String direction = 'RIGHT';
  String nextDirection = 'RIGHT';
  bool isPlaying = false;
  int score = 0;
  Timer? gameTimer;
  final Random random = Random();

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  void _initializeGame() {
    // بداية آمنة للثعبان - في منتصف اللوحة
    snake = [
      [gridSize ~/ 2, gridSize ~/ 2],
      [gridSize ~/ 2 - 1, gridSize ~/ 2],
      [gridSize ~/ 2 - 2, gridSize ~/ 2]
    ];
    direction = 'RIGHT';
    nextDirection = 'RIGHT';
    score = 0;
    isPlaying = true;
    _generateFood();
    _startTimer();
  }

  void _startTimer() {
    gameTimer?.cancel();
    gameTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (isPlaying && mounted) {
        _moveSnake();
        setState(() {});
      }
    });
  }

  void _generateFood() {
    List<List<int>> availablePositions = [];
    
    // ابحث عن جميع المواقع الفارغة
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        bool isOccupied = false;
        for (var segment in snake) {
          if (segment[0] == i && segment[1] == j) {
            isOccupied = true;
            break;
          }
        }
        if (!isOccupied) {
          availablePositions.add([i, j]);
        }
      }
    }
    
    if (availablePositions.isEmpty) {
      // اللاعب فاز!
      _gameOver();
      return;
    }
    
    int randomIndex = random.nextInt(availablePositions.length);
    food = availablePositions[randomIndex];
  }

  void _moveSnake() {
    if (!isPlaying) return;
    
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
    
    // التحقق من التصادم مع الجدار
    if (newHead[0] < 0 || newHead[0] >= gridSize || newHead[1] < 0 || newHead[1] >= gridSize) {
      _gameOver();
      return;
    }
    
    // التحقق من أكل الطعام
    bool ateFood = (newHead[0] == food[0] && newHead[1] == food[1]);
    
    // إضافة الرأس الجديد
    snake.insert(0, newHead);
    
    if (ateFood) {
      score++;
      _generateFood();
    } else {
      snake.removeLast();
    }
    
    // التحقق من التصادم مع الذات (تجاهل الرأس الجديد)
    for (int i = 1; i < snake.length; i++) {
      if (snake[i][0] == snake[0][0] && snake[i][1] == snake[0][1]) {
        _gameOver();
        return;
      }
    }
  }

  void _gameOver() {
    if (!isPlaying) return;
    
    isPlaying = false;
    gameTimer?.cancel();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over!'),
        content: Text('Your score: $score\nPlay again?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initializeGame();
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

  void _resetGame() {
    _initializeGame();
    setState(() {});
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
                  'Snake Game',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  'Score: $score',
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
              child: Container(
                padding: const EdgeInsets.all(20),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridSize,
                    childAspectRatio: 1,
                  ),
                  itemCount: gridSize * gridSize,
                  itemBuilder: (context, index) {
                    int x = index % gridSize;
                    int y = index ~/ gridSize;
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
          ),
          
          // أزرار التحكم
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade900,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [_buildControlButton('↑', 'UP')],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildControlButton('←', 'LEFT'),
                    const SizedBox(width: 50),
                    _buildControlButton('→', 'RIGHT'),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [_buildControlButton('↓', 'DOWN')],
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

  Widget _buildControlButton(String icon, String dir) {
    return Container(
      margin: const EdgeInsets.all(5),
      child: ElevatedButton(
        onPressed: isPlaying ? () => _changeDirection(dir) : null,
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