import 'dart:math';
import 'package:flutter/material.dart';
import '../models/letter_state.dart';
import '../theme/app_theme.dart';

class LetterTile extends StatefulWidget {
  final TileData data;
  final double size;
  final int revealDelayMs;
  final bool isWinningAnimation;

  const LetterTile({
    super.key,
    required this.data,
    required this.size,
    this.revealDelayMs = 0,
    this.isWinningAnimation = false,
  });

  @override
  State<LetterTile> createState() => _LetterTileState();
}

class _LetterTileState extends State<LetterTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _flipAnimation;
  late Animation<double> _bounceAnimation;
  LetterStatus _displayedStatus = LetterStatus.empty;

  @override
  void initState() {
    super.initState();
    _displayedStatus = widget.data.status;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _flipAnimation.addListener(() {
      if (_flipAnimation.value >= 0.5 && _displayedStatus != widget.data.status) {
        setState(() {
          _displayedStatus = widget.data.status;
        });
      }
    });

    if (_shouldAnimateFlip(widget.data.status)) {
      _triggerFlip();
    }
  }

  bool _shouldAnimateFlip(LetterStatus status) {
    return status == LetterStatus.correct ||
        status == LetterStatus.present ||
        status == LetterStatus.absent;
  }

  void _triggerFlip() {
    Future.delayed(Duration(milliseconds: widget.revealDelayMs), () {
      if (mounted) {
        _controller.forward(from: 0.0);
      }
    });
  }

  @override
  void didUpdateWidget(covariant LetterTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.data.status != widget.data.status) {
      if (_shouldAnimateFlip(widget.data.status)) {
        _triggerFlip();
      } else {
        _displayedStatus = widget.data.status;
      }
    }

    if (widget.isWinningAnimation && !oldWidget.isWinningAnimation) {
      Future.delayed(Duration(milliseconds: widget.revealDelayMs), () {
        if (mounted) {
          _controller.forward(from: 0.0);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (widget.isWinningAnimation) {
          return Transform.scale(
            scale: _bounceAnimation.value,
            child: _buildTileContent(isDark, widget.data.status),
          );
        }

        final angle = _flipAnimation.value * pi;
        final isUnderHalf = _flipAnimation.value < 0.5;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateX(angle),
          alignment: Alignment.center,
          child: Transform(
            // Keep the letter upright when flipped
            transform: isUnderHalf ? Matrix4.identity() : Matrix4.rotationX(pi),
            alignment: Alignment.center,
            child: _buildTileContent(isDark, _displayedStatus),
          ),
        );
      },
    );
  }

  Widget _buildTileContent(bool isDark, LetterStatus status) {
    Color bg;
    Color border;
    Color textColor;

    switch (status) {
      case LetterStatus.empty:
        bg = isDark ? GameColors.darkSurface : GameColors.lightSurface;
        border = isDark ? GameColors.darkBorder : GameColors.lightBorder;
        textColor = isDark ? GameColors.darkTextPrimary : GameColors.lightTextPrimary;
        break;

      case LetterStatus.pending:
        bg = isDark ? GameColors.darkSurface : GameColors.lightSurface;
        border = isDark ? GameColors.darkBorderActive : GameColors.lightBorderActive;
        textColor = isDark ? GameColors.darkTextPrimary : GameColors.lightTextPrimary;
        break;

      case LetterStatus.correct:
        bg = isDark ? GameColors.correctDark : GameColors.correctLight;
        border = Colors.transparent;
        textColor = Colors.white;
        break;

      case LetterStatus.present:
        bg = isDark ? GameColors.presentDark : GameColors.presentLight;
        border = Colors.transparent;
        textColor = Colors.white;
        break;

      case LetterStatus.absent:
        bg = isDark ? GameColors.absentDark : GameColors.absentLight;
        border = Colors.transparent;
        textColor = Colors.white;
        break;
    }

    final fontSize = widget.size * 0.46;

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(widget.size * 0.16),
        border: Border.all(
          color: border,
          width: status == LetterStatus.pending ? 2.0 : 1.5,
        ),
        boxShadow: status == LetterStatus.empty
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      alignment: Alignment.center,
      child: Text(
        widget.data.char,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
