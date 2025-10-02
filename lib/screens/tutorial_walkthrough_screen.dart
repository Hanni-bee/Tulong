import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';

class TutorialWalkthroughScreen extends StatefulWidget {
  const TutorialWalkthroughScreen({super.key});

  @override
  State<TutorialWalkthroughScreen> createState() => _TutorialWalkthroughScreenState();
}

class _TutorialWalkthroughScreenState extends State<TutorialWalkthroughScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  int _currentPage = 0;
  final int _totalPages = 6;

  final List<TutorialPage> _tutorialPages = [
    TutorialPage(
      title: 'Welcome to T.U.L.O.N.G!',
      subtitle: 'Your emergency companion during disasters',
      description: 'Stay connected with your community and get help when you need it most.',
      icon: Icons.emergency,
      color: AppColors.primaryRed,
      lottieAsset: 'assets/lottie/welcome.json',
      disasterGif: 'assets/gifs/disasters/emergency.gif',
      features: ['Real-time emergency alerts', 'Community chat', 'Emergency contacts'],
    ),
    TutorialPage(
      title: 'Emergency Alerts',
      subtitle: 'Stay informed about disasters',
      description: 'Get instant notifications about typhoons, earthquakes, floods, and other emergencies in your area.',
      icon: Icons.warning,
      color: Colors.orange,
      lottieAsset: 'assets/lottie/emergency.json',
      disasterGif: 'assets/gifs/disasters/fire.gif',
      features: ['Weather alerts', 'Disaster warnings', 'Evacuation notices'],
    ),
    TutorialPage(
      title: 'Community Chat',
      subtitle: 'Connect with neighbors',
      description: 'Chat with people in your area to share information, ask for help, or offer assistance.',
      icon: Icons.chat,
      color: Colors.blue,
      lottieAsset: 'assets/lottie/chat.json',
      disasterGif: 'assets/gifs/disasters/earthquake.gif',
      features: ['Global community chat', 'Voice messages (walkie talkie)', 'Real-time messaging'],
    ),
    TutorialPage(
      title: 'Emergency Contacts',
      subtitle: 'Stay connected with family',
      description: 'Add emergency contacts and family members to quickly send messages during disasters.',
      icon: Icons.contacts,
      color: Colors.green,
      lottieAsset: 'assets/lottie/contacts.json',
      disasterGif: 'assets/gifs/disasters/flood.gif',
      features: ['Add family contacts', 'Quick messaging', 'Global chat access'],
    ),
    TutorialPage(
      title: 'Offline Mode',
      subtitle: 'Works even without internet',
      description: 'The app continues to work offline and syncs your messages when connection is restored.',
      icon: Icons.wifi_off,
      color: Colors.purple,
      lottieAsset: 'assets/lottie/offline.json',
      disasterGif: null,
      features: ['Offline messaging', 'Auto-sync', 'Emergency contacts'],
    ),
    TutorialPage(
      title: 'Safety Tips',
      subtitle: 'Be prepared for emergencies',
      description: 'Learn essential safety tips and emergency procedures to keep you and your family safe.',
      icon: Icons.security,
      color: Colors.teal,
      lottieAsset: 'assets/lottie/safety.json',
      disasterGif: null,
      features: ['Emergency procedures', 'Safety checklists', 'First aid tips'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeTutorial();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipTutorial() {
    _completeTutorial();
  }

  Future<void> _completeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_completed', true);
    
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/main');
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    _animationController.reset();
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(),
            
            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _totalPages,
                itemBuilder: (context, index) {
                  return _buildTutorialPage(_tutorialPages[index]);
                },
              ),
            ),
            
            // Navigation buttons
            _buildNavigationButtons(),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_currentPage + 1} of $_totalPages',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton(
                onPressed: _skipTutorial,
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: (_currentPage + 1) / _totalPages,
            backgroundColor: Colors.grey.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              _tutorialPages[_currentPage].color,
            ),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialPage(TutorialPage page) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // Animation container
              Container(
                height: 300,
                width: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: page.color.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // Background with color
                      Container(
                        color: page.color.withOpacity(0.1),
                      ),
                      
                      // Disaster GIF if available
                      if (page.disasterGif != null)
                        Positioned.fill(
                          child: Image.asset(
                            page.disasterGif!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildFallbackContent(page);
                            },
                          ),
                        ),
                      
                      // Simple overlay for better text visibility
                      if (page.disasterGif != null)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                          ),
                        ),
                      
                      // Content overlay
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icon
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: page.color.withOpacity(0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: page.color.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Icon(
                                page.icon,
                                size: 60,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Title
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: page.color,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                page.title,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: page.color,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Title and subtitle
              Text(
                page.title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              Text(
                page.subtitle,
                style: TextStyle(
                  fontSize: 18,
                  color: page.color,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 20),
              
              Text(
                page.description,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              // Features list
              _buildFeaturesList(page.features, page.color),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesList(List<String> features, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
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
              Icon(
                Icons.check_circle,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Key Features:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...features.map((feature) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    feature,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildFallbackContent(TutorialPage page) {
    return Container(
      color: page.color.withOpacity(0.1),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              page.icon,
              size: 80,
              color: page.color,
            ),
            const SizedBox(height: 16),
            Text(
              page.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: page.color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Previous button
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousPage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _tutorialPages[_currentPage].color,
                  side: BorderSide(color: _tutorialPages[_currentPage].color),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Previous',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          
          if (_currentPage > 0) const SizedBox(width: 16),
          
          // Next/Get Started button
          Expanded(
            flex: _currentPage > 0 ? 1 : 2,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: _tutorialPages[_currentPage].color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 8,
                shadowColor: _tutorialPages[_currentPage].color.withOpacity(0.3),
              ),
              child: Text(
                _currentPage == _totalPages - 1 ? 'Get Started' : 'Next',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TutorialPage {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final String lottieAsset;
  final String? disasterGif;
  final List<String> features;

  TutorialPage({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.lottieAsset,
    this.disasterGif,
    required this.features,
  });
}
