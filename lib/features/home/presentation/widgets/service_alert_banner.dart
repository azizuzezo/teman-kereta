import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/data_badges.dart';
import '../../../../domain/entities/transit_models.dart';

/// Compact banner for real service disruptions. The caller only builds it
/// when [alerts] is non-empty (see `disruptionAlerts`): a normal service
/// shows nothing at all.
class ServiceAlertBanner extends StatelessWidget {
  const ServiceAlertBanner({required this.alerts, super.key});

  /// Non-empty, most severe first.
  final List<ServiceAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final top = alerts.first;
    final severe = top.status == ServiceStatus.disrupted;
    final fill = severe ? tk.dangerSoft : tk.warningSoft;
    final fg = severe ? tk.danger : tk.warning;
    final extra = alerts.length - 1;

    return Semantics(
      container: true,
      button: true,
      label:
          'Gangguan layanan: ${top.title}. ${top.description}'
          '${extra > 0 ? ' Dan $extra info lainnya.' : ''} Ketuk untuk detail.',
      excludeSemantics: true,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(TkRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showDetails(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                children: <Widget>[
                  Icon(
                    severe ? Icons.error_rounded : Icons.warning_amber_rounded,
                    color: fg,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          top.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(color: fg),
                        ),
                        if (top.description.isNotEmpty)
                          Text(
                            top.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: tk.text,
                            ),
                          ),
                        if (extra > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '+$extra info lainnya',
                              style: textTheme.labelMedium?.copyWith(color: fg),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: tk.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => _AlertSheet(alerts: alerts),
      ),
    );
  }
}

class _AlertSheet extends StatelessWidget {
  const _AlertSheet({required this.alerts});

  final List<ServiceAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: <Widget>[
            Text('Info layanan', style: textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final alert in alerts) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(alert.title, style: textTheme.titleSmall),
                  ),
                  const SizedBox(width: 8),
                  ServiceStatusBadge(status: alert.status),
                ],
              ),
              if (alert.description.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(alert.description, style: textTheme.bodyMedium),
              ],
              const SizedBox(height: 4),
              Text(
                '${alert.sourceLabel} · ${DateFormat('d MMM, HH.mm', 'id_ID').format(alert.updatedAt)}',
                style: textTheme.bodySmall,
              ),
              if (alert != alerts.last) ...<Widget>[
                const SizedBox(height: 12),
                Divider(color: tk.border),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
