import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/severity_colors.dart';
import '../constants/soft_ui_design.dart';
import '../utils/theme_colors.dart';

/// Variant for the alert card: emergency (red, severity, EMERGENCY pill) or tips (orange, preparedness).
enum EmergencyAlertVariant { emergency, tips }

class EmergencyAlertWidget extends StatefulWidget {
  final String title;
  final String message;
  final String severity;
  final VoidCallback? onTap;
  final bool showGif;
  final String? gifPath;
  final EmergencyAlertVariant variant;

  const EmergencyAlertWidget({
    super.key,
    required this.title,
    required this.message,
    required this.severity,
    this.onTap,
    this.showGif = false,
    this.gifPath,
    this.variant = EmergencyAlertVariant.emergency,
  });

  @override
  State<EmergencyAlertWidget> createState() => _EmergencyAlertWidgetState();
}

class _EmergencyAlertWidgetState extends State<EmergencyAlertWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _pressController;
  late AnimationController _iconPulseController;
  late AnimationController _enterController;
  
  late Animation<double> _pulseAnimation;
  late Animation<double> _pressScaleAnimation;
  late Animation<double> _pressElevationAnimation;
  late Animation<double> _iconPulseAnimation;
  late Animation<double> _enterAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Main card pulse (subtle)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.005, // Very subtle
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _pulseController.repeat(reverse: true);
    
    // Press animation
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _pressScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeOut,
    ));
    
    _pressElevationAnimation = Tween<double>(
      begin: 8.0,
      end: 4.0,
    ).animate(CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeOut,
    ));
    
    // Icon pulse (subtle)
    _iconPulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _iconPulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(
      parent: _iconPulseController,
      curve: Curves.easeInOut,
    ));
    
    _iconPulseController.repeat(reverse: true);
    
    // Enter animation
    _enterController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _enterAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _enterController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _enterController,
      curve: Curves.easeOut,
    ));
    
    _enterController.forward();
    
    // Haptic feedback for emergency alerts - Reduced intensity
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pressController.dispose();
    _iconPulseController.dispose();
    _enterController.dispose();
    super.dispose();
  }
  
  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      HapticFeedback.lightImpact();
      _pressController.forward();
    }
  }
  
  void _handleTapUp(TapUpDetails details) {
    _pressController.reverse();
    if (widget.onTap != null) {
      widget.onTap!();
    }
  }
  
  void _handleTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isTips = widget.variant == EmergencyAlertVariant.tips;
    final emergencyColor = isTips ? DisasterTypeColors.general : AppColors.primaryRed;
    
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _pressScaleAnimation, _pressElevationAnimation, _enterAnimation, _slideAnimation]),
      builder: (context, child) {
        return FadeTransition(
          opacity: _enterAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Transform.scale(
              scale: _pulseAnimation.value * _pressScaleAnimation.value,
              child: GestureDetector(
                onTapDown: _handleTapDown,
                onTapUp: _handleTapUp,
                onTapCancel: _handleTapCancel,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ThemeColors.surface(context),
                    borderRadius: BorderRadius.circular(SoftUIDesign.cardBorderRadius),
                    // Neumorphic dual shadows for depth (animated on press)
                    boxShadow: SoftUIDesign.getCardShadow(context: context, elevation: _pressElevationAnimation.value),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(SoftUIDesign.cardBorderRadius),
                    child: Stack(
                      children: [
                        // Emergency GIF background if enabled (subtle, behind content)
                        if (widget.showGif && widget.gifPath != null)
                          Positioned.fill(
                            child: Opacity(
                              opacity: 0.15, // Very subtle background
                              child: Image.asset(
                                widget.gifPath!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: emergencyColor.withOpacity(0.05),
                                  );
                                },
                              ),
                            ),
                          ),
                        
                        // Soft overlay gradient for readability (only if GIF shown)
                        if (widget.showGif && widget.gifPath != null)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    ThemeColors.surface(context).withOpacity(0.85),
                                    ThemeColors.surface(context).withOpacity(0.95),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        
                        // Main content
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(SoftUIDesign.cardBorderRadius),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with icon and severity - Neumorphic card style
                              Row(
                                children: [
                              // Icon container - Neumorphic raised with pulse
                              AnimatedBuilder(
                                animation: _iconPulseAnimation,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _iconPulseAnimation.value,
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: ThemeColors.surfaceContainer(context),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          ...SoftUIDesign.getSoftShadow(context: context, elevation: 2.0),
                                          // Subtle glow on icon
                                          BoxShadow(
                                            color: emergencyColor.withOpacity(0.15 * (_iconPulseAnimation.value - 1.0) / 0.08),
                                            blurRadius: 8,
                                            spreadRadius: 0,
                                          ),
                                        ],
                                        border: Border.all(
                                          color: emergencyColor.withOpacity(0.1),
                                          width: 1,
                                        ),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: emergencyColor.withOpacity(0.2),
                                            width: 1,
                                          ),
                                        ),
                                        child: isTips
                                            ? Icon(
                                                Icons.tips_and_updates_rounded,
                                                color: emergencyColor,
                                                size: 28,
                                              )
                                            : ClipRRect(
                                                borderRadius: BorderRadius.circular(6),
                                                child: Image.asset(
                                                  'assets/images/app_logo (3).png',
                                                  width: 28,
                                                  height: 28,
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Icon(
                                                      Icons.emergency,
                                                      color: emergencyColor,
                                                      size: 24,
                                                    );
                                                  },
                                                ),
                                              ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.title,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: ThemeColors.textPrimary(context),
                                        letterSpacing: -0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    if (!isTips)
                                      AnimatedBuilder(
                                        animation: _iconPulseController,
                                        builder: (context, child) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: emergencyColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: emergencyColor.withOpacity(0.2 + 0.1 * (_iconPulseAnimation.value - 1.0) / 0.08),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    color: emergencyColor,
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: emergencyColor.withOpacity(0.6 * (_iconPulseAnimation.value - 1.0) / 0.08),
                                                        blurRadius: 4,
                                                        spreadRadius: 1,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Severity: ${widget.severity.toUpperCase()}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: emergencyColor,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    if (isTips)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: emergencyColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: emergencyColor.withOpacity(0.25), width: 1),
                                        ),
                                        child: Text(
                                          'Preparedness',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: emergencyColor,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (!isTips)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        emergencyColor,
                                        emergencyColor.withOpacity(0.8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: emergencyColor.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    'EMERGENCY',
                                    style: TextStyle(
                                      color: ThemeColors.textWhite(context),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              if (isTips)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: emergencyColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: emergencyColor.withOpacity(0.4), width: 1),
                                  ),
                                  child: Text(
                                    'Tips',
                                    style: TextStyle(
                                      color: emergencyColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                            
                          const SizedBox(height: 20),
                          
                          // Message - Neumorphic card style with subtle separator
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Subtle divider
                              Container(
                                height: 1,
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      emergencyColor.withOpacity(0.1),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: ThemeColors.surfaceContainer(context),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: SoftUIDesign.getSoftShadow(context: context, elevation: 2.0),
                                  border: Border.all(
                                    color: emergencyColor.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  widget.message,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: ThemeColors.textPrimary(context),
                                    fontWeight: FontWeight.w500,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Action hint - Enhanced interactive button
                          if (widget.onTap != null)
                            StatefulBuilder(
                              builder: (context, setState) {
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      widget.onTap!();
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: ThemeColors.surfaceContainer(context),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: SoftUIDesign.getSoftShadow(context: context, elevation: 2.0),
                                        border: Border.all(
                                          color: emergencyColor.withOpacity(0.15),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: emergencyColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Icon(
                                              Icons.arrow_forward_ios,
                                              color: emergencyColor,
                                              size: 14,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            isTips ? 'See tips' : 'Tap for more information',
                                            style: TextStyle(
                                              color: emergencyColor,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
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
        ));
      },
    );
  }
}
