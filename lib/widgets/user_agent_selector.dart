import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserAgentSelector extends ConsumerWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const UserAgentSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  Future<void> _editPreset(
    BuildContext context,
    WidgetRef ref, [
    UserAgentPreset? preset,
  ]) async {
    final nameController = TextEditingController(text: preset?.name);
    final valueController = TextEditingController(text: preset?.value);
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<({String name, String value})>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        clipBehavior: Clip.antiAlias,
        title: Text(
          preset == null
              ? context.appLocalizations.addUserAgentPreset
              : context.appLocalizations.editUserAgentPreset,
        ),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: context.appLocalizations.name,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? context.appLocalizations.emptyTip(
                          context.appLocalizations.name,
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: valueController,
                  maxLength: TextInputLimits.userAgent,
                  inputFormatters: TextInputLimits.limit(
                    TextInputLimits.userAgent,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: context.appLocalizations.userAgent,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? context.appLocalizations.emptyTip(
                          context.appLocalizations.userAgent,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.appLocalizations.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(dialogContext, (
                name: nameController.text.trim(),
                value: valueController.text.trim(),
              ));
            },
            child: Text(context.appLocalizations.save),
          ),
        ],
      ),
    );
    nameController.dispose();
    valueController.dispose();
    if (result == null) return;
    await ref
        .read(userAgentPresetsProvider.notifier)
        .save(id: preset?.id, name: result.name, value: result.value);
  }

  Future<void> _managePresets(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, dialogRef, _) {
          final presets = dialogRef.watch(userAgentPresetsProvider);
          return AlertDialog(
            clipBehavior: Clip.antiAlias,
            title: Text(context.appLocalizations.userAgentPresets),
            content: SizedBox(
              width: 560,
              child: presets.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Text(
                        context.appLocalizations.noUserAgentPresets,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 420),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: presets.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final preset = presets[index];
                          return ListTile(
                            title: Text(preset.name),
                            subtitle: Text(
                              preset.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: context.appLocalizations.edit,
                                  onPressed: () =>
                                      _editPreset(context, dialogRef, preset),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: context.appLocalizations.delete,
                                  onPressed: () => dialogRef
                                      .read(userAgentPresetsProvider.notifier)
                                      .remove(preset.id),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () => _editPreset(context, dialogRef),
                icon: const Icon(Icons.add_rounded),
                label: Text(context.appLocalizations.add),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(context.appLocalizations.submit),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customPresets = ref.watch(userAgentPresetsProvider);
    final presets = <UserAgentPreset>[];
    final seenValues = <String>{};
    for (final preset in [...builtInUserAgentPresets, ...customPresets]) {
      if (seenValues.add(preset.value)) presets.add(preset);
    }
    final knownValues = presets.map((item) => item.value).toSet();
    final selectedValue = value.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            key: ValueKey(selectedValue),
            initialValue: selectedValue,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.appLocalizations.userAgent,
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(context.appLocalizations.defaultText),
              ),
              for (final preset in presets)
                DropdownMenuItem(
                  value: preset.value,
                  child: Text(
                    '${preset.name} · ${preset.value}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (selectedValue.isNotEmpty &&
                  !knownValues.contains(selectedValue))
                DropdownMenuItem(
                  value: selectedValue,
                  child: Text(
                    '${context.appLocalizations.custom} · $selectedValue',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (next) => onChanged(next ?? ''),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          tooltip: context.appLocalizations.userAgentPresets,
          onPressed: () => _managePresets(context, ref),
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    );
  }
}
