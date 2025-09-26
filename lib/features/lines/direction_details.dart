import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:latlong2/latlong.dart' as ll;

import 'package:mi_linea/core/geojson.dart';
import 'package:mi_linea/data/services/backend_service.dart';
import 'package:mi_linea/core/env.dart';
import 'package:mi_linea/theme/theme_extensions.dart';

enum BaseMapStyle {
  mapboxStreets,
  mapboxNavigation,
  mapboxLight,
  mapboxSatellite,
  cartoVoyager,
  osm,
}

class DirectionDetails extends StatefulWidget {
  final int directionId;
  final String title;
  final String colorHex;

  const DirectionDetails({
    super.key,
    required this.directionId,
    required this.title,
    required this.colorHex,
  });

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

  ll.LatLng? _userLatLng;
  bool _locLoading = false;
  bool _locDenied = false;

  BaseMapStyle _style = BaseMapStyle.mapboxStreets;

  @override
  void initState() {
    super.initState();
    _load();
    _initLocation();
  }

  Future<void> _initLocation() async {
    setState(() {
      _locLoading = true;
      _locDenied = false;
    });
    try {
      var perm = await geo.Geolocator.checkPermission();
      if (perm == geo.LocationPermission.denied) {
        perm = await geo.Geolocator.requestPermission();
      }
      if (perm == geo.LocationPermission.denied ||
          perm == geo.LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locDenied = true;
            _locLoading = false;
          });
        }
        return;
      }
      final p = await geo.Geolocator.getCurrentPosition(
          locationSettings:
          const geo.LocationSettings(accuracy: geo.LocationAccuracy.best));
      if (!mounted) return;
      setState(() {
        _userLatLng = ll.LatLng(p.latitude, p.longitude);
        _locLoading = false;
      });
      _rebuildMarkers();
    } catch (_) {
      if (mounted) setState(() => _locLoading = false);
    }
  }

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
        setState(() {
          _error = 'No hay geometría para esta dirección.';
          _loading = false;
        });
        return;
      }

      final mainColor = colorFromHex(widget.colorHex);
      final lines = parseGeoJsonLine(geom, color: mainColor, width: 6);

      final polylinesTmp = <Polyline>[];
      final allPts = <ll.LatLng>[];
      for (final l in lines) {
        final pts = l.points.map((p) => ll.LatLng(p.lat, p.lng)).toList();
        allPts.addAll(pts);
        polylinesTmp.add(Polyline(
            points: pts, color: Colors.white, strokeWidth: l.width + 4));
        polylinesTmp.add(
            Polyline(points: pts, color: l.color, strokeWidth: l.width));
      }

      LatLngBounds? boundsTmp;
      if (allPts.isNotEmpty) {
        boundsTmp = LatLngBounds.fromPoints(allPts);
      }

      if (!mounted) return;
      setState(() {
        _polylines = polylinesTmp;
        _bounds = boundsTmp;
        _loading = false;
      });

      _rebuildMarkers();

      if (boundsTmp != null) {
        scheduleMicrotask(() {
          try {
            _mapCtl.fitCamera(
              CameraFit.bounds(
                bounds: boundsTmp!,
                padding: const EdgeInsets.fromLTRB(12, 120, 12, 80),
              ),
            );
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

  void _rebuildMarkers() {
    final markersTmp = <Marker>[];

    if (_polylines.isNotEmpty) {
      final colorLayer = _polylines
          .where((p) => p.strokeWidth > 4)
          .expand((p) => p.points)
          .toList();
      if (colorLayer.isNotEmpty) {
        markersTmp.add(
          Marker(
            point: colorLayer.first,
            width: 36,
            height: 36,
            child: const Icon(Icons.radio_button_checked,
                color: Color(0xFF007AFF), size: 26),
          ),
        );
        markersTmp.add(
          Marker(
            point: colorLayer.last,
            width: 36,
            height: 36,
            child:
            const Icon(Icons.place, color: Color(0xFFFF3B30), size: 26),
          ),
        );
      }
    }

    if (_userLatLng != null) {
      markersTmp.add(
        Marker(
          point: _userLatLng!,
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                          Theme.of(context).brightness == Brightness.dark
                              ? 0.40
                              : 0.20),
                      blurRadius: 6,
                    )
                  ],
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      );
    }

    setState(() => _markers = markersTmp);
  }

  TileLayer _buildTileLayer() {
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
          retinaMode: MediaQuery.of(context).devicePixelRatio > 1.5,
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

  Future<void> _pickStyle() async {
    final chosen = await showModalBottomSheet<BaseMapStyle>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return _StyleSheet(current: _style, hasToken: AppEnv.mapboxToken.isNotEmpty);
      },
    );
    if (chosen != null && mounted) setState(() => _style = chosen);
  }

  void _recenterRoute() {
    final b = _bounds;
    if (b == null) return;
    _mapCtl.fitCamera(
      CameraFit.bounds(
        bounds: b,
        padding: const EdgeInsets.fromLTRB(12, 120, 12, 80),
      ),
    );
  }

  void _centerOnUser() {
    if (_userLatLng == null) return;
    _mapCtl.move(_userLatLng!, 16);
  }

  @override
  Widget build(BuildContext context) {
    final mapWidget = FlutterMap(
      mapController: _mapCtl,
      options: const MapOptions(
        initialCenter: ll.LatLng(-17.39, -66.157),
        initialZoom: 13,
      ),
      children: [
        _buildTileLayer(),
        PolylineLayer(polylines: _polylines),
        MarkerLayer(markers: _markers),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Cambiar estilo',
            onPressed: _pickStyle,
            icon: const Icon(Icons.layers_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: mapWidget),
          Positioned(
            right: 12,
            bottom: 20 + MediaQuery.of(context).padding.bottom,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'style_${widget.directionId}',
                  onPressed: _pickStyle,
                  child: const Icon(Icons.layers),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'user_${widget.directionId}',
                  onPressed: _userLatLng == null
                      ? (_locLoading ? null : _initLocation)
                      : _centerOnUser,
                  child: _locLoading
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Icon(
                    _userLatLng == null
                        ? (_locDenied
                        ? Icons.location_disabled
                        : Icons.my_location)
                        : Icons.my_location,
                  ),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'recenter_${widget.directionId}',
                  onPressed: _recenterRoute,
                  child: const Icon(Icons.center_focus_strong),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'refresh_${widget.directionId}',
                  onPressed: _load,
                  child: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          if (_loading)
            const Positioned.fill(
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Positioned.fill(
              child: Container(
                color: const Color(0x33000000),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Error',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => setState(() => _error = null),
                            child: const Text('OK'),
                          ),
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

class _StyleSheet extends StatelessWidget {
  final BaseMapStyle current;
  final bool hasToken;
  const _StyleSheet({required this.current, required this.hasToken});

  @override
  Widget build(BuildContext context) {
    Widget tile(BaseMapStyle style, String title, String? subtitle) {
      final selected = style == current;
      return ListTile(
        leading: Icon(
          style == BaseMapStyle.mapboxSatellite
              ? Icons.satellite_alt
              : Icons.map_outlined,
          color: selected ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: selected
            ? const Icon(Icons.check_circle, color: Colors.green)
            : null,
        onTap: () => Navigator.pop(context, style),
      );
    }

    final list = <Widget>[
      if (hasToken) ...[
        tile(BaseMapStyle.mapboxStreets, 'Mapbox Streets', 'General'),
        tile(BaseMapStyle.mapboxNavigation, 'Mapbox Navigation', 'Contraste'),
        tile(BaseMapStyle.mapboxLight, 'Mapbox Light/Dark', 'Claro / Oscuro'),
        tile(BaseMapStyle.mapboxSatellite, 'Mapbox Satellite', 'Satélite'),
      ],
      tile(BaseMapStyle.cartoVoyager, 'Carto Voyager', 'Ligero'),
      tile(BaseMapStyle.osm, 'OpenStreetMap', 'Básico'),
    ];

    final bottom = MediaQuery.of(context).padding.bottom + 12;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListView(
        padding: EdgeInsets.fromLTRB(8, 6, 8, bottom),
        children: [
          const Center(
              child: Text('Estilos de mapa',
                  style: TextStyle(fontWeight: FontWeight.w700))),
          const SizedBox(height: 6),
          ...list,
        ],
      ),
    );
  }
}