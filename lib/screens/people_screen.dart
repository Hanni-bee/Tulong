import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../utils/theme_colors.dart';
import '../constants/app_strings.dart';
import '../providers/network_provider.dart';
import '../widgets/user_card.dart';
import '../widgets/search_bar.dart';
import '../utils/responsive_helper.dart';
import '../utils/responsive_spacing.dart';
import 'modern_personal_chat_screen.dart';
import '../widgets/modern_empty_state.dart';
import '../widgets/polished_shimmer.dart';
import '../widgets/polished_animations.dart';
import '../constants/app_typography.dart';
import 'package:flutter/services.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  // Sample users data
  final List<Map<String, dynamic>> _users = [
    {
      'id': '1',
      'name': 'Max Holloway',
      'status': 'Hey, what are you up?',
      'isOnline': true,
      'lastSeen': '1 min ago',
      'avatar': null,
    },
    {
      'id': '2',
      'name': 'Charles Oliveira',
      'status': 'Available for help',
      'isOnline': true,
      'lastSeen': '2 min ago',
      'avatar': null,
    },
    {
      'id': '3',
      'name': 'Alexa Grasso',
      'status': 'In emergency mode',
      'isOnline': false,
      'lastSeen': '5 min ago',
      'avatar': null,
    },
    {
      'id': '4',
      'name': 'Jon Jones',
      'status': 'Standing by',
      'isOnline': true,
      'lastSeen': '30 sec ago',
      'avatar': null,
    },
    {
      'id': '5',
      'name': 'Amanda Nunes',
      'status': 'Ready to assist',
      'isOnline': true,
      'lastSeen': '1 min ago',
      'avatar': null,
    },
    {
      'id': '6',
      'name': 'Conor McGregor',
      'status': 'Offline',
      'isOnline': false,
      'lastSeen': '10 min ago',
      'avatar': null,
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) {
      return _users;
    }
    return _users.where((user) {
      return user['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
             user['status'].toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.background(context),
      appBar: AppBar(
        title: const Text(
          AppStrings.people,
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Consumer<NetworkProvider>(
            builder: (context, networkProvider, child) {
              return Container(
                margin: EdgeInsets.only(right: ResponsiveSpacing.getResponsiveSpacing(context)),
                padding: ResponsiveSpacing.getResponsivePadding(context, horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.online,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wifi_tethering,
                      color: ThemeColors.surface(context),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${networkProvider.connectedUsers} connected',
                      style: const TextStyle(
                        color: ThemeColors.surface(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search functionality
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshUsers,
        child: SingleChildScrollView(
          padding: ResponsiveHelper.getResponsiveEdgeInsets(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar
              CustomSearchBar(
                controller: _searchController,
                hintText: 'Search people...',
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            
              const SizedBox(height: 16),
              
              // Online users count
              Row(
                children: [
                  const Icon(
                    Icons.people,
                    color: AppColors.online,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_users.where((user) => user['isOnline']).length} connected',
                    style: const TextStyle(
                      color: AppColors.online,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      // TODO: Show filter options
                    },
                    icon: const Icon(Icons.filter_list, size: 18),
                    label: const Text('Filter'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryRed,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Users list with loading and empty states
              LayoutBuilder(
                builder: (context, constraints) {
                  // Show loading skeleton
                  if (_isLoading) {
                    return PolishedStaggeredList(
                      staggerDuration: const Duration(milliseconds: 100),
                      children: List.generate(5, (index) {
                        return const PolishedListItemSkeleton();
                      }),
                    );
                  }

                  // Show empty state
                  if (_filteredUsers.isEmpty) {
                    return ModernEmptyState(
                      icon: _searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
                      title: _searchQuery.isEmpty ? 'No Users Yet' : 'No Results Found',
                      message: _searchQuery.isEmpty
                          ? 'No users are currently connected to the network.'
                          : 'Try adjusting your search to find what you\'re looking for.',
                      actionLabel: _searchQuery.isEmpty ? null : 'Clear Search',
                      onAction: _searchQuery.isEmpty
                          ? null
                          : () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                    );
                  }

                  // Show users list
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: UserCard(
                          name: user['name'],
                          status: user['status'],
                          isOnline: user['isOnline'],
                          lastSeen: user['lastSeen'],
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _showUserProfile(context, user);
                          },
                          onMessage: () {
                            HapticFeedback.mediumImpact();
                            _openPersonalMessage(context, user);
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserProfile(BuildContext context, Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: ThemeColors.surface(context),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.lightGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // User info
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primaryRed,
                    child: Text(
                      user['name'][0],
                      style: const TextStyle(
                        color: ThemeColors.surface(context),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user['name'],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: ThemeColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: user['isOnline'] ? AppColors.online : AppColors.mediumGray,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        user['isOnline'] ? 'Connected' : 'Last seen ${user['lastSeen']}',
                        style: TextStyle(
                          color: user['isOnline'] ? AppColors.online : AppColors.mediumGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user['status'],
                    style: const TextStyle(
                      fontSize: 16,
                      color: ThemeColors.textSecondary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openPersonalMessage(context, user);
                      },
                      icon: const Icon(Icons.message),
                      label: const Text('Message'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryRed,
                        side: const BorderSide(color: AppColors.primaryRed),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _openPersonalMessage(BuildContext context, Map<String, dynamic> user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ModernPersonalChatScreen(
          contactName: user['name'],
          contactId: user['id'],
          contactAvatar: user['avatar'],
          isOnline: user['isOnline'],
        ),
      ),
    );
  }

  Future<void> _refreshUsers() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    // Simulate updating user status
    setState(() {
      _isLoading = false;
      // In a real app, this would fetch fresh data from the server
      // For now, we'll just trigger a rebuild to show the refresh worked
    });
    
    if (mounted) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Users refreshed', style: AppTypography.bodyMedium.copyWith(color: Colors.white)),
          duration: const Duration(seconds: 1),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}
