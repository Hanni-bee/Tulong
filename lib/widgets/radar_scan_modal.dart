import 'package:flutter/material.dart';

/// Radar Scan Modal for device discovery
class RadarScanModal extends StatelessWidget {
  final VoidCallback? onPairedDevicesTap;

  const RadarScanModal({
    super.key,
    this.onPairedDevicesTap,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Radar Scan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (onPairedDevicesTap != null)
              ElevatedButton(
                onPressed: onPairedDevicesTap,
                child: const Text('Show Paired Devices'),
              ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
