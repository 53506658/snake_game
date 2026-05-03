import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snake Game',
      theme: ThemeData.dark(),
      home: const SnakeHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SnakeHomePage extends StatefulWidget {
  const SnakeHomePage({super.key});

  @override
  State<SnakeHomePage> createState() => _SnakeHomePageState();
}

class _SnakeHomePageState extends State<SnakeHomePage> {
  static const int boardSize = 15;
  late List<List<int>> snake;
  late List<int> food;
  String currentDirection = 'RIGHT';
  String nextDirection = 'RIGHT';
  bool isGameRunning = true;
  int currentScore = 0;
  Timer? gameLoop;
  final Random randomGenerator = Random();

  @override
  void initState() {
    super.initState();
    startNewGame();
  }

  void startNewGame() {
    // بداية آمنة للثعبان
    snake = [
      [7, 7],
      [6, 7],
      [5, 7],
      [4, 7]
    ];
    currentDirection = 'RIGHT';
    nextDirection = 'RIGHT';
    currentScore = 0;
    isGameRunning = true;
    generateValidFood();
    startGameLoop();
  }

  void startGameLoop() {
    gameLoop?.cancel();
    gameLoop = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (isGameRunning && mounted) {
        moveSnake();
        setState(() {});
      }
    });
  }

  void generateValidFood() {
    List<List<int>> freeCells = [];
    
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        bool isOccupied = false;
        for (var segment in snake) {
          if (segment[0] == i && segment[1] == j) {
            isOccupied = true;
            break;
          }
        }
        if (!isOccupied) {
          freeCells.add([i, j]);
        }
      }
    }
    
    if (freeCells.isEmpty) {
      // اللاعب فاز!
      gameOver();
      return;
    }
    
    int randomIndex = randomGenerator.nextInt(freeCells.length);
    food = freeCells[randomIndex];
  }

  void moveSnake() {
    if (!isGameRunning) return;
    
    currentDirection = nextDirection;
    List<int> newHead = List.from(snake.first);
    
    switch (currentDirection) {
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
    if (newHead[0] < 0 || newHead[0] >= boardSize || newHead[1] < 0 || newHead[1] >= boardSize) {
      gameOver();
      return;
    }
    
    // التحقق من أكل الطعام
    bool didEatFood = (newHead[0] == food[0] && newHead[1] == food[1]);
    
    // إضافة الرأس الجديد
    snake.insert(0, newHead);
    
    if (didEatFood) {
      currentScore++;
      generateValidFood();
    } else {
      snake.removeLast();
    }
    
    // التحقق من التصادم مع الذات
    for (int i = 1; i < snake.length; i++) {
      if (snake[i][0] == snake[0][0] && snake[i][1] == snake[0][1]) {
        gameOver();
        return;
      }
    }
  }

  void gameOver() {
    if (!isGameRunning) return;
    
    isGameRunning = false;
    gameLoop?.cancel();
    
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
              startNewGame();
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

  void changeDirection(String newDirection) {
    if ((currentDirection == 'UP' && newDirection == 'DOWN') ||
        (currentDirection == 'DOWN' && newDirection == 'UP') ||
        (currentDirection == 'LEFT' && newDirection == 'RIGHT') ||
        (currentDirection == 'RIGHT' && newDirection == 'LEFT')) {
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
                  'Snake Game',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  'Score: $currentScore',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
          
          // شاشة اللعبة
          Expanded(
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                if (details.delta.dy > 0) {
                  changeDirection('DOWN');
                } else if (details.delta.dy < 0) {
                  changeDirection('UP');
                }
              },
              onHorizontalDragUpdate: (details) {
                if (details.delta.dx > 0) {
                  changeDirection('RIGHT');
                } else if (details.delta.dx < 0) {
                  changeDirection('LEFT');
                }
              },
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: boardSize,
                  childAspectRatio: 1,
                ),
                itemCount: boardSize * boardSize,
                itemBuilder: (context, index) {
                  int x = index % boardSize;
                  int y = index ~/ boardSize;
                  
                  // التحقق مما إذا كانت الخلية جزء من الثعبان
                  bool isSnakeCell = false;
                  for (var segment in snake) {
                    if (segment[0] == x && segment[1] == y) {
                      isSnakeCell = true;
                      break;
                    }
                  }
                  
                  bool isFoodCell = (food[0] == x && food[1] == y);
                  
                  return Container(
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: isSnakeCell
                          ? Colors.green
                          : (isFoodCell ? Colors.red : Colors.grey.shade800),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                },
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
        onPressed: isGameRunning ? () => changeDirection(dir) : null,
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
    gameLoop?.cancel();
    super.dispose();
  }
}