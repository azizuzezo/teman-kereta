import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';

/// What the Beranda "Mulai perjalanan" card plans: a KRL ride or an intercity
/// one. The two never share a station list or a search.
enum TripMode { krl, intercity }

class TripModeController extends Notifier<TripMode> {
  @override
  TripMode build() => TripMode.krl;

  void select(TripMode mode) => state = mode;
}

final tripModeProvider = NotifierProvider<TripModeController, TripMode>(
  TripModeController.new,
);

String tripModeLabel(TripMode mode) => switch (mode) {
  TripMode.krl => 'KRL',
  TripMode.intercity => 'Antar Kota',
};

/// The flip between KRL and Antar Kota.
class TripModeToggle extends StatelessWidget {
  const TripModeToggle({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final TripMode selected;
  final ValueChanged<TripMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tk.surface,
        borderRadius: BorderRadius.circular(TkRadius.control + 4),
        border: Border.all(color: tk.border),
      ),
      child: Row(
        children: <Widget>[
          for (final mode in TripMode.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: mode == selected,
                label: 'Mode ${tripModeLabel(mode)}',
                excludeSemantics: true,
                child: Material(
                  color: mode == selected ? tk.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(TkRadius.control),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(TkRadius.control),
                    onTap: () => onSelected(mode),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 40),
                      child: Center(
                        child: Text(
                          tripModeLabel(mode),
                          style: textTheme.labelLarge?.copyWith(
                            color: mode == selected
                                ? tk.onPrimary
                                : tk.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
