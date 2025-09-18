import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:latlong2/latlong.dart' as ll;

import 'package:mi_linea/core/geocoding.dart';
import 'package:mi_linea/core/geojson.dart';
import 'package:mi_linea/data/models/fastest_option.dart';
import 'package:mi_linea/data/services/backend_service.dart';

class MapTabFlutterMap extends StatefulWidget {
  const MapTabFlutterMap({super.key});
  @override
  State<MapTabFlutterMap> createState() => _MapTabFlutterMapState();
}

class _MapTabFlutterMapState extends State<MapTabFlutterMap> {
  final mapCtl = MapController();
  final api = BackendService();

  final originCtl = TextEditingController();
  final destCtl = TextEditingController();

  LngLat? origin;
  LngLat? destination;

  bool pickingOrigin = false;
  bool pickingDestination = false;

  List<FastestOption> results = [];
  FastestOption? selected;
  bool loading = false;

  final ll.LatLng cochabamba = const ll.LatLng(-17.39, -66.157);

  @override
  void dispose() {
    originCtl.dispose();
    destCtl.dispose();
    super.dispose();
  }

  void _fitToLines(List<GeoLine> lines) {
    final pts = lines.expand((l) => l.points).toList();
    if (pts.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(pts.map((p) => ll.LatLng(p.lat, p.lng)).toList());
    scheduleMicrotask(() {
      try {
        mapCtl.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.fromLTRB(24, 140, 24, 220)));
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
      final p = await geo.Geolocator.getCurrentPosition(locationSettings: const geo.LocationSettings(accuracy: geo.LocationAccuracy.best));
      setState(() {
        origin = LngLat(p.longitude, p.latitude);
        originCtl.text = 'Mi ubicación (${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)})';
      });
      mapCtl.move(ll.LatLng(p.latitude, p.longitude), 15);
    } catch (e) {
      _alert('Ubicación', '$e');
    }
  }

  Future<void> _geocode({required bool forOrigin}) async {
    final query = forOrigin ? originCtl.text.trim() : destCtl.text.trim();
    if (query.isEmpty) return;
    final res = await GeocodingService.searchFirst(query);
    if (res.error != null) return _alert('Geocoding', res.error!);
    final c = res.coord!;
    setState(() {
      if (forOrigin) {
        origin = c;
      } else {
        destination = c;
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
        _alert('Sin resultados', 'No se encontraron líneas cercanas. Ajusta origen/destino o verifica tus shapes.');
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
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
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
      lines.add(stroke(l, l.color.withValues(alpha: 0.85), l.width));
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

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    final topInset = padding.top;
    final bottomInset = padding.bottom;

    // Altura del menú flotante (AppShell)
    const navHeight = 72.0;
    const navBottomMargin = 12.0;
    final navTotalBottom = navHeight + navBottomMargin + bottomInset;

    final markers = <Marker>[
      if (origin != null)
        Marker(point: ll.LatLng(origin!.lat, origin!.lng), width: 40, height: 40, child: const _Pin(color: Color(0xFF007AFF))),
      if (destination != null)
        Marker(point: ll.LatLng(destination!.lat, destination!.lng), width: 40, height: 40, child: const _Pin(color: Color(0xFFFF3B30))),
    ];

    return Stack(
      children: [
        // UN SOLO FlutterMap con todas las capas
        Positioned.fill(
          child: FlutterMap(
            mapController: mapCtl,
            options: MapOptions(
              initialCenter: cochabamba,
              initialZoom: 12,
              onTap: (tapPos, latlng) {
                setState(() {
                  if (pickingOrigin) {
                    origin = LngLat(latlng.longitude, latlng.latitude);
                    originCtl.text = '(${latlng.latitude.toStringAsFixed(5)}, ${latlng.longitude.toStringAsFixed(5)})';
                    pickingOrigin = false;
                  } else if (pickingDestination) {
                    destination = LngLat(latlng.longitude, latlng.latitude);
                    destCtl.text = '(${latlng.latitude.toStringAsFixed(5)}, ${latlng.longitude.toStringAsFixed(5)})';
                    pickingDestination = false;
                  }
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.mi_linea',
              ),
              PolylineLayer(polylines: _polylines()),
              MarkerLayer(markers: markers),
            ],
          ),
        ),

        // Pill superior respetando el status bar
        Positioned(
          top: topInset + 8,
          left: 12,
          right: 12,
          child: _SearchPill(
            originCtl: originCtl,
            destCtl: destCtl,
            pickingOrigin: pickingOrigin,
            pickingDestination: pickingDestination,
            onPickOrigin: () => setState(() => pickingOrigin = !pickingOrigin),
            onPickDestination: () => setState(() => pickingDestination = !pickingDestination),
            onSwap: () => setState(() {
              final tmp = origin;
              origin = destination;
              destination = tmp;
              final t2 = originCtl.text;
              originCtl.text = destCtl.text;
              destCtl.text = t2;
            }),
            onGeocodeOrigin: () => _geocode(forOrigin: true),
            onGeocodeDest: () => _geocode(forOrigin: false),
            onMyLocation: _useMyLocationAsOrigin,
            onCalc: loading ? null : _calc,
          ),
        ),

        // Botones flotantes con margen dinámico para no chocar con el nav
        Positioned(
          right: 12 + padding.right,
          bottom: navTotalBottom + (results.isEmpty ? 12 : 220),
          child: Column(
            children: [
              _RoundFab(icon: Icons.my_location, onPressed: _useMyLocationAsOrigin),
              const SizedBox(height: 10),
              _RoundFab(icon: Icons.center_focus_strong, onPressed: selected == null ? null : _recenter),
            ],
          ),
        ),

        if (results.isNotEmpty)
          _ResultsDraggableSheet(
            bottomSafeSpace: navTotalBottom,
            results: results,
            selected: selected,
            onPick: (o) {
              setState(() => selected = o);
              final segs = parseGeoJsonLine(o.segGeom, color: colorFromHex(o.colorHex), width: 6);
              final walkTo = parseGeoJsonLine(o.walkTo, color: const Color(0xFF757575), width: 3);
              final walkFrom = parseGeoJsonLine(o.walkFrom, color: const Color(0xFF757575), width: 3);
              _fitToLines([...walkTo, ...segs, ...walkFrom]);
            },
          ),
      ],
    );
  }
}

class _SearchPill extends StatelessWidget {
  final TextEditingController originCtl;
  final TextEditingController destCtl;
  final bool pickingOrigin;
  final bool pickingDestination;
  final VoidCallback onPickOrigin;
  final VoidCallback onPickDestination;
  final VoidCallback onSwap;
  final VoidCallback onGeocodeOrigin;
  final VoidCallback onGeocodeDest;
  final VoidCallback onMyLocation;
  final VoidCallback? onCalc;

  const _SearchPill({
    required this.originCtl,
    required this.destCtl,
    required this.pickingOrigin,
    required this.pickingDestination,
    required this.onPickOrigin,
    required this.onPickDestination,
    required this.onSwap,
    required this.onGeocodeOrigin,
    required this.onGeocodeDest,
    required this.onMyLocation,
    required this.onCalc,
  });

  @override
  Widget build(BuildContext context) {
    final blur = 12.0;
    final content = Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const Icon(Icons.radio_button_checked, size: 18, color: Color(0xFF007AFF)),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: originCtl,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Selecciona origen',
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(onPressed: onGeocodeOrigin, icon: const Icon(Icons.search)),
            IconButton(onPressed: onPickOrigin, icon: const Icon(Icons.map_outlined)),
          ]),
          const SizedBox(height: 8),
          Stack(
            alignment: Alignment.centerRight,
            children: [
              Row(children: [
                const Icon(Icons.place, size: 20, color: Color(0xFFFF3B30)),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: destCtl,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Selecciona destino',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(onPressed: onGeocodeDest, icon: const Icon(Icons.search)),
                IconButton(onPressed: onPickDestination, icon: const Icon(Icons.add_location_alt_outlined)),
              ]),
              IconButton(onPressed: onSwap, icon: const Icon(Icons.swap_vert_circle, size: 26)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(onPressed: onMyLocation, child: const Text('Mi ubicación')),
              const Spacer(),
              FilledButton(onPressed: onCalc, child: const Text('Calcular')),
            ],
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: content),
    );
  }
}

class _RoundFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  const _RoundFab({required this.icon, this.onPressed});
  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: Colors.white.withValues(alpha: enabled ? 0.9 : 0.55),
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(width: 48, height: 48, child: Icon(icon, size: 20, color: const Color(0xFF333333))),
          ),
        ),
      ),
    );
  }
}

class _ResultsDraggableSheet extends StatelessWidget {
  final double bottomSafeSpace;
  final List<FastestOption> results;
  final FastestOption? selected;
  final ValueChanged<FastestOption> onPick;

  const _ResultsDraggableSheet({
    required this.bottomSafeSpace,
    required this.results,
    required this.selected,
    required this.onPick,
  });

  String _fmtKm(double m) => '${(m / 1000).toStringAsFixed(m >= 1000 ? 0 : 1)} km';

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.22,
      minChildSize: 0.18,
      maxChildSize: 0.65,
      builder: (context, controller) {
        return Container(
          padding: EdgeInsets.only(bottom: bottomSafeSpace),
          decoration: const BoxDecoration(
            color: Color(0xFFFDFDFD),
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, -4))],
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 8),
              const Text('Opciones', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: results.length,
                  itemBuilder: (_, i) {
                    final o = results[i];
                    final active = selected?.lineDirectionId == o.lineDirectionId;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => onPick(o),
                        child: Ink(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4))],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(width: 22, height: 22, decoration: BoxDecoration(color: colorFromHex(o.colorHex), borderRadius: BorderRadius.circular(6))),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${o.code} • ${o.lineName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      Text('"${o.headsign}"', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          _Chip(text: _fmtKm(o.walkToM), icon: Icons.directions_walk),
                                          const SizedBox(width: 6),
                                          _Chip(text: _fmtKm(o.rideM), icon: Icons.directions_bus),
                                          const SizedBox(width: 6),
                                          _Chip(text: _fmtKm(o.walkFromM), icon: Icons.directions_walk),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: active ? Theme.of(context).colorScheme.primary : const Color(0xFFE5E5EA),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('${o.etaMinutes.toStringAsFixed(0)} min', style: TextStyle(color: active ? Colors.white : const Color(0xFF000000))),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFF1F1F3), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [Icon(icon, size: 14, color: const Color(0xFF666666)), const SizedBox(width: 4), Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF444444)))]),
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
        Container(width: 28, height: 28, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 6)])),
        Container(width: 18, height: 18, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      ],
    );
  }
}