import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../utils/theme_colors.dart';
import '../widgets/animated_loader.dart';
import '../widgets/micro_interactions.dart';
import '../widgets/parallax_scroll.dart';
import '../widgets/interactive_elements.dart' as ie;
import '../widgets/custom_transitions.dart' as custom_transitions;
import '../constants/app_icons.dart' as app_icons;

class AnimationDemoScreen extends StatefulWidget {
  const AnimationDemoScreen({super.key});

  @override
  State<AnimationDemoScreen> createState() => _AnimationDemoScreenState();
}

class _AnimationDemoScreenState extends State<AnimationDemoScreen>
    with TickerProviderStateMixin {
  late AnimationController _demoController;
  bool _isLoading = false;
  bool _showSuccess = false;
  bool _showError = false;
  bool _showEmpty = false;

  @override
  void initState() {
    super.initState();
    _demoController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _demoController.forward();
  }

  @override
  void dispose() {
    _demoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.background(context),
      appBar: AppBar(
        title: const Text('🎨 Animation Demo'),
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ParallaxScrollView(
        children: [
          // Header Section
          _buildHeader(),
          
          // Lottie Animations Section
          _buildLottieSection(),
          
          // Micro-interactions Section
          _buildMicroInteractionsSection(),
          
          // Interactive Elements Section
          _buildInteractiveElementsSection(),
          
          // Custom Transitions Section
          _buildTransitionsSection(),
          
          // Parallax Demo Section
          _buildParallaxDemo(),
          
          // Custom Icons Section
          _buildCustomIconsSection(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedText(
            'Design & Animation Enhancements',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: ThemeColors.textPrimary(context),
            ),
            type: AnimatedTextType.typewriter,
          ),
          const SizedBox(height: 16),
          AnimatedText(
            'Experience the power of beautiful animations and micro-interactions',
            style: TextStyle(
              fontSize: 16,
              color: ThemeColors.textSecondary(context),
            ),
            type: AnimatedTextType.fade,
          ),
        ],
      ),
    );
  }

  Widget _buildLottieSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎭 Lottie Animations',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ThemeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAnimationButton(
                'Loading',
                () => setState(() {
                  _isLoading = !_isLoading;
                  _showSuccess = false;
                  _showError = false;
                  _showEmpty = false;
                }),
                AppColors.info,
              ),
              _buildAnimationButton(
                'Success',
                () => setState(() {
                  _showSuccess = !_showSuccess;
                  _isLoading = false;
                  _showError = false;
                  _showEmpty = false;
                }),
                AppColors.success,
              ),
              _buildAnimationButton(
                'Error',
                () => setState(() {
                  _showError = !_showError;
                  _isLoading = false;
                  _showSuccess = false;
                  _showEmpty = false;
                }),
                AppColors.error,
              ),
              _buildAnimationButton(
                'Empty',
                () => setState(() {
                  _showEmpty = !_showEmpty;
                  _isLoading = false;
                  _showSuccess = false;
                  _showError = false;
                }),
                AppColors.mediumGray,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const AnimatedLoader(
              message: 'Loading amazing content...',
              size: 120,
            ),
          if (_showSuccess)
            SuccessAnimation(
              message: 'Operation completed successfully!',
              onComplete: () => setState(() => _showSuccess = false),
            ),
          if (_showError)
            ErrorAnimation(
              message: 'Something went wrong!',
              onComplete: () => setState(() => _showError = false),
            ),
          if (_showEmpty)
            EmptyStateAnimation(
              message: 'No data available',
              subtitle: 'Try refreshing or check your connection',
              actionText: 'Refresh',
              onAction: () => setState(() => _showEmpty = false),
            ),
        ],
      ),
    );
  }

  Widget _buildMicroInteractionsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎯 Micro-interactions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ThemeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              MicroInteractionButton(
                onTap: () => HapticFeedback.lightImpact(),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              BounceWidget(
                autoStart: true,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              ShakeWidget(
                child: GestureDetector(
                  onTap: () {
                  // Shake animation will be triggered by the widget itself
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.warning,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
              GlowWidget(
                autoStart: true,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.info,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.star,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveElementsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎮 Interactive Elements',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ThemeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 16),
          ie.InteractiveCard(
            onTap: () => HapticFeedback.mediumImpact(),
            backgroundColor: AppColors.primaryRed.withOpacity(0.1),
            child: const Column(
              children: [
                Icon(Icons.touch_app, size: 32, color: AppColors.primaryRed),
                SizedBox(height: 8),
                Text(
                  'Tap me!',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryRed,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ie.InteractiveButton(
                text: 'Animated Button',
                onPressed: () => HapticFeedback.lightImpact(),
                backgroundColor: AppColors.primaryRed,
                icon: Icons.play_arrow,
              ),
              InteractiveSwitch(
                value: true,
                onChanged: (value) => HapticFeedback.lightImpact(),
                activeColor: AppColors.success,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransitionsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎬 Custom Transitions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ThemeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTransitionButton('Slide Right', custom_transitions.SlideDirection.right),
              _buildTransitionButton('Slide Left', custom_transitions.SlideDirection.left),
              _buildTransitionButton('Slide Up', custom_transitions.SlideDirection.up),
              _buildTransitionButton('Slide Down', custom_transitions.SlideDirection.down),
              _buildTransitionButton('Fade', null),
              _buildTransitionButton('Scale', null),
              _buildTransitionButton('Rotate', null),
              _buildTransitionButton('Bounce', null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParallaxDemo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🌊 Parallax Scrolling',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ThemeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (context, index) {
                return Container(
                  width: 150,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryRed.withOpacity(0.3),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Parallax Card ${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryRed,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomIconsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎨 Custom Icons',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ThemeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              app_icons.AnimatedIcon(
                app_icons.AppIcons.disaster,
                size: 32,
                color: AppColors.primaryRed,
              ),
              app_icons.AnimatedIcon(
                app_icons.AppIcons.emergency,
                size: 32,
                color: AppColors.error,
              ),
              app_icons.AnimatedIcon(
                app_icons.AppIcons.network,
                size: 32,
                color: AppColors.info,
              ),
              app_icons.AnimatedIcon(
                app_icons.AppIcons.radio,
                size: 32,
                color: AppColors.warning,
              ),
              app_icons.PulsingIcon(
                app_icons.AppIcons.sos,
                size: 32,
                color: AppColors.error,
              ),
              app_icons.PulsingIcon(
                app_icons.AppIcons.online,
                size: 32,
                color: AppColors.success,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimationButton(String text, VoidCallback onTap, Color color) {
    return ie.InteractiveButton(
      text: text,
      onPressed: onTap,
      backgroundColor: color,
    );
  }

  Widget _buildTransitionButton(String text, custom_transitions.SlideDirection? direction) {
    return ie.InteractiveButton(
      text: text,
      onPressed: () {
        if (direction != null) {
          Navigator.of(context).push(
            custom_transitions.CustomSlideTransition(
              direction: direction,
              child: _buildDemoPage(text),
            ),
          );
        } else {
          // Handle other transition types
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => _buildDemoPage(text),
            ),
          );
        }
      },
      backgroundColor: AppColors.primaryRed,
    );
  }

  Widget _buildDemoPage(String title) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.animation,
              size: 64,
              color: AppColors.primaryRed,
            ),
            const SizedBox(height: 16),
            Text(
              '$title Transition',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: ThemeColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This page demonstrates the custom transition effect.',
              style: TextStyle(
                color: ThemeColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 24),
            ie.InteractiveButton(
              text: 'Go Back',
              onPressed: () => Navigator.of(context).pop(),
              backgroundColor: AppColors.primaryRed,
            ),
          ],
        ),
      ),
    );
  }
}
