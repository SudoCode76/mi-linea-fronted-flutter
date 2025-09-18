import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import 'package:mi_linea/core/geojson.dart';
import 'package:mi_linea/data/services/backend_service.dart';

class DirectionDetails extends StatefulWidget {
  final int directionId;
  final String title;
  final String colorHex;

  const DirectionDetails({super.key, required this.directionId, required this.title, required this.colorHex});

  @override
  State<DirectionDetails> createState() => _DirectionDetailsState();
}

class _DirectionDetailsState extends State<DirectionDetails> {
  final BackendService api = BackendService();

  final MapController _mapCtl = MapController();
  bool _loading = true;
  String? _error;

  List<Polyline> _polylines = [];
  List<Marker> _markers = [];
  LatLngBounds? _bounds;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _polylines = [];
      _markers = [];
      _bounds = null;
    });

    try {
      final r = await api.directionRoute(widget.directionId);
      final geom = r.geometry;
      if (geom == null) {
        setState(() => _error = 'No hay geometría para esta dirección.');
        return;
      }

      final mainColor = colorFromHex(widget.colorHex);
      final lines = parseGeoJsonLine(geom, color: mainColor, width: 6);

      final polylines = <Polyline>[];
      final allPts = <ll.LatLng>[];
      for (final l in lines) {
        final pts = l.points.map((p) => ll.LatLng(p.lat, p.lng)).toList();
        allPts.addAll(pts);
        polylines.add(Polyline(points: pts, color: Colors.white, strokeWidth: l.width + 4));
        polylines.add(Polyline(points: pts, color: l.color, strokeWidth: l.width));
      }

      final markers = <Marker>[];
      if (allPts.isNotEmpty) {
        markers.add(Marker(point: allPts.first, width: 36, height: 36, child: const Icon(Icons.radio_button_checked, color: Color(0xFF007AFF), size: 26)));
        markers.add(Marker(point: allPts.last, width: 36, height: 36, child: const Icon(Icons.place, color: Color(0xFFFF3B30), size: 26)));
      }

      LatLngBounds? bounds;
      if (allPts.isNotEmpty) {
        bounds = LatLngBounds.fromPoints(allPts);
      }

      if (!mounted) return;
      setState(() {
        _polylines = polylines;
        _markers = markers;
        _bounds = bounds;
        _loading = false;
      });

      if (bounds != null) {
        scheduleMicrotask(() {
          try {
            _mapCtl.fitCamera(CameraFit.bounds(bounds: bounds!, padding: const EdgeInsets.fromLTRB(28, 120, 28, 28)));
          } catch (_) {}
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _recenter() {
    final b = _bounds;
    if (b == null) return;
    _mapCtl.fitCamera(CameraFit.bounds(bounds: b, padding: const EdgeInsets.fromLTRB(28, 120, 28, 28)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapCtl,
              options: MapOptions(initialCenter: const ll.LatLng(-17.39, -66.157), initialZoom: 12),
              children: [
                TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: const ['a', 'b', 'c'], userAgentPackageName: 'com.example.mi_linea'),
                PolylineLayer(polylines: _polylines),
                MarkerLayer(markers: _markers),
              ],
            ),
          ),
          Positioned(
            right: 12,
            bottom: 20,
            child: Column(
              children: [
                FloatingActionButton.small(onPressed: _recenter, child: const Icon(Icons.center_focus_strong)),
                const SizedBox(height: 10),
                FloatingActionButton.small(onPressed: _load, child: const Icon(Icons.refresh)),
              ],
            ),
          ),
          if (_error != null)
            Positioned.fill(
              child: Container(
                color: const Color(0x33000000),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Error', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: () => setState(() => _error = null), child: const Text('OK')),
                      ]),
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