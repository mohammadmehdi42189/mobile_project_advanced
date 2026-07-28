import 'package:flutter/material.dart';
import 'library_screen.dart';
import 'discover_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  static const pages = [
    DiscoverScreen(),
    SearchScreen(),
    LibraryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: index, children: pages),
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (value) => setState(() => index = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          label: 'محبوب',
        ),
        NavigationDestination(icon: Icon(Icons.search), label: 'جست‌وجو'),
        NavigationDestination(
          icon: Icon(Icons.video_library_outlined),
          label: 'فهرست‌ها',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'پروفایل',
        ),
      ],
    ),
  );
}
