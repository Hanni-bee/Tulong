import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../constants/soft_ui_design.dart';
import '../widgets/unified_top_bar.dart';
import '../utils/custom_scroll_physics.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
  
  // Scroll controller for enhanced scroll behavior
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;
  
  final List<DisasterScenario> _scenarios = [
    DisasterScenario(
      title: 'General Emergency',
      description: 'Emergency situation detected in your area. All users will be notified through the mesh network.',
      severity: 'Critical',
      icon: Icons.emergency_rounded,
      color: AppColors.primaryRed,
      disasterGif: 'assets/gifs/disasters/emergency.gif',
      actions: [
        'Stay alert and monitor updates',
        'Follow emergency instructions',
        'Contact local authorities if needed',
        'Check on neighbors and family',
      ],
      timeLeft: 10, // 10 minutes
    ),
    DisasterScenario(
      title: 'Fire Emergency',
      description: 'Fire outbreak detected in nearby area. Immediate evacuation may be required.',
      severity: 'Critical',
      icon: Icons.local_fire_department_rounded,
      color: Colors.red.shade700,
      disasterGif: 'assets/gifs/disasters/fire.gif',
      actions: [
        'Evacuate immediately if in danger zone',
        'Call fire department (911)',
        'Stay low to ground to avoid smoke',
        'Do not use elevators during fire',
      ],
      timeLeft: 15, // 15 minutes
    ),
    DisasterScenario(
      title: 'Earthquake Warning',
      description: 'Seismic activity detected. Magnitude 6.5 earthquake detected nearby.',
      severity: 'Critical',
      icon: Icons.vibration_rounded,
      color: Colors.orange.shade700,
      disasterGif: 'assets/gifs/disasters/earthquake.gif',
      actions: [
        'Drop, Cover, and Hold On',
        'Move to open area away from buildings',
        'Check for injuries and help others',
        'Avoid damaged structures',
      ],
      timeLeft: 30, // 30 minutes
    ),
    DisasterScenario(
      title: 'Flood Alert',
      description: 'Heavy rainfall causing flash floods. Water levels rising rapidly.',
      severity: 'High',
      icon: Icons.water_drop_rounded,
      color: Colors.blue.shade700,
      disasterGif: 'assets/gifs/disasters/flood.gif',
      actions: [
        'Move to higher ground immediately',
        'Avoid walking or driving through floodwaters',
        'Stay informed about water levels',
        'Secure important documents and supplies',
      ],
      timeLeft: 60, // 1 hour
    ),
  ];

  @override
  void initState() {
    super.initState();
    
    // Listen to scroll position for scroll-to-top button
    _scrollController.addListener(_onScroll);
    
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

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final shouldShow = _scrollController.offset > 400;
    if (shouldShow != _showScrollToTop) {
      setState(() {
        _showScrollToTop = shouldShow;
      });
    }
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    HapticFeedback.lightImpact();
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _refreshData() async {
    HapticFeedback.mediumImpact();
    // Refresh scenario data if needed
    await Future.delayed(const Duration(milliseconds: 800));
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
          children: [
            // Unified Top Bar
            UnifiedTopBar(
              title: 'Emergency Monitoring',
              icon: Icons.emergency_rounded,
              iconColor: AppColors.primaryRed,
              showBackButton: true,
              onBackPressed: () => Navigator.of(context).pop(),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: _isAutoPlaying 
                        ? AppColors.primaryRed.withOpacity(0.1)
                        : AppColors.lightGray.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isAutoPlaying 
                          ? AppColors.primaryRed.withOpacity(0.3)
                          : AppColors.lightGray.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isAutoPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: _isAutoPlaying ? AppColors.primaryRed : AppColors.textSecondary,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isAutoPlaying = !_isAutoPlaying;
                      });
                      if (_isAutoPlaying) {
                        _startScenarioDemo();
                      } else {
                        _scenarioTimer?.cancel();
                      }
                    },
                    tooltip: _isAutoPlaying ? 'Pause simulation' : 'Start simulation',
                  ),
                ),
              ],
            ),
            
            // Main Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshData,
                color: AppColors.primaryRed,
                backgroundColor: Colors.white,
                displacement: 60,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const EnhancedScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // System Overview Card
                    _buildSystemOverview(),
                    
                    const SizedBox(height: 20),
                    
                    // Scenario Selector
                    _buildScenarioSelector(),
                    
                    const SizedBox(height: 20),
                    
                    // Statistics Panel
                    _buildStatisticsPanel(),
                    
                    const SizedBox(height: 20),
            
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
            
                    const SizedBox(height: 20),
                    
                    // Current scenario info
                    _buildScenarioInfo(_scenarios[_currentScenario]),
                    
                    const SizedBox(height: 20),
                    
                    // Manual trigger button
                    Container(
                      width: double.infinity,
                      decoration: SoftUIDesign.buttonDecoration(
                        backgroundColor: AppColors.primaryRed,
                        borderRadius: 18,
                        shadowColor: AppColors.primaryRed,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            _simulateEmergency();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.sos_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Trigger Emergency Alert',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
            
            // Community response simulation
            _buildCommunityResponse(currentScenario),
            
            const SizedBox(height: 32),
            
                    // Safety tips
                    _buildSafetyTips(currentScenario),
                  ],
                ),
              ),
              ),
            ),
          ],
        ),
          ),
          // Scroll-to-top button  
          if (_showScrollToTop)
            Positioned(
              bottom: 100,
              right: 20,
              child: FloatingActionButton.small(
                onPressed: _scrollToTop,
                backgroundColor: AppColors.primaryRed,
                child: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
              ).animate()
                  .fadeIn(duration: 200.ms)
                  .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
            ),
        ],
      ),
    );
  }

  Widget _buildSystemOverview() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: SoftUIDesign.cardDecoration(
        backgroundColor: AppColors.white,
        borderRadius: 28,
        elevation: 4.0,
        borderColor: AppColors.primaryRed.withOpacity(0.2),
        showBorder: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: SoftUIDesign.getCardShadow(elevation: 4.0),
                  border: Border.all(
                    color: AppColors.primaryRed.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/app_logo (3).png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.emergency_rounded,
                        color: Colors.white,
                        size: 32,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'T.U.L.O.N.G Emergency System',
                      style: AppTypography.cardTitle.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '24/7 Disaster Monitoring',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: SoftUIDesign.cardDecoration(
              backgroundColor: AppColors.white,
              borderRadius: 20,
              elevation: 2.0,
              borderColor: AppColors.lightGray.withOpacity(0.3),
              showBorder: true,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.info,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'The emergency alert system continuously monitors for disasters and automatically notifies all users in your area through the mesh network. This simulation demonstrates how the system responds to different emergency scenarios.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.7,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioSelector() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: SoftUIDesign.cardDecoration(
        backgroundColor: AppColors.white,
        borderRadius: 28,
        elevation: 4.0,
        borderColor: AppColors.lightGray.withOpacity(0.3),
        showBorder: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryRed.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.category_rounded,
                  color: AppColors.primaryRed,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Emergency Scenarios',
                style: AppTypography.cardTitle.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
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
                onTap: () {
                  HapticFeedback.selectionClick();
                  _selectScenario(index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: SoftUIDesign.cardDecoration(
                    backgroundColor: AppColors.white,
                    borderRadius: 18,
                    elevation: isSelected ? 4.0 : 2.0,
                    borderColor: isSelected 
                        ? scenario.color.withOpacity(0.4)
                        : AppColors.lightGray.withOpacity(0.3),
                    showBorder: true,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? scenario.color.withOpacity(0.2)
                              : AppColors.lightGray.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          scenario.icon,
                          size: 18,
                          color: isSelected ? scenario.color : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        scenario.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? scenario.color : AppColors.textSecondary,
                          letterSpacing: -0.2,
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
      padding: const EdgeInsets.all(24),
      decoration: SoftUIDesign.cardDecoration(
        backgroundColor: AppColors.white,
        borderRadius: 28,
        elevation: 4.0,
        borderColor: AppColors.lightGray.withOpacity(0.3),
        showBorder: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.info.withOpacity(0.25),
                    width: 1.5,
                  ),
                  boxShadow: SoftUIDesign.getSoftShadow(elevation: 2.0),
                ),
                child: Icon(
                  Icons.analytics_rounded,
                  color: AppColors.info,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Network Statistics',
                style: AppTypography.cardTitle.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.people_rounded,
                  label: 'Users Affected',
                  value: '$_affectedUsers',
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.check_circle_rounded,
                  label: 'Responses',
                  value: '$_responseCount',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.trending_up_rounded,
                  label: 'Response Rate',
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
      padding: const EdgeInsets.all(18),
      decoration: SoftUIDesign.cardDecoration(
        backgroundColor: AppColors.white,
        borderRadius: 20,
        elevation: 3.0,
        borderColor: color.withOpacity(0.25),
        showBorder: true,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: color.withOpacity(0.25),
                width: 1.5,
              ),
              boxShadow: SoftUIDesign.getSoftShadow(elevation: 2.0),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.2,
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
            padding: const EdgeInsets.all(28),
            decoration: SoftUIDesign.cardDecoration(
              backgroundColor: AppColors.white,
              borderRadius: 24,
              elevation: 5.0,
              borderColor: scenario.color.withOpacity(0.4),
              showBorder: true,
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
                
                // Real-time Countdown - Enhanced
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: SoftUIDesign.cardDecoration(
                    backgroundColor: AppColors.white,
                    borderRadius: 20,
                    elevation: 3.0,
                    borderColor: scenario.color.withOpacity(0.3),
                    showBorder: true,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scenario.color,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: SoftUIDesign.getCardShadow(elevation: 3.0),
                          border: Border.all(
                            color: scenario.color.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.timer_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Time Remaining',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTime(_remainingSeconds),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: scenario.color,
                              fontFeatures: [FontFeature.tabularFigures()],
                              letterSpacing: 1.0,
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
      padding: const EdgeInsets.all(28),
      decoration: SoftUIDesign.cardDecoration(
        backgroundColor: AppColors.white,
        borderRadius: 28,
        elevation: 4.0,
        borderColor: scenario.color.withOpacity(0.25),
        showBorder: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scenario.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scenario.color.withOpacity(0.25),
                    width: 1.5,
                  ),
                  boxShadow: SoftUIDesign.getSoftShadow(elevation: 2.0),
                ),
                child: Icon(
                  scenario.icon,
                  color: scenario.color,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scenario.title,
                      style: AppTypography.cardTitle.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      scenario.description,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.6,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityResponse(DisasterScenario scenario) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: SoftUIDesign.cardDecoration(
        backgroundColor: AppColors.white,
        borderRadius: 28,
        elevation: 4.0,
        borderColor: AppColors.lightGray.withOpacity(0.3),
        showBorder: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.25),
                    width: 1.5,
                  ),
                  boxShadow: SoftUIDesign.getSoftShadow(elevation: 2.0),
                ),
                child: Icon(
                  Icons.people_rounded,
                  color: Colors.green.shade700,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Community Response',
                style: AppTypography.cardTitle.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
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
      padding: const EdgeInsets.all(28),
      decoration: SoftUIDesign.cardDecoration(
        backgroundColor: AppColors.white,
        borderRadius: 28,
        elevation: 4.0,
        borderColor: AppColors.lightGray.withOpacity(0.3),
        showBorder: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.amber.withOpacity(0.25),
                    width: 1.5,
                  ),
                  boxShadow: SoftUIDesign.getSoftShadow(elevation: 2.0),
                ),
                child: Icon(
                  Icons.tips_and_updates_rounded,
                  color: Colors.amber.shade700,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Recommended Safety Actions',
                style: AppTypography.cardTitle.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...scenario.actions.map((action) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: SoftUIDesign.cardDecoration(
                backgroundColor: AppColors.white,
                borderRadius: 20,
                elevation: 3.0,
                borderColor: scenario.color.withOpacity(0.25),
                showBorder: true,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scenario.color,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: SoftUIDesign.getCardShadow(elevation: 3.0),
                      border: Border.all(
                        color: scenario.color.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      action,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
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
