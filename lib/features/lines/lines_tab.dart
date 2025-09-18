import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mi_linea/core/geojson.dart';
import 'package:mi_linea/data/models/line_item.dart';
import 'package:mi_linea/data/services/backend_service.dart';
import 'direction_details.dart';

class LinesTab extends StatefulWidget {
  const LinesTab({super.key});
  @override
  State<LinesTab> createState() => _LinesTabState();
}

class _LinesTabState extends State<LinesTab> {
  final BackendService api = BackendService();
  List<LineItem> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final data = await api.getLines();
      if (mounted) setState(() => items = data);
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(title: const Text('Error cargando líneas'), content: Text('$e'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    final bottomInset = padding.bottom;

    // espacio para el menú flotante
    const navHeight = 72.0;
    const navBottomMargin = 12.0;
    final listBottomPadding = bottomInset + navHeight + navBottomMargin + 24;

    return SafeArea(
      top: true,
      bottom: false,
      child: Column(
        children: [
          // Buscador “glass”
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _HeaderSearch(onRefresh: _load),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('No hay líneas para mostrar'), const SizedBox(height: 8), OutlinedButton(onPressed: _load, child: const Text('Reintentar'))]),
            )
                : ListView.separated(
              padding: EdgeInsets.fromLTRB(16, 8, 16, listBottomPadding),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final it = items[i];
                return _LineCard(
                  code: it.code,
                  name: it.lineName,
                  headsign: it.headsign,
                  direction: it.direction,
                  colorHex: it.colorHex,
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => DirectionDetails(directionId: it.lineDirectionId, title: '${it.code} • ${it.lineName} (${it.headsign})', colorHex: it.colorHex),
                    ));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderSearch extends StatelessWidget {
  final VoidCallback onRefresh;
  const _HeaderSearch({required this.onRefresh});
  @override
  Widget build(BuildContext context) {
    final bg = Colors.white.withOpacity(0.92);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 4))]),
          child: Row(children: [
            const Icon(Icons.search, size: 18),
            const SizedBox(width: 8),
            const Expanded(child: Text('Buscar línea, zona o destino', style: TextStyle(color: Color(0xFF6F6F6F)))),
            IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh, size: 18)),
          ]),
        ),
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  final String code;
  final String name;
  final String headsign;
  final String direction;
  final String colorHex;
  final VoidCallback onTap;

  const _LineCard({required this.code, required this.name, required this.headsign, required this.direction, required this.colorHex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final col = colorFromHex(colorHex);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 6))]),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(12))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$code • $name', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('"$headsign"', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF6F6F6F))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFF1F1F3), borderRadius: BorderRadius.circular(10)),
                    child: Text(direction, style: const TextStyle(fontSize: 12, color: Color(0xFF444444))),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}