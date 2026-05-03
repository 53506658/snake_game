cat > lib/main.dart << 'EOF'
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

void main() => runApp(SnakeGame());

class SnakeGame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snake Game',
      theme: ThemeData.dark(),
      home: GameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class GameScreen extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const int gridSize = 20;
  List<List<int>> snake = [[10, 10]];
  List<int> food = [15, 10];
  String direction = 'RIGHT';
  String nextDirection = 'RIGHT';
  bool isPlaying = true;
  int score = 0;
  Timer? gameTimer;
  final Random random = Random();

  @override
  void initState() {
    super.initState();
    startGame();
  }

  void startGame() {
    snake = [[10, 10]];
    direction = 'RIGHT';
    nextDirection = 'RIGHT';
    isPlaying = true;
    score = 0;
    generateFood();
    gameTimer?.cancel();
    gameTimer = Timer.periodic(Duration(milliseconds: 150), (timer) {
      if (isPlaying) {
        moveSnake();
        setState(() {});
      }
    });
  }

  void generateFood() {
    do {
      food = [random.nextInt(gridSize), random.nextInt(gridSize)];
    } while (snake.any((segment) => segment[0] == food[0] && segment[1] == food[1]));
  }

  void moveSnake() {
    direction = nextDirection;
    List<int> newHead = List.from(snake.first);
    
    switch (direction) {
      case 'UP': newHead[1]--; break;
      case 'DOWN': newHead[1]++; break;
      case 'LEFT': newHead[0]--; break;
      case 'RIGHT': newHead[0]++; break;
    }
    
    if (newHead[0] < 0 || newHead[0] >= gridSize || newHead[1] < 0 || newHead[1] >= gridSize) {
      gameOver();
      return;
    }
    
    bool ateFood = (newHead[0] == food[0] && newHead[1] == food[1]);
    snake.insert(0, newHead);
    
    if (ateFood) {
      score++;
      generateFood();
    } else {
      snake.removeLast();
    }
    
    for (int i = 1; i < snake.length; i++) {
      if (snake[i][0] == snake[0][0] && snake[i][1] == snake[0][1]) {
        gameOver();
        return;
      }
    }
  }

  void gameOver() {
    isPlaying = false;
    gameTimer?.cancel();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Game Over!'),
        content: Text('Your score: $score\nPlay again?'),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); startGame(); setState(() {}); }, child: Text('Yes')),
          TextButton(onPressed: () => Navigator.pop(context), child: Text('No')),
        ],
      ),
    );
  }

  void changeDirection(String newDirection) {
    if ((direction == 'UP' && newDirection == 'DOWN') ||
        (direction == 'DOWN' && newDirection == 'UP') ||
        (direction == 'LEFT' && newDirection == 'RIGHT') ||
        (direction == 'RIGHT' && newDirection == 'LEFT')) return;
    nextDirection = newDirection;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.green.shade900,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Snake Game', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('Score: $score', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                if (details.delta.dy > 0) changeDirection('DOWN');
                else if (details.delta.dy < 0) changeDirection('UP');
              },
              onHorizontalDragUpdate: (details) {
                if (details.delta.dx > 0) changeDirection('RIGHT');
                else if (details.delta.dx < 0) changeDirection('LEFT');
              },
              child: Container(
                padding: EdgeInsets.all(20),
                child: GridView.builder(
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridSize,
                    childAspectRatio: 1,
                  ),
                  itemCount: gridSize * gridSize,
                  itemBuilder: (context, index) {
                    int x = index % gridSize;
                    int y = index ~/ gridSize;
                    bool isSnake = snake.any((segment) => segment[0] == x && segment[1] == y);
                    bool isFood = food[0] == x && food[1] == y;
                    return Container(
                      margin: EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: isSnake ? Colors.green : (isFood ? Colors.red : Colors.grey.shade800),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.green.shade900,
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [_buildControlButton('↑', 'UP')]),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _buildControlButton('←', 'LEFT'), SizedBox(width: 50), _buildControlButton('→', 'RIGHT'),
                ]),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [_buildControlButton('↓', 'DOWN')]),
                SizedBox(height: 10),
                Text('Use arrows or swipe', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(String icon, String dir) {
    return Container(
      margin: EdgeInsets.all(5),
      child: ElevatedButton(
        onPressed: isPlaying ? () => changeDirection(dir) : null,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: Size(60, 60)),
        child: Text(icon, style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    super.dispose();
  }
}
EOF