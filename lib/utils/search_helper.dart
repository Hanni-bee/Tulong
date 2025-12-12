import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Search Helper Utility
/// 
/// Provides:
/// - Recent searches management
/// - Search suggestions/autocomplete
/// - Search result highlighting
class SearchHelper {
  static const String _recentSearchesKey = 'recent_searches';
  static const int _maxRecentSearches = 10;

  // ============================================================================
  // RECENT SEARCHES
  // ============================================================================

  /// Save a search query to recent searches
  static Future<void> saveRecentSearch(String query, {String? context}) async {
    if (query.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final key = context != null ? '${_recentSearchesKey}_$context' : _recentSearchesKey;
    final recentSearches = await getRecentSearches(context: context);

    // Remove if already exists
    recentSearches.remove(query.trim());

    // Add to beginning
    recentSearches.insert(0, query.trim());

    // Limit to max
    if (recentSearches.length > _maxRecentSearches) {
      recentSearches.removeRange(_maxRecentSearches, recentSearches.length);
    }

    await prefs.setStringList(key, recentSearches);
  }

  /// Get recent searches
  static Future<List<String>> getRecentSearches({String? context}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = context != null ? '${_recentSearchesKey}_$context' : _recentSearchesKey;
    return prefs.getStringList(key) ?? [];
  }

  /// Clear recent searches
  static Future<void> clearRecentSearches({String? context}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = context != null ? '${_recentSearchesKey}_$context' : _recentSearchesKey;
    await prefs.remove(key);
  }

  // ============================================================================
  // SEARCH SUGGESTIONS/AUTOCOMPLETE
  // ============================================================================

  /// Get search suggestions based on query and available items
  static List<String> getSuggestions(
    String query,
    List<String> availableItems, {
    int maxSuggestions = 5,
  }) {
    if (query.trim().isEmpty) {
      return availableItems.take(maxSuggestions).toList();
    }

    final lowerQuery = query.toLowerCase();
    final suggestions = availableItems
        .where((item) => item.toLowerCase().contains(lowerQuery))
        .take(maxSuggestions)
        .toList();

    // Sort by relevance (exact match first, then starts with, then contains)
    suggestions.sort((a, b) {
      final aLower = a.toLowerCase();
      final bLower = b.toLowerCase();

      if (aLower == lowerQuery) return -1;
      if (bLower == lowerQuery) return 1;
      if (aLower.startsWith(lowerQuery)) return -1;
      if (bLower.startsWith(lowerQuery)) return 1;
      return 0;
    });

    return suggestions;
  }

  // ============================================================================
  // SEARCH RESULT HIGHLIGHTING
  // ============================================================================

  /// Highlight search query in text
  static List<TextSpan> highlightText(String text, String query) {
    if (query.trim().isEmpty) {
      return [TextSpan(text: text)];
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        // Add remaining text
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }

      // Add text before match
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          backgroundColor: Color(0xFFFFEB3B),
          color: Colors.black87,
        ),
      ));

      start = index + query.length;
    }

    return spans;
  }

  // ============================================================================
  // SEARCH FILTERING
  // ============================================================================

  /// Filter items based on search query
  static List<T> filterItems<T>(
    List<T> items,
    String query,
    String Function(T) getSearchableText, {
    bool caseSensitive = false,
  }) {
    if (query.trim().isEmpty) {
      return items;
    }

    final lowerQuery = caseSensitive ? query : query.toLowerCase();

    return items.where((item) {
      final searchableText = getSearchableText(item);
      final lowerText = caseSensitive ? searchableText : searchableText.toLowerCase();
      return lowerText.contains(lowerQuery);
    }).toList();
  }

  /// Filter items with multiple search terms
  static List<T> filterItemsWithTerms<T>(
    List<T> items,
    String query,
    String Function(T) getSearchableText,
  ) {
    if (query.trim().isEmpty) {
      return items;
    }

    final terms = query
        .toLowerCase()
        .split(' ')
        .where((term) => term.isNotEmpty)
        .toList();

    return items.where((item) {
      final searchableText = getSearchableText(item).toLowerCase();
      return terms.every((term) => searchableText.contains(term));
    }).toList();
  }
}

