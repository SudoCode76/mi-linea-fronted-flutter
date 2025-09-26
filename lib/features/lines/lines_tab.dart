import 'dart:async';
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

  final TextEditingController _searchCtl = TextEditingController();
  Timer? _debounce;

  List<LineItem> _all = [];
  List<LineItem> items = [];
  bool loading = true;
  bool searching = false;
  String currentQuery = '';

  @override
  void initState() {
    super.initState();
    _initialLoad();
    _searchCtl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtl.removeListener(_onSearchChanged);
    _searchCtl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final q = _searchCtl.text.trim();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(q);
    });
  }

  Future<void> _initialLoad() async {
    setState(() {
      loading = true;
      currentQuery = '';
    });
    try {
      final data = await api.getLines(); // sin filtro
      if (!mounted) return;
      _all = data;
      items = List.from(_all);
    } catch (e) {
      if (!mounted) return;
      _showError('Error cargando líneas', '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _performSearch(String q) async {
    currentQuery = q;
    if (q.isEmpty) {
      // Restaurar todo
      setState(() {
        items = List.from(_all);
        searching = false;
      });
      return;
    }

    setState(() {
      searching = true;
    });

    try {
      // --- BÚSQUEDA REMOTA ---
      final data = await api.getLines(query: q);
      if (!mounted) return;
      items = data;
      searching = false;

      // --- BÚSQUEDA LOCAL (alternativa) ---
      // final norm = _norm(q);
      // items = _all.where((l) {
      //   final txt = _norm('${l.code} ${l.lineName} ${l.headsign}');
      //   return txt.contains(norm);
      // }).toList();
      // searching = false;

      setState(() {});
    } catch (e) {
      if (!mounted) return;
      searching = false;
      _showError('Error buscando', '$e');
      setState(() {});
    }
  }

  String _norm(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[áàä]'), 'a')
        .replaceAll(RegExp(r'[éèë]'), 'e')
        .replaceAll(RegExp(r'[íìï]'), 'i')
        .replaceAll(RegExp(r'[óòö]'), 'o')
        .replaceAll(RegExp(r'[úùü]'), 'u')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _showError(String title, String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  void _clearSearch() {
    _searchCtl.clear(); // disparará listener -> restaurar lista
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    final bottomInset = padding.bottom;

    const navHeight = 72.0;
    const navBottomMargin = 12.0;
    final listBottomPadding = bottomInset + navHeight + navBottomMargin + 24;

    final showEmpty = !loading && items.isEmpty && currentQuery.isNotEmpty && !searching;

    return SafeArea(
      top: true,
      bottom: false,
      child: Column(
        children: [
          // Buscador “glass”
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _SearchHeader(
              controller: _searchCtl,
              onRefresh: _initialLoad,
              onClear: _clearSearch,
              searching: searching,
              hasText: _searchCtl.text.trim().isNotEmpty,
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : showEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Sin resultados para “$currentQuery”'),
                  const SizedBox(height: 10),
                  OutlinedButton(onPressed: _clearSearch, child: const Text('Limpiar búsqueda')),
                ],
              ),
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
                      builder: (_) => DirectionDetails(
                        directionId: it.lineDirectionId,
                        title: '${it.code} • ${it.lineName} (${it.headsign})',
                        colorHex: it.colorHex,
                      ),
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

// --- Header con TextField ---
class _SearchHeader extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onRefresh;
  final VoidCallback onClear;
  final bool searching;
  final bool hasText;

  const _SearchHeader({
    required this.controller,
    required this.onRefresh,
    required this.onClear,
    required this.searching,
    required this.hasText,
  });

  @override
  Widget build(BuildContext context) {
    final bg = Colors.white.withOpacity(0.92);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 4))
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.search, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: 'Buscar línea, zona o destino',
                  ),
                  textInputAction: TextInputAction.search,
                ),
              ),
              if (searching)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (hasText)
                IconButton(
                  tooltip: 'Limpiar',
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 18),
                )
              else
                IconButton(
                  tooltip: 'Refrescar',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh, size: 18),
                ),
            ],
          ),
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

  const _LineCard({
    required this.code,
    required this.name,
    required this.headsign,
    required this.direction,
    required this.colorHex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final col = colorFromHex(colorHex);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 6))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(12))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$code • $name', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('"$headsign"', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF6F6F6F))),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFF1F1F3), borderRadius: BorderRadius.circular(10)),
                      child: Text(direction, style: const TextStyle(fontSize: 12, color: Color(0xFF444444))),
                    ),
                  ],
                ),
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