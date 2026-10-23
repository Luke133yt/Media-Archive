import 'package:flutter/material.dart';

import 'add_page.dart';
import 'glass.dart';
import 'library_page.dart';
import 'movie_night_page.dart';
import 'settings_page.dart';
import '../update_service.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  static const _pages = <Widget>[
    LibraryPage(),
    SettingsPage(),
    MovieNightPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateService.checkAndPrompt(context);
    });
  }

  void _add() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const AddPage()));

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final body = IndexedStack(index: _index, children: _pages);

    if (wide) {
      return Scaffold(
        floatingActionButton: _index == 0
            ? FloatingActionButton.extended(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Aggiungi'),
              )
            : null,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 12),
                radius: 28,
                child: NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  labelType: NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Icon(Icons.album, size: 30),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.video_library_outlined),
                      selectedIcon: Icon(Icons.video_library),
                      label: Text('Archivio'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.tune),
                      selectedIcon: Icon(Icons.tune),
                      label: Text('Impostazioni'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.add_circle_outline),
                      selectedIcon: Icon(Icons.add_circle),
                      label: Text('Movie Night'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: body),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      floatingActionButton: _index == 0
          ? FloatingActionButton(
              onPressed: _add,
              child: const Icon(Icons.add),
            )
          : null,
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: GlassCard(
            padding: EdgeInsets.zero,
            radius: 30,
            child: NavigationBar(
              height: 64,
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.video_library_outlined),
                  selectedIcon: Icon(Icons.video_library),
                  label: 'Archivio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune),
                  label: 'Impostazioni',
                ),
                NavigationDestination(
                  icon: Icon(Icons.add_circle_outline),
                  selectedIcon: Icon(Icons.add_circle),
                  label: 'Movie Night',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
