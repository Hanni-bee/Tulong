import 'dart:io';

/// Script to help migrate all TextStyle instances to UnifiedTypography
/// This script provides patterns and utilities for consistent typography migration
class TypographyMigration {
  
  /// Common patterns to replace in the codebase
  static final Map<String, String> replacementPatterns = {
    // Display styles
    r"TextStyle\(\s*fontSize:\s*48,\s*fontWeight:\s*FontWeight\.w900[^)]*\)": "UnifiedTypography.displayXLarge",
    r"TextStyle\(\s*fontSize:\s*36,\s*fontWeight:\s*FontWeight\.w[89]00[^)]*\)": "UnifiedTypography.displayLarge",
    r"TextStyle\(\s*fontSize:\s*28,\s*fontWeight:\s*FontWeight\.w[78]00[^)]*\)": "UnifiedTypography.displayMedium",
    r"TextStyle\(\s*fontSize:\s*24,\s*fontWeight:\s*FontWeight\.w[67]00[^)]*\)": "UnifiedTypography.displaySmall",
    
    // Headline styles
    r"TextStyle\(\s*fontSize:\s*22,\s*fontWeight:\s*FontWeight\.w[67]00[^)]*\)": "UnifiedTypography.headlineLarge",
    r"TextStyle\(\s*fontSize:\s*20,\s*fontWeight:\s*FontWeight\.w[56]00[^)]*\)": "UnifiedTypography.headlineMedium",
    r"TextStyle\(\s*fontSize:\s*18,\s*fontWeight:\s*FontWeight\.w[56]00[^)]*\)": "UnifiedTypography.headlineSmall",
    
    // Title styles
    r"TextStyle\(\s*fontSize:\s*16,\s*fontWeight:\s*FontWeight\.w[56]00[^)]*\)": "UnifiedTypography.titleLarge",
    r"TextStyle\(\s*fontSize:\s*14,\s*fontWeight:\s*FontWeight\.w[56]00[^)]*\)": "UnifiedTypography.titleMedium",
    r"TextStyle\(\s*fontSize:\s*12,\s*fontWeight:\s*FontWeight\.w[56]00[^)]*\)": "UnifiedTypography.titleSmall",
    
    // Body styles
    r"TextStyle\(\s*fontSize:\s*16,\s*fontWeight:\s*FontWeight\.w[34]00[^)]*\)": "UnifiedTypography.bodyLarge",
    r"TextStyle\(\s*fontSize:\s*14,\s*fontWeight:\s*FontWeight\.w[34]00[^)]*\)": "UnifiedTypography.bodyMedium",
    r"TextStyle\(\s*fontSize:\s*12,\s*fontWeight:\s*FontWeight\.w[34]00[^)]*\)": "UnifiedTypography.bodySmall",
    
    // Label styles
    r"TextStyle\(\s*fontSize:\s*14,\s*fontWeight:\s*FontWeight\.w[45]00[^)]*\)": "UnifiedTypography.labelLarge",
    r"TextStyle\(\s*fontSize:\s*12,\s*fontWeight:\s*FontWeight\.w[45]00[^)]*\)": "UnifiedTypography.labelMedium",
    r"TextStyle\(\s*fontSize:\s*10,\s*fontWeight:\s*FontWeight\.w[45]00[^)]*\)": "UnifiedTypography.labelSmall",
  };

  /// Specific patterns for common UI elements
  static final Map<String, String> specificPatterns = {
    // App titles
    r"TextStyle\(\s*fontSize:\s*32,\s*fontWeight:\s*FontWeight\.bold[^)]*\)": "UnifiedTypography.displayLarge",
    r"TextStyle\(\s*fontSize:\s*24,\s*fontWeight:\s*FontWeight\.bold[^)]*\)": "UnifiedTypography.displaySmall",
    
    // Page titles
    r"TextStyle\(\s*fontSize:\s*20,\s*fontWeight:\s*FontWeight\.w[67]00[^)]*\)": "UnifiedTypography.headlineMedium",
    r"TextStyle\(\s*fontSize:\s*18,\s*fontWeight:\s*FontWeight\.w[67]00[^)]*\)": "UnifiedTypography.headlineSmall",
    
    // Section headers
    r"TextStyle\(\s*fontSize:\s*16,\s*fontWeight:\s*FontWeight\.w[67]00[^)]*\)": "UnifiedTypography.titleLarge",
    r"TextStyle\(\s*fontSize:\s*14,\s*fontWeight:\s*FontWeight\.w[67]00[^)]*\)": "UnifiedTypography.titleMedium",
    
    // Body text
    r"TextStyle\(\s*fontSize:\s*16,\s*fontWeight:\s*FontWeight\.w[34]00[^)]*\)": "UnifiedTypography.bodyLarge",
    r"TextStyle\(\s*fontSize:\s*14,\s*fontWeight:\s*FontWeight\.w[34]00[^)]*\)": "UnifiedTypography.bodyMedium",
    r"TextStyle\(\s*fontSize:\s*12,\s*fontWeight:\s*FontWeight\.w[34]00[^)]*\)": "UnifiedTypography.bodySmall",
    
    // Form elements
    r"TextStyle\(\s*fontSize:\s*14,\s*fontWeight:\s*FontWeight\.w[56]00[^)]*\)": "UnifiedTypography.formLabel",
    r"TextStyle\(\s*fontSize:\s*16,\s*fontWeight:\s*FontWeight\.w[45]00[^)]*\)": "UnifiedTypography.formInput",
    
    // Error messages
    r"TextStyle\(\s*fontSize:\s*12,\s*fontWeight:\s*FontWeight\.w[45]00[^)]*\)": "UnifiedTypography.errorText",
  };

  /// Files that need typography updates (priority order)
  static const List<String> priorityFiles = [
    'lib/screens/main_navigation.dart',
    'lib/screens/modern_home_screen.dart',
    'lib/screens/modern_profile_screen.dart',
    'lib/screens/user_info_screen.dart',
    'lib/screens/auth/sign_in_screen.dart',
    'lib/screens/auth/sign_in_screen_simple.dart',
    'lib/screens/setup/address_setup_screen.dart',
    'lib/screens/update_profile_screen.dart',
    'lib/screens/modern_people_screen.dart',
    'lib/screens/modern_global_chat_screen.dart',
    'lib/screens/notifications_screen.dart',
    'lib/screens/calls_screen.dart',
    'lib/screens/messages_screen.dart',
  ];

  /// Common text style patterns that should be replaced
  static const List<Map<String, String>> commonReplacements = [
    // App titles
    {
      'pattern': r"TextStyle\(\s*fontSize:\s*32,\s*fontWeight:\s*FontWeight\.bold[^)]*\)",
      'replacement': 'UnifiedTypography.displayLarge',
    },
    {
      'pattern': r"TextStyle\(\s*fontSize:\s*24,\s*fontWeight:\s*FontWeight\.bold[^)]*\)",
      'replacement': 'UnifiedTypography.displaySmall',
    },
    
    // Page titles
    {
      'pattern': r"TextStyle\(\s*fontSize:\s*20,\s*fontWeight:\s*FontWeight\.w[67]00[^)]*\)",
      'replacement': 'UnifiedTypography.headlineMedium',
    },
    {
      'pattern': r"TextStyle\(\s*fontSize:\s*18,\s*fontWeight:\s*FontWeight\.w[67]00[^)]*\)",
      'replacement': 'UnifiedTypography.headlineSmall',
    },
    
    // Section headers
    {
      'pattern': r"TextStyle\(\s*fontSize:\s*16,\s*fontWeight:\s*FontWeight\.w[67]00[^)]*\)",
      'replacement': 'UnifiedTypography.titleLarge',
    },
    {
      'pattern': r"TextStyle\(\s*fontSize:\s*14,\s*fontWeight:\s*FontWeight\.w[67]00[^)]*\)",
      'replacement': 'UnifiedTypography.titleMedium',
    },
    
    // Body text
    {
      'pattern': r"TextStyle\(\s*fontSize:\s*16,\s*fontWeight:\s*FontWeight\.w[34]00[^)]*\)",
      'replacement': 'UnifiedTypography.bodyLarge',
    },
    {
      'pattern': r"TextStyle\(\s*fontSize:\s*14,\s*fontWeight:\s*FontWeight\.w[34]00[^)]*\)",
      'replacement': 'UnifiedTypography.bodyMedium',
    },
    {
      'pattern': r"TextStyle\(\s*fontSize:\s*12,\s*fontWeight:\s*FontWeight\.w[34]00[^)]*\)",
      'replacement': 'UnifiedTypography.bodySmall',
    },
  ];

  /// Get the import statement for UnifiedTypography
  static String getImportStatement() {
    return "import '../constants/unified_typography.dart';";
  }

  /// Check if a file already has the UnifiedTypography import
  static bool hasUnifiedTypographyImport(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return false;
      
      final content = file.readAsStringSync();
      return content.contains("unified_typography.dart");
    } catch (e) {
      return false;
    }
  }

  /// Add UnifiedTypography import to a file if not present
  static void addImportIfNeeded(String filePath) {
    if (hasUnifiedTypographyImport(filePath)) return;
    
    try {
      final file = File(filePath);
      if (!file.existsSync()) return;
      
      final content = file.readAsStringSync();
      final lines = content.split('\n');
      
      // Find the last import statement
      int lastImportIndex = -1;
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].trim().startsWith('import ')) {
          lastImportIndex = i;
        }
      }
      
      if (lastImportIndex != -1) {
        lines.insert(lastImportIndex + 1, getImportStatement());
        file.writeAsStringSync(lines.join('\n'));
      }
    } catch (e) {
      print('Error adding import to $filePath: $e');
    }
  }
}
