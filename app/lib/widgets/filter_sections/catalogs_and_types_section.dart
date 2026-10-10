import 'package:flutter/material.dart';

import '../../controllers/filter_dialog_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';

class CatalogsAndTypesSection extends StatelessWidget {
  final FilterDialogController controller;
  final AppLocalizations l10n;
  final Color accentColor;

  const CatalogsAndTypesSection({
    super.key,
    required this.controller,
    required this.l10n,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final allCatalogs = FilterDialogController.defaultCatalogs;
    final allTypes = FilterDialogController.defaultObjectTypes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section: Catalogs
        Row(
          children: [
            Icon(Icons.auto_stories_rounded, size: 16, color: accentColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.catalogs,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: accentColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: allCatalogs.map((cat) {
            final selected = state.selectedCatalogs.contains(cat);
            return FilterChip(
              label: Text(cat),
              selected: selected,
              onSelected: (val) => controller.setCatalogSelected(cat, val),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // Section: Object Types
        Row(
          children: [
            Icon(Icons.blur_circular_rounded, size: 16, color: accentColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.objectTypes,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: accentColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: allTypes.map((type) {
            final selected = state.selectedObjectTypes.contains(type);
            return FilterChip(
              label: Text(localizeObjectType(type, l10n)),
              selected: selected,
              onSelected: (val) => controller.setObjectTypeSelected(type, val),
            );
          }).toList(),
        ),
      ],
    );
  }
}
