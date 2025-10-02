import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class OptimizedUserCard extends StatelessWidget {
  final String name;
  final String status;
  final bool isOnline;
  final String? lastSeen;
  final String? avatar;
  final VoidCallback? onTap;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;

  const OptimizedUserCard({
    super.key,
    required this.name,
    required this.status,
    required this.isOnline,
    this.lastSeen,
    this.avatar,
    this.onTap,
    this.onCall,
    this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Optimized Avatar with const
                  _buildAvatar(),
                  
                  const SizedBox(width: 12),
                  
                  // Optimized Content with const
                  Expanded(
                    child: _buildContent(),
                  ),
                  
                  // Optimized Actions
                  _buildActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isOnline ? AppColors.online : AppColors.mediumGray,
        borderRadius: BorderRadius.circular(24),
      ),
      child: avatar != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.network(
                avatar!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
              ),
            )
          : _buildDefaultAvatar(),
    );
  }

  Widget _buildDefaultAvatar() {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          status,
          style: TextStyle(
            fontSize: 14,
            color: isOnline ? AppColors.textSecondary : AppColors.mediumGray,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (lastSeen != null) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isOnline ? AppColors.online : AppColors.mediumGray,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isOnline ? 'Connected' : 'Last seen $lastSeen',
                style: TextStyle(
                  fontSize: 12,
                  color: isOnline ? AppColors.online : AppColors.mediumGray,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionButton(
          icon: Icons.message,
          color: AppColors.primaryRed,
          onTap: onMessage,
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          icon: Icons.call,
          color: AppColors.online,
          onTap: onCall,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}
