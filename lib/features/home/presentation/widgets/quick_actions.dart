import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/tk_components.dart';

/// Two shortcuts to routes that already exist: schedule search and the
/// nearby-places explorer.
class QuickActions extends StatelessWidget {
  const QuickActions({
    required this.onSearchTrains,
    required this.onExplore,
    super.key,
  });

  final VoidCallback onSearchTrains;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _ActionTile(
            icon: Icons.search_rounded,
            label: 'Cari kereta',
            onTap: onSearchTrains,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: Icons.explore_outlined,
            label: 'Jelajahi sekitar',
            onTap: onExplore,
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return TkCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      semanticLabel: label,
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tk.primarySoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: tk.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// The saved favorite route (one at most), opening trip search for it.
class FavoriteRouteTile extends StatelessWidget {
  const FavoriteRouteTile({
    required this.originName,
    required this.destinationName,
    required this.onTap,
    super.key,
  });

  final String originName;
  final String destinationName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    return TkCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      semanticLabel: 'Rute favorit, $originName ke $destinationName',
      child: Row(
        children: <Widget>[
          Icon(Icons.star_rounded, color: tk.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Rute favorit', style: textTheme.labelMedium),
                Text(
                  '$originName ke $destinationName',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: tk.textMuted),
        ],
      ),
    );
  }
}
