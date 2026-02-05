import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../services/model_integration_test.dart';

/// Widget that shows a button to run model integration tests
class ModelTestButton extends StatelessWidget {
  const ModelTestButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.bug_report, color: AppColors.primaryRed),
      tooltip: 'Run Model Integration Test',
      onPressed: () => _runTest(context),
    );
  }

  Future<void> _runTest(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Run comprehensive test
      final results = await ModelIntegrationTest.runFullTest();

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Show results
      if (context.mounted) {
        _showResults(context, results);
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showResults(BuildContext context, Map<String, dynamic> results) {
    final overallStatus = results['overallStatus'] as String;
    final canClassify = results['canClassify'] as bool? ?? false;
    final errors = results['errors'] as List<dynamic>;
    final tests = results['tests'] as Map<String, dynamic>;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    canClassify ? Icons.check_circle : Icons.error,
                    color: canClassify ? AppColors.success : AppColors.error,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Model Integration Test',
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: canClassify
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: canClassify ? AppColors.success : AppColors.error,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      canClassify ? Icons.check_circle : Icons.error,
                      color: canClassify ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Status: ${overallStatus.toUpperCase()}\n'
                        'Can Classify: ${canClassify ? "YES ✅" : "NO ❌"}',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: canClassify ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Test Results:',
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...tests.entries.map((entry) {
                        final testName = entry.key;
                        final testResult = entry.value as Map<String, dynamic>;
                        final passed = testResult['success'] == true ||
                            testResult['valid'] == true ||
                            testResult['exists'] == true;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                passed ? Icons.check : Icons.close,
                                size: 16,
                                color: passed ? AppColors.success : AppColors.error,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  testName,
                                  style: AppTypography.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (errors.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Errors:',
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...errors.map((error) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '• $error',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.error,
                                ),
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
