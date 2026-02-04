import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../utils/theme_colors.dart';
import '../services/sqlite_service.dart';
import '../widgets/animated_neumorphic_card.dart';
import '../widgets/modern_user_card.dart';
import '../widgets/modern_responsive_layout.dart';
import '../widgets/modern_floating_layout.dart';
import '../widgets/enhanced_text_styles.dart';
import '../widgets/enhanced_shadows.dart' as shadows;
import 'private_chat_screen.dart';
import '../constants/unified_typography.dart';

class ModernPeopleScreen extends StatefulWidget {
  const ModernPeopleScreen({super.key});

  @override
  State<ModernPeopleScreen> createState() => _ModernPeopleScreenState();
}

class _ModernPeopleScreenState extends State<ModernPeopleScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';

  // Dynamic users data
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
    
    // Load users from database
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final sqliteService = Provider.of<SQLiteService>(context, listen: false);
      final users = await sqliteService.getAllUsers();
      
      // Transform database users to display format
      final transformedUsers = users.map((user) {
        return {
          'id': user['id'].toString(),
          'name': user['name'] ?? 'Unknown User',
          'status': user['role'] ?? 'User',
          'isOnline': (user['is_online'] ?? 0) == 1,
          'lastSeen': _formatLastSeen(user['last_seen']),
          'role': _getRoleFromDatabase(user['role']),
          'location': user['location'] ?? 'Unknown',
        };
      }).toList();
      
      if (mounted) {
        setState(() {
          _users = transformedUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading users: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatLastSeen(dynamic lastSeen) {
    if (lastSeen == null) return 'Unknown';
    
    try {
      final lastSeenTime = DateTime.fromMillisecondsSinceEpoch(lastSeen * 1000);
      final now = DateTime.now();
      final difference = now.difference(lastSeenTime);
      
      if (difference.inMinutes < 1) {
        return 'now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} minutes ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hours ago';
      } else {
        return '${difference.inDays} days ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getRoleFromDatabase(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return 'admin';
      case 'moderator':
        return 'moderator';
      default:
        return 'user';
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredUsers {
    List<Map<String, dynamic>> filtered = _users.where((user) {
      final matchesSearch = user['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
                          user['status'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
                          user['location'].toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesFilter = _selectedFilter == 'All' || 
                           (_selectedFilter == 'Connected' && user['isOnline']) ||
                           (_selectedFilter == 'Disconnected' && !user['isOnline']) ||
                           (_selectedFilter == 'Admins' && user['role'] == 'admin') ||
                           (_selectedFilter == 'Moderators' && user['role'] == 'moderator');
      
      return matchesSearch && matchesFilter;
    }).toList();
    
    // Sort by online status first, then by name
    filtered.sort((a, b) {
      if (a['isOnline'] != b['isOnline']) {
        return b['isOnline'] ? 1 : -1;
      }
      return a['name'].compareTo(b['name']);
    });
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return ModernFloatingLayout(
      hasFloatingAppBar: false,
      hasFloatingBottomBar: true,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 24),
              
              // Search and Filter
              _buildSearchAndFilter(),
              const SizedBox(height: 24),
              
              // Stats Cards
              _buildStatsCards(),
              const SizedBox(height: 24),
              
              // Users List
              _buildUsersList(),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // People icon (consistent with other screens)
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ThemeColors.surface(context),
              borderRadius: BorderRadius.circular(12),
              boxShadow: shadows.EnhancedShadows.buttonLight,
            ),
            child: const Icon(
              Icons.people,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Title and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const PageTitle('Connected People'),
              ],
            ),
          ),
          
          // Settings button
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ThemeColors.surface(context),
              borderRadius: BorderRadius.circular(12),
              boxShadow: shadows.EnhancedShadows.buttonLight,
            ),
            child: IconButton(
              onPressed: () => _showSettings(context),
              icon: const Icon(
                Icons.settings,
                color: AppColors.primary,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Column(
      children: [
        // Search bar
        AnimatedNeumorphicCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: const InputDecoration(
              hintText: 'Search people...',
              hintStyle: TextStyle(
                color: AppColors.mediumGray,
                fontSize: 16,
              ),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: AppColors.mediumGray),
              suffixIcon: Icon(Icons.filter_list, color: AppColors.mediumGray),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Filter chips
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: ['All', 'Connected', 'Disconnected', 'Admins', 'Moderators'].map((filter) {
              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedFilter = filter);
                    HapticFeedback.lightImpact();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.lightGray,
                        width: 1.5,
                      ),
                      boxShadow: shadows.EnhancedShadows.cardLight,
                    ),
                    child: Row(
                      children: [
                        if (isSelected) const Icon(Icons.check, size: 14, color: Colors.white),
                        if (isSelected) const SizedBox(width: 6),
                        Text(
                          filter,
                          style: TextStyle(
                            color: isSelected ? AppColors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards() {
    final onlineCount = _users.where((u) => u['isOnline']).length;
    final adminCount = _users.where((u) => u['role'] == 'admin').length;
    final moderatorCount = _users.where((u) => u['role'] == 'moderator').length;
    
    return shadows.LightCard(
      padding: const EdgeInsets.all(16),
      child: ModernResponsiveGrid(
      children: [
        _buildStatCard(
          title: 'Connected',
          value: onlineCount.toString(),
          icon: Icons.people,
          color: AppColors.success,
          isActive: onlineCount > 0,
        ),
        _buildStatCard(
          title: 'Admins',
          value: adminCount.toString(),
          icon: Icons.admin_panel_settings,
          color: AppColors.primaryRed,
          isActive: adminCount > 0,
        ),
        _buildStatCard(
          title: 'Moderators',
          value: moderatorCount.toString(),
          icon: Icons.shield,
          color: AppColors.warning,
          isActive: moderatorCount > 0,
        ),
        _buildStatCard(
          title: 'Total',
          value: _users.length.toString(),
          icon: Icons.group,
          color: AppColors.info,
          isActive: true,
        ),
      ],
    ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isActive,
  }) {
    return shadows.LightCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: UnifiedTypography.displaySmall,
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: ThemeColors.textSecondary(context),
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(
            color: AppColors.primaryRed,
          ),
        ),
      );
    }
    
    final filteredUsers = _filteredUsers;
    
    if (filteredUsers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: AppColors.lightGray,
              ),
              SizedBox(height: 16),
              Text(
                'No users found',
                style: TextStyle(
                  fontSize: 18,
                  color: ThemeColors.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return ModernResponsiveList(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: filteredUsers.map((user) {
        return ModernUserCard(
          name: user['name'],
          status: user['status'],
          isOnline: user['isOnline'],
          lastSeen: user['lastSeen'],
          avatarText: user['name'][0],
          statusColor: user['role'] == 'admin' 
              ? AppColors.primaryRed 
              : user['role'] == 'moderator' 
                  ? AppColors.warning 
                  : null,
          onTap: () => _showUserProfile(context, user),
          onMessage: () => _navigateToPrivateChat(context, user),
        );
      }).toList(),
    );
  }

  void _showUserProfile(BuildContext context, Map<String, dynamic> user) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      builder: (context) => AnimatedNeumorphicCard(
        margin: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // User avatar
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: user['role'] == 'admin' 
                    ? AppColors.primaryRed 
                    : user['role'] == 'moderator' 
                        ? AppColors.warning 
                        : AppColors.info,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Center(
                child: Text(
                  user['name'][0],
                  style: const TextStyle(
                    color: ThemeColors.surface(context),
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // User info
            Text(
              user['name'],
              style: UnifiedTypography.displaySmall,
            ),
            
            Text(
              user['status'],
              style: const TextStyle(
                fontSize: 16,
                color: ThemeColors.textSecondary(context),
              ),
            ),
            
            Text(
              user['location'],
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.mediumGray,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.message,
                  label: 'Message',
                  color: AppColors.primary,
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToPrivateChat(context, user);
                  },
                ),
                _buildActionButton(
                  icon: Icons.info,
                  label: 'Info',
                  color: AppColors.info,
                  onTap: () {
                    Navigator.pop(context);
                    // Show more info
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPrivateChat(BuildContext context, Map<String, dynamic> user) {
    HapticFeedback.lightImpact();
    
    // Debug logging
    print('Navigating to private chat with user: ${user['name']}');
    print('User data: $user');
    
    // Ensure we have valid non-null values
    final contactName = user['name']?.toString() ?? 'Unknown User';
    final contactEmail = user['email']?.toString() ?? '${contactName.toLowerCase().replaceAll(' ', '.')}@example.com';
    final contactAvatar = user['avatar']?.toString();
    
    print('Processed data - Name: $contactName, Email: $contactEmail');
    
    // Navigate to private chat screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PrivateChatScreen(
          contactName: contactName,
          contactEmail: contactEmail,
          contactAvatar: contactAvatar,
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      builder: (context) => AnimatedNeumorphicCard(
        margin: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'People Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ThemeColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.sort, color: AppColors.primaryRed),
              title: const Text('Sort by'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.filter_list, color: AppColors.primaryRed),
              title: const Text('Filter options'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.refresh, color: AppColors.primaryRed),
              title: const Text('Refresh list'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
