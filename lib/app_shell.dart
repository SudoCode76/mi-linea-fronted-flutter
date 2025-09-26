import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'features/map/map_tab_flutter_map.dart';
import 'features/lines/lines_tab.dart';
import 'features/chat/chat_tab.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  // Clave para invocar métodos públicos del mapa
  final GlobalKey<MapTabFlutterMapState> _mapKey = GlobalKey<MapTabFlutterMapState>();

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    final bottomInset = padding.bottom;
    final navHorizontalMargin = 16.0;
    final navBottomMargin = 12.0 + bottomInset;
    const navHeight = 72.0;
    final navOverlapHeight = navHeight + navBottomMargin;

    final tabs = <Widget>[
      MapTabFlutterMap(key: _mapKey),
      const LinesTab(),
      ChatTab(
        navOverlapHeight: navOverlapHeight,
        onViewInMap: (oLng, oLat, payload) {
          // Mostrar la ruta en el mapa
          _mapKey.currentState?.showFastestFromChat(payload);
          // Cambiar a tab "Mapa"
          if (mounted) {
            setState(() => _index = 0);
          }
        },
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: IndexedStack(index: _index, children: tabs)),
          Positioned(
            left: navHorizontalMargin,
            right: navHorizontalMargin,
            bottom: navBottomMargin,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  height: navHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 6)),
                    ],
                  ),
                  child: Center(
                    child: GNav(
                      selectedIndex: _index,
                      onTabChange: (i) => setState(() => _index = i),
                      gap: 8,
                      haptic: true,
                      rippleColor: Colors.black12,
                      hoverColor: Colors.black12,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      tabBorderRadius: 22,
                      curve: Curves.easeOutQuad,
                      duration: const Duration(milliseconds: 280),
                      color: const Color(0xFF6F6F6F),
                      activeColor: Colors.white,
                      tabBackgroundColor: Theme.of(context).colorScheme.primary,
                      backgroundColor: Colors.transparent,
                      tabs: const [
                        GButton(icon: Icons.map_outlined, text: 'Mapa'),
                        GButton(icon: Icons.list_alt_outlined, text: 'Líneas'),
                        GButton(icon: Icons.chat_bubble_outline, text: 'Chat'),
                      ],
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