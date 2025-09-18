import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mi_linea/data/services/backend_service.dart';

class ChatTab extends StatefulWidget {
  final void Function(double oLng, double oLat, Map<String, dynamic> payload)? onViewInMap;
  const ChatTab({super.key, this.onViewInMap});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final BackendService api = BackendService();
  final List<_Msg> messages = [];
  final controller = TextEditingController();
  bool sending = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending) return;
    setState(() {
      messages.add(_Msg(text, true));
      sending = true;
      controller.clear();
    });

    double? lng;
    double? lat;

    try {
      final perm = await geo.Geolocator.checkPermission();
      if (perm == geo.LocationPermission.always || perm == geo.LocationPermission.whileInUse) {
        final pos = await geo.Geolocator.getCurrentPosition(locationSettings: const geo.LocationSettings(accuracy: geo.LocationAccuracy.best));
        lng = pos.longitude;
        lat = pos.latitude;
      }
    } catch (_) {}

    try {
      final j = await api.chatAsk(message: text, oLng: lng, oLat: lat);
      final reply = j['reply'] ?? 'Listo.';
      setState(() => messages.add(_Msg(reply, false)));

      final best = j['fastest']?['best'];
      if (best != null && lng != null && lat != null) {
        setState(() => messages.add(_Msg.withAction('Ver en mapa la mejor opción', () => widget.onViewInMap?.call(lng!, lat!, Map<String, dynamic>.from(j)))));
      }
    } catch (e) {
      setState(() => messages.add(_Msg('Error: $e', false)));
    } finally {
      setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      bottom: false,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: const [
                Text('Chat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: messages.length,
              itemBuilder: (_, i) => messages[i].build(context),
            ),
          ),
          const Divider(height: 1),
          // Input protegido con SafeArea
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: '¿A dónde quieres ir?',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
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
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
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

    final child = action == null ? bubble : TextButton(onPressed: action, child: bubble);

    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: child),
    );
  }
}