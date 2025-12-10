import 'package:flutter/material.dart';
import 'dart:async';
import '../constants/app_colors.dart';

class RadarScanModal extends StatefulWidget {
  final VoidCallback onPairedDevicesTap;
  
  const RadarScanModal({super.key, required this.onPairedDevicesTap});

  @override
  State<RadarScanModal> createState() => _RadarScanModalState();
}

class _RadarScanModalState extends State<RadarScanModal> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _scanStatus = 'Scanning for nearby devices...';
  Timer? _statusTimer;

  final List<String> _statusMessages = [
    'Scanning for nearby devices...',
    'Looking for mesh nodes...',
    'Analyzing signal strength...',
    'Discovering available channels...',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Cycle scan status text
    int index = 0;
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      setState(() {
        index = (index + 1) % _statusMessages.length;
        _scanStatus = _statusMessages[index];
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Scanning Area',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _scanStatus,
                key: ValueKey<String>(_scanStatus),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
            
            // Radar Animation
            SizedBox(
              height: 200,
              width: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _buildRipple(0),
                  _buildRipple(0.33),
                  _buildRipple(0.66),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryRed.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.radar,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Manual Pair Button
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onPairedDevicesTap();
              },
              icon: const Icon(Icons.bluetooth),
              label: const Text('View Paired Devices'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.lightGray),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRipple(double startValue) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double t = (_controller.value + startValue) % 1.0;
        final double size = 200 * t;
        final double opacity = 1.0 - t;
        
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primaryRed.withOpacity(opacity),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}

