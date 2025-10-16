import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

class EmergencyAlertWidget extends StatefulWidget {
  final String title;
  final String message;
  final String severity;
  final VoidCallback? onTap;
  final bool showGif;
  final String? gifPath;

  const EmergencyAlertWidget({
    super.key,
    required this.title,
    required this.message,
    required this.severity,
    this.onTap,
    this.showGif = false,
    this.gifPath,
  });

  @override
  State<EmergencyAlertWidget> createState() => _EmergencyAlertWidgetState();
}

class _EmergencyAlertWidgetState extends State<EmergencyAlertWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.elasticIn,
    ));
    
    _pulseController.repeat(reverse: true);
    
    // Haptic feedback for emergency alerts - Reduced intensity
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getSeverityColor() {
    switch (widget.severity.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.yellow;
      case 'low':
        return Colors.green;
      default:
        return AppColors.primaryRed;
    }
  }

  IconData _getSeverityIcon() {
    switch (widget.severity.toLowerCase()) {
      case 'critical':
        return Icons.warning;
      case 'high':
        return Icons.error;
      case 'medium':
        return Icons.info;
      case 'low':
        return Icons.check_circle;
      default:
        return Icons.emergency;
    }
  }

  @override
  Widget build(BuildContext context) {
    final severityColor = _getSeverityColor();
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Transform.translate(
            offset: Offset(
              _shakeAnimation.value * 2,
              0.0,
            ),
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: severityColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // Emergency GIF background if enabled
                      if (widget.showGif && widget.gifPath != null)
                        Positioned.fill(
                          child: Image.asset(
                            widget.gifPath!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: severityColor.withOpacity(0.1),
                              );
                            },
                          ),
                        ),
                      
                      // Better overlay for text visibility
                      if (widget.showGif && widget.gifPath != null)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7), // Increased opacity for better contrast
                          ),
                        ),
                      
                      // Content
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: widget.showGif ? Colors.transparent : severityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: severityColor,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with icon and severity
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: severityColor,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: severityColor.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _getSeverityIcon(),
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.title,
                                        style: TextStyle(
                                          fontSize: 18, // Reduced from 20 to prevent overflow
                                          fontWeight: FontWeight.bold,
                                          color: widget.showGif ? Colors.white : severityColor,
                                          shadows: widget.showGif ? [
                                            Shadow(
                                              color: Colors.black,
                                              blurRadius: 2,
                                              offset: const Offset(1, 1),
                                            ),
                                          ] : null,
                                        ),
                                        maxLines: 1, // Prevent text wrapping
                                        overflow: TextOverflow.ellipsis, // Add ellipsis if too long
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Severity: ${widget.severity.toUpperCase()}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: widget.showGif ? Colors.white : severityColor.withOpacity(0.8),
                                          shadows: widget.showGif ? [
                                            Shadow(
                                              color: Colors.black,
                                              blurRadius: 2,
                                              offset: const Offset(1, 1),
                                            ),
                                          ] : null,
                                        ),
                                        maxLines: 1, // Prevent text wrapping
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Flexible( // Changed from Container to Flexible to prevent overflow
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8, // Reduced padding
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: severityColor,
                                      borderRadius: BorderRadius.circular(16), // Reduced radius
                                    ),
                                    child: Text(
                                      'EMERGENCY',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9, // Reduced font size
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5, // Added letter spacing for readability
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Message
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: widget.showGif 
                                    ? Colors.black.withOpacity(0.8) // Increased opacity for better contrast
                                    : Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: severityColor.withOpacity(0.5), // Increased border opacity
                                  width: 2, // Increased border width
                                ),
                              ),
                              child: Text(
                                widget.message,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: widget.showGif ? Colors.white : AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                  shadows: widget.showGif ? [
                                    Shadow(
                                      color: Colors.black,
                                      blurRadius: 2,
                                      offset: const Offset(1, 1),
                                    ),
                                  ] : null, // Add text shadows when showing GIF
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Action hint
                            if (widget.onTap != null)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: widget.showGif 
                                      ? Colors.black.withOpacity(0.6) // Dark background when showing GIF
                                      : severityColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: widget.showGif ? Border.all(
                                    color: severityColor.withOpacity(0.5),
                                    width: 1,
                                  ) : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.touch_app,
                                      color: widget.showGif ? Colors.white : severityColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Tap for more information',
                                      style: TextStyle(
                                        color: widget.showGif ? Colors.white : severityColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        shadows: widget.showGif ? [
                                          Shadow(
                                            color: Colors.black,
                                            blurRadius: 2,
                                            offset: const Offset(1, 1),
                                          ),
                                        ] : null, // Add text shadows when showing GIF
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
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
