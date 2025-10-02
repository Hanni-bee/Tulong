import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ModernStatusIndicator extends StatefulWidget {
  final String title;
  final String status;
  final bool isOnline;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;
  final bool showPulse;
  final String? subtitle;

  const ModernStatusIndicator({
    super.key,
    required this.title,
    required this.status,
    required this.isOnline,
    required this.icon,
    this.color,
    this.onTap,
    this.showPulse = false,
    this.subtitle,
  });

  @override
  State<ModernStatusIndicator> createState() => _ModernStatusIndicatorState();
}

class _ModernStatusIndicatorState extends State<ModernStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    if (widget.showPulse && widget.isOnline) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (widget.color ?? (widget.isOnline ? AppColors.success : AppColors.warning))
                .withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Status icon with pulse animation
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: widget.showPulse && widget.isOnline ? _pulseAnimation.value : 1.0,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: widget.color ?? (widget.isOnline ? AppColors.success : AppColors.warning),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: (widget.color ?? (widget.isOnline ? AppColors.success : AppColors.warning))
                              .withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.icon,
                      color: AppColors.white,
                      size: 24,
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Status dot
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: widget.color ?? (widget.isOnline ? AppColors.success : AppColors.warning),
                          shape: BoxShape.circle,
                          boxShadow: widget.isOnline ? [
                            BoxShadow(
                              color: (widget.color ?? AppColors.success).withOpacity(0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ] : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.status,
                          style: TextStyle(
                            fontSize: 14,
                            color: widget.color ?? (widget.isOnline ? AppColors.success : AppColors.warning),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Arrow indicator
            if (widget.onTap != null)
              const Icon(
                Icons.chevron_right,
                color: AppColors.mediumGray,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
