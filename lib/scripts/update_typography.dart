import 'dart:io';

/// Comprehensive script to update all TextStyle instances to UnifiedTypography
void main() async {
  print('🎨 Starting Typography Migration...');
  
  // List of critical files to update
  final criticalFiles = [
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

  for (final filePath in criticalFiles) {
    await updateFileTypography(filePath);
  }
  
  print('✅ Typography migration completed!');
}

/// Update typography in a specific file
Future<void> updateFileTypography(String filePath) async {
  try {
    final file = File(filePath);
    if (!file.existsSync()) {
      print('⚠️  File not found: $filePath');
      return;
    }

    String content = await file.readAsString();
    String originalContent = content;
    
    // Add import if not present
    if (!content.contains('unified_typography.dart')) {
      content = addUnifiedTypographyImport(content);
    }
    
    // Replace common TextStyle patterns
    content = replaceCommonTextStyles(content);
    
    if (content != originalContent) {
      await file.writeAsString(content);
      print('✅ Updated: $filePath');
    } else {
      print('⏭️  No changes needed: $filePath');
    }
  } catch (e) {
    print('❌ Error updating $filePath: $e');
  }
}

/// Add UnifiedTypography import to file content
String addUnifiedTypographyImport(String content) {
  final lines = content.split('\n');
  int lastImportIndex = -1;
  
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].trim().startsWith('import ')) {
      lastImportIndex = i;
    }
  }
  
  if (lastImportIndex != -1) {
    lines.insert(lastImportIndex + 1, "import '../constants/unified_typography.dart';");
    return lines.join('\n');
  }
  
  return content;
}

/// Replace common TextStyle patterns with UnifiedTypography
String replaceCommonTextStyles(String content) {
  // Common patterns to replace
  final replacements = [
    // App titles
    {
      'pattern': RegExp(r'TextStyle\(\s*fontSize:\s*32,\s*fontWeight:\s*FontWeight\.bold[^)]*\)'),
      'replacement': 'UnifiedTypography.displayLarge',
    },
    {
      'pattern': RegExp(r'TextStyle\(\s*fontSize:\s*24,\s*fontWeight:\s*FontWeight\.bold[^)]*\)'),
      'replacement': 'UnifiedTypography.displaySmall',
    },
    
    // Page titles
    {
      'pattern': RegExp(r'TextStyle\(\s*fontSize:\s*20,\s*fontWeight:\s*FontWeight\.w[67]00[^)]*\)'),
      'replacement': 'UnifiedTypography.headlineMedium',
    },
    {
      'pattern': RegExp(r'TextStyle\(\s*fontSize:\s*18,\s*fontWeight:\s*FontWeight\.w[67]00[^)]*\)'),
      'replacement': 'UnifiedTypography.headlineSmall',
    },
    
    // Section headers
    {
      'pattern': RegExp(r'TextStyle\(\s*fontSize:\s*16,\s*fontWeight:\s*FontWeight\.w[67]00[^)]*\)'),
      'replacement': 'UnifiedTypography.titleLarge',
    },
    {
      'pattern': RegExp(r'TextStyle\(\s*fontSize:\s*14,\s*fontWeight:\s*FontWeight\.w[67]00[^)]*\)'),
      'replacement': 'UnifiedTypography.titleMedium',
    },
    
    // Body text
    {
      'pattern': RegExp(r'TextStyle\(\s*fontSize:\s*16,\s*fontWeight:\s*FontWeight\.w[34]00[^)]*\)'),
      'replacement': 'UnifiedTypography.bodyLarge',
    },
    {
      'pattern': RegExp(r'TextStyle\(\s*fontSize:\s*14,\s*fontWeight:\s*FontWeight\.w[34]00[^)]*\)'),
      'replacement': 'UnifiedTypography.bodyMedium',
    },
    {
      'pattern': RegExp(r'TextStyle\(\s*fontSize:\s*12,\s*fontWeight:\s*FontWeight\.w[34]00[^)]*\)'),
      'replacement': 'UnifiedTypography.bodySmall',
    },
    
    // Labels
    {
      'pattern': RegExp(r'TextStyle\(\s*fontSize:\s*14,\s*fontWeight:\s*FontWeight\.w[45]00[^)]*\)'),
      'replacement': 'UnifiedTypography.labelLarge',
    },
    {
      'pattern': RegExp(r'TextStyle\(\s*fontSize:\s*12,\s*fontWeight:\s*FontWeight\.w[45]00[^)]*\)'),
      'replacement': 'UnifiedTypography.labelMedium',
    },
    
    // Buttons
    {
      'pattern': RegExp(r'TextStyle\(\s*fontSize:\s*16,\s*fontWeight:\s*FontWeight\.w[56]00[^)]*\)'),
      'replacement': 'UnifiedTypography.buttonLarge',
    },
    {
      'pattern': RegExp(r'TextStyle\(\s*fontSize:\s*14,\s*fontWeight:\s*FontWeight\.w[56]00[^)]*\)'),
      'replacement': 'UnifiedTypography.buttonMedium',
    },
    
    // Error messages
    {
      'pattern': RegExp(r'TextStyle\(\s*fontSize:\s*12,\s*fontWeight:\s*FontWeight\.w[45]00[^)]*\)'),
      'replacement': 'UnifiedTypography.errorText',
    },
  ];
  
  for (final replacement in replacements) {
    content = content.replaceAll(replacement['pattern'] as RegExp, replacement['replacement'] as String);
  }
  
  return content;
}
