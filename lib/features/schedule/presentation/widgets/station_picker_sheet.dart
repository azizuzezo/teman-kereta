import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../domain/entities/transit_models.dart';

/// Searchable station list in a bottom sheet. Resolves to the picked
/// station id, or null when dismissed.
Future<String?> showStationPicker(
  BuildContext context, {
  required List<Station> stations,
  required String title,
  String? selectedId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _StationPickerSheet(
      stations: stations,
      title: title,
      selectedId: selectedId,
    ),
  );
}

class _StationPickerSheet extends StatefulWidget {
  const _StationPickerSheet({
    required this.stations,
    required this.title,
    required this.selectedId,
  });

  final List<Station> stations;
  final String title;
  final String? selectedId;

  @override
  State<_StationPickerSheet> createState() => _StationPickerSheetState();
}

class _StationPickerSheetState extends State<_StationPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final needle = _query.trim().toLowerCase();
    final sorted = List<Station>.of(widget.stations)
      ..sort((a, b) => a.name.compareTo(b.name));
    final filtered = needle.isEmpty
        ? sorted
        : sorted
              .where(
                (s) =>
                    s.name.toLowerCase().contains(needle) ||
                    s.code.toLowerCase().contains(needle),
              )
              .toList(growable: false);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Semantics(
                header: true,
                child: Text(widget.title, style: textTheme.titleLarge),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: false,
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Cari nama atau kode stasiun',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Stasiun tidak ditemukan',
                          style: textTheme.bodyMedium?.copyWith(
                            color: tk.textMuted,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final station = filtered[index];
                        final selected = station.id == widget.selectedId;
                        return ListTile(
                          minTileHeight: 56,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              TkRadius.control,
                            ),
                          ),
                          selected: selected,
                          selectedTileColor: tk.primarySoft,
                          selectedColor: tk.primary,
                          leading: Icon(
                            selected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: selected ? tk.primary : tk.textMuted,
                          ),
                          title: Text(
                            station.name,
                            style: textTheme.titleSmall?.copyWith(
                              color: selected ? tk.primary : tk.text,
                            ),
                          ),
                          trailing: Text(
                            station.code,
                            style: textTheme.labelMedium?.copyWith(
                              color: tk.textMuted,
                              fontFeatures: AppTheme.timeFeatures,
                            ),
                          ),
                          onTap: () => Navigator.pop(context, station.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
