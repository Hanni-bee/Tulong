import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/severity_colors.dart';
import '../utils/theme_colors.dart';
import '../constants/app_typography.dart';
import '../models/emergency_type.dart';
import '../services/sqlite_service.dart';
import '../providers/chat_provider.dart';

/// Modal to display sender information.
/// For Emergency Detection messages, shows Name, Severity, and Date/Time.
/// For SOS messages, shows Name, SOS Message, and Address.
/// Otherwise shows Name and Address from profile.
/// Loads by [senderUid] (exact) when provided; otherwise falls back to [senderName] (LIKE).
class SenderInfoModal extends StatefulWidget {
  final String? senderUid;
  final String? senderName;
  final SeverityLevel? severityLevel;
  final EmergencyType? emergencyType;
  final bool isEmergencyDetection;
  final bool isSos;
  final String? messageText;
  final DateTime? messageTimestamp;

  const SenderInfoModal({
    super.key,
    this.senderUid,
    this.senderName,
    this.severityLevel,
    this.emergencyType,
    this.isEmergencyDetection = false,
    this.isSos = false,
    this.messageText,
    this.messageTimestamp,
  });

  @override
  State<SenderInfoModal> createState() => _SenderInfoModalState();
}

class _SenderInfoModalState extends State<SenderInfoModal> {
  bool _isLoading = true;
  Map<String, dynamic>? _userInfo;
  String? _errorMessage;
  bool _requestedProfile = false;
  SeverityLevel? _profileSeverityLevel;

  String? get _lookupUid {
    final uid = widget.senderUid?.trim();
    if (uid == null || uid.isEmpty) return null;
    if (widget.isSos && uid.length > 3) {
      return uid.substring(0, uid.length - 3).trim();
    }
    return uid;
  }

  SeverityLevel? get _resolvedSeverityLevel =>
      widget.isEmergencyDetection ? (widget.severityLevel ?? _profileSeverityLevel) : null;

  bool get _showsEmergencyDetectionSection =>
      widget.isEmergencyDetection && (_resolvedSeverityLevel != null || widget.emergencyType != null);

  bool get _showsSosSection => widget.isSos;

  String get _dialogTitle {
    if (_showsEmergencyDetectionSection) return 'Emergency Information';
    if (_showsSosSection) return 'SOS Information';
    return 'Sender Information';
  }

  IconData get _dialogIcon {
    if (_showsEmergencyDetectionSection) return Icons.emergency;
    if (_showsSosSection) return Icons.sos_rounded;
    return Icons.person;
  }

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
      final sqliteService = SQLiteService();
      final db = await sqliteService.database;
      List<Map<String, dynamic>> results = [];
      SeverityLevel? resolvedProfileSeverity;
      final prefs = await SharedPreferences.getInstance();

      if (_lookupUid != null && _lookupUid!.isNotEmpty) {
        final storedSeverity =
            prefs.getString('profile_severity_$_lookupUid');
        if (storedSeverity != null &&
            storedSeverity.isNotEmpty &&
            storedSeverity.toUpperCase() != 'UNKNOWN') {
          resolvedProfileSeverity = SeverityLevel.fromString(storedSeverity);
        }

        final cachedName = prefs.getString('profile_name_$_lookupUid')?.trim() ?? '';
        final cachedStreet = prefs.getString('profile_street_$_lookupUid')?.trim() ?? '';
        final cachedBarangay = prefs.getString('profile_barangay_$_lookupUid')?.trim() ?? '';
        final cachedCity = prefs.getString('profile_city_$_lookupUid')?.trim() ?? '';
        final cachedProvince = prefs.getString('profile_province_$_lookupUid')?.trim() ?? '';

        final cachedAddress = _formatAddressParts(
          street: cachedStreet,
          barangay: cachedBarangay,
          city: cachedCity,
          province: cachedProvince,
        );

        if (cachedName.isNotEmpty || cachedAddress != 'Not provided') {
          setState(() {
            _userInfo = {
              'name': cachedName.isNotEmpty
                  ? cachedName
                  : (widget.senderName ?? _lookupUid ?? 'Unknown'),
              'address': cachedAddress == 'Not provided' ? 'Not available' : cachedAddress,
            };
            _profileSeverityLevel = resolvedProfileSeverity;
            _isLoading = false;
          });
          return;
        }
      }

      // Prefer UID-based lookup (exact) when available
      if (_lookupUid != null && _lookupUid!.isNotEmpty) {
        results = await db.query(
          'users',
          where: 'uid = ?',
          whereArgs: [_lookupUid!],
        );
      }

      // Fallback: search by name (exact then partial) when no UID or not found by UID
      if (results.isEmpty && widget.senderName != null && widget.senderName!.trim().isNotEmpty) {
        String fullNameQuery = 'first_name || " " || last_name';
        results = await db.query(
          'users',
          where: '$fullNameQuery = ?',
          whereArgs: [widget.senderName!.trim()],
        );
        if (results.isEmpty) {
          results = await db.query(
            'users',
            where: 'first_name LIKE ? OR last_name LIKE ? OR $fullNameQuery LIKE ?',
            whereArgs: [
              widget.senderName!.trim(),
              widget.senderName!.trim(),
              '%${widget.senderName!.trim()}%',
            ],
          );
        }
      }

      if (results.isNotEmpty) {
        final user = results.first;
        setState(() {
          _userInfo = {
            'name': '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim(),
            'address': _formatAddress(user),
          };
          _profileSeverityLevel = resolvedProfileSeverity;
          _isLoading = false;
        });
        return;
      }

      // Not found: if we have UID and haven't requested profile yet, request then retry
      if (_lookupUid != null &&
          _lookupUid!.isNotEmpty &&
          !_requestedProfile &&
          ChatProvider.instance != null) {
        _requestedProfile = true;
        await ChatProvider.instance!.requestProfileFromESP32(_lookupUid!);
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) await _loadSenderInfo();
        return;
      }

      // User not found (offline or no data)
      setState(() {
        _userInfo = {
          'name': widget.senderName ?? _lookupUid ?? widget.senderUid ?? 'Unknown',
          'address': 'Not available',
        };
        _profileSeverityLevel = resolvedProfileSeverity;
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

  Widget _buildEmergencySeverityCard(Color baseColor) {
    final severity = _resolvedSeverityLevel;
    final severityColor = severity != null ? SeverityColors.color(severity) : baseColor;
    final severityLabel = severity?.label ?? 'Unknown';
    return _buildInfoCard(
      icon: Icons.emergency,
      label: 'Severity',
      value: severityLabel,
      color: severityColor,
    );
  }

  Widget _buildDateTimeCard(Color baseColor) {
    final dateTime = widget.messageTimestamp;
    final value = dateTime != null
        ? DateFormat('MMM dd, yyyy hh:mm:ss a').format(dateTime)
        : 'Not available';
    return _buildInfoCard(
      icon: Icons.access_time,
      label: 'Date and Time',
      value: value,
      color: baseColor,
    );
  }

  Widget _buildSosMessageCard(Color baseColor) {
    final message = widget.messageText?.trim();
    return _buildInfoCard(
      icon: Icons.sms,
      label: 'SOS Message',
      value: (message != null && message.isNotEmpty) ? message : 'Not available',
      color: AppColors.error,
    );
  }

  String _formatAddressParts({
    String? street,
    String? barangay,
    String? city,
    String? province,
    String? region,
  }) {
    final parts = <String>[];

    if (street != null && street.isNotEmpty) parts.add(street);
    if (barangay != null && barangay.isNotEmpty) parts.add(barangay);
    if (city != null && city.isNotEmpty) parts.add(city);
    if (province != null && province.isNotEmpty) parts.add(province);
    if (region != null && region.isNotEmpty) parts.add(region);

    return parts.isEmpty ? 'Not provided' : parts.join(', ');
  }

  String _formatAddress(Map<String, dynamic> user) {
    return _formatAddressParts(
      street: user['street']?.toString(),
      barangay: user['barangay']?.toString(),
      city: user['city']?.toString(),
      province: user['province']?.toString(),
      region: user['region']?.toString(),
    );
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
          color: ThemeColors.surface(context),
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
                    child: Icon(
                      _dialogIcon,
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
                          _dialogTitle,
                          style: AppTypography.headlineSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _userInfo?['name'] ?? widget.senderName ?? widget.senderUid ?? 'Unknown',
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
                        : _userInfo != null || _showsEmergencyDetectionSection || _showsSosSection
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Name
                                  _buildInfoCard(
                                    icon: Icons.person,
                                    label: 'Name',
                                    value: _userInfo?['name'] ?? widget.senderName ?? widget.senderUid ?? 'Unknown',
                                    color: cyanBlue,
                                  ),
                                  const SizedBox(height: 20),
                                  // Emergency Severity (from Emergency Detection) — replaces Contact Number & Address
                                  if (_showsEmergencyDetectionSection) ...[
                                    _buildEmergencySeverityCard(cyanBlue),
                                    const SizedBox(height: 20),
                                    _buildDateTimeCard(cyanBlue),
                                  ] else if (_showsSosSection) ...[
                                    _buildSosMessageCard(cyanBlue),
                                    const SizedBox(height: 20),
                                    _buildInfoCard(
                                      icon: Icons.location_on,
                                      label: 'Address',
                                      value: _userInfo?['address'] ?? 'Not available',
                                      color: cyanBlue,
                                    ),
                                  ] else ...[
                                    // Address
                                    _buildInfoCard(
                                      icon: Icons.location_on,
                                      label: 'Address',
                                      value: _userInfo?['address'] ?? 'Not available',
                                      color: cyanBlue,
                                    ),
                                  ],
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
