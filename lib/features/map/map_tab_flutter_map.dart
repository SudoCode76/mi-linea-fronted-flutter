import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:latlong2/latlong.dart' as ll;

import 'package:mi_linea/core/env.dart';
import 'package:mi_linea/core/geocoding.dart';
import 'package:mi_linea/core/geojson.dart';
import 'package:mi_linea/data/models/fastest_option.dart';
import 'package:mi_linea/data/services/backend_service.dart';
import 'package:mi_linea/theme/app_theme.dart';
import 'package:mi_linea/theme/theme_extensions.dart';

enum BaseMapStyle {
  osm,
  mapboxStreets,
  mapboxNavigation,
  mapboxLight,
  mapboxSatellite,
  cartoVoyager,
}

class MapTabFlutterMap extends StatefulWidget {
  final AppThemeController themeController;
  const MapTabFlutterMap({
    super.key,
    required this.themeController,
  });
  @override
  MapTabFlutterMapState createState() => MapTabFlutterMapState();
}

class MapTabFlutterMapState extends State<MapTabFlutterMap> {
  final mapCtl = MapController();
  final api = BackendService();

  final originCtl = TextEditingController();
  final destCtl = TextEditingController();
  final FocusNode _originFocus = FocusNode();
  final FocusNode _destFocus = FocusNode();

  LngLat? origin;
  LngLat? destination;

  bool pickingOrigin = false;
  bool pickingDestination = false;

  List<FastestOption> results = [];
  FastestOption? selected;
  bool loading = false;

  List<PlaceSuggestion> _originSugs = [];
  List<PlaceSuggestion> _destSugs = [];
  Timer? _debounce;

  final ll.LatLng cochabamba = const ll.LatLng(-17.39, -66.157);

  BaseMapStyle _style = BaseMapStyle.mapboxStreets;

  @override
  void dispose() {
    _debounce?.cancel();
    _originFocus.dispose();
    _destFocus.dispose();
    originCtl.dispose();
    destCtl.dispose();
    super.dispose();
  }

  // ---- Método público invocado desde el Chat ----
  void showFastestFromChat(Map<String, dynamic> payload) {
    final fastest = payload['fastest'];
    final originJson = payload['origin'];
    final destJson = payload['destination'];

    if (originJson is Map && originJson['lng'] != null && originJson['lat'] != null) {
      origin = LngLat(
        (originJson['lng'] as num).toDouble(),
        (originJson['lat'] as num).toDouble(),
      );
      originCtl.text = originJson['label']?.toString() ?? originCtl.text;
    }
    if (destJson is Map && destJson['lng'] != null && destJson['lat'] != null) {
      destination = LngLat(
        (destJson['lng'] as num).toDouble(),
        (destJson['lat'] as num).toDouble(),
      );
      destCtl.text = destJson['label']?.toString() ?? destCtl.text;
    }

    final List<FastestOption> newResults = [];
    if (fastest is Map) {
      final resList = fastest['results'];
      if (resList is List) {
        for (final r in resList) {
          if (r is Map<String, dynamic>) {
            newResults.add(FastestOption.fromJson(r));
          } else if (r is Map) {
            newResults.add(FastestOption.fromJson(Map<String, dynamic>.from(r)));
          }
        }
      }
    }

    if (newResults.isNotEmpty) {
      results = newResults;
      selected = newResults.first;
      final segs = parseGeoJsonLine(selected!.segGeom, color: colorFromHex(selected!.colorHex), width: 6);
      final walkTo = parseGeoJsonLine(selected!.walkTo, color: const Color(0xFF757575), width: 3);
      final walkFrom = parseGeoJsonLine(selected!.walkFrom, color: const Color(0xFF757575), width: 3);
      _fitToLines([...walkTo, ...segs, ...walkFrom]);
    }

    pickingOrigin = false;
    pickingDestination = false;
    _originSugs = [];
    _destSugs = [];
    _originFocus.unfocus();
    _destFocus.unfocus();
    if (mounted) setState(() {});
  }

  // --- Tile layer adaptado a modo oscuro ---
  TileLayer _buildTileLayer(BuildContext context) {
    final token = AppEnv.mapboxToken;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (_style) {
      case BaseMapStyle.mapboxStreets:
        return TileLayer(
          urlTemplate: isDark
              ? 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/256/{z}/{x}/{y}{r}?access_token=$token&language=es'
              : 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}{r}?access_token=$token&language=es',
          retinaMode: MediaQuery.of(context).devicePixelRatio > 1.5,
          userAgentPackageName: 'com.example.mi_linea',
        );
      case BaseMapStyle.mapboxNavigation:
        return TileLayer(
          urlTemplate: isDark
              ? 'https://api.mapbox.com/styles/v1/mapbox/navigation-night-v1/tiles/256/{z}/{x}/{y}{r}?access_token=$token&language=es'
              : 'https://api.mapbox.com/styles/v1/mapbox/navigation-day-v1/tiles/256/{z}/{x}/{y}{r}?access_token=$token&language=es',
          retinaMode: MediaQuery.of(context).devicePixelRatio > 1.5,
          userAgentPackageName: 'com.example.mi_linea',
        );
      case BaseMapStyle.mapboxLight:
        return TileLayer(
          urlTemplate: isDark
              ? 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/256/{z}/{x}/{y}{r}?access_token=$token&language=es'
              : 'https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/256/{z}/{x}/{y}{r}?access_token=$token&language=es',
          retinaMode: MediaQuery.of(context).devicePixelRatio > 1.5,
          userAgentPackageName: 'com.example.mi_linea',
        );
      case BaseMapStyle.mapboxSatellite:
        return TileLayer(
          urlTemplate:
          'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/256/{z}/{x}/{y}{r}?access_token=$token&language=es',
          retinaMode: MediaQuery.of(context).devicePixelRatio > 1.5,
          userAgentPackageName: 'com.example.mi_linea',
        );
      case BaseMapStyle.cartoVoyager:
        return TileLayer(
          urlTemplate:
          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.example.mi_linea',
        );
      case BaseMapStyle.osm:
      default:
        return TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.example.mi_linea',
        );
    }
  }

  Future<void> _pickBaseMap() async {
    final chosen = await showModalBottomSheet<BaseMapStyle>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.90,
          builder: (ctx, controller) {
            return _BasemapPickerList(
              current: _style,
              scrollController: controller,
            );
          },
        );
      },
    );
    if (chosen != null && mounted) setState(() => _style = chosen);
  }

  Future<void> _openThemePicker() async {
    final pref = widget.themeController.preference;
    final picked = await showModalBottomSheet<ThemePreference>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _themeTile(ThemePreference.system, 'Sistema', Icons.phone_android, pref),
              _themeTile(ThemePreference.light, 'Claro', Icons.light_mode_outlined, pref),
              _themeTile(ThemePreference.dark, 'Oscuro', Icons.dark_mode_outlined, pref),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked != null) {
      await widget.themeController.setPreference(picked);
    }
  }

  ListTile _themeTile(ThemePreference p, String label, IconData icon, ThemePreference current) {
    final sel = p == current;
    return ListTile(
      leading: Icon(icon, color: sel ? Theme.of(context).colorScheme.primary : null),
      title: Text(label),
      trailing: sel ? const Icon(Icons.check_circle, color: Colors.green) : null,
      onTap: () => Navigator.pop(context, p),
    );
  }

  void _fitToLines(List<GeoLine> lines) {
    final pts = lines.expand((l) => l.points).toList();
    if (pts.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(
      pts.map((p) => ll.LatLng(p.lat, p.lng)).toList(),
    );
    scheduleMicrotask(() {
      try {
        mapCtl.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.fromLTRB(24, 140, 24, 220),
          ),
        );
      } catch (_) {}
    });
  }

  Future<void> _useMyLocationAsOrigin() async {
    try {
      var perm = await geo.Geolocator.checkPermission();
      if (perm == geo.LocationPermission.denied) {
        perm = await geo.Geolocator.requestPermission();
      }
      if (perm == geo.LocationPermission.deniedForever) return;
      final p = await geo.Geolocator.getCurrentPosition(
        locationSettings:
        const geo.LocationSettings(accuracy: geo.LocationAccuracy.best),
      );
      final coords = LngLat(p.longitude, p.latitude);
      setState(() {
        origin = coords;
        originCtl.text = 'Buscando dirección…';
        _originSugs = [];
      });
      unawaited(_updateOriginLabelWithReverse(coords));
      mapCtl.move(ll.LatLng(p.latitude, p.longitude), 15);
    } catch (e) {
      _alert('Ubicación', '$e');
    }
  }

  Future<void> _updateOriginLabelWithReverse(LngLat c) async {
    final name = await GeocodingService.reverse(c.lng, c.lat);
    if (!mounted) return;
    if (origin == c && (name ?? '').isNotEmpty) {
      setState(() => originCtl.text = name!);
    }
  }

  Future<void> _updateDestLabelWithReverse(LngLat c) async {
    final name = await GeocodingService.reverse(c.lng, c.lat);
    if (!mounted) return;
    if (destination == c && (name ?? '').isNotEmpty) {
      setState(() => destCtl.text = name!);
    }
  }

  Future<void> _geocode({required bool forOrigin}) async {
    final query = forOrigin ? originCtl.text.trim() : destCtl.text.trim();
    if (query.isEmpty) return;
    final res = await GeocodingService.searchFirst(query);
    if (res.error != null) return _alert('Geocoding', res.error!);
    final c = res.coord!;
    final name = res.name ?? query;
    setState(() {
      if (forOrigin) {
        origin = c;
        originCtl.text = name;
        _originSugs = [];
        pickingOrigin = false;
      } else {
        destination = c;
        destCtl.text = name;
        _destSugs = [];
        pickingDestination = false;
      }
    });
    mapCtl.move(ll.LatLng(c.lat, c.lng), 15);
  }

  Future<void> _calc() async {
    if (origin == null || destination == null) {
      return _alert('Faltan datos', 'Define Origen y Destino (escribe o pulsa en el mapa).');
    }
    setState(() {
      loading = true;
      results = [];
      selected = null;
    });
    try {
      final r = await api.fastest(
        oLng: origin!.lng,
        oLat: origin!.lat,
        dLng: destination!.lng,
        dLat: destination!.lat,
      );
      if (!mounted) return;
      setState(() {
        results = r;
        selected = r.isNotEmpty ? r.first : null;
      });
      if (r.isEmpty) {
        _alert('Sin resultados', 'No se encontraron líneas cercanas.');
      } else {
        final segs = parseGeoJsonLine(selected!.segGeom, color: colorFromHex(selected!.colorHex), width: 6);
        final walkTo = parseGeoJsonLine(selected!.walkTo, color: const Color(0xFF757575), width: 3);
        final walkFrom = parseGeoJsonLine(selected!.walkFrom, color: const Color(0xFF757575), width: 3);
        _fitToLines([...walkTo, ...segs, ...walkFrom]);
      }
    } catch (e) {
      _alert('Error al calcular', '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _alert(String title, String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  List<Polyline> _polylines() {
    if (selected == null) return [];
    final segs = parseGeoJsonLine(selected!.segGeom, color: colorFromHex(selected!.colorHex), width: 6);
    final walkTo = parseGeoJsonLine(selected!.walkTo, color: const Color(0xFF757575), width: 3);
    final walkFrom = parseGeoJsonLine(selected!.walkFrom, color: const Color(0xFF757575), width: 3);

    Polyline stroke(GeoLine l, Color c, double w) => Polyline(
      points: l.points.map((p) => ll.LatLng(p.lat, p.lng)).toList(),
      color: c,
      strokeWidth: w,
    );

    final lines = <Polyline>[];
    for (final l in segs) {
      lines.add(stroke(l, Colors.white, l.width + 4));
      lines.add(stroke(l, l.color, l.width));
    }
    for (final l in [...walkTo, ...walkFrom]) {
      lines.add(stroke(l, Colors.white, l.width + 2));
      lines.add(stroke(l, l.color.withOpacity(.85), l.width));
    }
    return lines;
  }

  void _recenter() {
    if (selected == null) return;
    final segs = parseGeoJsonLine(selected!.segGeom, color: colorFromHex(selected!.colorHex), width: 6);
    final walkTo = parseGeoJsonLine(selected!.walkTo, color: const Color(0xFF757575), width: 3);
    final walkFrom = parseGeoJsonLine(selected!.walkFrom, color: const Color(0xFF757575), width: 3);
    _fitToLines([...walkTo, ...segs, ...walkFrom]);
  }

  void _debouncedSuggest({required bool forOrigin, required String text}) {
    _debounce?.cancel();
    if (text.trim().length < 3) {
      setState(() {
        if (forOrigin) {
          _originSugs = [];
        } else {
          _destSugs = [];
        }
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final list = await GeocodingService.suggest(text.trim(), limit: 6);
      if (!mounted) return;
      setState(() {
        if (forOrigin) {
          _originSugs = list;
        } else {
          _destSugs = list;
        }
      });
    });
  }

  void _selectOriginSuggestion(PlaceSuggestion s) {
    setState(() {
      origin = s.coord;
      originCtl.text = s.name;
      _originSugs = [];
      pickingOrigin = false;
    });
    mapCtl.move(ll.LatLng(s.coord.lat, s.coord.lng), 15);
  }

  void _selectDestSuggestion(PlaceSuggestion s) {
    setState(() {
      destination = s.coord;
      destCtl.text = s.name;
      _destSugs = [];
      pickingDestination = false;
    });
    mapCtl.move(ll.LatLng(s.coord.lat, s.coord.lng), 15);
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    final size = MediaQuery.of(context).size;
    final topInset = padding.top;
    final bottomInset = padding.bottom;

    const navHeight = 72.0;
    const navBottomMargin = 12.0;
    final navTotalBottom = navHeight + navBottomMargin + bottomInset;
    final sheetMinPx = size.height * 0.22;

    final markers = <Marker>[
      if (origin != null)
        Marker(
          point: ll.LatLng(origin!.lat, origin!.lng),
          width: 40,
          height: 40,
          child: const _Pin(color: Color(0xFF007AFF)),
        ),
      if (destination != null)
        Marker(
          point: ll.LatLng(destination!.lat, destination!.lng),
          width: 40,
          height: 40,
          child: const _Pin(color: Color(0xFFFF3B30)),
        ),
    ];

    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: mapCtl,
            options: MapOptions(
              initialCenter: cochabamba,
              initialZoom: 12,
              onTap: (tapPos, latlng) {
                setState(() {
                  if (pickingOrigin) {
                    final c = LngLat(latlng.longitude, latlng.latitude);
                    origin = c;
                    originCtl.text = 'Buscando dirección…';
                    _originSugs = [];
                    pickingOrigin = false;
                    unawaited(_updateOriginLabelWithReverse(c));
                  } else if (pickingDestination) {
                    final c = LngLat(latlng.longitude, latlng.latitude);
                    destination = c;
                    destCtl.text = 'Buscando dirección…';
                    _destSugs = [];
                    pickingDestination = false;
                    unawaited(_updateDestLabelWithReverse(c));
                  }
                });
              },
              onLongPress: (tapPos, latlng) {
                final c = LngLat(latlng.longitude, latlng.latitude);
                setState(() {
                  destination = c;
                  destCtl.text = 'Buscando dirección…';
                  _destSugs = [];
                  pickingDestination = false;
                  pickingOrigin = false;
                });
                unawaited(_updateDestLabelWithReverse(c));
              },
            ),
            children: [
              _buildTileLayer(context),
              PolylineLayer(polylines: _polylines()),
              MarkerLayer(markers: markers),
            ],
          ),
        ),
        // Pill superior (sin AppBar, se compensa con topInset)
        Positioned(
          top: topInset + 8,
          left: 12,
          right: 12,
          child: _SearchPill(
            originCtl: originCtl,
            destCtl: destCtl,
            originFocus: _originFocus,
            destFocus: _destFocus,
            originSugs: _originSugs,
            destSugs: _destSugs,
            onOriginChanged: (t) => _debouncedSuggest(forOrigin: true, text: t),
            onDestChanged: (t) => _debouncedSuggest(forOrigin: false, text: t),
            onPickOrigin: () => setState(() {
              pickingOrigin = !pickingOrigin;
              if (pickingOrigin) {
                pickingDestination = false;
                _originFocus.unfocus();
                _destFocus.unfocus();
                _originSugs = [];
                _destSugs = [];
              }
            }),
            onPickDestination: () => setState(() {
              pickingDestination = !pickingDestination;
              if (pickingDestination) {
                pickingOrigin = false;
                _originFocus.unfocus();
                _destFocus.unfocus();
                _originSugs = [];
                _destSugs = [];
              }
            }),
            onSelectOriginSuggestion: _selectOriginSuggestion,
            onSelectDestSuggestion: _selectDestSuggestion,
            onGeocodeOrigin: () => _geocode(forOrigin: true),
            onGeocodeDest: () => _geocode(forOrigin: false),
            onCalc: loading ? null : _calc,
            pickingOrigin: pickingOrigin,
            pickingDestination: pickingDestination,
          ),
        ),
        // FABs (agregamos botón de tema)
        Positioned(
          right: 12 + padding.right,
          bottom: navTotalBottom + (results.isEmpty ? 12 : sheetMinPx + 12),
          child: Column(
            children: [
              _RoundFab(icon: Icons.brightness_6_outlined, onPressed: _openThemePicker),
              const SizedBox(height: 10),
              _RoundFab(icon: Icons.layers, onPressed: _pickBaseMap),
              const SizedBox(height: 10),
              _RoundFab(icon: Icons.my_location, onPressed: _useMyLocationAsOrigin),
              const SizedBox(height: 10),
              _RoundFab(
                icon: Icons.center_focus_strong,
                onPressed: selected == null ? null : _recenter,
              ),
            ],
          ),
        ),
        if (results.isNotEmpty)
          _ResultsDraggableSheet(
            bottomSafeSpace: navTotalBottom,
            initialChildSize: selected != null ? 0.26 : 0.22,
            minChildSize: selected != null ? 0.22 : 0.18,
            maxChildSize: 0.70,
            results: results,
            selected: selected,
            onPick: (o) {
              setState(() => selected = o);
              final segs = parseGeoJsonLine(o.segGeom, color: colorFromHex(o.colorHex), width: 6);
              final walkTo = parseGeoJsonLine(o.walkTo, color: const Color(0xFF757575), width: 3);
              final walkFrom = parseGeoJsonLine(o.walkFrom, color: const Color(0xFF757575), width: 3);
              _fitToLines([...walkTo, ...segs, ...walkFrom]);
            },
            onCenter: _recenter,
          ),
        if (loading)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }
}

// ---------- Basemap picker ----------
class _BasemapPickerList extends StatelessWidget {
  final BaseMapStyle current;
  final ScrollController scrollController;
  const _BasemapPickerList({
    required this.current,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    Widget tile(BaseMapStyle s, String title, String? subtitle) {
      final selected = s == current;
      return ListTile(
        leading: Icon(
          s == BaseMapStyle.mapboxSatellite
              ? Icons.satellite_alt
              : Icons.map_outlined,
          color: selected ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing:
        selected ? const Icon(Icons.check_circle, color: Colors.green) : null,
        onTap: () => Navigator.pop(context, s),
      );
    }

    final bottom = MediaQuery.of(context).viewPadding.bottom + 12;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.only(left: 8, right: 8, bottom: bottom),
        children: [
          const SizedBox(height: 6),
          const Center(
              child: Text('Estilo de mapa',
                  style: TextStyle(fontWeight: FontWeight.w700))),
          const SizedBox(height: 6),
          tile(BaseMapStyle.mapboxStreets, 'Mapbox Streets', 'General / Dark adapt'),
          tile(BaseMapStyle.mapboxNavigation, 'Mapbox Navigation', 'Alto contraste'),
          tile(BaseMapStyle.mapboxLight, 'Mapbox Light/Dark', 'Minimalista'),
          tile(BaseMapStyle.mapboxSatellite, 'Mapbox Satellite', 'Satélite + labels'),
          tile(BaseMapStyle.cartoVoyager, 'Carto Voyager', 'Ligero'),
          tile(BaseMapStyle.osm, 'OpenStreetMap', 'Estándar'),
        ],
      ),
    );
  }
}

// ---------- Search Pill (sin "Mi ubicación" interno) ----------
class _SearchPill extends StatelessWidget {
  final TextEditingController originCtl;
  final TextEditingController destCtl;
  final FocusNode originFocus;
  final FocusNode destFocus;

  final List<PlaceSuggestion> originSugs;
  final List<PlaceSuggestion> destSugs;

  final ValueChanged<String> onOriginChanged;
  final ValueChanged<String> onDestChanged;

  final VoidCallback onPickOrigin;
  final VoidCallback onPickDestination;
  final void Function(PlaceSuggestion) onSelectOriginSuggestion;
  final void Function(PlaceSuggestion) onSelectDestSuggestion;

  final VoidCallback onGeocodeOrigin;
  final VoidCallback onGeocodeDest;
  final VoidCallback? onCalc;

  final bool pickingOrigin;
  final bool pickingDestination;

  const _SearchPill({
    required this.originCtl,
    required this.destCtl,
    required this.originFocus,
    required this.destFocus,
    required this.originSugs,
    required this.destSugs,
    required this.onOriginChanged,
    required this.onDestChanged,
    required this.onPickOrigin,
    required this.onPickDestination,
    required this.onSelectOriginSuggestion,
    required this.onSelectDestSuggestion,
    required this.onGeocodeOrigin,
    required this.onGeocodeDest,
    required this.onCalc,
    required this.pickingOrigin,
    required this.pickingDestination,
  });

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<AppGlass>() ?? AppGlass.light();
    final shapes =
        Theme.of(context).extension<AppShapes>() ?? AppShapes.defaults();
    final scheme = Theme.of(context).colorScheme;
    final blur = glass.blurSigma;

    final fieldTextStyle = TextStyle(
      color: scheme.onSurface.withValues(alpha: .90),
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );

    InputDecoration decoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: scheme.onSurface.withValues(alpha: .55),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      isDense: true,
      filled: true,
      fillColor: scheme.surfaceVariant.withValues(alpha: .28),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(shapes.radiusMd + 2),
        borderSide:
        BorderSide(color: scheme.outline.withValues(alpha: .25)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(shapes.radiusMd + 2),
        borderSide:
        BorderSide(color: scheme.outline.withValues(alpha: .18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(shapes.radiusMd + 2),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    );

    Widget buildSuggestions(
        List<PlaceSuggestion> sugs, void Function(PlaceSuggestion) onSelect) {
      if (sugs.isEmpty) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(shapes.radiusMd),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? .30
                    : .10,
              ),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        constraints: const BoxConstraints(maxHeight: 220),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: sugs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final s = sugs[i];
            return ListTile(
              dense: true,
              leading: Icon(Icons.location_on_outlined, color: scheme.primary),
              title: Text(
                s.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 13.5,
                ),
              ),
              onTap: () => onSelect(s),
            );
          },
        ),
      );
    }

    final content = Container(
      decoration: BoxDecoration(
        color: glass.surface.withValues(alpha: glass.opacity),
        border: Border.all(color: glass.border),
        borderRadius: BorderRadius.circular(shapes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha:
              Theme.of(context).brightness == Brightness.dark ? 0.32 : 0.12,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ORIGEN
          Row(
            children: [
              Icon(
                pickingOrigin
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  style: fieldTextStyle,
                  focusNode: originFocus,
                  controller: originCtl,
                  onChanged: onOriginChanged,
                  decoration: decoration('Selecciona origen'),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: onGeocodeOrigin,
                tooltip: 'Buscar origen',
                icon: const Icon(Icons.search),
                color: scheme.onSurfaceVariant,
              ),
              IconButton(
                onPressed: onPickOrigin,
                tooltip: 'Elegir origen en el mapa',
                icon: const Icon(Icons.map_outlined),
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
          buildSuggestions(originSugs, onSelectOriginSuggestion),
          const SizedBox(height: 12),
          // DESTINO
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 20,
                color: Color(0xFFFF3B30),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  style: fieldTextStyle,
                  focusNode: destFocus,
                  controller: destCtl,
                  onChanged: onDestChanged,
                  decoration: decoration('Selecciona destino'),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: onGeocodeDest,
                tooltip: 'Buscar destino',
                icon: const Icon(Icons.search),
                color: scheme.onSurfaceVariant,
              ),
              IconButton(
                onPressed: onPickDestination,
                tooltip: 'Elegir destino en el mapa',
                icon: const Icon(Icons.map_outlined),
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
          buildSuggestions(destSugs, onSelectDestSuggestion),
          const SizedBox(height: 16),
          Row(
            children: [
              const Spacer(),
              FilledButton(
                onPressed: onCalc,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                child: const Text('Calcular'),
              ),
            ],
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(shapes.radiusLg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: content,
      ),
    );
  }
}

// ---------- Fabs ----------
class _RoundFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  const _RoundFab({required this.icon, this.onPressed});
  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(
          alpha: enabled ? 0.95 : 0.55,
        ),
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, size: 20),
          ),
        ),
      ),
    );
  }
}

// ---------- Results Sheet ----------
class _ResultsDraggableSheet extends StatelessWidget {
  final double bottomSafeSpace;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final List<FastestOption> results;
  final FastestOption? selected;
  final ValueChanged<FastestOption> onPick;
  final VoidCallback onCenter;

  const _ResultsDraggableSheet({
    required this.bottomSafeSpace,
    required this.initialChildSize,
    required this.minChildSize,
    required this.maxChildSize,
    required this.results,
    required this.selected,
    required this.onPick,
    required this.onCenter,
  });

  String _fmtKm(double m) =>
      '${(m / 1000).toStringAsFixed(m >= 1000 ? 0 : 1)} km';

  @override
  Widget build(BuildContext context) {
    final hasSelected = selected != null;
    final filtered = hasSelected
        ? results
        .where((o) => o.lineDirectionId != selected!.lineDirectionId)
        .toList()
        : results;

    final extraBottom = bottomSafeSpace + 16;
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.40
                      : 0.15,
                ),
                blurRadius: 22,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: colorScheme.outline.withValues(alpha: .4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Opciones',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  padding: EdgeInsets.fromLTRB(12, 0, 12, extraBottom),
                  itemCount: filtered.length + (hasSelected ? 1 : 0),
                  physics: const ClampingScrollPhysics(),
                  itemBuilder: (_, i) {
                    if (hasSelected && i == 0) {
                      final s = selected!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Ink(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: Theme.of(context).brightness ==
                                      Brightness.dark
                                      ? 0.40
                                      : 0.10,
                                ),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: colorFromHex(s.colorHex),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text('${s.code} • ${s.lineName}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700)),
                                      Text('"${s.headsign}"',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: colorScheme.onSurface
                                                  .withValues(alpha: .65))),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: onCenter,
                                  icon: const Icon(Icons.center_focus_strong),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    final idx = i - (hasSelected ? 1 : 0);
                    final o = filtered[idx];
                    final active =
                        selected?.lineDirectionId == o.lineDirectionId;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => onPick(o),
                        child: Ink(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: Theme.of(context).brightness ==
                                      Brightness.dark
                                      ? 0.40
                                      : 0.10,
                                ),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: colorFromHex(o.colorHex),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text('${o.code} • ${o.lineName}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      Text('"${o.headsign}"',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: colorScheme.onSurface
                                                  .withValues(alpha: .65))),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          _Chip(
                                              text: _fmtKm(o.walkToM),
                                              icon: Icons.directions_walk),
                                          const SizedBox(width: 6),
                                          _Chip(
                                              text: _fmtKm(o.rideM),
                                              icon: Icons.directions_bus),
                                          const SizedBox(width: 6),
                                          _Chip(
                                              text: _fmtKm(o.walkFromM),
                                              icon: Icons.directions_walk),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? colorScheme.primary
                                        : colorScheme.surfaceVariant,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${o.etaMinutes.toStringAsFixed(0)} min',
                                    style: TextStyle(
                                      color: active
                                          ? Colors.white
                                          : colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.chevron_right, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Chip({required this.text, required this.icon});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceVariant.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: scheme.onSurface.withValues(alpha: .65)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurface.withValues(alpha: .80),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  final Color color;
  const _Pin({required this.color});
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha:
                  Theme.of(context).brightness == Brightness.dark ? 0.40 : 0.18,
                ),
                blurRadius: 6,
              )
            ],
          ),
        ),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}