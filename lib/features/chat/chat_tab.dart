import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mi_linea/data/services/backend_service.dart';

class ChatTab extends StatefulWidget {
  final void Function(double oLng, double oLat, Map<String, dynamic> payload)? onViewInMap;
  final double navOverlapHeight;

  const ChatTab({
    super.key,
    this.onViewInMap,
    this.navOverlapHeight = 0,
  });

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final BackendService api = BackendService();
  final List<_Msg> messages = [];
  final controller = TextEditingController();
  bool sending = false;

  bool _autoIncludeLocation = true;
  double? lastLng;
  double? lastLat;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _maybeUpdateLocation() async {
    if (!_autoIncludeLocation) return;
    try {
      final perm = await geo.Geolocator.checkPermission();
      if (perm == geo.LocationPermission.denied) {
        final p2 = await geo.Geolocator.requestPermission();
        if (p2 == geo.LocationPermission.denied || p2 == geo.LocationPermission.deniedForever) return;
      }
      final pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(accuracy: geo.LocationAccuracy.best),
      );
      lastLng = pos.longitude;
      lastLat = pos.latitude;
    } catch (_) {}
  }

  void _appendBot(String text) {
    setState(() => messages.add(_Msg(text, false)));
  }

  Future<void> _send() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending) return;

    setState(() {
      messages.add(_Msg(text, true));
      sending = true;
      controller.clear();
    });

    await _maybeUpdateLocation();

    try {
      final j = await api.chatAsk(
        message: text,
        oLng: lastLng,
        oLat: lastLat,
      );

      final reply = (j['reply'] ?? 'Listo.').toString();
      _appendBot(reply);

      final needs = j['needs'];
      if (needs is Map && needs['origin'] == true && lastLng == null) {
        _appendBot('Activa o comparte tu ubicación para calcular desde tu posición actual.');
      }
      if (needs is Map && needs['destination'] == true) {
        _appendBot('Indica el destino (ej: UMSS, “San Martín y Aroma”, “Paseo Aranjuez”).');
      }

      final best = j['fastest']?['best'];
      final origin = j['origin'];
      if (best != null && origin is Map && origin['lng'] != null && origin['lat'] != null) {
        final lng = (origin['lng'] as num).toDouble();
        final lat = (origin['lat'] as num).toDouble();
        messages.add(
          _Msg.withAction(
            'Ver mejor opción en el mapa',
                () {
              // Cerrar teclado si abierto
              FocusScope.of(context).unfocus();
              widget.onViewInMap?.call(lng, lat, Map<String, dynamic>.from(j));
            },
          ),
        );
        setState(() {});
      }
    } catch (e) {
      _appendBot('Error: $e');
    } finally {
      setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final double reserveForNav = viewInsets > 0 ? 0.0 : widget.navOverlapHeight;

    const inputBarHeight = 70.0;

    return SafeArea(
      top: true,
      bottom: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: reserveForNav),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const Text('Chat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    tooltip: _autoIncludeLocation
                        ? 'Enviando ubicación automáticamente'
                        : 'No se envía ubicación',
                    icon: Icon(
                      _autoIncludeLocation ? Icons.location_on : Icons.location_off,
                      color: _autoIncludeLocation ? Colors.blue : Colors.grey,
                    ),
                    onPressed: () => setState(() => _autoIncludeLocation = !_autoIncludeLocation),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, inputBarHeight + 12),
                itemCount: messages.length,
                itemBuilder: (_, i) => messages[i].build(context),
              ),
            ),
            Container(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(height: 1),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      8,
                      6,
                      8,
                      8 + (viewInsets > 0 ? MediaQuery.of(context).padding.bottom : 0),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                              hintText: '¿A dónde quieres ir?',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                              ),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: sending ? null : _send,
                          child: sending
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Msg {
  final String text;
  final bool me;
  final VoidCallback? action;
  _Msg(this.text, this.me) : action = null;
  _Msg.withAction(this.text, this.action) : me = false;

  Widget build(BuildContext context) {
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: me ? Theme.of(context).colorScheme.primary : const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: TextStyle(color: me ? Colors.white : Colors.black)),
    );
    final child = action == null
        ? bubble
        : TextButton(
      onPressed: action,
      style: TextButton.styleFrom(padding: EdgeInsets.zero),
      child: bubble,
    );
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: child,
      ),
    );
  }
}