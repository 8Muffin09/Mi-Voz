import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/communication_request.dart';
import '../../communication/application/requests_providers.dart';
import '../../communication/presentation/sync_status_banner.dart';
import '../../migration/presentation/migration_screen.dart';

/// Navegación principal del adulto (inicio, solicitudes, historial, ajustes).
class AdultShell extends ConsumerWidget {
  const AdultShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(adultRequestsProvider).value ?? const [];
    final newCount = requests
        .where((r) => r.status == RequestStatus.newRequest)
        .length;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    void select(int i) =>
        shell.goBranch(i, initialLocation: i == shell.currentIndex);

    final destinations = [
      (Icons.dashboard_outlined, Icons.dashboard_rounded, 'Inicio'),
      (Icons.inbox_outlined, Icons.inbox_rounded, 'Solicitudes'),
      (Icons.history_outlined, Icons.history_rounded, 'Historial'),
      (Icons.settings_outlined, Icons.settings_rounded, 'Ajustes'),
    ];

    Widget icon(int i, bool selected) {
      final base = Icon(selected ? destinations[i].$2 : destinations[i].$1);
      if (i == 1 && newCount > 0) {
        return Badge(label: Text('$newCount'), child: base);
      }
      return base;
    }

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (var i = 0; i < destinations.length; i++)
                  NavigationRailDestination(
                    icon: icon(i, false),
                    selectedIcon: icon(i, true),
                    label: Text(destinations[i].$3),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _WithSyncBanner(shell)),
          ],
        ),
      );
    }
    return Scaffold(
      body: _WithSyncBanner(shell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: select,
        destinations: [
          for (var i = 0; i < destinations.length; i++)
            NavigationDestination(
              key: Key('nav-$i'),
              icon: icon(i, false),
              selectedIcon: icon(i, true),
              label: destinations[i].$3,
            ),
        ],
      ),
    );
  }
}

class _WithSyncBanner extends StatelessWidget {
  const _WithSyncBanner(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SyncStatusBanner(),
      const MigrationOfferBanner(),
      Expanded(child: child),
    ],
  );
}
