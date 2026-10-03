import 'package:flutter/material.dart';

import '../theme/astro_theme.dart';

/// Reusable responsive master/detail scaffold for target list screens.
/// On desktop/tablet (width >= [breakpointWidth]), renders side-by-side master list and detail pane.
/// On mobile (width < [breakpointWidth]), renders full-width list view and triggers tap callbacks.
class TargetListScaffold<T> extends StatelessWidget {
  final List<T> items;
  final T? selectedItem;
  final ValueChanged<T> onItemSelected;
  final Widget Function(BuildContext context, T item, bool isSelected) itemBuilder;
  final Widget Function(BuildContext context, T item)? detailBuilder;
  final Widget? header;
  final Widget emptyState;
  final bool isLoading;
  final double breakpointWidth;
  final int masterFlex;
  final int detailFlex;
  final EdgeInsetsGeometry contentPadding;

  const TargetListScaffold({
    super.key,
    required this.items,
    this.selectedItem,
    required this.onItemSelected,
    required this.itemBuilder,
    this.detailBuilder,
    this.header,
    required this.emptyState,
    this.isLoading = false,
    this.breakpointWidth = 900.0,
    this.masterFlex = 5,
    this.detailFlex = 6,
    this.contentPadding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    final palette = AstroPalette.of(context);
    final isWide = MediaQuery.of(context).size.width >= breakpointWidth;

    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(color: palette.accent),
      );
    }

    final listView = items.isEmpty
        ? emptyState
        : ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isSelected = isWide && selectedItem == item;
              return itemBuilder(context, item, isSelected);
            },
          );

    final masterPane = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) ...[
          header!,
          const SizedBox(height: 8),
        ],
        Expanded(child: listView),
      ],
    );

    if (!isWide) {
      return Padding(
        padding: contentPadding,
        child: masterPane,
      );
    }

    // Wide screen: 2-pane master/detail
    final detailPane = (selectedItem != null && detailBuilder != null)
        ? detailBuilder!(context, selectedItem as T)
        : Center(
            child: Text(
              "Select a target to view details",
              style: TextStyle(color: palette.textSecondary, fontSize: 13),
            ),
          );

    return Padding(
      padding: contentPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: masterFlex, child: masterPane),
          const SizedBox(width: 14),
          Expanded(flex: detailFlex, child: detailPane),
        ],
      ),
    );
  }
}
