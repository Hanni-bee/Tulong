import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../providers/chat_provider.dart';
import '../utils/theme_colors.dart';

/// RF channel values for Channel 1–5. Must match ChatProvider usage.
const List<int> rfChannelValues = [108, 100, 104, 112, 120];

/// SharedPreferences key for selected channel index (0–4). Must match ChatProvider.
const String rfChannelPrefKey = 'rf_channel_index';

/// Shows a modal bottom sheet to select RF channel (Channel 1–5).
/// On selection: saves to SharedPreferences, calls [chatProvider.setRfChannel]
/// and [chatProvider.addChannelSwitchNotification], then pops with the selected index.
/// [onSelected] is called with the new index after pop (e.g. for Home to update state).
Future<void> showChannelSelectorModal(
  BuildContext context,
  ChatProvider chatProvider, {
  void Function(int index)? onSelected,
}) async {
  final index = await showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _ChannelSelectorModalContent(
      chatProvider: chatProvider,
      onSelected: onSelected,
    ),
  );
  if (index != null) onSelected?.call(index);
}

class _ChannelSelectorModalContent extends StatefulWidget {
  final ChatProvider chatProvider;
  final void Function(int index)? onSelected;

  const _ChannelSelectorModalContent({
    required this.chatProvider,
    this.onSelected,
  });

  @override
  State<_ChannelSelectorModalContent> createState() =>
      _ChannelSelectorModalContentState();
}

class _ChannelSelectorModalContentState extends State<_ChannelSelectorModalContent> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedIndex();
  }

  Future<void> _loadSavedIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(rfChannelPrefKey);
    if (!mounted) return;
    setState(() {
      _selectedIndex = (saved ?? 0).clamp(0, rfChannelValues.length - 1);
    });
  }

  Future<void> _selectChannel(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(rfChannelPrefKey, index);
    await widget.chatProvider.setRfChannel(rfChannelValues[index]);
    widget.chatProvider.addChannelSwitchNotification(index + 1);
    if (!context.mounted) return;
    Navigator.pop(context, index);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: ThemeColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: ThemeColors.shadow(context, opacity: 0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ThemeColors.textTertiary(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'RF Channel',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ThemeColors.textPrimary(context),
                    ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: rfChannelValues.length,
                itemBuilder: (context, i) {
                  final isSelected = i == _selectedIndex;
                  return Semantics(
                    label: 'Channel ${i + 1} (RF ${rfChannelValues[i]})',
                    selected: isSelected,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _selectChannel(i),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? ThemeColors.surfaceContainerHigh(context)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(
                                    color: AppColors.primaryRed.withOpacity(0.3),
                                    width: 1,
                                  )
                                : null,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Channel ${i + 1} (RF ${rfChannelValues[i]})',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        isSelected ? FontWeight.w600 : FontWeight.w500,
                                    color: ThemeColors.textPrimary(context),
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  size: 22,
                                  color: AppColors.primaryRed,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
