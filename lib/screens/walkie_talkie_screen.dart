import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../constants/soft_ui_design.dart';
import '../widgets/unified_top_bar.dart';
import '../widgets/solid_modal_header.dart';
import '../widgets/solid_divider.dart';
import '../utils/prototype_animations.dart';

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

  // Users drawer state (dropdown)
  bool _usersExpanded = true;
  String _userFilter = 'All'; // All, Online, Muted

  late final AnimationController _usersController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..value = 1.0;

  late final Animation<double> _usersExpandAnim = CurvedAnimation(
    parent: _usersController,
    curve: Curves.easeInOutCubic,
  );
  
  // Pagination
  int _currentPage = 0;
  static const int _itemsPerPage = 5;
  
  // Stagger animations for list
  StaggeredListAnimations? _userListStagger;
  // Stagger animations for filter chips
  late final List<AnimationController> _filterChipControllers = [];
  late final List<Animation<double>> _filterChipAnimations = [];

  // PTT
  bool _isTransmitting = false;
  bool _isListening = false;
  Duration _transmissionTime = Duration.zero;
  
  // Emergency long-press
  late AnimationController _emergencyHoldController;
  bool _isEmergencyHolding = false;

  // Search + Sort
  final TextEditingController _searchCtrl = TextEditingController();
  String _sortBy = 'Status'; // Status | Name

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

    _emergencyHoldController =
        AnimationController(duration: const Duration(milliseconds: 1200), vsync: this)
          ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          HapticFeedback.heavyImpact();
          _isEmergencyHolding = false;
          _emergencyHoldController.reset();
          _sendEmergencyAlert();
        }
      });
    
    _initializeStaggerAnimations();
    
    // Trigger animations on initial load if expanded
    if (_usersExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerStaggerAnimations();
    });
    }

    _searchCtrl.addListener(() {
    setState(() {
        _currentPage = 0;
        // Update animations when search changes
        _updateUserListStagger();
        _userListStagger?.replay();
      });
    });
  }
  
  void _initializeStaggerAnimations() {
    // Dispose old animations if they exist
    _userListStagger?.dispose();
    
    // Initialize filter chip animations
    for (final controller in _filterChipControllers) {
      controller.dispose();
    }
    _filterChipControllers.clear();
    _filterChipAnimations.clear();
    
    // Create filter chip animations (3 chips: All, Online, Muted)
    for (int i = 0; i < 3; i++) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      );
      final animation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
      _filterChipControllers.add(controller);
      _filterChipAnimations.add(animation);
    }
    
    // Initialize user list stagger animations
    _updateUserListStagger();
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
    _emergencyHoldController.dispose();
    _usersController.dispose();
    _userListStagger?.dispose();
    for (final controller in _filterChipControllers) {
      controller.dispose();
    }
    _searchCtrl.dispose();
    super.dispose();
  }

  // ===== Build =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            TopBarConfigs.callsTopBar(
              status: _isTransmitting ? 'Transmitting...' : null,
              onRefresh: _refreshConnections,
              onSettings: _showSettingsDialog,
            ),

            // Scrollable main body (Users panel etc.)
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                      _buildUsersCard(context),
                    ],
                  ),
                ),
              ),
            ),

            // Fixed bottom controls
            _buildVoiceControls(context),
          ],
        ),
      ),
    );
  }

  // ===== Users Card (Dropdown) =====

  Widget _buildUsersCard(BuildContext context) {
    final totalActive =
        _connectedUsers.where((u) => u['isActive'] == true).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                      decoration: SoftUIDesign.cardDecoration(
                        backgroundColor: AppColors.white,
                        borderRadius: SoftUIDesign.cardBorderRadius,
                        elevation: 4.0,
                        borderColor: AppColors.primaryRed.withOpacity(0.2),
                        showBorder: true,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Column(
                          children: [
            // Header (tappable to expand/collapse)
                            Material(
              color: const Color(0xFFE53935),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _usersExpanded = !_usersExpanded;
                                    if (_usersExpanded) {
                                      _usersController.forward();
                      // Trigger staggered animations when expanding
                      _triggerStaggerAnimations();
                                    } else {
                                      _usersController.reverse();
                                    }
                                  });
                                },
                splashColor: Colors.white.withOpacity(0.12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                          color: AppColors.white,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.people, color: Color(0xFFE53935), size: 15),
                                      ),
                      const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                            // Title with live count
                            Row(
                              children: [
                                const Text(
                                  'Users',
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                                  ),
                                const SizedBox(width: 8),
                                _badge(
                                  '$totalActive/${_connectedUsers.length}',
                                  background: Colors.white.withOpacity(0.22),
                                  foreground: Colors.white,
                                ),
                                                ],
                                              ),
                            const SizedBox(height: 2),
                            const Text(
                              'Emergency',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                      AnimatedRotation(
                        duration: const Duration(milliseconds: 220),
                        turns: _usersExpanded ? 0 : 0.5,
                        child: const Icon(Icons.expand_more, color: AppColors.white),
                      ),
                                ],
                              ),
                            ),
              ),
            ),

            // Body (animated drop)
                          SizeTransition(
                            sizeFactor: _usersExpandAnim,
                            axisAlignment: -1.0,
                              child: Column(
                                children: [
                  const SizedBox(height: 10),

                  // Filter + Search + Sort Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 8,
                      spacing: 8,
                                                    children: [
                        _buildAnimatedFilterChip('All', 0),
                        _buildAnimatedFilterChip('Online', 1),
                        _buildAnimatedFilterChip('Muted', 2),
                        const SizedBox(width: 4),
                        _searchField(),
                        const SizedBox(width: 4),
                        _sortMenu(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  const SolidDivider(indent: 12, endIndent: 12),
                  const SizedBox(height: 4),

                  // List (capped height so bottom controls stay visible)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.42,
                    ),
                    child: _buildUsersList(),
                  ),

                  // Pagination
                  if (_getFilteredSortedSearched().length > _itemsPerPage)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                      child: _buildPaginationControls(),
                                                        ),
                ],
                                                      ),
            ),
                                                    ],
                                                ),
                                              ),
                                            );
  }

  Widget _searchField() {
    return SizedBox(
      width: 200,
      child: TextField(
        controller: _searchCtrl,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search users',
          prefixIcon: const Icon(Icons.search, size: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
      ),
    );
  }

  Widget _sortMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Sort',
      onSelected: (value) => setState(() => _sortBy = value),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'Status', child: Text('Sort by Status')),
        PopupMenuItem(value: 'Name', child: Text('Sort by Name')),
      ],
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: SoftUIDesign.cardDecoration(
          backgroundColor: Colors.white,
          borderRadius: 10,
          elevation: 2,
          borderColor: AppColors.lightGray.withOpacity(0.3),
          showBorder: true,
                                            ),
                                            child: Row(
          mainAxisSize: MainAxisSize.min,
                                              children: [
            const Icon(Icons.sort, size: 18, color: Colors.black87),
            const SizedBox(width: 6),
            Text(
              _sortBy,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.expand_more, size: 16),
          ],
        ),
      ),
    );
  }

  void _triggerStaggerAnimations() {
    // Trigger filter chip animations
    for (int i = 0; i < _filterChipControllers.length; i++) {
      _filterChipControllers[i].reset();
      Future.delayed(Duration(milliseconds: i * 80), () {
        _filterChipControllers[i].forward();
      });
    }
    
    // Update and trigger user list animations
    _updateUserListStagger();
    _userListStagger?.replay();
  }

  Widget _buildAnimatedFilterChip(String label, int index) {
    if (index >= _filterChipAnimations.length) {
      return _filterChip(label);
    }
    
    return FadeTransition(
      opacity: _filterChipAnimations[index],
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-0.1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _filterChipControllers[index],
          curve: Curves.easeOutCubic,
        )),
        child: _filterChip(label),
      ),
    );
  }

  Widget _filterChip(String label) {
    final isSelected = _userFilter == label;

    final count = label == 'All'
        ? _connectedUsers.length
        : label == 'Online'
            ? _connectedUsers.where((u) => u['isActive'] == true).length
            : _connectedUsers.where((u) => u['isMuted'] == true).length;

    return GestureDetector(
      onTap: () {
        setState(() {
          _userFilter = label;
          _currentPage = 0;
          // Update animations when filter changes
          _updateUserListStagger();
          _userListStagger?.replay();
        });
      },
                                                      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: SoftUIDesign.cardDecoration(
          backgroundColor:
              isSelected ? AppColors.primaryRed : Colors.transparent,
          borderRadius: 10,
          elevation: isSelected ? 3 : 0,
          borderColor: isSelected
              ? AppColors.primaryRed
              : AppColors.lightGray.withOpacity(0.35),
          showBorder: true,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            _badge(
              '$count',
              background: isSelected
                  ? Colors.white.withOpacity(0.25)
                  : const Color(0xFFE53935).withOpacity(0.15),
              foreground: isSelected ? Colors.white : const Color(0xFFE53935),
                                                    ),
                                                  ],
                                                ),
      ),
    );
  }

  Widget _buildUsersList() {
    final paged = _getPaginatedUsers();

    if (paged.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
                                                  child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.search_off, size: 28, color: Colors.black38),
              SizedBox(height: 8),
                                                          Text(
                'No matching users',
                                                            style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                                                            ),
                                                          ),
              SizedBox(height: 4),
                                                      Text(
                'Try a different filter or keyword.',
                style: TextStyle(color: Colors.black45),
                                                      ),
                                                    ],
                                                  ),
                                                ),
      );
    }

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      itemCount: paged.length,
      separatorBuilder: (context, _) =>
          const SolidDivider(indent: 12, endIndent: 12),
      itemBuilder: (context, index) {
        final user = paged[index];

        if (_userListStagger != null && index < paged.length) {
          return _userListStagger!.buildAnimatedItem(
            index,
            _UserTile(
              name: user['name'] as String,
              isActive: user['isActive'] == true,
              isMuted: user['isMuted'] == true,
              isSpeaking: user['isSpeaking'] == true,
            ),
          );
        }
        
        return _UserTile(
          name: user['name'] as String,
          isActive: user['isActive'] == true,
          isMuted: user['isMuted'] == true,
          isSpeaking: user['isSpeaking'] == true,
        );
      },
                                      );
  }

  // ===== Voice Controls (fixed bottom) =====

  Widget _buildVoiceControls(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                      padding: const EdgeInsets.all(12),
                      decoration: SoftUIDesign.cardDecoration(
                        backgroundColor: AppColors.white,
                        borderRadius: SoftUIDesign.cardBorderRadius,
                        elevation: 4.0,
                        borderColor: AppColors.primaryRed.withOpacity(0.2),
                        showBorder: true,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final double availableHeight = constraints.maxHeight;
          final bool isCompact = availableHeight < 280;

          final double micSize = isCompact
              ? (availableHeight * 0.28).clamp(58.0, 72.0)
              : (availableHeight * 0.30).clamp(65.0, 84.0);
          final double btnSize = isCompact
              ? (availableHeight * 0.14).clamp(32.0, 42.0)
              : (availableHeight * 0.16).clamp(36.0, 50.0);
                          
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
              // Header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                        Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryRed,
                      borderRadius:
                          BorderRadius.circular(SoftUIDesign.buttonBorderRadius),
                                            boxShadow: SoftUIDesign.getSoftShadow(
                                              elevation: 2.0,
                                              shadowColor: AppColors.primaryRed.withOpacity(0.3),
                                            ),
                                          ),
                    child: const Icon(Icons.radio, color: Colors.white, size: 13),
                                          ),
                  const SizedBox(width: 8),
                                        const Text(
                                          'Voice Controls',
                                          style: TextStyle(
                                            fontSize: 14,
                      fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                              ),
              const SizedBox(height: 8),

              // Mic button (press & hold)
              Center(
                                        child: SizedBox(
                  width: micSize,
                  height: micSize,
                                          child: GestureDetector(
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
                                              animation: _pulseAnimation,
                                              builder: (context, child) {
                        final double scale = _isTransmitting
                            ? _recordingAnimation.value
                            : _pulseAnimation.value;
                                                return Transform.scale(
                          scale: scale,
                          child: DecoratedBox(
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFE53935),
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                color: Colors.white.withOpacity(0.22),
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: Stack(
                                                      alignment: Alignment.center,
                                                      children: [
                                Icon(Icons.mic,
                                    color: Colors.white, size: micSize * 0.34),
                                                        if (_isTransmitting)
                                                          Positioned(
                                    top: 18,
                                    right: 18,
                                                            child: Container(
                                                              width: 16,
                                                              height: 16,
                                                              decoration: const BoxDecoration(
                                        color: Colors.white,
                                                                shape: BoxShape.circle,
                                                              ),
                                                              child: const Icon(
                                                                Icons.radio_button_checked,
                                                                color: Color(0xFFE53935),
                                                                size: 12,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
              const SizedBox(height: 10),
                              
              // Controls row
                              Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                  // Listen toggle
                  Tooltip(
                    message: _isListening ? 'Disable Listen' : 'Enable Listen',
                    child: InkResponse(
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            _toggleListening();
                                          },
                      radius: 30,
                                          child: Container(
                        width: btnSize,
                        height: btnSize,
                                            decoration: BoxDecoration(
                                              color: _isListening 
                                                  ? const Color(0xFF27AE60)
                                                  : const Color(0xFF7F8C8D),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white.withOpacity(0.3),
                                                width: 2,
                                              ),
                                            ),
                        child: Icon(
                                                  _isListening ? Icons.volume_up : Icons.volume_off,
                          color: Colors.white,
                          size: 22,
                                                ),
                                            ),
                                          ),
                                        ),
                                        
                  // Emergency (hold)
                  Tooltip(
                    message: 'Hold to send Emergency Alert',
                    child: GestureDetector(
                                          onLongPressStart: (_) {
                                            HapticFeedback.selectionClick();
                                            setState(() => _isEmergencyHolding = true);
                                            _emergencyHoldController.forward(from: 0);
                                          },
                                          onLongPressEnd: (_) {
                        if (_emergencyHoldController.status !=
                            AnimationStatus.completed) {
                          _emergencyHoldController.reverse(
                            from: _emergencyHoldController.value,
                          );
                                            }
                                            setState(() => _isEmergencyHolding = false);
                                          },
                                          onLongPressCancel: () {
                        _emergencyHoldController.reverse(
                          from: _emergencyHoldController.value,
                        );
                                            setState(() => _isEmergencyHolding = false);
                                          },
                                          child: SizedBox(
                        width: btnSize + 18,
                        height: btnSize + 18,
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                SizedBox(
                              width: btnSize + 12,
                              height: btnSize + 12,
                                                  child: AnimatedBuilder(
                                                    animation: _emergencyHoldController,
                                                    builder: (context, _) => CircularProgressIndicator(
                                  value: _isEmergencyHolding
                                      ? _emergencyHoldController.value
                                      : 0,
                                                      strokeWidth: 6,
                                  backgroundColor:
                                      const Color(0xFFE53935).withOpacity(0.12),
                                  valueColor: const AlwaysStoppedAnimation(
                                      Color(0xFFE53935)),
                                                    ),
                                                  ),
                                                ),
                                                Container(
                              width: btnSize,
                              height: btnSize,
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFE53935),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: Colors.white.withOpacity(0.3),
                                                      width: 2,
                                                    ),
                                                  ),
                              child: const Icon(Icons.emergency,
                                  color: Colors.white, size: 22),
                                                ),
                                              ],
                        ),
                                            ),
                                          ),
                                        ),
                                      ],
                              ),
              const SizedBox(height: 8),
                              
              // Labels
                              Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Text(
                                          'Listen',
                                          style: TextStyle(
                      color:
                          _isListening ? const Color(0xFF27AE60) : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                                          ),
                                        ),
                  const Text(
                                          'Emergency',
                                          style: TextStyle(
                      color: Color(0xFFE53935),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                                          ),
                                        ),
                                      ],
                              ),
              const SizedBox(height: 8),
                              
              // Status chip
                              Center(
                                      child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                        decoration: SoftUIDesign.cardDecoration(
                                          backgroundColor: AppColors.primaryRed.withOpacity(0.08),
                                          borderRadius: SoftUIDesign.buttonBorderRadius,
                                          elevation: 2.0,
                                          borderColor: AppColors.primaryRed.withOpacity(0.3),
                                          showBorder: true,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _isTransmitting ? Icons.radio_button_checked : Icons.mic,
                                              color: const Color(0xFFE53935),
                        size: 16,
                                            ),
                      const SizedBox(width: 6),
                                            Text(
                                              _isTransmitting ? 'TRANSMITTING...' : 'Hold to transmit',
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                              
              if (_isTransmitting) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: SoftUIDesign.cardDecoration(
                                            backgroundColor: AppColors.primaryRed.withOpacity(0.05),
                                            borderRadius: SoftUIDesign.buttonBorderRadius,
                                            elevation: 1.0,
                                            borderColor: AppColors.primaryRed.withOpacity(0.2),
                                            showBorder: true,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                        width: 6,
                        height: 6,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFE53935),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                      const SizedBox(width: 6),
                                              Text(
                        _formatDuration(_transmissionTime),
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                                                ),
                                              ),
                                            ],
                                        ),
                                      ),
              ],
                            ],
                          );
                        },
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

  void _toggleListening() {
    setState(() => _isListening = !_isListening);
  }

  void _refreshConnections() {
    // hook for data refresh
    setState(() {});
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Settings'),
        content: const Text('Settings options will be implemented here.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
    );
  }

  void _sendEmergencyAlert() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const SolidModalHeader(
          icon: Icons.emergency,
          iconColor: Color(0xFFE53935),
          title: 'Emergency Alert',
        ),
        content: const Text(
          'This will send an emergency alert to all connected users. Use only in genuine emergency situations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Emergency alert sent to all connected users'),
                  backgroundColor: Color(0xFFE53935),
                ),
              );
            },
            child: const Text('Send Alert'),
          ),
        ],
      ),
    );
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.lightGray.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryRed.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Previous page',
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: _currentPage > 0
                ? () {
                    setState(() {
                      _currentPage--;
                      // Update animations when page changes
                      _updateUserListStagger();
                      _userListStagger?.replay();
                    });
                  }
                : null,
            color: _currentPage > 0 ? AppColors.primaryRed : Colors.grey,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          Text(
            'Page ${_currentPage + 1} of $totalPages',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryRed,
            ),
          ),
          const SizedBox(width: 6),
          Text('($length users)',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Next page',
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: _currentPage < totalPages - 1
                ? () {
                    setState(() {
                      _currentPage++;
                      // Update animations when page changes
                      _updateUserListStagger();
                      _userListStagger?.replay();
                    });
                  }
                : null,
            color: _currentPage < totalPages - 1 
                ? AppColors.primaryRed 
                : Colors.grey,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text,
      {required Color background, required Color foreground}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        ),
      child: Text(
        text,
              style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ====== User Tile (Material-leaning, compact, accessible) ======

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.name,
    required this.isActive,
    required this.isMuted,
    required this.isSpeaking,
  });

  final String name;
  final bool isActive;
  final bool isMuted;
  final bool isSpeaking;

  Color get _borderColor {
    if (isSpeaking) return const Color(0xFF27AE60);
    if (isMuted) return const Color(0xFFE53935);
    if (isActive) return const Color(0xFFE53935).withOpacity(0.2);
    return const Color(0xFF7F8C8D).withOpacity(0.5);
    }

  Color get _fill {
    if (isSpeaking) return const Color(0xFF27AE60).withOpacity(0.12);
    if (!isActive) return const Color(0xFF7F8C8D).withOpacity(0.08);
    return Colors.white;
  }

  String get _statusText {
    if (isSpeaking) return 'Speaking';
    if (isMuted) return 'Muted';
    if (isActive) return 'Active';
    return 'Offline';
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);

    return Container(
              decoration: BoxDecoration(
        color: _fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor, width: isSpeaking || isMuted ? 2 : 1),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isActive ? const Color(0xFFE53935) : const Color(0xFF7F8C8D),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: isSpeaking
                      ? const Color(0xFF27AE60)
                      : isMuted
                          ? const Color(0xFFE53935)
                          : isActive
                              ? const Color(0xFF27AE60)
                              : const Color(0xFF7F8C8D),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          _statusText,
          style: TextStyle(
            fontSize: 11,
            color: isSpeaking
                ? const Color(0xFF27AE60)
                : isMuted
                    ? const Color(0xFFE53935)
                    : AppColors.textSecondary,
        ),
        ),
        trailing: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isSpeaking
                ? const Color(0xFF27AE60).withOpacity(0.08)
                : isMuted
                    ? const Color(0xFFE53935).withOpacity(0.08)
                    : const Color(0xFFE53935).withOpacity(0.08),
            shape: BoxShape.circle,
            border: Border.all(
              color: isSpeaking
                  ? const Color(0xFF27AE60).withOpacity(0.3)
                  : isMuted
                      ? const Color(0xFFE53935).withOpacity(0.3)
                      : const Color(0xFFE53935).withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Icon(
            isSpeaking ? Icons.volume_up : (isMuted ? Icons.mic_off : Icons.mic),
            size: 16,
            color: isSpeaking
                ? const Color(0xFF27AE60)
                : isMuted
                    ? const Color(0xFFE53935)
                    : const Color(0xFFE53935),
          ),
        ),
      ),
    );
  }

  static String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}