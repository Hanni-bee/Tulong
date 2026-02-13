import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
  final Map<int, bool> _expanded = {};
  int? _lastExpandedIndex;
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
    final last = prefs.getInt(StorageKeys.disasterTipsLastExpandedIndex);
    if (last != null && last >= 0 && last < disasterTipsTypes.length) {
      if (mounted) {
        setState(() {
          _lastExpandedIndex = last;
          _expanded[last] = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scrollToExpandedCard(last);
          });
        });
      }
    }
    final keys = prefs.getKeys().where((k) => k.startsWith(StorageKeys.disasterTipsCheckPrefix)).toSet();
    final checked = keys.where((k) => prefs.getBool(k) == true).toSet();
    if (mounted) {
      setState(() => _checkedKeys.addAll(checked));
    }
    if (mounted) {
      _maybeShowFirstTimeHint(prefs);
    }
  }

  void _scrollToExpandedCard(int index) {
    if (!mounted || index < 0 || index >= _cardKeys.length) return;
    final ctx = _cardKeys[index].currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
  }

  Future<void> _maybeShowFirstTimeHint(SharedPreferences prefs) async {
    if (prefs.getBool(StorageKeys.disasterTipsHintShown) == true) return;
    await prefs.setBool(StorageKeys.disasterTipsHintShown, true);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tap a disaster to see what to do before, during, and after.',
          style: TextStyle(color: ThemeColors.textPrimary(context)),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ThemeColors.surfaceContainer(context),
      ),
    );
  }

  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();
    if (mounted) {
      setState(() {
        _expanded.clear();
        if (_lastExpandedIndex != null) {
          _expanded[_lastExpandedIndex!] = true;
        }
      });
    }
  }

  Future<void> _toggleExpanded(int index) async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    final next = !(_expanded[index] ?? false);
    setState(() {
      _expanded[index] = next;
      if (next) {
        _lastExpandedIndex = index;
      }
    });
    if (next) await prefs.setInt(StorageKeys.disasterTipsLastExpandedIndex, index);
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
              actions: [
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: ThemeColors.textPrimary(context)),
                  color: ThemeColors.surfaceContainer(context),
                  onSelected: (value) {
                    if (value == 'reset') _resetProgress();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'reset', child: Text('Reset progress')),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      DisasterTypeColors.general.withValues(alpha: 0.08),
                      DisasterTypeColors.general.withValues(alpha: 0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: DisasterTypeColors.general.withValues(alpha: 0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    ...SoftUIDesign.getSoftShadow(context: context, elevation: 1),
                    BoxShadow(
                      color: DisasterTypeColors.general.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            DisasterTypeColors.general.withValues(alpha: 0.2),
                            DisasterTypeColors.general.withValues(alpha: 0.12),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: SoftUIDesign.getSoftShadow(context: context, elevation: 1),
                      ),
                      child: Icon(
                        Icons.emergency_rounded,
                        size: 26,
                        color: DisasterTypeColors.general,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'What to do before, during, and after.',
                            style: AppTypography.bodyLarge.copyWith(
                              color: ThemeColors.textPrimary(context),
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap a category to expand and track your progress.',
                            style: AppTypography.bodySmall.copyWith(color: ThemeColors.textTertiary(context)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: DisasterTypeColors.general,
                backgroundColor: ThemeColors.surface(context),
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  itemCount: disasterTipsTypes.length,
                  itemBuilder: (context, index) {
                    // #region agent log
                    final t = disasterTipsTypes[index];
                    _agentLog('H4', 'disaster_tips_screen.dart:list', 'card list build', {
                      'index': index,
                      'cardCount': disasterTipsTypes.length,
                      'typeName': t.name,
                      'typeLabel': t.label,
                      'hasTipSet': disasterTipsData.containsKey(t),
                    });
                    // #endregion
                    final card = Padding(
                      key: _cardKeys[index],
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _DisasterCard(
                        type: disasterTipsTypes[index],
                        tipSet: disasterTipsData[disasterTipsTypes[index]]!,
                        expanded: _expanded[index] ?? false,
                        onTap: () => _toggleExpanded(index),
                        checkedKeys: _checkedKeys,
                        checkKey: _checkKey,
                        onToggleCheck: (type, phase, idx) => _toggleCheck(type, phase, idx),
                        onCopy: _copyTips,
                        minTouchTarget: _minTouchTarget,
                      ),
                    );
                    return _StaggeredCard(index: index, child: card);
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

class _DisasterCard extends StatelessWidget {
  final EmergencyType type;
  final DisasterTipSet tipSet;
  final bool expanded;
  final VoidCallback onTap;
  final Set<String> checkedKeys;
  final String Function(EmergencyType type, String phase, int tipIndex) checkKey;
  final void Function(EmergencyType type, String phase, int tipIndex) onToggleCheck;
  final void Function(DisasterTipSet set, EmergencyType type) onCopy;
  final double minTouchTarget;

  const _DisasterCard({
    required this.type,
    required this.tipSet,
    required this.expanded,
    required this.onTap,
    required this.checkedKeys,
    required this.checkKey,
    required this.onToggleCheck,
    required this.onCopy,
    required this.minTouchTarget,
  });

  @override
  Widget build(BuildContext context) {
    final accent = DisasterTypeColors.color(type);
    final hasTips = tipSet.before.isNotEmpty || tipSet.during.isNotEmpty || tipSet.after.isNotEmpty;

    // #region agent log
    final surfaceColor = ThemeColors.surfaceContainer(context);
    final textColor = ThemeColors.textPrimary(context);
    _agentLog('H2', '_DisasterCard.build', 'card building', {
      'typeLabel': type.label,
      'hasTips': hasTips,
      'accentHex': '#${accent.value.toRadixString(16)}',
      'surfaceHex': '#${surfaceColor.value.toRadixString(16)}',
      'textPrimaryHex': '#${textColor.value.toRadixString(16)}',
    });
    // #endregion

    final cardDecoration = SoftUIDesign.cardDecoration(
      context: context,
      backgroundColor: ThemeColors.surfaceContainer(context),
      borderRadius: SoftUIDesign.cardBorderRadius,
      elevation: expanded ? 6 : 4,
      showBorder: false,
    );

    return Semantics(
      label: '${type.label}, disaster tips, tap to expand',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SoftUIDesign.cardBorderRadius),
          splashColor: accent.withValues(alpha: 0.12),
          highlightColor: accent.withValues(alpha: 0.06),
          child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          decoration: cardDecoration,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(SoftUIDesign.cardBorderRadius),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(SoftUIDesign.cardBorderRadius)),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(SoftUIDesign.cardPadding, 14, SoftUIDesign.cardPadding, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildIconWithBadge(context, accent),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              type.label,
                              style: AppTypography.titleMedium.copyWith(
                                color: ThemeColors.textPrimary(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (!expanded) ...[
                              const SizedBox(height: 6),
                              Text(
                                hasTips ? 'Tap to see what to do before, during, and after.' : 'No tips available.',
                                style: AppTypography.bodySmall.copyWith(color: ThemeColors.textSecondary(context)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          Icons.expand_more_rounded,
                          size: 28,
                          color: ThemeColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: expanded
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Divider(height: 1, thickness: 1, color: accent.withValues(alpha: 0.25)),
                            if (hasTips && _totalChecklistCount() > 0) _buildProgressBar(context, accent),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                              child: hasTips ? _buildPhasesWithChips(context, accent) : _buildEmpty(context, accent),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              child: _buildCopyButton(context, accent),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  int _totalChecklistCount() {
    return tipSet.during.length;
  }

  int _duringCheckedCount() {
    int count = 0;
    for (var i = 0; i < tipSet.during.length; i++) {
      if (checkedKeys.contains(checkKey(type, 'during', i))) count++;
    }
    return count;
  }

  int _checkedCountForThisType() {
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

  Widget _buildIconWithBadge(BuildContext context, Color accent) {
    final count = _checkedCountForThisType();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accent.withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: SoftUIDesign.getSoftShadow(context: context, elevation: 1.5),
          ),
          child: Icon(type.icon, color: accent, size: 26),
        ),
        if (count > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ThemeColors.surfaceContainer(context), width: 1.5),
                boxShadow: SoftUIDesign.getSoftShadow(context: context, elevation: 1),
              ),
              constraints: const BoxConstraints(minWidth: 20),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: AppTypography.labelSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressBar(BuildContext context, Color accent) {
    final total = _totalChecklistCount();
    if (total == 0) return const SizedBox.shrink();
    final completed = _duringCheckedCount();
    final progress = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildCopyButton(BuildContext context, Color accent) {
    return Align(
      alignment: Alignment.centerRight,
      child: FilledButton.tonalIcon(
        onPressed: () => onCopy(tipSet, type),
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

  static const Map<String, IconData> _phaseIcons = {
    'Before': Icons.schedule_rounded,
    'During': Icons.emergency_rounded,
    'After': Icons.check_circle_outline_rounded,
  };

  Widget _buildPhasesWithChips(BuildContext context, Color accent) {
    final phases = <String>[];
    if (tipSet.before.isNotEmpty) phases.add('Before');
    if (tipSet.during.isNotEmpty) phases.add('During');
    if (tipSet.after.isNotEmpty) phases.add('After');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (phases.isNotEmpty) ...[
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: phases.map((label) {
              final icon = _phaseIcons[label];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.35), width: 1),
                  boxShadow: SoftUIDesign.getSoftShadow(context: context, elevation: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: accent),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: AppTypography.labelLarge.copyWith(color: accent, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],
        if (tipSet.before.isNotEmpty) _phaseSection(context, 'Before', tipSet.before, type, accent, false),
        if (tipSet.during.isNotEmpty) _phaseSection(context, 'During', tipSet.during, type, accent, true),
        if (tipSet.after.isNotEmpty) _phaseSection(context, 'After', tipSet.after, type, accent, false),
      ],
    );
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
              final key = checkKey(type, phaseKey, i);
              final checked = checkedKeys.contains(key);
              return Semantics(
                label: 'Checkbox, $text',
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onToggleCheck(type, phaseKey, i),
                      borderRadius: BorderRadius.circular(10),
                      splashColor: accent.withValues(alpha: 0.15),
                      highlightColor: accent.withValues(alpha: 0.08),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: minTouchTarget,
                              height: minTouchTarget,
                              child: Checkbox(
                                value: checked,
                                onChanged: (_) => onToggleCheck(type, phaseKey, i),
                                activeColor: accent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                fillColor: WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.selected)) return accent;
                                  return Colors.transparent;
                                }),
                              ),
                            ),
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
}

/// Wraps a card with staggered entrance animation (fade + slide).
class _StaggeredCard extends StatefulWidget {
  const _StaggeredCard({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_StaggeredCard> createState() => _StaggeredCardState();
}

class _StaggeredCardState extends State<_StaggeredCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.index * 40), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // #region agent log
    _agentLog('H1', '_StaggeredCard.build', 'staggered card build', {
      'index': widget.index,
      'controllerValue': _controller.value,
      'slideX': _slide.value.dx,
      'slideY': _slide.value.dy,
    });
    // #endregion
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SlideTransition(
          position: _slide,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
