import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

import 'features/map/map_tab_flutter_map.dart';
import 'features/lines/lines_tab.dart';
import 'features/chat/chat_tab.dart';
import 'theme/app_theme.dart';
import 'theme/theme_extensions.dart';

class AppShell extends StatefulWidget {
  final AppThemeController themeController;
  const AppShell({super.key, required this.themeController});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final _mapKey = GlobalKey<MapTabFlutterMapState>();

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<AppGlass>() ?? AppGlass.light();
    final shapes =
        Theme.of(context).extension<AppShapes>() ?? AppShapes.defaults();
    final durations =
        Theme.of(context).extension<AppDurations>() ?? AppDurations.defaults();
    final colorScheme = Theme.of(context).colorScheme;

    final padding = MediaQuery.of(context).padding;
    final bottomInset = padding.bottom;
    const navHeight = 72.0;
    final navBottomMargin = 12.0 + bottomInset;
    final navHorizontalMargin = 16.0;
    final navOverlapHeight = navHeight + navBottomMargin;

    final tabs = <Widget>[
      MapTabFlutterMap(
        key: _mapKey,
        themeController: widget.themeController,
      ),
      const LinesTab(),
      ChatTab(
        navOverlapHeight: navOverlapHeight,
        onViewInMap: (lng, lat, payload) {
          _mapKey.currentState?.showFastestFromChat(payload);
          if (mounted) setState(() => _index = 0);
        },
      ),
    ];

    final unselectedColor = colorScheme.onSurface.withValues(alpha: .72);

    return Scaffold(
      // Sin AppBar en ningún tab
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(index: _index, children: tabs),
          ),
          Positioned(
            left: navHorizontalMargin,
            right: navHorizontalMargin,
            bottom: navBottomMargin,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(shapes.sheetRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: glass.blurSigma,
                  sigmaY: glass.blurSigma,
                ),
                child: AnimatedContainer(
                  duration: durations.normal,
                  height: navHeight,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: glass.surface.withValues(alpha: glass.opacity),
                    border: Border.all(color: glass.border),
                    borderRadius: BorderRadius.circular(shapes.sheetRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: Theme.of(context).brightness ==
                              Brightness.dark
                              ? 0.30
                              : 0.12,
                        ),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: GNav(
                      selectedIndex: _index,
                      onTabChange: (i) => setState(() => _index = i),
                      gap: 8,
                      haptic: true,
                      rippleColor: colorScheme.primary.withValues(alpha: .12),
                      hoverColor: colorScheme.primary.withValues(alpha: .08),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      tabBorderRadius: 22,
                      curve: Curves.easeOutQuad,
                      duration: const Duration(milliseconds: 260),
                      color: unselectedColor,
                      activeColor: colorScheme.onPrimaryContainer,
                      tabBackgroundColor: colorScheme.primaryContainer,
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