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
  final ScrollController _scroll = ScrollController();
  bool sending = false;

  bool _autoIncludeLocation = true; // funcionalidad silenciosa
  double? lastLng;
  double? lastLat;

  @override
  void dispose() {
    controller.dispose();
    _scroll.dispose();
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
    _scrollToEndDelayed();
  }

  void _scrollToEndDelayed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending) return;

    setState(() {
      messages.add(_Msg(text, true));
      sending = true;
      controller.clear();
    });
    _scrollToEndDelayed();

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
        _appendBot('Activa tu ubicación (permisos del sistema) para calcular desde donde estás.');
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
              FocusScope.of(context).unfocus();
              widget.onViewInMap?.call(lng, lat, Map<String, dynamic>.from(j));
            },
          ),
        );
        _scrollToEndDelayed();
      }
    } catch (e) {
      _appendBot('Error: $e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final topPad = MediaQuery.of(context).padding.top + 8;
    final double reserveForNav = viewInsets > 0 ? 0.0 : widget.navOverlapHeight;

    const inputBarHeight = 78.0;

    return Padding(
      padding: EdgeInsets.only(top: topPad, bottom: reserveForNav),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(12, 0, 12, inputBarHeight + 12),
              itemCount: messages.length,
              itemBuilder: (_, i) => messages[i].build(context),
            ),
          ),
          _ChatInputBar(
            controller: controller,
            sending: sending,
            onSend: _send,
            viewInsets: viewInsets,
          ),
        ],
      ),
    );
  }
}

// ---------------- Input Bar estilizada (sin doble fondo) ----------------
class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final double viewInsets;

  const _ChatInputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.viewInsets,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pillColor = isDark
        ? scheme.surfaceVariant.withValues(alpha: .35)
        : scheme.surfaceVariant.withValues(alpha: .55);

    final iconColor = isDark
        ? scheme.onSurface.withValues(alpha: .90)
        : scheme.onSurface.withValues(alpha: .80);

    final sendBg = scheme.primaryContainer;
    final sendFg = scheme.onPrimaryContainer;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          6,
          12,
          8 + (viewInsets > 0 ? MediaQuery.of(context).padding.bottom : 0),
        ),
        child: Row(
          children: [
            // Pill con TextField transparente (sin borde interno)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                height: 50,
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(28),
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                clipBehavior: Clip.antiAlias,
                child: Theme(
                  // Override del InputDecorationTheme global para este TextField
                  data: Theme.of(context).copyWith(
                    inputDecorationTheme: const InputDecorationTheme(
                      filled: false,
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: '¿A dónde quieres ir?',
                      hintStyle: TextStyle(
                        color: scheme.onSurface.withValues(alpha: .45),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        letterSpacing: .2,
                      ),
                    ),
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    cursorColor: scheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _CircularSendButton(
              sending: sending,
              onPressed: sending ? null : onSend,
              bg: sendBg,
              fg: sendFg,
              iconColor: iconColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _CircularSendButton extends StatelessWidget {
  final bool sending;
  final VoidCallback? onPressed;
  final Color bg;
  final Color fg;
  final Color iconColor;

  const _CircularSendButton({
    required this.sending,
    required this.onPressed,
    required this.bg,
    required this.fg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !sending;
    return AnimatedScale(
      scale: sending ? 0.92 : 1,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: Material(
        shape: const CircleBorder(),
        color: bg,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Center(
              child: sending
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation(fg),
                ),
              )
                  : Icon(
                Icons.send_rounded,
                color: enabled ? iconColor : iconColor.withValues(alpha: .35),
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- Mensajes ----------------
class _Msg {
  final String text;
  final bool me;
  final VoidCallback? action;
  _Msg(this.text, this.me) : action = null;
  _Msg.withAction(this.text, this.action) : me = false;

  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMe = me;

    final bg = isMe ? scheme.primaryContainer : scheme.surfaceContainerHighest;
    final fg = isMe ? scheme.onPrimaryContainer : scheme.onSurface.withValues(alpha: .92);

    final bubble = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isMe ? 16 : 4),
          topRight: const Radius.circular(16),
          bottomLeft: const Radius.circular(16),
          bottomRight: Radius.circular(isMe ? 4 : 16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark ? 0.30 : 0.10,
            ),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );

    final child = action == null
        ? bubble
        : TextButton(
      onPressed: action,
      style: TextButton.styleFrom(padding: EdgeInsets.zero),
      child: bubble,
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: child,
      ),
    );
  }
}