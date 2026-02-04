import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../constants/app_colors.dart';
import '../utils/theme_colors.dart';
import '../constants/app_typography.dart';
import '../widgets/unified_top_bar.dart';
import '../constants/soft_ui_design.dart';

class DisasterDemoScreen extends StatefulWidget {
  const DisasterDemoScreen({super.key});

  @override
  State<DisasterDemoScreen> createState() => _DisasterDemoScreenState();
}

class _DisasterDemoScreenState extends State<DisasterDemoScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;
  
  bool _isEmergencyActive = false;
  int _currentScenario = 0;
  Timer? _scenarioTimer;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  bool _isAutoPlaying = true;
  int _affectedUsers = 0;
  int _responseCount = 0;
  
  final List<DisasterScenario> _scenarios = [
    DisasterScenario(
      title: 'General Emergency',
      description: 'Emergency situation detected in your area',
      severity: 'Critical',
      icon: Icons.emergency,
      color: AppColors.primaryRed,
      disasterGif: 'assets/gifs/disasters/emergency.gif',
      actions: ['Stay alert', 'Follow instructions', 'Contact authorities'],
      timeLeft: 10, // 10 minutes
    ),
    DisasterScenario(
      title: 'Fire Emergency',
      description: 'Fire outbreak detected in nearby area',
      severity: 'Critical',
      icon: Icons.local_fire_department,
      color: Colors.red,
      disasterGif: 'assets/gifs/disasters/fire.gif',
      actions: ['Evacuate immediately', 'Call fire department', 'Stay low to ground'],
      timeLeft: 15, // 15 minutes
    ),
    DisasterScenario(
      title: 'Earthquake Warning',
      description: 'Magnitude 6.5 earthquake detected nearby',
      severity: 'Critical',
      icon: Icons.vibration,
      color: Colors.orange,
      disasterGif: 'assets/gifs/disasters/earthquake.gif',
      actions: ['Drop, Cover, Hold', 'Move to open area', 'Check for injuries'],
      timeLeft: 30, // 30 minutes
    ),
    DisasterScenario(
      title: 'Flood Alert',
      description: 'Heavy rainfall causing flash floods',
      severity: 'High',
      icon: Icons.water_drop,
      color: Colors.blue,
      disasterGif: 'assets/gifs/disasters/flood.gif',
      actions: ['Move to higher ground', 'Avoid flooded areas', 'Stay informed'],
      timeLeft: 60, // 1 hour
    ),
  ];

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03, // Significantly reduced from 1.2 to 1.03 for subtle effect
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut, // Changed from elasticIn for smoother, less jarring animation
    ));
    
    _startScenarioDemo();
    _startCountdown();
    _affectedUsers = 20;
    _responseCount = 12;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    _scenarioTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startScenarioDemo() {
    if (!_isAutoPlaying) return;
    
    _scenarioTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (mounted && _isAutoPlaying) {
        setState(() {
          _currentScenario = (_currentScenario + 1) % _scenarios.length;
        });
        
        _triggerEmergencyAlert();
      }
    });
  }

  void _selectScenario(int index) {
    if (index == _currentScenario) return;
    
    setState(() {
      _currentScenario = index;
      _remainingSeconds = _scenarios[index].timeLeft * 60;
      _affectedUsers = (20 + (index * 5)).clamp(10, 50);
      _responseCount = (_affectedUsers * 0.6).round();
    });
    
    _startCountdown();
    _triggerEmergencyAlert();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _remainingSeconds = _scenarios[_currentScenario].timeLeft * 60;
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _triggerEmergencyAlert() {
    setState(() {
      _isEmergencyActive = true;
      _affectedUsers = (20 + (_currentScenario * 5)).clamp(10, 50);
      _responseCount = (_affectedUsers * 0.6).round();
    });
    
    HapticFeedback.mediumImpact();
    
    // Start animations
    _pulseController.repeat(reverse: true);
    _shakeController.forward().then((_) {
      _shakeController.reset();
    });
    
    // Auto-hide after 5 seconds
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isEmergencyActive = false;
        });
        _pulseController.stop();
        _pulseController.reset();
      }
    });
  }

  void _simulateEmergency() {
    _triggerEmergencyAlert();
  }

  @override
  Widget build(BuildContext context) {
    final currentScenario = _scenarios[_currentScenario];
    
    return Scaffold(
      backgroundColor: ThemeColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            // Unified Top Bar
            UnifiedTopBar(
              title: 'Disaster Simulation',
              subtitle: _isAutoPlaying ? 'Auto-playing' : 'Paused',
              icon: Icons.science_rounded,
              iconColor: AppColors.warning,
              showBackButton: true,
              onBackPressed: () => Navigator.of(context).pop(),
              actions: [
                IconButton(
                  icon: Icon(_isAutoPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: () {
                    setState(() {
                      _isAutoPlaying = !_isAutoPlaying;
                    });
                    if (_isAutoPlaying) {
                      _startScenarioDemo();
                    } else {
                      _scenarioTimer?.cancel();
                    }
                  },
                  tooltip: _isAutoPlaying ? 'Pause' : 'Play',
                ),
              ],
            ),
            
            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Scenario Selector
                    _buildScenarioSelector(),
                    
                    const SizedBox(height: 16),
                    
                    // Statistics Panel
                    _buildStatisticsPanel(),
                    
                    const SizedBox(height: 16),
            
            // Emergency alert simulation
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _isEmergencyActive ? _pulseAnimation.value : 1.0,
                  child: _buildEmergencyAlert(currentScenario),
                );
              },
            ),
            
                    const SizedBox(height: 16),
                    
                    // Current scenario info
                    _buildScenarioInfo(_scenarios[_currentScenario]),
                    
                    const SizedBox(height: 16),
                    
                    // Manual trigger button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _simulateEmergency,
                        icon: const Icon(Icons.sos_rounded),
                        label: const Text(
                          'Trigger Emergency Alert',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 8,
                          shadowColor: AppColors.primaryRed.withOpacity(0.3),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
            
            // Community response simulation
            _buildCommunityResponse(currentScenario),
            
            const SizedBox(height: 32),
            
                    // Safety tips
                    _buildSafetyTips(currentScenario),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SoftUIDesign.cardDecoration(
        context: context,
        backgroundColor: ThemeColors.surface(context),
        borderRadius: SoftUIDesign.cardBorderRadius,
        elevation: 3.0,
        borderColor: AppColors.lightGray.withOpacity(0.3),
        showBorder: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category_rounded, color: AppColors.primaryRed, size: 20),
              const SizedBox(width: 8),
              Text(
                'Select Scenario',
                style: AppTypography.cardTitle.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_scenarios.length, (index) {
              final scenario = _scenarios[index];
              final isSelected = index == _currentScenario;
              return GestureDetector(
                onTap: () => _selectScenario(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? scenario.color.withOpacity(0.15)
                        : AppColors.lightGray.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected 
                          ? scenario.color
                          : AppColors.lightGray.withOpacity(0.3),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        scenario.icon,
                        size: 18,
                        color: isSelected ? scenario.color : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        scenario.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? scenario.color : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsPanel() {
    final responseRate = _affectedUsers > 0 
        ? ((_responseCount / _affectedUsers) * 100).round()
        : 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SoftUIDesign.cardDecoration(
        context: context,
        backgroundColor: ThemeColors.surface(context),
        borderRadius: SoftUIDesign.cardBorderRadius,
        elevation: 3.0,
        borderColor: AppColors.lightGray.withOpacity(0.3),
        showBorder: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_rounded, color: AppColors.info, size: 20),
              const SizedBox(width: 8),
              Text(
                'Simulation Stats',
                style: AppTypography.cardTitle.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.people_rounded,
                  label: 'Affected',
                  value: '$_affectedUsers',
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.check_circle_rounded,
                  label: 'Responses',
                  value: '$_responseCount',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.trending_up_rounded,
                  label: 'Rate',
                  value: '$responseRate%',
                  color: AppColors.info,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyAlert(DisasterScenario scenario) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            _isEmergencyActive ? _shakeAnimation.value * 1.5 : 0.0, // Significantly reduced vibration
            0.0,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: scenario.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: scenario.color,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: scenario.color.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Disaster GIF Display
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: scenario.color.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        // Disaster GIF
                        Positioned.fill(
                          child: Image.asset(
                            scenario.disasterGif,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: scenario.color.withOpacity(0.1),
                                child: Center(
                                  child: Icon(
                                    scenario.icon,
                                    size: 80,
                                    color: scenario.color,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        
                        // Overlay gradient - Reduced opacity for better text readability
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2), // Reduced from 0.4 to 0.2
                            ),
                          ),
                        ),
                        
                        // Content overlay with better background for text readability
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7), // Dark background for text
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: scenario.color.withOpacity(0.8),
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: scenario.color,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    scenario.icon,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        scenario.title,
                                        style: const TextStyle(
                                          fontSize: 16, // Reduced from 18
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black,
                                              blurRadius: 2,
                                              offset: Offset(1, 1),
                                            ),
                                          ],
                                        ),
                                        maxLines: 1, // Prevent text wrapping
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        scenario.description,
                                        style: const TextStyle(
                                          fontSize: 11, // Reduced from 12
                                          color: Colors.white,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black,
                                              blurRadius: 2,
                                              offset: Offset(1, 1),
                                            ),
                                          ],
                                        ),
                                        maxLines: 2, // Allow 2 lines for description
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Flexible( // Changed to Flexible to prevent overflow
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6, // Reduced padding
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: scenario.color,
                                      borderRadius: BorderRadius.circular(10), // Reduced radius
                                    ),
                                    child: Text(
                                      scenario.severity.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8, // Reduced font size
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5, // Added letter spacing
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Real-time Countdown
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scenario.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: scenario.color.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: scenario.color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.timer_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Time Remaining',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatTime(_remainingSeconds),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: scenario.color,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScenarioInfo(DisasterScenario scenario) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SoftUIDesign.cardDecoration(
        context: context,
        backgroundColor: ThemeColors.surface(context),
        borderRadius: SoftUIDesign.cardBorderRadius,
        elevation: 3.0,
        borderColor: scenario.color.withOpacity(0.2),
        showBorder: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scenario.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  scenario.icon,
                  color: scenario.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scenario.title,
                      style: AppTypography.cardTitle.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scenario.description,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: scenario.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  scenario.severity.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'This is how T.U.L.O.N.G would respond to a ${scenario.title.toLowerCase()}. The app automatically sends alerts to all users in the affected area through the mesh network.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityResponse(DisasterScenario scenario) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SoftUIDesign.cardDecoration(
        context: context,
        backgroundColor: ThemeColors.surface(context),
        borderRadius: SoftUIDesign.cardBorderRadius,
        elevation: 3.0,
        borderColor: AppColors.lightGray.withOpacity(0.3),
        showBorder: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.people,
                color: Colors.green,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Community Response',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildResponseItem(
            'Maria Santos',
            'I\'m safe at home. How is everyone else?',
            '2 min ago',
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildResponseItem(
            'Juan Dela Cruz',
            'Need help evacuating elderly neighbor',
            '5 min ago',
            Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildResponseItem(
            'Ana Rodriguez',
            'Emergency supplies available at my house',
            '8 min ago',
            Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildResponseItem(String name, String message, String time, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: color,
                child: Text(
                  name[0],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyTips(DisasterScenario scenario) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SoftUIDesign.cardDecoration(
        context: context,
        backgroundColor: ThemeColors.surface(context),
        borderRadius: SoftUIDesign.cardBorderRadius,
        elevation: 3.0,
        borderColor: AppColors.lightGray.withOpacity(0.3),
        showBorder: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tips_and_updates,
                color: Colors.amber,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Safety Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...scenario.actions.map((action) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: scenario.color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    action,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

}

class DisasterScenario {
  final String title;
  final String description;
  final String severity;
  final IconData icon;
  final Color color;
  final String disasterGif;
  final List<String> actions;
  final int timeLeft;

  DisasterScenario({
    required this.title,
    required this.description,
    required this.severity,
    required this.icon,
    required this.color,
    required this.disasterGif,
    required this.actions,
    required this.timeLeft,
  });
}
