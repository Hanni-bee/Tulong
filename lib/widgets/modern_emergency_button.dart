import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../constants/app_colors.dart';

class ModernEmergencyButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String? label;
  final bool isActive;
  final bool showPulse;
  final double? size;
  final bool isPrimary;
  final String? subtitle;

  const ModernEmergencyButton({
    super.key,
    this.onPressed,
    this.label,
    this.isActive = false,
    this.showPulse = true,
    this.size,
    this.isPrimary = false,
    this.subtitle,
  });

  @override
  State<ModernEmergencyButton> createState() => _ModernEmergencyButtonState();
}

class _ModernEmergencyButtonState extends State<ModernEmergencyButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _pressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _pressAnimation;
  late Animation<double> _rotationAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _pressAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.05,
    ).animate(CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeInOut,
    ));

    if (widget.showPulse && widget.isActive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _pressController.forward();
    HapticFeedback.mediumImpact();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _pressController.reverse();
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final buttonSize = widget.size ?? (widget.isPrimary ? 100.0 : 80.0);
    
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _pressController]),
      builder: (context, child) {
        return Transform.scale(
          scale: widget.showPulse && widget.isActive 
              ? _pulseAnimation.value * _pressAnimation.value
              : _pressAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: GestureDetector(
              onTapDown: _handleTapDown,
              onTapUp: _handleTapUp,
              onTapCancel: _handleTapCancel,
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  color: widget.isActive ? AppColors.error : AppColors.primaryRed,
                  shape: widget.isPrimary ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: widget.isPrimary ? BorderRadius.circular(20) : null,
                  boxShadow: _isPressed
                      ? [
                          // Pressed state - reduced shadow
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(2, 2),
                          ),
                        ]
                      : [
                          // Normal state - raised shadow with emergency glow
                          BoxShadow(
                            color: (widget.isActive ? AppColors.error : AppColors.primaryRed)
                                .withOpacity(0.6),
                            blurRadius: widget.isPrimary ? 30 : 20,
                            spreadRadius: widget.isPrimary ? 4 : 2,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: widget.isPrimary ? 20 : 12,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: AppColors.white.withOpacity(0.8),
                            blurRadius: widget.isPrimary ? 20 : 12,
                            offset: const Offset(0, -8),
                          ),
                        ],
                ),
                child: widget.isPrimary 
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.emergency,
                              color: AppColors.white,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.label ?? 'EMERGENCY',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (widget.subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.subtitle!,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      )
                    : Center(
                        child: Icon(
                          Icons.emergency,
                          color: AppColors.white,
                          size: buttonSize * 0.4,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ModernEmergencyFAB extends StatefulWidget {
  final VoidCallback? onPressed;
  final String? label;
  final bool isActive;
  final bool showPulse;
  final bool requireHold; // if true, trigger only on long-press
  final Duration holdDuration;

  const ModernEmergencyFAB({
    super.key,
    this.onPressed,
    this.label,
    this.isActive = false,
    this.showPulse = true,
    this.requireHold = false,
    this.holdDuration = const Duration(milliseconds: 800),
  });

  @override
  State<ModernEmergencyFAB> createState() => _ModernEmergencyFABState();
}

class _ModernEmergencyFABState extends State<ModernEmergencyFAB>
    with SingleTickerProviderStateMixin {
  late final AnimationController _holdController;
  Timer? _holdTimer;
  bool _isHolding = false;
  int _holdSequence = 0; // Increment to invalidate delayed callbacks

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(vsync: this, duration: widget.holdDuration);
  }

  @override
  void didUpdateWidget(covariant ModernEmergencyFAB oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.holdDuration != widget.holdDuration) {
      _holdController.duration = widget.holdDuration;
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _holdController.dispose();
    super.dispose();
  }

  void _startHold() {
    if (!widget.requireHold) return;
    _isHolding = true;
    _holdSequence++; // Increment sequence to invalidate any previous delayed callbacks
    final currentSequence = _holdSequence;
    HapticFeedback.mediumImpact();
    _holdController
      ..reset()
      ..forward();
    _holdTimer?.cancel();
    _holdTimer = Timer(widget.holdDuration, () {
      if (!mounted || !_isHolding) return;
      if (currentSequence != _holdSequence) return; // Hold was cancelled and restarted
      
      if (_isHolding) {
        // Wait for animation to visually complete (ensure the ring is fully filled)
        // Add a small delay to ensure smooth visual transition before showing modal
        Future.delayed(const Duration(milliseconds: 150), () {
          // Check if still holding and sequence matches (user didn't cancel)
          if (!mounted || !_isHolding || currentSequence != _holdSequence) return;
          
          HapticFeedback.heavyImpact();
          widget.onPressed?.call();
          _isHolding = false;
          // Keep animation at completed state briefly before resetting
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && currentSequence == _holdSequence) {
              _holdController.reset();
            }
          });
        });
      }
    });
  }

  void _cancelHold() {
    if (!widget.requireHold) return;
    _isHolding = false;
    _holdSequence++; // Invalidate any pending delayed callbacks
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final coreButton = Stack(
      children: [
        // Pulse ring effect
        if (widget.showPulse && widget.isActive)
          TweenAnimationBuilder<double>(
            duration: const Duration(seconds: 2),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.scale(
                scale: 1.0 + (value * 0.3),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.error.withOpacity(0.3 - (value * 0.3)),
                      width: 2,
                    ),
                  ),
                ),
              );
            },
            onEnd: () {
              // Restart animation
            },
          ),
        
        // Hold progress ring
        if (widget.requireHold)
          AnimatedBuilder(
            animation: _holdController,
            builder: (context, _) {
              return SizedBox(
                width: 88,
                height: 88,
                child: CircularProgressIndicator(
                  value: _isHolding ? _holdController.value : 0,
                  strokeWidth: 5,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.error),
                  backgroundColor: AppColors.error.withOpacity(0.1),
                ),
              );
            },
          ),

        // Main button
        ModernEmergencyButton(
          onPressed: widget.requireHold ? null : widget.onPressed,
          label: widget.label,
          isActive: widget.isActive,
          showPulse: widget.showPulse,
          size: 80,
        ),
      ],
    );

    if (!widget.requireHold) return coreButton;

    return GestureDetector(
      onLongPressStart: (_) => _startHold(),
      onLongPressEnd: (_) => _cancelHold(),
      onLongPressCancel: _cancelHold,
      behavior: HitTestBehavior.opaque,
      child: coreButton,
    );
  }
}
