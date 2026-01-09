import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/soft_ui_design.dart';
import '../providers/chat_provider.dart';

class EmergencyAlertWidget extends StatefulWidget {
  final String? title;
  final String? message;
  final String? severity;
  final VoidCallback? onTap;
  final bool showGif;
  final String? gifPath;
  final bool useDynamicStatus;

  const EmergencyAlertWidget({
    super.key,
    this.title,
    this.message,
    this.severity,
    this.onTap,
    this.showGif = false,
    this.gifPath,
    this.useDynamicStatus = false,
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

  String _getDynamicTitle(ChatProvider? chatProvider) {
    if (!widget.useDynamicStatus) {
      return widget.title ?? 'Emergency System Active';
    }
    
    final isConnected = chatProvider?.isConnected ?? false;
    if (isConnected) {
      return 'Emergency System Active';
    } else {
      return 'Emergency System Standby';
    }
  }

  String _getDynamicMessage(ChatProvider? chatProvider) {
    if (!widget.useDynamicStatus) {
      return widget.message ?? 'Emergency alert system is monitoring for disasters and will automatically notify all users in your area.';
    }
    
    final isConnected = chatProvider?.isConnected ?? false;
    if (isConnected) {
      return 'Emergency alert system is monitoring for disasters and will automatically notify all users in your area. Mesh network is active and ready.';
    } else {
      return 'Emergency alert system is ready. Connect to ESP32 mesh network to enable automatic disaster monitoring and area-wide notifications.';
    }
  }

  String _getDynamicSeverity(ChatProvider? chatProvider) {
    if (!widget.useDynamicStatus) {
      return widget.severity ?? 'High';
    }
    
    final isConnected = chatProvider?.isConnected ?? false;
    return isConnected ? 'High' : 'Medium';
  }

  @override
  Widget build(BuildContext context) {
    // Use app's red theme for emergency
    final emergencyColor = AppColors.primaryRed;
    final chatProvider = widget.useDynamicStatus 
        ? Provider.of<ChatProvider>(context, listen: true)
        : null;
    
    final dynamicTitle = _getDynamicTitle(chatProvider);
    final dynamicMessage = _getDynamicMessage(chatProvider);
    final dynamicSeverity = _getDynamicSeverity(chatProvider);
    
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
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(SoftUIDesign.cardBorderRadius),
                    // Neumorphic dual shadows for depth (animated on press)
                    boxShadow: SoftUIDesign.getCardShadow(elevation: _pressElevationAnimation.value),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
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
                        
                        // Soft overlay for readability (only if GIF shown)
                        if (widget.showGif && widget.gifPath != null)
                          Positioned.fill(
                            child: Container(
                              color: AppColors.white.withOpacity(0.9),
                            ),
                          ),
                        
                        // Main content
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with icon and severity - Neumorphic card style
                              Row(
                                children: [
                              // Icon container - Enhanced with app logo
                              AnimatedBuilder(
                                animation: _iconPulseAnimation,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _iconPulseAnimation.value,
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: AppColors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: emergencyColor.withOpacity(0.2 * (_iconPulseAnimation.value - 1.0) / 0.08),
                                            blurRadius: 12,
                                            spreadRadius: 1,
                                            offset: const Offset(0, 4),
                                          ),
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.04),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: emergencyColor.withOpacity(0.25),
                                          width: 1.5,
                                        ),
                                      ),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: emergencyColor,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: emergencyColor.withOpacity(0.3),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.asset(
                                              'assets/images/app_logo (3).png',
                                              width: 44,
                                              height: 44,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Icon(
                                                  Icons.emergency_rounded,
                                                  color: AppColors.white,
                                                  size: 28,
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
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Title - Single line to prevent splitting
                                    Row(
                                      children: [
                                        Flexible(
                                          flex: 1,
                                          child: Text(
                                            dynamicTitle,
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.textPrimary,
                                              letterSpacing: -0.2,
                                              height: 1.2,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Emergency badge - Compact style
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: emergencyColor,
                                            borderRadius: BorderRadius.circular(10),
                                            boxShadow: SoftUIDesign.getSoftShadow(elevation: 2.0),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: const Text(
                                            'EMERGENCY',
                                            style: TextStyle(
                                              color: AppColors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // Severity badge - Neumorphic style with subtle pulse
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
                                                'Severity: ${dynamicSeverity.toUpperCase()}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: emergencyColor,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                            
                          const SizedBox(height: 24),
                          
                          // Message - Enhanced card style with subtle separator
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Enhanced divider
                              Container(
                                height: 2,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: emergencyColor.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(18),
                                decoration: SoftUIDesign.cardDecoration(
                                  backgroundColor: AppColors.white,
                                  borderRadius: 14,
                                  elevation: 2.0,
                                  borderColor: emergencyColor.withOpacity(0.15),
                                  showBorder: true,
                                ),
                                child: Text(
                                  dynamicMessage,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    height: 1.6,
                                    letterSpacing: -0.1,
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
                                      HapticFeedback.mediumImpact();
                                      widget.onTap!();
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                      decoration: SoftUIDesign.cardDecoration(
                                        backgroundColor: emergencyColor.withOpacity(0.06),
                                        borderRadius: 16,
                                        elevation: 2.0,
                                        borderColor: emergencyColor.withOpacity(0.25),
                                        showBorder: true,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Tap for more information',
                                            style: TextStyle(
                                              color: emergencyColor,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            color: emergencyColor,
                                            size: 18,
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
