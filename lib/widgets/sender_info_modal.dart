import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../services/sqlite_service.dart';
import '../services/firebase_service.dart';

/// Modal to display sender's basic information (Name, Contact Number, Address)
class SenderInfoModal extends StatefulWidget {
  final String senderName;

  const SenderInfoModal({
    super.key,
    required this.senderName,
  });

  @override
  State<SenderInfoModal> createState() => _SenderInfoModalState();
}

class _SenderInfoModalState extends State<SenderInfoModal> {
  bool _isLoading = true;
  Map<String, dynamic>? _userInfo;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSenderInfo();
  }

  Future<void> _loadSenderInfo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Try to find user by name in the database
      final sqliteService = SQLiteService();
      
      // Search in SQLite first - try exact match first, then partial
      final db = await sqliteService.database;
      
      // First try exact match on full name
      String fullNameQuery = 'first_name || " " || last_name';
      var results = await db.query(
        'users',
        where: '$fullNameQuery = ?',
        whereArgs: [widget.senderName.trim()],
      );

      // If no exact match, try partial match
      if (results.isEmpty) {
        // Try matching first name or last name
        results = await db.query(
          'users',
          where: 'first_name LIKE ? OR last_name LIKE ? OR $fullNameQuery LIKE ?',
          whereArgs: [
            widget.senderName.trim(),
            widget.senderName.trim(),
            '%${widget.senderName.trim()}%',
          ],
        );
      }

      if (results.isNotEmpty) {
        final user = results.first;
        setState(() {
          _userInfo = {
            'name': '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim(),
            'phone': user['phone']?.toString() ?? 'Not provided',
            'address': _formatAddress(user),
          };
          _isLoading = false;
        });
        return;
      }

      // If not found in SQLite, try Firebase
      try {
        final firebaseService = FirebaseService();
        final snapshot = await firebaseService.database.ref('users').get();
        
        if (snapshot.exists) {
          final users = snapshot.value as Map<dynamic, dynamic>;
          Map<String, dynamic>? foundUser;
          
          users.forEach((key, value) {
            final user = value as Map<dynamic, dynamic>;
            final firstName = user['FirstName']?.toString() ?? '';
            final lastName = user['LastName']?.toString() ?? '';
            final fullName = '$firstName $lastName'.trim();
            
            // Try exact match first
            if (fullName.toLowerCase() == widget.senderName.toLowerCase().trim()) {
              foundUser = {
                'name': fullName,
                'phone': user['Phone']?.toString() ?? 'Not provided',
                'address': _formatFirebaseAddress(user),
              };
            } else if (fullName.toLowerCase().contains(widget.senderName.toLowerCase().trim()) ||
                firstName.toLowerCase().contains(widget.senderName.toLowerCase().trim()) ||
                lastName.toLowerCase().contains(widget.senderName.toLowerCase().trim())) {
              // Partial match
              foundUser ??= {
                  'name': fullName,
                  'phone': user['Phone']?.toString() ?? 'Not provided',
                  'address': _formatFirebaseAddress(user),
                };
            }
          });

          if (foundUser != null) {
            setState(() {
              _userInfo = foundUser;
              _isLoading = false;
            });
            return;
          }
        }
      } catch (e) {
        print('Firebase search error: $e');
      }

      // If not found, show limited info
      setState(() {
        _userInfo = {
          'name': widget.senderName,
          'phone': 'Not available',
          'address': 'Not available',
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load user information';
        _isLoading = false;
      });
      print('Error loading sender info: $e');
    }
  }

  String _formatAddress(Map<String, dynamic> user) {
    final parts = <String>[];
    
    if (user['street']?.toString().isNotEmpty == true) {
      parts.add(user['street'].toString());
    }
    if (user['barangay']?.toString().isNotEmpty == true) {
      parts.add(user['barangay'].toString());
    }
    if (user['city']?.toString().isNotEmpty == true) {
      parts.add(user['city'].toString());
    }
    if (user['province']?.toString().isNotEmpty == true) {
      parts.add(user['province'].toString());
    }
    if (user['region']?.toString().isNotEmpty == true) {
      parts.add(user['region'].toString());
    }
    
    return parts.isEmpty ? 'Not provided' : parts.join(', ');
  }

  String _formatFirebaseAddress(Map<dynamic, dynamic> user) {
    final parts = <String>[];
    
    if (user['Street']?.toString().isNotEmpty == true) {
      parts.add(user['Street'].toString());
    } else if (user['Address']?.toString().isNotEmpty == true) {
      parts.add(user['Address'].toString());
    }
    if (user['Barangay']?.toString().isNotEmpty == true) {
      parts.add(user['Barangay'].toString());
    }
    if (user['City']?.toString().isNotEmpty == true) {
      parts.add(user['City'].toString());
    }
    if (user['Province']?.toString().isNotEmpty == true) {
      parts.add(user['Province'].toString());
    }
    if (user['Region']?.toString().isNotEmpty == true) {
      parts.add(user['Region'].toString());
    }
    
    return parts.isEmpty ? 'Not provided' : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    const Color cyanBlue = Color(0xFF3498DB);
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cyanBlue,
                    cyanBlue.withOpacity(0.8),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sender Information',
                          style: AppTypography.headlineSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.senderName,
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: _isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 60),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 72,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    _errorMessage!,
                                    style: AppTypography.bodyLarge.copyWith(
                                      color: AppColors.mediumGray,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _userInfo != null
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Name
                                  _buildInfoCard(
                                    icon: Icons.person,
                                    label: 'Name',
                                    value: _userInfo!['name'] ?? widget.senderName,
                                    color: cyanBlue,
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // Contact Number
                                  _buildInfoCard(
                                    icon: Icons.phone,
                                    label: 'Contact Number',
                                    value: _userInfo!['phone'] ?? 'Not available',
                                    color: cyanBlue,
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // Address
                                  _buildInfoCard(
                                    icon: Icons.location_on,
                                    label: 'Address',
                                    value: _userInfo!['address'] ?? 'Not available',
                                    color: cyanBlue,
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
              ),
            ),
            
            // Close button
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Close',
                    style: AppTypography.bodyLarge.copyWith(
                      color: cyanBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.mediumGray,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.darkGray,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    height: 1.4,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
