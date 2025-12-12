import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../widgets/unified_top_bar.dart';
import '../widgets/solid_divider.dart';
import '../utils/prototype_animations.dart';
import '../widgets/enhanced_skeleton_loaders.dart';
import '../widgets/enhanced_empty_state.dart';
import '../widgets/accessible_text.dart';
import '../widgets/enhanced_search_bar.dart';
import '../utils/search_helper.dart';
import '../utils/icon_system.dart';

class WalkieTalkieScreen extends StatefulWidget {
  const WalkieTalkieScreen({super.key});

  @override
  State<WalkieTalkieScreen> createState() => _WalkieTalkieScreenState();
}

class _WalkieTalkieScreenState extends State<WalkieTalkieScreen>
    with TickerProviderStateMixin {
  // Animations
  late AnimationController _pulseController;
  late AnimationController _recordingController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _recordingAnimation;

  // Filter state
  final String _userFilter = 'All'; // All, Online, Muted
  
  // Pagination
  int _currentPage = 0;
  static const int _itemsPerPage = 5;
  
  // Stagger animations for list
  StaggeredListAnimations? _userListStagger;

  // PTT
  bool _isTransmitting = false;
  Duration _transmissionTime = Duration.zero;
  
  // Loading state
  bool _isLoading = false;

  // Search + Sort
  final TextEditingController _searchCtrl = TextEditingController();
  final String _sortBy = 'Status'; // Status | Name

  // Demo data
  final List<Map<String, dynamic>> _connectedUsers = [
    {
      'id': '1',
      'name': 'John Smith',
      'isActive': true,
      'isMuted': false,
      'isSpeaking': false,
      'voiceLevel': 0.0,
      'role': 'admin',
    },
    {
      'id': '2',
      'name': 'Maria Garcia',
      'isActive': true,
      'isMuted': true,
      'isSpeaking': false,
      'voiceLevel': 0.0,
      'role': 'member',
    },
    {
      'id': '3',
      'name': 'David Lee',
      'isActive': true,
      'isMuted': false,
      'isSpeaking': true,
      'voiceLevel': 0.8,
      'role': 'member',
    },
    {
      'id': '4',
      'name': 'Sarah Johnson',
      'isActive': false,
      'isMuted': false,
      'isSpeaking': false,
      'voiceLevel': 0.0,
      'role': 'member',
    },
  ];

  @override
  void initState() {
    super.initState();
    
    // PTT pulse
    _pulseController =
        AnimationController(duration: const Duration(seconds: 2), vsync: this)
          ..repeat(reverse: true);
    _recordingController =
        AnimationController(duration: const Duration(milliseconds: 420), vsync: this);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _recordingAnimation = Tween<double>(begin: 0.95, end: 1.06).animate(
      CurvedAnimation(parent: _recordingController, curve: Curves.easeInOut),
    );

    _updateUserListStagger();

    _searchCtrl.addListener(() {
    setState(() {
        _currentPage = 0;
        // Update animations when search changes
        _updateUserListStagger();
        _userListStagger?.replay();
      });
    });
  }
  
  void _updateUserListStagger() {
    _userListStagger?.dispose();
    final currentUsers = _getPaginatedUsers();
    _userListStagger = StaggeredListAnimations(
      vsync: this,
      itemCount: currentUsers.length,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _recordingController.dispose();
    _userListStagger?.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ===== Build =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top bar with ON AIR badge
                TopBarConfigs.callsTopBar(
                  status: _isTransmitting ? 'Transmitting...' : null,
                  onRefresh: _refreshConnections,
                  badges: _isTransmitting
                      ? [
                          _buildOnAirBadge(),
                        ]
                      : null,
                ),

                // Scrollable main body (Users panel etc.)
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 180), // Space for fixed controls
                      child: Column(
                        children: [
                          _buildUsersCard(context),
                        ],
                      ),
                    ),
                  ),
                ),

                // Fixed bottom controls (no ON AIR badge here)
                _buildVoiceControls(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ON AIR Badge for top bar
  Widget _buildOnAirBadge() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      constraints: const BoxConstraints(maxHeight: 28), // Constrain height
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE53935).withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              _formatDuration(_transmissionTime),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                height: 1.0,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'ON AIR',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.5,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  // ===== Users List Header & Body =====

  Widget _buildUsersCard(BuildContext context) {
    return Column(
      children: [
        // 1. Stats & Filters Row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats Header
              Row(
                children: [
                  AccessibleHeading(
                    'Active Channels',
                    level: HeadingLevel.h3,
                    color: AppColors.textPrimary,
                    backgroundColor: AppColors.backgroundLight,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.online.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.online,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        AccessibleBodyText(
                          '${_connectedUsers.where((u) => u['isActive'] == true).length} Connected',
                          size: BodySize.small,
                          color: AppColors.online,
                          backgroundColor: AppColors.online.withOpacity(0.1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Enhanced Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: EnhancedSearchBar(
            controller: _searchCtrl,
            hintText: 'Search users...',
            onChanged: (value) {
              setState(() {
                _currentPage = 0;
                _updateUserListStagger();
                _userListStagger?.replay();
              });
            },
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                SearchHelper.saveRecentSearch(value, context: 'walkie_talkie');
              }
            },
            suggestions: _connectedUsers.map((u) => u['name'] as String).toList(),
            showRecentSearches: true,
            searchContext: 'walkie_talkie',
          ),
        ),

        const SizedBox(height: 16),

        // 3. User List
        _buildUsersList(),
        
        // 4. Pagination
        if (_getFilteredSortedSearched().length > _itemsPerPage)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: _buildPaginationControls(),
          ),
      ],
    );
  }



  Widget _buildUsersList() {
    if (_isLoading) {
      return const SkeletonUserList(itemCount: 5);
    }

    final paged = _getPaginatedUsers();

    if (paged.isEmpty) {
      // Determine if it's a search result or no users at all
      final isSearchResult = _searchCtrl.text.isNotEmpty;
      
      if (isSearchResult) {
        return EmptyStatePresets.noSearchResults(
          onClearSearch: () {
            setState(() {
              _searchCtrl.clear();
            });
          },
          searchQuery: _searchCtrl.text,
        );
      } else {
        return EmptyStatePresets.noUsersConnected(
          onRefresh: _refreshConnections,
          onScanDevices: () {
            // Could open device scanner if needed
            _refreshConnections();
          },
        );
      }
    }

    // Use Column with fixed height to enforce pagination (no infinite scroll)
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: paged.length * 80.0, // Approximate height per item
      ),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(), // Disable scrolling - pagination only
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        itemCount: paged.length,
        separatorBuilder: (context, _) =>
            const SolidDivider(indent: 12, endIndent: 12),
        itemBuilder: (context, index) {
          final user = paged[index];

          final userTile = _UserTile(
            name: user['name'] as String,
            isActive: user['isActive'] == true,
            isMuted: user['isMuted'] == true,
            isSpeaking: user['isSpeaking'] == true,
            searchQuery: _searchCtrl.text.trim().isNotEmpty ? _searchCtrl.text.trim() : null,
          );

          if (_userListStagger != null && index < paged.length) {
            return _userListStagger!.buildAnimatedItem(index, userTile);
          }
          
          return userTile;
        },
      ),
    );
  }

  // ===== Voice Controls (Floating & Transparent) =====

  Widget _buildVoiceControls(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main Controls Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Main Mic Button (Center - Large)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTapDown: (_) {
                      HapticFeedback.mediumImpact();
                      _startTransmission();
                    },
                    onTapUp: (_) {
                      HapticFeedback.lightImpact();
                      _stopTransmission();
                    },
                    onTapCancel: () {
                      HapticFeedback.lightImpact();
                      _stopTransmission();
                    },
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_pulseAnimation, _recordingAnimation]),
                      builder: (context, child) {
                        final double scale = _isTransmitting
                            ? _recordingAnimation.value
                            : 1.0;
                        final double pulseScale = _isTransmitting
                            ? 1.0 + (_pulseAnimation.value - 1.0) * 0.5
                            : 1.0;
                        
                        return Transform.scale(
                          scale: scale,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Pulse Effect
                              if (_isTransmitting)
                                Container(
                                  width: 88 * pulseScale,
                                  height: 88 * pulseScale,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE53935).withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              
                              // Main Button
                              Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: _isTransmitting
                                        ? [const Color(0xFFEF5350), const Color(0xFFD32F2F)]
                                        : [const Color(0xFFEF5350).withOpacity(0.8), const Color(0xFFD32F2F).withOpacity(0.8)],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFD32F2F).withOpacity(_isTransmitting ? 0.5 : 0.3),
                                      blurRadius: _isTransmitting ? 20 : 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _isTransmitting ? Icons.mic : Icons.mic_none_rounded,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isTransmitting ? 'Transmitting...' : 'Hold to Speak',
                    style: TextStyle(
                      color: _isTransmitting ? const Color(0xFFE53935) : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== Helpers =====

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final mm = twoDigits(duration.inMinutes.remainder(60));
    final ss = twoDigits(duration.inSeconds.remainder(60));
    return '$mm:$ss';
  }

  void _startTransmission() {
    setState(() => _isTransmitting = true);
    _recordingController.forward();
    _tickTransmission();
  }

  void _tickTransmission() {
    if (!_isTransmitting) return;
    setState(() {
      _transmissionTime = Duration(seconds: _transmissionTime.inSeconds + 1);
    });
    Future.delayed(const Duration(seconds: 1), _tickTransmission);
  }

  void _stopTransmission() {
    setState(() => _isTransmitting = false);
    _recordingController.reverse();
    _transmissionTime = Duration.zero;
  }

  Future<void> _refreshConnections() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      setState(() {
        _isLoading = false;
        // Replay list animations
        _updateUserListStagger();
        _userListStagger?.replay();
      });
    }
  }
  
  // Data helpers (filter + search + sort + paginate)

  List<Map<String, dynamic>> _getFilteredSortedSearched() {
    // Filter
    Iterable<Map<String, dynamic>> base = switch (_userFilter) {
      'Online' => _connectedUsers.where((u) => u['isActive'] == true),
      'Muted' => _connectedUsers.where((u) => u['isMuted'] == true),
      _ => _connectedUsers,
    };

    // Search
    final term = _searchCtrl.text.trim().toLowerCase();
    if (term.isNotEmpty) {
      base = base.where((u) => (u['name'] as String).toLowerCase().contains(term));
    }

    // Sort
    final list = base.toList();
    if (_sortBy == 'Name') {
      list.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    } else {
      // Status: speaking > active > muted > offline
      int score(Map<String, dynamic> u) {
        if (u['isSpeaking'] == true) return 0;
        if (u['isActive'] == true && u['isMuted'] != true) return 1;
        if (u['isMuted'] == true) return 2;
        return 3;
      }

      list.sort((a, b) {
        final s = score(a).compareTo(score(b));
        return s != 0 ? s : (a['name'] as String).compareTo(b['name'] as String);
      });
    }
    return list;
  }

  List<Map<String, dynamic>> _getPaginatedUsers() {
    final list = _getFilteredSortedSearched();
    final totalPages = (list.length / _itemsPerPage).ceil();
    
    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    }
    
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, list.length);
    return list.sublist(startIndex, endIndex);
  }

  int _getTotalPages() => (_getFilteredSortedSearched().length / _itemsPerPage).ceil();

  Widget _buildPaginationControls() {
    final totalPages = _getTotalPages();
    final length = _getFilteredSortedSearched().length;
    
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: AppColors.lightGray.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPageButton(
              icon: Icons.chevron_left_rounded,
              onTap: _currentPage > 0 ? () => _changePage(-1) : null,
              enabled: _currentPage > 0,
            ),
            
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Page ${_currentPage + 1} of $totalPages',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$length Users',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            
            _buildPageButton(
              icon: Icons.chevron_right_rounded,
              onTap: _currentPage < totalPages - 1 ? () => _changePage(1) : null,
              enabled: _currentPage < totalPages - 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageButton({
    required IconData icon,
    required VoidCallback? onTap,
    required bool enabled,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: enabled ? AppColors.primaryRed.withOpacity(0.08) : Colors.grey.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 22,
            color: enabled ? AppColors.primaryRed : Colors.grey.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  void _changePage(int delta) {
    setState(() {
      _currentPage += delta;
      _updateUserListStagger();
      _userListStagger?.replay();
    });
  }
}

// ====== User Tile (Material-leaning, compact, accessible) ======

class _UserTile extends StatefulWidget {
  const _UserTile({
    required this.name,
    required this.isActive,
    required this.isMuted,
    required this.isSpeaking,
    this.searchQuery,
  });

  final String name;
  final bool isActive;
  final bool isMuted;
  final bool isSpeaking;
  final String? searchQuery;

  @override
  State<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<_UserTile> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isSpeaking) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_UserTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking != oldWidget.isSpeaking) {
      if (widget.isSpeaking) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color get _borderColor {
    if (widget.isSpeaking) return const Color(0xFF27AE60);
    if (widget.isMuted) return const Color(0xFFFFA000); // Orange for Muted
    if (widget.isActive) return const Color(0xFFE53935).withOpacity(0.2);
    return const Color(0xFF7F8C8D).withOpacity(0.5);
  }

  Color get _fill {
    if (widget.isSpeaking) return const Color(0xFF27AE60).withOpacity(0.12);
    if (widget.isMuted) return const Color(0xFFFFA000).withOpacity(0.12); // Orange bg for Muted
    if (!widget.isActive) return const Color(0xFF7F8C8D).withOpacity(0.08);
    return Colors.white;
  }

  String get _statusText {
    if (widget.isSpeaking) return 'Speaking';
    if (widget.isMuted) return 'Muted';
    if (widget.isActive) return 'Active';
    return 'Offline';
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initials(widget.name);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: _borderColor, width: widget.isSpeaking || widget.isMuted ? 2.5 : 1.5),
        boxShadow: [
          BoxShadow(
            color: _borderColor.withOpacity(0.2),
            blurRadius: widget.isSpeaking ? 12 : 6,
            offset: const Offset(0, 4),
            spreadRadius: widget.isSpeaking ? 2 : 0,
          ),
        ],
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Enhanced Speaking Pulse Effect with multiple rings
            if (widget.isSpeaking)
              ...List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    final delay = index * 0.3;
                    final adjustedValue = ((_pulseAnimation.value + delay) % 1.0);
                    return Positioned.fill(
                      child: Container(
                        width: 40 * (1.0 + adjustedValue * 0.4),
                        height: 40 * (1.0 + adjustedValue * 0.4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF27AE60).withOpacity(0.2 * (1 - adjustedValue)),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF27AE60).withOpacity(0.3 * (1 - adjustedValue)),
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            
            // Avatar
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: widget.isActive
                    ? const Color(0xFFE53935)
                    : const Color(0xFF7F8C8D),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            
            // Status Dot
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: widget.isSpeaking
                      ? const Color(0xFF27AE60)
                      : widget.isMuted
                          ? const Color(0xFFFFA000)
                          : widget.isActive
                              ? const Color(0xFF27AE60)
                              : const Color(0xFF7F8C8D),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: widget.searchQuery != null && widget.searchQuery!.isNotEmpty
            ? HighlightedText(
                text: widget.name,
                query: widget.searchQuery!,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: widget.isActive ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize: 13,
                ),
              )
            : Text(
                widget.name,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: widget.isActive ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
        subtitle: Text(
          _statusText,
          style: TextStyle(
            fontSize: 11,
            color: widget.isSpeaking
                ? const Color(0xFF27AE60)
                : widget.isMuted
                    ? const Color(0xFFFFA000)
                    : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  static String _initials(String fullName) {
    final parts =
        fullName.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}