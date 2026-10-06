import 'dart:math';
import 'package:flutter/material.dart';
import '../models/letter_state.dart';
import 'letter_tile.dart';

class WordGrid extends StatelessWidget {
  final List<List<TileData>> grid;
  final int currentAttempt;
  final int wordLength;
  final bool shakeActiveRow;
  final bool isWon;
  final int winningRowIndex;

  const WordGrid({
    super.key,
    required this.grid,
    required this.currentAttempt,
    required this.wordLength,
    this.shakeActiveRow = false,
    this.isWon = false,
    this.winningRowIndex = -1,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate dynamic tile size to fit available width and height gracefully
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;

        // Total columns = wordLength, total rows = 6
        const gap = 6.0;
        final horizontalPaddings = 24.0;
        final maxTileWidth = (availableWidth - horizontalPaddings - (wordLength - 1) * gap) / wordLength;
        final maxTileHeight = (availableHeight - 5 * gap - 16.0) / 6;

        // Pick smaller to maintain square aspect ratio and cap maximum tile size
        final rawSize = min(maxTileWidth, maxTileHeight);
        final tileSize = rawSize.clamp(34.0, 62.0);

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (rowIndex) {
              final isCurrent = rowIndex == currentAttempt;
              final shouldShake = isCurrent && shakeActiveRow;
              final isWinningRow = isWon && rowIndex == winningRowIndex;

              Widget rowWidget = Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(wordLength, (colIndex) {
                  final tile = grid[rowIndex][colIndex];
                  final delay = rowIndex < currentAttempt
                      ? colIndex * 140
                      : (isWinningRow ? colIndex * 100 : 0);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: gap / 2),
                    child: LetterTile(
                      data: tile,
                      size: tileSize,
                      revealDelayMs: delay,
                      isWinningAnimation: isWinningRow,
                    ),
                  );
                }),
              );

              if (shouldShake) {
                rowWidget = _ShakeWidget(child: rowWidget);
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: gap / 2),
                child: rowWidget,
              );
            }),
          ),
        );
      },
    );
  }
}

class _ShakeWidget extends StatefulWidget {
  final Widget child;

  const _ShakeWidget({required this.child});

  @override
  State<_ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<_ShakeWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: -3), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -3, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_animation.value, 0),
          child: widget.child,
        );
      },
    );
  }
}
