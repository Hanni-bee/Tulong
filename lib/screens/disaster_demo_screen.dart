import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../constants/app_colors.dart';

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
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));
    
    _startScenarioDemo();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    _scenarioTimer?.cancel();
    super.dispose();
  }

  void _startScenarioDemo() {
    _scenarioTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (mounted) {
        setState(() {
          _currentScenario = (_currentScenario + 1) % _scenarios.length;
        });
        
        _triggerEmergencyAlert();
      }
    });
  }

  void _triggerEmergencyAlert() {
    setState(() {
      _isEmergencyActive = true;
    });
    
    // Reduced haptic feedback - lighter impact instead of heavy
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(8, 8),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.8),
                blurRadius: 20,
                offset: const Offset(-8, -8),
              ),
            ],
          ),
          child: SafeArea(
            child: Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors.white,
              ),
              child: Row(
                children: [
                  _buildNeumorphicButton(
                    icon: Icons.arrow_back_ios_new,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.warning,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Disaster Demo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Emergency simulation',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildNeumorphicActionButton(
                    icon: Icons.info_outline,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Demo instructions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info,
                        color: Colors.blue,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Interactive Demo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This demo shows how T.U.L.O.N.G works during real disasters. Emergency alerts will appear automatically, or you can trigger them manually.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
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
            
            const SizedBox(height: 32),
            
            // Current scenario info
            _buildScenarioInfo(currentScenario),
            
            const SizedBox(height: 32),
            
            // Manual trigger button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _simulateEmergency,
                icon: const Icon(Icons.warning),
                label: const Text(
                  'Simulate Emergency Alert',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: Colors.red.withOpacity(0.3),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Community response simulation
            _buildCommunityResponse(currentScenario),
            
            const SizedBox(height: 32),
            
            // Safety tips
            _buildSafetyTips(currentScenario),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyAlert(DisasterScenario scenario) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            _isEmergencyActive ? _shakeAnimation.value * 5 : 0.0, // Reduced from 10 to 5
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
                
                // Time remaining
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scenario.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.access_time,
                        color: scenario.color,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Time remaining: ${scenario.timeLeft} minutes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: scenario.color,
                        ),
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
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: scenario.color,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Current Scenario',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'This is how T.U.L.O.N.G would respond to a ${scenario.title.toLowerCase()}. The app automatically sends alerts to all users in the affected area.',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityResponse(DisasterScenario scenario) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
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
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
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

  Widget _buildNeumorphicButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(4, 4),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 8,
            offset: const Offset(-4, -4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Center(
            child: Icon(
              icon,
              color: AppColors.textPrimary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNeumorphicActionButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(3, 3),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 6,
            offset: const Offset(-3, -3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Center(
            child: Icon(
              icon,
              color: AppColors.textSecondary,
              size: 18,
            ),
          ),
        ),
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
