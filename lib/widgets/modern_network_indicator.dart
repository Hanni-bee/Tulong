import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../constants/app_colors.dart';

class ModernNetworkIndicator extends StatefulWidget {
  final bool showText;
  final bool showIcon;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const ModernNetworkIndicator({
    super.key,
    this.showText = true,
    this.showIcon = true,
    this.margin,
    this.padding,
  });

  @override
  State<ModernNetworkIndicator> createState() => _ModernNetworkIndicatorState();
}

class _ModernNetworkIndicatorState extends State<ModernNetworkIndicator>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  
  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  bool _isConnected = false;
  final bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _initConnectivity();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    final connectivity = Connectivity();
    final results = await connectivity.checkConnectivity();
    _connectionStatus = results.isNotEmpty ? results.first : ConnectivityResult.none;
    _updateConnectionStatus(_connectionStatus);

    connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
      _updateConnectionStatus(result);
    });
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    setState(() {
      _connectionStatus = result;
      _isConnected = result != ConnectivityResult.none;
    });

    if (_isConnected) {
      _pulseController.stop();
      _fadeController.forward();
      
      // Auto-hide after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _fadeController.reverse();
        }
      });
    } else {
      _pulseController.repeat(reverse: true);
      _fadeController.forward();
    }
  }

  Color _getStatusColor() {
    switch (_connectionStatus) {
      case ConnectivityResult.wifi:
        return AppColors.success;
      case ConnectivityResult.mobile:
        return AppColors.warning;
      case ConnectivityResult.ethernet:
        return AppColors.info;
      case ConnectivityResult.bluetooth:
        return AppColors.statusActive;
      case ConnectivityResult.vpn:
        return AppColors.mediumGray;
      case ConnectivityResult.other:
        return AppColors.mediumGray;
      case ConnectivityResult.none:
        return AppColors.error;
    }
  }

  String _getStatusText() {
    switch (_connectionStatus) {
      case ConnectivityResult.wifi:
        return 'WiFi Connected';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet Connected';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth Connected';
      case ConnectivityResult.vpn:
        return 'VPN Connected';
      case ConnectivityResult.other:
        return 'Connected';
      case ConnectivityResult.none:
        return 'No Connection';
    }
  }

  IconData _getStatusIcon() {
    switch (_connectionStatus) {
      case ConnectivityResult.wifi:
        return Icons.wifi;
      case ConnectivityResult.mobile:
        return Icons.signal_cellular_alt;
      case ConnectivityResult.ethernet:
        return Icons.settings_ethernet;
      case ConnectivityResult.bluetooth:
        return Icons.bluetooth;
      case ConnectivityResult.vpn:
        return Icons.vpn_lock;
      case ConnectivityResult.other:
        return Icons.network_check;
      case ConnectivityResult.none:
        return Icons.wifi_off;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible && _isConnected) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _fadeController]),
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            margin: widget.margin ?? const EdgeInsets.all(16),
            padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getStatusColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _getStatusColor().withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _getStatusColor().withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showIcon) ...[
                  Transform.scale(
                    scale: _isConnected ? 1.0 : _pulseAnimation.value,
                    child: Icon(
                      _getStatusIcon(),
                      color: _getStatusColor(),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (widget.showText) ...[
                  Text(
                    _getStatusText(),
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class ModernNetworkStatusBar extends StatelessWidget {
  final Widget child;
  final bool showIndicator;
  final bool showText;
  final bool showIcon;

  const ModernNetworkStatusBar({
    super.key,
    required this.child,
    this.showIndicator = false,
    this.showText = true,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (showIndicator)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ModernNetworkIndicator(
              showText: showText,
              showIcon: showIcon,
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
      ],
    );
  }
}
