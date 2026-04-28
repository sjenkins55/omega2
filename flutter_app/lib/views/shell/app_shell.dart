import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  static const _tabs = [
    _TabItem(label: 'Home',     icon: Icons.home_outlined,      activeIcon: Icons.home,           path: '/'),
    _TabItem(label: 'History',  icon: Icons.history_outlined,   activeIcon: Icons.history,        path: '/history'),
    _TabItem(label: 'Insights', icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart,      path: '/insights'),
    _TabItem(label: 'Profile',  icon: Icons.person_outline,     activeIcon: Icons.person,         path: '/profile'),
  ];

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < _tabs.length; i++) {
      if (location == _tabs[i].path ||
          (i != 0 && location.startsWith(_tabs[i].path))) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (index) {
          if (index != selected) {
            context.go(_tabs[index].path);
          }
        },
        destinations: _tabs
            .map(
              (t) => NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.activeIcon),
                label: t.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TabItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String path;

  const _TabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.path,
  });
}
