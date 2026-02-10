/// Invisible Maze Game
/// Fine Motor Skills Training - Navigate through the maze by touch

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/aura_theme.dart';

class InvisibleMazeGame extends StatefulWidget {
  final Function(int score, int eyeContact, int motor) onGameComplete;

  const InvisibleMazeGame({
    super.key,
    required this.onGameComplete,
  });

  @override
  State<InvisibleMazeGame> createState() => _InvisibleMazeGameState();
}

class _InvisibleMazeGameState extends State<InvisibleMazeGame>
    with TickerProviderStateMixin {
  // Game state
  Timer? _gameTimer;
  int _timeRemaining = 60;
  int _score = 0;
  int _wallHits = 0;
  int _mazesCompleted = 0;
  bool _isGameOver = false;
  bool _isDrawing = false;
  
  // Maze state
  late List<MazeWall> _walls;
  late Offset _startPoint;
  late Offset _endPoint;
  Offset? _currentPosition;
  List<Offset> _trailPath = [];
  bool _reachedEnd = false;
  
  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(_pulseController);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateMaze();
      _startGame();
    });
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _generateMaze() {
    final size = MediaQuery.of(context).size;
    final mazeWidth = size.width - 60;
    final mazeHeight = size.height - 250;
    final mazeLeft = 30.0;
    final mazeTop = 120.0;
    
    _walls = [];
    
    // Create a simple maze with paths
    // Outer boundary
    _walls.add(MazeWall(Offset(mazeLeft, mazeTop), Offset(mazeLeft + mazeWidth, mazeTop))); // Top
    _walls.add(MazeWall(Offset(mazeLeft, mazeTop + mazeHeight), Offset(mazeLeft + mazeWidth, mazeTop + mazeHeight))); // Bottom
    _walls.add(MazeWall(Offset(mazeLeft, mazeTop), Offset(mazeLeft, mazeTop + mazeHeight))); // Left
    _walls.add(MazeWall(Offset(mazeLeft + mazeWidth, mazeTop), Offset(mazeLeft + mazeWidth, mazeTop + mazeHeight))); // Right
    
    // Internal walls creating a simple maze path
    final wallThickness = 20.0;
    final sectionWidth = mazeWidth / 4;
    final sectionHeight = mazeHeight / 4;
    
    // Horizontal walls
    _walls.add(MazeWall(
      Offset(mazeLeft + sectionWidth, mazeTop + sectionHeight),
      Offset(mazeLeft + mazeWidth * 0.7, mazeTop + sectionHeight),
    ));
    
    _walls.add(MazeWall(
      Offset(mazeLeft, mazeTop + sectionHeight * 2),
      Offset(mazeLeft + mazeWidth * 0.5, mazeTop + sectionHeight * 2),
    ));
    
    _walls.add(MazeWall(
      Offset(mazeLeft + sectionWidth, mazeTop + sectionHeight * 3),
      Offset(mazeLeft + mazeWidth, mazeTop + sectionHeight * 3),
    ));
    
    // Vertical walls
    _walls.add(MazeWall(
      Offset(mazeLeft + sectionWidth * 2, mazeTop + sectionHeight),
      Offset(mazeLeft + sectionWidth * 2, mazeTop + sectionHeight * 2),
    ));
    
    _walls.add(MazeWall(
      Offset(mazeLeft + sectionWidth * 3, mazeTop + sectionHeight * 2),
      Offset(mazeLeft + sectionWidth * 3, mazeTop + sectionHeight * 3),
    ));
    
    // Start and end points
    _startPoint = Offset(mazeLeft + 40, mazeTop + 40);
    _endPoint = Offset(mazeLeft + mazeWidth - 40, mazeTop + mazeHeight - 40);
    
    _trailPath = [];
    _reachedEnd = false;
    _currentPosition = null;
  }

  void _startGame() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _timeRemaining--;
          if (_timeRemaining <= 0) {
            _endGame();
          }
        });
      }
    });
  }

  bool _checkWallCollision(Offset point) {
    const collisionDistance = 15.0;
    
    for (var wall in _walls) {
      final distance = _distanceToLineSegment(point, wall.start, wall.end);
      if (distance < collisionDistance) {
        return true;
      }
    }
    return false;
  }

  double _distanceToLineSegment(Offset point, Offset start, Offset end) {
    final l2 = (end - start).distanceSquared;
    if (l2 == 0) return (point - start).distance;
    
    var t = ((point.dx - start.dx) * (end.dx - start.dx) + 
             (point.dy - start.dy) * (end.dy - start.dy)) / l2;
    t = t.clamp(0.0, 1.0);
    
    final projection = Offset(
      start.dx + t * (end.dx - start.dx),
      start.dy + t * (end.dy - start.dy),
    );
    
    return (point - projection).distance;
  }

  void _onPanStart(DragStartDetails details) {
    if (_isGameOver) return;
    
    final position = details.localPosition;
    final distanceToStart = (position - _startPoint).distance;
    
    if (distanceToStart < 40) {
      setState(() {
        _isDrawing = true;
        _currentPosition = position;
        _trailPath = [position];
        _reachedEnd = false;
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDrawing || _isGameOver) return;
    
    final position = details.localPosition;
    
    if (_checkWallCollision(position)) {
      HapticFeedback.heavyImpact();
      setState(() {
        _wallHits++;
        _score = max(0, _score - 5);
      });
    }
    
    setState(() {
      _currentPosition = position;
      _trailPath.add(position);
      
      // Check if reached end
      final distanceToEnd = (position - _endPoint).distance;
      if (distanceToEnd < 35) {
        _reachedEnd = true;
        _onMazeComplete();
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isGameOver) return;
    
    setState(() {
      _isDrawing = false;
      if (!_reachedEnd) {
        // Reset if didn't reach end
        _trailPath = [];
        _currentPosition = null;
      }
    });
  }

  void _onMazeComplete() {
    _isDrawing = false;
    _mazesCompleted++;
    _score += 50 - (_wallHits * 2).clamp(0, 40);
    
    HapticFeedback.mediumImpact();
    
    // Generate new maze after a short delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && !_isGameOver) {
        setState(() {
          _wallHits = 0;
          _generateMaze();
        });
      }
    });
  }

  void _endGame() {
    _isGameOver = true;
    _gameTimer?.cancel();
    
    // Calculate scores
    final motorScore = min(100, _mazesCompleted * 25 + max(0, 100 - _wallHits * 5)).toInt();
    final eyeContactScore = min(100, _mazesCompleted * 20 + 40).toInt();
    
    widget.onGameComplete(_score, eyeContactScore, motorScore);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AuraTheme.gameG3,
            AuraTheme.gameG3.withAlpha(200),
            Colors.white,
          ],
        ),
      ),
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: CustomPaint(
          painter: MazePainter(
            walls: _walls,
            startPoint: _startPoint,
            endPoint: _endPoint,
            trailPath: _trailPath,
            currentPosition: _currentPosition,
            pulseValue: _pulseAnimation.value,
            reachedEnd: _reachedEnd,
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Score
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(220),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(20),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.stars, color: Colors.amber, size: 28),
                            const SizedBox(width: 8),
                            Text(
                              '$_score',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AuraTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Mazes completed
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(220),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: AuraTheme.success, size: 24),
                            const SizedBox(width: 6),
                            Text(
                              '$_mazesCompleted',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AuraTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Timer
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: _timeRemaining <= 10
                              ? AuraTheme.error.withAlpha(220)
                              : Colors.white.withAlpha(220),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer,
                              color: _timeRemaining <= 10 ? Colors.white : AuraTheme.textDark,
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$_timeRemaining',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _timeRemaining <= 10 ? Colors.white : AuraTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Instructions
                Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(200),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _reachedEnd 
                        ? '🎉 Great! Get ready for the next maze!'
                        : '👆 Drag from the green circle to the flag! Avoid the walls!',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AuraTheme.textDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MazeWall {
  final Offset start;
  final Offset end;
  
  MazeWall(this.start, this.end);
}

class MazePainter extends CustomPainter {
  final List<MazeWall> walls;
  final Offset startPoint;
  final Offset endPoint;
  final List<Offset> trailPath;
  final Offset? currentPosition;
  final double pulseValue;
  final bool reachedEnd;

  MazePainter({
    required this.walls,
    required this.startPoint,
    required this.endPoint,
    required this.trailPath,
    required this.currentPosition,
    required this.pulseValue,
    required this.reachedEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw walls
    final wallPaint = Paint()
      ..color = const Color(0xFF66BB6A).withAlpha(80)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    
    for (var wall in walls) {
      canvas.drawLine(wall.start, wall.end, wallPaint);
    }
    
    // Draw trail path
    if (trailPath.length > 1) {
      final trailPaint = Paint()
        ..color = const Color(0xFF4CAF50).withAlpha(150)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      
      final path = Path();
      path.moveTo(trailPath.first.dx, trailPath.first.dy);
      for (var point in trailPath.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, trailPaint);
    }
    
    // Draw start point
    final startPaint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(startPoint, 25 * pulseValue, startPaint);
    
    // Start inner circle
    final startInnerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(startPoint, 12, startInnerPaint);
    
    // Draw end point (flag)
    final endPaint = Paint()
      ..color = reachedEnd ? const Color(0xFFFFD700) : const Color(0xFFFF5722)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(endPoint, 25 * pulseValue, endPaint);
    
    // Flag icon simulation
    final flagPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final flagPath = Path();
    flagPath.moveTo(endPoint.dx - 8, endPoint.dy - 12);
    flagPath.lineTo(endPoint.dx + 10, endPoint.dy - 6);
    flagPath.lineTo(endPoint.dx - 8, endPoint.dy);
    flagPath.close();
    canvas.drawPath(flagPath, flagPaint);
    
    // Draw current position
    if (currentPosition != null) {
      final posPaint = Paint()
        ..color = const Color(0xFF2196F3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(currentPosition!, 15, posPaint);
      
      final posInnerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(currentPosition!, 6, posInnerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant MazePainter oldDelegate) => true;
}
