import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/search_helper.dart';
import '../utils/icon_system.dart';

/// Enhanced Search Bar Widget
/// 
/// Provides:
/// - Search suggestions/autocomplete
/// - Recent searches
/// - Search filters
/// - Search result highlighting
/// - Voice search (optional)
class EnhancedSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final VoidCallback? onClear;
  final List<String>? suggestions;
  final bool showRecentSearches;
  final String? searchContext;
  final bool enableVoiceSearch;
  final VoidCallback? onVoiceSearch;
  final List<SearchFilter>? filters;
  final void Function(SearchFilter)? onFilterChanged;
  final bool enabled;

  const EnhancedSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.suggestions,
    this.showRecentSearches = true,
    this.searchContext,
    this.enableVoiceSearch = false,
    this.onVoiceSearch,
    this.filters,
    this.onFilterChanged,
    this.enabled = true,
  });

  @override
  State<EnhancedSearchBar> createState() => _EnhancedSearchBarState();
}

class _EnhancedSearchBarState extends State<EnhancedSearchBar> {
  final FocusNode _focusNode = FocusNode();
  bool _showSuggestions = false;
  List<String> _recentSearches = [];
  List<String> _filteredSuggestions = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _filterSuggestions();
    });
  }

  void _onFocusChanged() {
    setState(() {
      _showSuggestions = _focusNode.hasFocus;
    });
  }

  void _filterSuggestions() {
    final query = widget.controller.text;
    if (query.isEmpty) {
      _filteredSuggestions = [];
    } else if (widget.suggestions != null) {
      _filteredSuggestions = SearchHelper.getSuggestions(
        query,
        widget.suggestions!,
      );
    }
  }

  Future<void> _loadRecentSearches() async {
    final recent = await SearchHelper.getRecentSearches(
      context: widget.searchContext,
    );
    setState(() {
      _recentSearches = recent;
    });
  }

  void _onSuggestionTap(String suggestion) {
    widget.controller.text = suggestion;
    widget.onChanged?.call(suggestion);
    widget.onSubmitted?.call(suggestion);
    _focusNode.unfocus();
    setState(() {
      _showSuggestions = false;
    });
    SearchHelper.saveRecentSearch(suggestion, context: widget.searchContext);
  }

  void _onRecentSearchTap(String recent) {
    widget.controller.text = recent;
    widget.onChanged?.call(recent);
    widget.onSubmitted?.call(recent);
    _focusNode.unfocus();
    setState(() {
      _showSuggestions = false;
    });
  }

  void _clearSearch() {
    widget.controller.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
    setState(() {
      _showSuggestions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            onChanged: (value) {
              widget.onChanged?.call(value);
              _filterSuggestions();
            },
            onSubmitted: (value) {
              widget.onSubmitted?.call(value);
              if (value.trim().isNotEmpty) {
                SearchHelper.saveRecentSearch(value, context: widget.searchContext);
              }
              _focusNode.unfocus();
              setState(() {
                _showSuggestions = false;
              });
            },
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              prefixIcon: Icon(
                IconSystem.search,
                color: AppColors.textSecondary,
                size: 20,
              ),
              suffixIcon: _buildSuffixIcon(),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.lightGray,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.lightGray,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primaryRed,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),

        // Filters (if provided)
        if (widget.filters != null && widget.filters!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.filters!.map((filter) {
              return FilterChip(
                label: Text(filter.label),
                selected: filter.isSelected,
                onSelected: (selected) {
                  widget.onFilterChanged?.call(filter.copyWith(isSelected: selected));
                },
                avatar: filter.icon != null
                    ? Icon(filter.icon, size: 16)
                    : null,
              );
            }).toList(),
          ),
        ],

        // Suggestions dropdown
        if (_showSuggestions && (_filteredSuggestions.isNotEmpty || _recentSearches.isNotEmpty))
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView(
              shrinkWrap: true,
              children: [
                // Suggestions
                if (_filteredSuggestions.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Suggestions',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  ..._filteredSuggestions.map((suggestion) {
                    return ListTile(
                      leading: Icon(
                        IconSystem.search,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      title: Text(suggestion),
                      onTap: () => _onSuggestionTap(suggestion),
                      dense: true,
                    );
                  }),
                ],

                // Recent searches
                if (widget.showRecentSearches && _recentSearches.isNotEmpty) ...[
                  if (_filteredSuggestions.isNotEmpty)
                    const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Searches',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await SearchHelper.clearRecentSearches(
                              context: widget.searchContext,
                            );
                            _loadRecentSearches();
                          },
                          child: const Text(
                            'Clear',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._recentSearches.map((recent) {
                    return ListTile(
                      leading: Icon(
                        IconSystem.time,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      title: Text(recent),
                      onTap: () => _onRecentSearchTap(recent),
                      dense: true,
                    );
                  }),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget? _buildSuffixIcon() {
    if (widget.controller.text.isNotEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.enableVoiceSearch)
            IconButton(
              icon: Icon(
                IconSystem.mic,
                size: 20,
                color: AppColors.textSecondary,
              ),
              onPressed: widget.onVoiceSearch,
            ),
          IconButton(
            icon: Icon(
              IconSystem.close,
              size: 20,
              color: AppColors.textSecondary,
            ),
            onPressed: _clearSearch,
          ),
        ],
      );
    } else if (widget.enableVoiceSearch) {
      return IconButton(
        icon: Icon(
          IconSystem.mic,
          size: 20,
          color: AppColors.textSecondary,
        ),
        onPressed: widget.onVoiceSearch,
      );
    }
    return null;
  }
}

/// Search Filter Model
class SearchFilter {
  final String id;
  final String label;
  final IconData? icon;
  final bool isSelected;

  const SearchFilter({
    required this.id,
    required this.label,
    this.icon,
    this.isSelected = false,
  });

  SearchFilter copyWith({
    String? id,
    String? label,
    IconData? icon,
    bool? isSelected,
  }) {
    return SearchFilter(
      id: id ?? this.id,
      label: label ?? this.label,
      icon: icon ?? this.icon,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

/// Highlighted Text Widget
/// 
/// Displays text with highlighted search query
class HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  final TextAlign? textAlign;

  const HighlightedText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final spans = SearchHelper.highlightText(text, query);
    return RichText(
      text: TextSpan(
        style: style ?? const TextStyle(color: AppColors.textPrimary),
        children: spans,
      ),
      textAlign: textAlign ?? TextAlign.start,
    );
  }
}

