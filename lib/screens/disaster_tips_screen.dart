import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../constants/severity_colors.dart';
import '../constants/soft_ui_design.dart';
import '../constants/storage_keys.dart';
import '../data/disaster_tips.dart';
import '../models/emergency_type.dart';
import '../utils/theme_colors.dart';
import '../widgets/unified_top_bar.dart';

// #region agent log
const String _kIngestUrl = 'http://127.0.0.1:7242/ingest/28058bf5-0a71-42bc-bd24-84b78066f5f3';
void _agentLog(String hypothesisId, String location, String message, Map<String, dynamic> data) {
  final payload = jsonEncode({
    'hypothesisId': hypothesisId,
    'location': location,
    'message': message,
    'data': data,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  });
  debugPrint(payload);
  try {
    http.post(Uri.parse(_kIngestUrl), headers: {'Content-Type': 'application/json'}, body: payload).ignore();
  } catch (_) {}
}
// #endregion

/// Disaster Tips screen: what to do before, during, and after each disaster type.
/// Uses ThemeColors for full dark-mode support; DisasterTypeColors for per-type accents.
class DisasterTipsScreen extends StatefulWidget {
  const DisasterTipsScreen({super.key});

  @override
  State<DisasterTipsScreen> createState() => _DisasterTipsScreenState();
}

class _DisasterTipsScreenState extends State<DisasterTipsScreen> {
  final Set<String> _checkedKeys = {};
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _cardKeys = List.generate(disasterTipsTypes.length, (_) => GlobalKey());

  static const double _minTouchTarget = 48.0;

  @override
  void initState() {
    super.initState();
    _loadPersistedState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(StorageKeys.disasterTipsCheckPrefix)).toSet();
    final checked = keys.where((k) => prefs.getBool(k) == true).toSet();
    if (mounted) {
      setState(() => _checkedKeys.addAll(checked));
    }
  }

  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();
    // Refresh action no longer needs to clear expansion state
  }

  String _checkKey(EmergencyType type, String phase, int tipIndex) =>
      '${StorageKeys.disasterTipsCheckPrefix}${type.name}_${phase}_$tipIndex';

  Future<void> _toggleCheck(EmergencyType type, String phase, int tipIndex) async {
    HapticFeedback.lightImpact();
    final key = _checkKey(type, phase, tipIndex);
    final prefs = await SharedPreferences.getInstance();
    final next = !_checkedKeys.contains(key);
    setState(() {
      if (next) {
        _checkedKeys.add(key);
      } else {
        _checkedKeys.remove(key);
      }
    });
    await prefs.setBool(key, next);
  }

  Future<void> _resetProgress() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(StorageKeys.disasterTipsCheckPrefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
    setState(() => _checkedKeys.clear());
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Checklist progress cleared.', style: TextStyle(color: ThemeColors.textPrimary(context))),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ThemeColors.surfaceContainer(context),
      ),
    );
  }

  void _copyTips(DisasterTipSet set, EmergencyType type) {
    HapticFeedback.lightImpact();
    final sb = StringBuffer();
    sb.writeln('${type.label} – What to do');
    sb.writeln('Before:');
    for (final t in set.before) {
      sb.writeln('• $t');
    }
    sb.writeln('During:');
    for (final t in set.during) {
      sb.writeln('• $t');
    }
    sb.writeln('After:');
    for (final t in set.after) {
      sb.writeln('• $t');
    }
    Clipboard.setData(ClipboardData(text: sb.toString()));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tips copied to clipboard.', style: TextStyle(color: ThemeColors.textPrimary(context))),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ThemeColors.surfaceContainer(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            UnifiedTopBar(
              title: 'Disaster Tips',
              icon: Icons.tips_and_updates_rounded,
              iconColor: DisasterTypeColors.general,
              showBackButton: true,
              onBackPressed: () => Navigator.of(context).pop(),
              compact: true,
              showUnderline: false,
              actions: [
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: ThemeColors.textPrimary(context)),
                  color: ThemeColors.surfaceContainer(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'reset') _resetProgress();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'reset',
                      child: Text('Reset progress'),
                    ),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      DisasterTypeColors.general.withValues(alpha: 0.15),
                      DisasterTypeColors.general.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: DisasterTypeColors.general.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: DisasterTypeColors.general.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: DisasterTypeColors.general.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shield_rounded,
                        size: 32,
                        color: DisasterTypeColors.general,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Be Prepared',
                            style: AppTypography.titleLarge.copyWith(
                              color: ThemeColors.textPrimary(context),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your guide to safety before, during, and after an emergency.',
                            style: AppTypography.bodySmall.copyWith(
                              color: ThemeColors.textSecondary(context),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0, curve: Curves.easeOutCubic),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: DisasterTypeColors.general,
                backgroundColor: ThemeColors.surface(context),
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
                  itemCount: disasterTipsTypes.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return const _GoBagWidget();
                    }
                    final tipIndex = index - 1;
                    final t = disasterTipsTypes[tipIndex];
                    _agentLog('H4', 'disaster_tips_screen.dart:list', 'card list build', {
                      'index': tipIndex,
                      'cardCount': disasterTipsTypes.length,
                      'typeName': t.name,
                      'typeLabel': t.label,
                      'hasTipSet': disasterTipsData.containsKey(t),
                    });
                    final card = Padding(
                      key: _cardKeys[tipIndex],
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: _DisasterCardButton(
                        type: t,
                        tipSet: disasterTipsData[t]!,
                        checkedKeys: _checkedKeys,
                        checkKey: _checkKey,
                        onToggleCheck: (type, phase, idx) => _toggleCheck(type, phase, idx),
                        onCopy: _copyTips,
                        minTouchTarget: _minTouchTarget,
                      ),
                    );
                    return _StaggeredCard(index: tipIndex, child: card);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _DisasterModalContent extends StatefulWidget {
  final EmergencyType type;
  final DisasterTipSet tipSet;
  final Set<String> checkedKeys;
  final String Function(EmergencyType type, String phase, int tipIndex) checkKey;
  final void Function(EmergencyType type, String phase, int tipIndex) onToggleCheck;
  final void Function(DisasterTipSet set, EmergencyType type) onCopy;
  final double minTouchTarget;

  const _DisasterModalContent({
    required this.type,
    required this.tipSet,
    required this.checkedKeys,
    required this.checkKey,
    required this.onToggleCheck,
    required this.onCopy,
    required this.minTouchTarget,
  });

  @override
  State<_DisasterModalContent> createState() => _DisasterModalContentState();
}

class _DisasterModalContentState extends State<_DisasterModalContent> {
  String _selectedPhase = 'During';

  @override
  void initState() {
    super.initState();
    if (widget.tipSet.during.isEmpty) {
      if (widget.tipSet.before.isNotEmpty) _selectedPhase = 'Before';
      else if (widget.tipSet.after.isNotEmpty) _selectedPhase = 'After';
    }
  }

  int _totalChecklistCount() {
    return widget.tipSet.before.length + widget.tipSet.during.length + widget.tipSet.after.length;
  }

  int _totalCheckedCount() {
    int count = 0;
    for (var i = 0; i < widget.tipSet.before.length; i++) {
      if (widget.checkedKeys.contains(widget.checkKey(widget.type, 'before', i))) count++;
    }
    for (var i = 0; i < widget.tipSet.during.length; i++) {
      if (widget.checkedKeys.contains(widget.checkKey(widget.type, 'during', i))) count++;
    }
    for (var i = 0; i < widget.tipSet.after.length; i++) {
      if (widget.checkedKeys.contains(widget.checkKey(widget.type, 'after', i))) count++;
    }
    return count;
  }

  static const Map<String, IconData> _phaseIcons = {
    'Before': Icons.schedule_rounded,
    'During': Icons.emergency_rounded,
    'After': Icons.check_circle_outline_rounded,
  };

  Widget _buildPhasesWithChips(BuildContext context, Color accent) {
    final phases = <String>[];
    if (widget.tipSet.before.isNotEmpty) phases.add('Before');
    if (widget.tipSet.during.isNotEmpty) phases.add('During');
    if (widget.tipSet.after.isNotEmpty) phases.add('After');
    
    if (phases.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: ThemeColors.surface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ThemeColors.border(context), width: 1),
          ),
          child: Row(
            children: phases.map((label) {
              final isSelected = _selectedPhase == label;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (!isSelected) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedPhase = label);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? accent.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: AppTypography.labelLarge.copyWith(
                          color: isSelected ? accent : ThemeColors.textSecondary(context),
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.02, 0), end: Offset.zero).animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey(_selectedPhase),
            child: _buildSelectedPhaseContent(context, accent),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedPhaseContent(BuildContext context, Color accent) {
    if (_selectedPhase == 'Before') {
      return _phaseSection(context, 'Before', widget.tipSet.before, widget.type, accent, true);
    } else if (_selectedPhase == 'During') {
      return _phaseSection(context, 'During', widget.tipSet.during, widget.type, accent, true);
    } else if (_selectedPhase == 'After') {
      return _phaseSection(context, 'After', widget.tipSet.after, widget.type, accent, true);
    }
    return const SizedBox.shrink();
  }

  Widget _phaseSection(
    BuildContext context,
    String phaseLabel,
    List<String> tips,
    EmergencyType type,
    Color accent,
    bool withChecklist,
  ) {
    final phaseKey = phaseLabel.toLowerCase();
    final icon = _phaseIcons[phaseLabel];
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: 8),
              ],
              Semantics(
                label: phaseLabel,
                child: Text(
                  phaseLabel,
                  style: AppTypography.titleSmall.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 2,
            width: 24,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 12),
          ...tips.asMap().entries.map((e) {
            final i = e.key;
            final text = e.value;
            if (withChecklist) {
              final key = widget.checkKey(type, phaseKey, i);
              final checked = widget.checkedKeys.contains(key);
              return Semantics(
                label: 'Checkbox, $text',
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          widget.onToggleCheck(type, phaseKey, i);
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      splashColor: accent.withValues(alpha: 0.15),
                      highlightColor: accent.withValues(alpha: 0.08),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: widget.minTouchTarget,
                              height: widget.minTouchTarget,
                              child: Checkbox(
                                value: checked,
                                onChanged: (_) {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    widget.onToggleCheck(type, phaseKey, i);
                                  });
                                },
                                activeColor: accent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                fillColor: WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.selected)) return accent;
                                  return Colors.transparent;
                                }),
                              ),
                            ).animate(target: checked ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 200.ms),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  text,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: ThemeColors.textPrimary(context),
                                    decoration: checked ? TextDecoration.lineThrough : null,
                                    decorationColor: ThemeColors.textTertiary(context),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        text,
                        style: AppTypography.bodyMedium.copyWith(
                          color: ThemeColors.textPrimary(context),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, Color accent) {
    final total = _totalChecklistCount();
    if (total == 0) return const SizedBox.shrink();
    final completed = _totalCheckedCount();
    final progress = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completed of $total completed',
                style: AppTypography.labelMedium.copyWith(
                  color: ThemeColors.textSecondary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (completed == total)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 18, color: accent),
                    const SizedBox(width: 4),
                    Text(
                      'Done!',
                      style: AppTypography.labelMedium.copyWith(color: accent, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: accent.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyButton(BuildContext context, Color accent) {
    return Align(
      alignment: Alignment.centerRight,
      child: FilledButton.tonalIcon(
        onPressed: () => widget.onCopy(widget.tipSet, widget.type),
        icon: Icon(Icons.copy_rounded, size: 18, color: accent),
        label: Text('Copy tips', style: AppTypography.labelLarge.copyWith(color: accent, fontWeight: FontWeight.w600)),
        style: FilledButton.styleFrom(
          backgroundColor: accent.withValues(alpha: 0.12),
          foregroundColor: accent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SoftUIDesign.buttonBorderRadius)),
          overlayColor: accent.withValues(alpha: 0.15),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, Color accent) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline_rounded, size: 40, color: ThemeColors.textTertiary(context)),
            const SizedBox(height: 12),
            Text(
              'No tips available',
              style: AppTypography.bodyMedium.copyWith(color: ThemeColors.textTertiary(context)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = DisasterTypeColors.color(widget.type);
    final hasTips = widget.tipSet.before.isNotEmpty || widget.tipSet.during.isNotEmpty || widget.tipSet.after.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ThemeColors.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Icon(widget.type.icon, color: accent, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.type.label} Tips',
                          style: AppTypography.titleLarge.copyWith(
                            color: ThemeColors.textPrimary(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Actionable preparedness checklist',
                          style: AppTypography.bodySmall.copyWith(
                            color: ThemeColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: ThemeColors.textSecondary(context)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            if (hasTips && _totalChecklistCount() > 0) _buildProgressBar(context, accent),
            Divider(height: 1, thickness: 1, color: ThemeColors.border(context)),
            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: hasTips ? _buildPhasesWithChips(context, accent) : _buildEmpty(context, accent),
              ),
            ),
            // Bottom Action
            if (hasTips)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: _buildCopyButton(context, accent),
              ),
          ],
        ),
      ),
    );
  }
}

class _DisasterCardButton extends StatelessWidget {
  final EmergencyType type;
  final DisasterTipSet tipSet;
  final Set<String> checkedKeys;
  final String Function(EmergencyType type, String phase, int tipIndex) checkKey;
  final void Function(EmergencyType type, String phase, int tipIndex) onToggleCheck;
  final void Function(DisasterTipSet set, EmergencyType type) onCopy;
  final double minTouchTarget;

  const _DisasterCardButton({
    required this.type,
    required this.tipSet,
    required this.checkedKeys,
    required this.checkKey,
    required this.onToggleCheck,
    required this.onCopy,
    required this.minTouchTarget,
  });

  int _totalChecklistCount() {
    return tipSet.before.length + tipSet.during.length + tipSet.after.length;
  }

  int _totalCheckedCount() {
    int count = 0;
    for (var i = 0; i < tipSet.before.length; i++) {
      if (checkedKeys.contains(checkKey(type, 'before', i))) count++;
    }
    for (var i = 0; i < tipSet.during.length; i++) {
      if (checkedKeys.contains(checkKey(type, 'during', i))) count++;
    }
    for (var i = 0; i < tipSet.after.length; i++) {
      if (checkedKeys.contains(checkKey(type, 'after', i))) count++;
    }
    return count;
  }

  void _showModal(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThemeColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _DisasterModalContent(
          type: type,
          tipSet: tipSet,
          checkedKeys: checkedKeys,
          checkKey: checkKey,
          onToggleCheck: onToggleCheck,
          onCopy: onCopy,
          minTouchTarget: minTouchTarget,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = DisasterTypeColors.color(type);
    final hasTips = tipSet.before.isNotEmpty || tipSet.during.isNotEmpty || tipSet.after.isNotEmpty;
    final total = _totalChecklistCount();
    final count = _totalCheckedCount();
    final progress = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;

    return Semantics(
      label: '${type.label}, disaster tips, tap to open',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showModal(context),
          borderRadius: BorderRadius.circular(16),
          splashColor: accent.withValues(alpha: 0.12),
          highlightColor: accent.withValues(alpha: 0.06),
          child: Container(
            decoration: BoxDecoration(
              color: ThemeColors.surfaceContainer(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ThemeColors.border(context),
                width: 1,
              ),
              boxShadow: SoftUIDesign.getSoftShadow(context: context, elevation: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 4,
                    color: accent,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Icon(type.icon, color: accent, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                type.label,
                                style: AppTypography.titleMedium.copyWith(
                                  color: ThemeColors.textPrimary(context),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                hasTips ? 'Actionable preparedness checklist and survival tips.' : 'No tips available.',
                                style: AppTypography.bodySmall.copyWith(
                                  color: ThemeColors.textSecondary(context),
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (hasTips)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (total > 0)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              value: progress,
                                              strokeWidth: 2,
                                              backgroundColor: accent.withValues(alpha: 0.15),
                                              valueColor: AlwaysStoppedAnimation<Color>(accent),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '$count/$total completed',
                                            style: AppTypography.labelMedium.copyWith(
                                              color: ThemeColors.textSecondary(context),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      const SizedBox.shrink(),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'See tips',
                                          style: AppTypography.labelLarge.copyWith(
                                            color: accent,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.chevron_right_rounded, size: 16, color: accent),
                                      ],
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a card with staggered entrance animation (fade + slide).
class _StaggeredCard extends StatelessWidget {
  const _StaggeredCard({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // #region agent log
    _agentLog('H1', '_StaggeredCard.build', 'staggered card build', {
      'index': index,
      'isAnimatedWithFlutterAnimate': true,
    });
    // #endregion
    
    return child
        .animate(delay: Duration(milliseconds: index * 50))
        .fadeIn(duration: 400.ms, curve: Curves.easeOut)
        .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutCubic);
  }
}

class _GoBagWidget extends StatefulWidget {
  const _GoBagWidget();

  @override
  State<_GoBagWidget> createState() => _GoBagWidgetState();
}

class _GoBagWidgetState extends State<_GoBagWidget> {
  final List<Map<String, dynamic>> _baseItems = [
    {'id': 'water', 'icon': Icons.water_drop_rounded, 'label': 'Water'},
    {'id': 'flashlight', 'icon': Icons.flashlight_on_rounded, 'label': 'Flashlight'},
    {'id': 'firstaid', 'icon': Icons.medical_services_rounded, 'label': 'First Aid'},
    {'id': 'powerbank', 'icon': Icons.battery_charging_full_rounded, 'label': 'Powerbank'},
    {'id': 'whistle', 'icon': Icons.campaign_rounded, 'label': 'Whistle'},
    {'id': 'food', 'icon': Icons.fastfood_rounded, 'label': 'Food'},
  ];

  final List<Map<String, dynamic>> _suggestionPool = [
    {'id': 'radio', 'icon': Icons.radio_rounded, 'label': 'Radio'},
    {'id': 'batteries', 'icon': Icons.battery_std_rounded, 'label': 'Batteries'},
    {'id': 'meds', 'icon': Icons.medication_rounded, 'label': 'Meds'},
    {'id': 'docs', 'icon': Icons.folder_shared_rounded, 'label': 'Documents'},
    {'id': 'cash', 'icon': Icons.payments_rounded, 'label': 'Cash'},
    {'id': 'clothes', 'icon': Icons.checkroom_rounded, 'label': 'Clothes'},
    {'id': 'blanket', 'icon': Icons.bed_rounded, 'label': 'Blanket'},
    {'id': 'multitool', 'icon': Icons.handyman_rounded, 'label': 'Multi-tool'},
    {'id': 'matches', 'icon': Icons.local_fire_department_rounded, 'label': 'Matches'},
    {'id': 'hygiene', 'icon': Icons.clean_hands_rounded, 'label': 'Hygiene'},
  ];

  final Set<String> _addedSuggestions = {};
  final Set<String> _checkedItemIds = {};

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load old state (indices) if they exist and migrate to new String IDs
    final oldKeys = prefs.getKeys().where((k) => k.startsWith('${StorageKeys.disasterTipsCheckPrefix}gobag_')).toList();
    for (final k in oldKeys) {
      final suffix = k.split('_').last;
      final idx = int.tryParse(suffix);
      if (idx != null && idx >= 0 && idx < _baseItems.length) {
        if (prefs.getBool(k) == true) {
          _checkedItemIds.add(_baseItems[idx]['id']);
        }
        await prefs.remove(k); // Remove old key after migrating to memory
      }
    }

    // Load new state (string IDs)
    final checkKeys = prefs.getKeys().where((k) => k.startsWith('${StorageKeys.disasterTipsCheckPrefix}gobagcheck_')).toSet();
    for (final k in checkKeys) {
      if (prefs.getBool(k) == true) {
        _checkedItemIds.add(k.split('gobagcheck_').last);
      }
    }

    final addedKeys = prefs.getKeys().where((k) => k.startsWith('${StorageKeys.disasterTipsCheckPrefix}gobagadded_')).toSet();
    for (final k in addedKeys) {
      if (prefs.getBool(k) == true) {
        _addedSuggestions.add(k.split('gobagadded_').last);
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _toggleCheck(String id) async {
    HapticFeedback.lightImpact();
    final next = !_checkedItemIds.contains(id);
    setState(() {
      if (next) _checkedItemIds.add(id);
      else _checkedItemIds.remove(id);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${StorageKeys.disasterTipsCheckPrefix}gobagcheck_$id', next);
  }

  Future<void> _toggleAddedSuggestion(String id) async {
    HapticFeedback.lightImpact();
    final next = !_addedSuggestions.contains(id);
    setState(() {
      if (next) {
        _addedSuggestions.add(id);
      } else {
        _addedSuggestions.remove(id);
        _checkedItemIds.remove(id); // uncheck if removed
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${StorageKeys.disasterTipsCheckPrefix}gobagadded_$id', next);
    if (!next) {
      await prefs.remove('${StorageKeys.disasterTipsCheckPrefix}gobagcheck_$id');
    }
  }

  void _showSuggestionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeColors.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: ThemeColors.border(context),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Icon(Icons.add_box_rounded, color: DisasterTypeColors.general),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Suggested Items',
                            style: AppTypography.titleMedium.copyWith(
                              color: ThemeColors.textPrimary(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: ThemeColors.textSecondary(context)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to add or remove items from your Go-Bag.',
                      style: AppTypography.bodySmall.copyWith(color: ThemeColors.textSecondary(context)),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _suggestionPool.map((item) {
                        final id = item['id'] as String;
                        final isAdded = _addedSuggestions.contains(id);
                        final accent = DisasterTypeColors.general;
                        return GestureDetector(
                          onTap: () {
                            _toggleAddedSuggestion(id);
                            setModalState(() {});
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isAdded ? accent.withValues(alpha: 0.15) : ThemeColors.surfaceContainer(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isAdded ? accent.withValues(alpha: 0.5) : ThemeColors.border(context),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item['icon'] as IconData,
                                  size: 18,
                                  color: isAdded ? accent : ThemeColors.textSecondary(context),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  item['label'] as String,
                                  style: AppTypography.labelLarge.copyWith(
                                    color: isAdded ? accent : ThemeColors.textPrimary(context),
                                    fontWeight: isAdded ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                                if (isAdded) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.check_circle_rounded, size: 14, color: accent),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = DisasterTypeColors.general;
    
    final activeItems = [
      ..._baseItems,
      ..._suggestionPool.where((item) => _addedSuggestions.contains(item['id'])),
    ];

    final progress = activeItems.isEmpty ? 0.0 : _checkedItemIds.length / activeItems.length;
    final isComplete = _checkedItemIds.length == activeItems.length && activeItems.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        decoration: BoxDecoration(
          color: ThemeColors.surfaceContainer(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: SoftUIDesign.getSoftShadow(context: context, elevation: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.backpack_rounded, color: accent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Go-Bag Checklist',
                          style: AppTypography.titleMedium.copyWith(
                            color: ThemeColors.textPrimary(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_checkedItemIds.length} of ${activeItems.length} packed',
                          style: AppTypography.bodySmall.copyWith(
                            color: ThemeColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isComplete)
                    Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28)
                        .animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
                ],
              ),
            ),
            if (!isComplete && progress > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: accent.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ),
            if (!isComplete && progress > 0)
              const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ...activeItems.map((item) {
                    final id = item['id'] as String;
                    final checked = _checkedItemIds.contains(id);
                    return GestureDetector(
                      onTap: () => _toggleCheck(id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: checked ? accent.withValues(alpha: 0.15) : ThemeColors.surface(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: checked ? accent.withValues(alpha: 0.5) : ThemeColors.border(context),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item['icon'] as IconData,
                              size: 18,
                              color: checked ? accent : ThemeColors.textTertiary(context),
                            ).animate(target: checked ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
                            const SizedBox(width: 8),
                            Text(
                              item['label'] as String,
                              style: AppTypography.labelLarge.copyWith(
                                color: checked ? accent : ThemeColors.textSecondary(context),
                                fontWeight: checked ? FontWeight.w600 : FontWeight.w500,
                                decoration: checked ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  GestureDetector(
                    onTap: _showSuggestionsModal,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: ThemeColors.surface(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: ThemeColors.border(context),
                          width: 1,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 18, color: ThemeColors.textSecondary(context)),
                          const SizedBox(width: 6),
                          Text(
                            'Add items',
                            style: AppTypography.labelLarge.copyWith(
                              color: ThemeColors.textSecondary(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }
}
