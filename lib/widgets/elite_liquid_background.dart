import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_colors.dart';

/// Unified liquid background foundation used across Splash, Sign-In, and Main Navigation.
/// Creates a consistent high-end "Elite" design language.
class EliteLiquidBackground extends StatelessWidget {
  final bool isLight;
  final List<Color>? customColors;

  const EliteLiquidBackground({
    super.key,
    this.isLight = false,
    this.customColors,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Base Gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: customColors ?? (isLight 
                ? [Colors.white, const Color(0xFFF8F9FA)] 
                : [AppColors.primary, AppColors.primaryDark]),
            ),
          ),
        ),
        
        // 2. Dynamic Orbs
        // Top Right
        Positioned(
          top: -100,
          right: -50,
          child: _Orb(
            color: (isLight ? AppColors.primaryRed : Colors.white).withOpacity(isLight ? 0.05 : 0.12), 
            size: 400
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true))
         .moveY(begin: 0, end: 50, duration: 6.seconds, curve: Curves.easeInOut)
         .moveX(begin: 0, end: -30, duration: 4.seconds, curve: Curves.easeInOut),

        // Bottom Left
        Positioned(
          bottom: 50,
          left: -100,
          child: _Orb(
            color: (isLight ? AppColors.primaryRed : Colors.white).withOpacity(isLight ? 0.04 : 0.08), 
            size: 350
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true))
         .moveY(begin: 0, end: -40, duration: 5.seconds, curve: Curves.easeInOut)
         .moveX(begin: 0, end: 60, duration: 7.seconds, curve: Curves.easeInOut),

        // 3. Global Backdrop Blur
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  const _Orb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

