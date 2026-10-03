import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';

class AnbarPage extends StatefulWidget {
  const AnbarPage({super.key});

  @override
  State<AnbarPage> createState() => _AnbarPageState();
}

class _KhadaStat {
  final String productionType;
  final String size;
  final String thickness;
  final String unit;
  final int producedKhada;
  final double producedWeight;
  final int remainingKhada;
  final double remainingWeight;
  final int producedToday;
  final int producedWeek;
  final int producedMonth;
  final int soldToday;
  final int soldWeek;
  final int soldMonth;
  final double soldWeightToday;
  final double soldWeightWeek;
  final double soldWeightMonth;

  _KhadaStat({
    required this.productionType,
    required this.size,
    required this.thickness,
    required this.unit,
    required this.producedKhada,
    required this.producedWeight,
    required this.remainingKhada,
    required this.remainingWeight,
    required this.producedToday,
    required this.producedWeek,
    required this.producedMonth,
    required this.soldToday,
    required this.soldWeek,
    required this.soldMonth,
    required this.soldWeightToday,
    required this.soldWeightWeek,
    required this.soldWeightMonth,
  });
}

class _AnbarPageState extends State<AnbarPage> {
  final DatabaseHelper _db = DatabaseHelper();
  List<_KhadaStat> _stats = [];
  bool _isLoading = true;

  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _sizeController = TextEditingController();
  final TextEditingController _thicknessController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void dispose() {
    _typeController.dispose();
    _sizeController.dispose();
    _thicknessController.dispose();
    super.dispose();
  }

  DateTime? _parseAnyDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String s = raw.trim();
    for (int i = 0; i < 10; i++) {
      s = s.replaceAll(persian[i], '$i').replaceAll(arabic[i], '$i');
    }
    s = s.replaceAll('\\', '-').replaceAll('/', '-');
    try {
      return DateTime.parse(s);
    } catch (_) {}
    try {
      return DateTime.parse(s.split(' ').first);
    } catch (_) {}
    final parts = s.split('-');
    if (parts.length == 3) {
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      final c = int.tryParse(parts[2]);
      if (a != null && b != null && c != null) {
        if (a > 1900 && a < 2200) return DateTime(a, b, c);
        if (c > 1900 && c < 2200) return DateTime(c, b, a);
      }
    }
    return null;
  }

  bool _isWeightUnit(String u) {
    return u == 'کیلوگرم' ||
        u == 'kg' ||
        u == 'Kg' ||
        u == 'تن' ||
        u == 'ton' ||
        u == 'Ton' ||
        u == 'کیلوگرام' ||
        u == 'کیلو';
  }

  String _fmtWeight(double kg, String unit) {
    if (_isWeightUnit(unit)) {
      final tons = kg / 1000;
      if (tons < 0.01 && tons > 0) return '${tons.toStringAsFixed(3)} تن';
      return '${tons.toStringAsFixed(tons % 1 == 0 ? 0 : 2)} تن';
    }
    return '${kg.toStringAsFixed(kg % 1 == 0 ? 0 : 1)} $unit';
  }

  // 🚫 Values we should never treat as a real production name
  bool _isGarbageName(String s) {
    final t = s.trim();
    return t.isEmpty || t == 'بلی' || t == 'خیر' || t == 'true' || t == 'false';
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _computeKhadaStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading anbar stats: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<List<_KhadaStat>> _computeKhadaStats() async {
    final db = await _db.database;

    final logs = await db.query('production_logs');
    final products = await db.query('produced_products');
    final sales = await db.query(
      'sales_invoices',
      where: "(sale_type = ? OR sale_type IS NULL)",
      whereArgs: ['فروش'],
    );

    // 🔑 Build a lookup: produced_product_id → best production name
    final Map<int, String> productNameById = {};
    for (final p in products) {
      final id = p['id'] as int?;
      if (id == null) continue;

      // Try multiple sources in order of quality
      final candidates = [
        p['production_type']?.toString() ?? '',
        p['product_name']?.toString() ?? '',
      ];

      String best = '';
      for (final c in candidates) {
        final trimmed = c.trim();
        if (!_isGarbageName(trimmed)) {
          best = trimmed;
          break;
        }
      }
      productNameById[id] = best;
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(const Duration(days: 6));
    final monthStart = DateTime(now.year, now.month, 1);

    final Map<String, Map<String, dynamic>> agg = {};

    Map<String, dynamic> ensure(
        String size, String thickness, String unit, String productionType) {
      final key = '$size|$thickness';
      if (!agg.containsKey(key)) {
        agg[key] = {
          'size': size,
          'thickness': thickness,
          'unit': unit,
          'productionType': productionType,
          'producedKhada': 0,
          'producedWeight': 0.0,
          'producedToday': 0,
          'producedWeek': 0,
          'producedMonth': 0,
          'soldToday': 0,
          'soldWeek': 0,
          'soldMonth': 0,
          'soldWeightToday': 0.0,
          'soldWeightWeek': 0.0,
          'soldWeightMonth': 0.0,
          'rawWeight': 0.0,
          'remainingWeight': 0.0,
        };
      }
      return agg[key]!;
    }

    // -------- 1) Production logs --------
    for (final log in logs) {
      final size = (log['size']?.toString() ?? '').trim();
      final thickness = (log['thickness']?.toString() ?? '').trim();
      if (size.isEmpty || thickness.isEmpty) continue;

      final unit = log['unit']?.toString() ?? 'متر';

      // 🔑 Lookup real name via produced_product_id FIRST
      final pid = log['produced_product_id'] as int?;
      String productionType = '';
      if (pid != null) {
        productionType = productNameById[pid] ?? '';
      }
      if (_isGarbageName(productionType)) {
        // Fall back to log's own production_type (if not garbage)
        final logType = (log['production_type']?.toString() ?? '').trim();
        productionType = _isGarbageName(logType) ? '' : logType;
      }

      final rawCount = int.tryParse(log['raw_count']?.toString() ?? '0') ?? 0;
      final rawWeight =
          double.tryParse(log['raw_weight']?.toString() ?? '0') ?? 0;
      final totalWeight =
          double.tryParse(log['total_weight']?.toString() ?? '0') ?? 0;

      final d = _parseAnyDate(log['production_date_en']?.toString());

      final a = ensure(size, thickness, unit, productionType);
      a['producedKhada'] = (a['producedKhada'] as int) + rawCount;
      a['producedWeight'] = (a['producedWeight'] as double) + totalWeight;
      if (rawWeight > 0) a['rawWeight'] = rawWeight;

      // Only overwrite the name if we found a real (non-garbage) one
      if (!_isGarbageName(productionType)) {
        a['productionType'] = productionType;
      }

      if (d != null) {
        if (!d.isBefore(todayStart)) {
          a['producedToday'] = (a['producedToday'] as int) + rawCount;
        }
        if (!d.isBefore(weekStart)) {
          a['producedWeek'] = (a['producedWeek'] as int) + rawCount;
        }
        if (!d.isBefore(monthStart)) {
          a['producedMonth'] = (a['producedMonth'] as int) + rawCount;
        }
      }
    }

    // -------- 2) Remaining stock --------
    for (final p in products) {
      final size = (p['size']?.toString() ?? '').trim();
      final thickness = (p['thickness']?.toString() ?? '').trim();
      if (size.isEmpty || thickness.isEmpty) continue;

      final unit = p['unit']?.toString() ?? 'متر';

      final candidates = [
        p['production_type']?.toString() ?? '',
        p['product_name']?.toString() ?? '',
      ];
      String productionType = '';
      for (final c in candidates) {
        final trimmed = c.trim();
        if (!_isGarbageName(trimmed)) {
          productionType = trimmed;
          break;
        }
      }

      final rem =
          double.tryParse(p['remaining_stock']?.toString() ?? '0') ?? 0;
      final totalW =
          double.tryParse(p['total_weight']?.toString() ?? '0') ?? 0;
      final rw = double.tryParse(p['raw_weight']?.toString() ?? '0') ?? 0;

      final a = ensure(size, thickness, unit, productionType);
      a['remainingWeight'] =
          ((a['remainingWeight'] ?? 0.0) as double) + (rem > 0 ? rem : totalW);
      if (rw > 0) a['rawWeight'] = rw;
      if (_isGarbageName(a['productionType'] as String) &&
          !_isGarbageName(productionType)) {
        a['productionType'] = productionType;
      }
    }

    // -------- 3) Sales --------
    final Map<int, String> productKey = {};
    for (final p in products) {
      final size = (p['size']?.toString() ?? '').trim();
      final thickness = (p['thickness']?.toString() ?? '').trim();
      if (size.isEmpty || thickness.isEmpty) continue;
      productKey[p['id'] as int] = '$size|$thickness';
    }

    for (final s in sales) {
      final pid = s['produced_product_id'];
      final key = pid != null ? productKey[pid as int] : null;
      if (key == null || !agg.containsKey(key)) continue;

      final soldWeight =
          double.tryParse(s['total_weight']?.toString() ?? '0') ?? 0;
      final soldCount =
          double.tryParse(s['unit_count']?.toString() ?? '0') ?? 0;

      final d = _parseAnyDate(s['date_en']?.toString());

      final a = agg[key]!;
      final rw = (a['rawWeight'] as double?) ?? 0;
      final khadaSold = rw > 0 ? (soldWeight / rw).round() : soldCount.round();

      if (d != null) {
        if (!d.isBefore(todayStart)) {
          a['soldToday'] = (a['soldToday'] as int) + khadaSold;
          a['soldWeightToday'] =
              (a['soldWeightToday'] as double) + soldWeight;
        }
        if (!d.isBefore(weekStart)) {
          a['soldWeek'] = (a['soldWeek'] as int) + khadaSold;
          a['soldWeightWeek'] = (a['soldWeightWeek'] as double) + soldWeight;
        }
        if (!d.isBefore(monthStart)) {
          a['soldMonth'] = (a['soldMonth'] as int) + khadaSold;
          a['soldWeightMonth'] =
              (a['soldWeightMonth'] as double) + soldWeight;
        }
      }
    }

    final result = <_KhadaStat>[];
    for (final a in agg.values) {
      final rw = (a['rawWeight'] as double?) ?? 0;
      final remW = (a['remainingWeight'] ?? 0.0) as double;
      final remKhada = rw > 0 ? (remW / rw).round() : 0;

      result.add(_KhadaStat(
        productionType: a['productionType'] as String,
        size: a['size'] as String,
        thickness: a['thickness'] as String,
        unit: a['unit'] as String,
        producedKhada: a['producedKhada'] as int,
        producedWeight: a['producedWeight'] as double,
        remainingKhada: remKhada,
        remainingWeight: remW,
        producedToday: a['producedToday'] as int,
        producedWeek: a['producedWeek'] as int,
        producedMonth: a['producedMonth'] as int,
        soldToday: a['soldToday'] as int,
        soldWeek: a['soldWeek'] as int,
        soldMonth: a['soldMonth'] as int,
        soldWeightToday: a['soldWeightToday'] as double,
        soldWeightWeek: a['soldWeightWeek'] as double,
        soldWeightMonth: a['soldWeightMonth'] as double,
      ));
    }

    result.sort((a, b) {
      final c = a.size.compareTo(b.size);
      if (c != 0) return c;
      return a.thickness.compareTo(b.thickness);
    });

    return result;
  }

  List<_KhadaStat> get _filtered {
    final typeQ = _typeController.text.trim().toLowerCase();
    final sizeQ = _sizeController.text.trim().toLowerCase();
    final thQ = _thicknessController.text.trim().toLowerCase();

    return _stats.where((s) {
      final matchesType =
          typeQ.isEmpty || s.productionType.toLowerCase().contains(typeQ);
      final matchesSize =
          sizeQ.isEmpty || s.size.toLowerCase().contains(sizeQ);
      final matchesTh =
          thQ.isEmpty || s.thickness.toLowerCase().contains(thQ);
      return matchesType && matchesSize && matchesTh;
    }).toList();
  }

  bool get _hasAnyFilter =>
      _typeController.text.trim().isNotEmpty ||
      _sizeController.text.trim().isNotEmpty ||
      _thicknessController.text.trim().isNotEmpty;

  void _clearAllFilters() {
    setState(() {
      _typeController.clear();
      _sizeController.clear();
      _thicknessController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final isEn = lang.isEnglish;

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Container(
        color: const Color(0xFFF5F5F7),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFCB001D), Color(0xFF8B0015)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFCB001D).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.warehouse_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'مدیریت انبار',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'خلاصه خاده های باقی مانده، تولید و فروش',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        color: Color(0xFFCB001D), size: 20),
                    onPressed: _loadStats,
                    padding: EdgeInsets.zero,
                    tooltip: 'بروزرسانی',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSearchRow(),
            const SizedBox(height: 14),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFCB001D)))
                  : _stats.isEmpty
                      ? _emptyState()
                      : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchRow() {
    return Row(
      children: [
        Expanded(
          child: _searchField(
            controller: _typeController,
            label: 'نوع تولید',
            hint: 'مثال: چارخ',
            icon: Icons.factory_outlined,
            color: const Color(0xFFCB001D),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 200,
          child: _searchField(
            controller: _sizeController,
            label: 'سایز',
            hint: 'مثال: 100',
            icon: Icons.straighten,
            color: const Color(0xFF1565C0),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 200,
          child: _searchField(
            controller: _thicknessController,
            label: 'ضخامت',
            hint: 'مثال: 5',
            icon: Icons.layers_outlined,
            color: const Color(0xFF2E7D32),
          ),
        ),
        if (_hasAnyFilter) ...[
          const SizedBox(width: 10),
          Tooltip(
            message: 'پاک کردن فیلترها',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _clearAllFilters,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.red.shade200, width: 1),
                  ),
                  child: Icon(Icons.close_rounded,
                      color: Colors.red.shade700, size: 20),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _searchField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: (_) => setState(() {}),
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A2E),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w400),
          prefixIcon: Container(
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 42, minHeight: 42),
          labelText: label,
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close,
                      size: 16, color: Colors.grey.shade400),
                  onPressed: () {
                    setState(() => controller.clear());
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _hasAnyFilter ? Icons.search_off_rounded : Icons.inbox_rounded,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            _hasAnyFilter
                ? 'هیچ نتیجه ای پیدا نشد'
                : 'هنوز هیچ تولیدی ثبت نشده است',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_hasAnyFilter) ...[
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('پاک کردن فیلترها'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFCB001D),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    final data = _filtered;

    int totRemain = 0,
        totProd = 0,
        totProdToday = 0,
        totProdWeek = 0,
        totProdMonth = 0,
        totSoldToday = 0,
        totSoldWeek = 0,
        totSoldMonth = 0;
    for (final s in data) {
      totRemain += s.remainingKhada;
      totProd += s.producedKhada;
      totProdToday += s.producedToday;
      totProdWeek += s.producedWeek;
      totProdMonth += s.producedMonth;
      totSoldToday += s.soldToday;
      totSoldWeek += s.soldWeek;
      totSoldMonth += s.soldMonth;
    }

    return Column(
      children: [
        Row(
          children: [
            _summaryCard('باقی مانده', '$totRemain',
                Icons.inventory_2_outlined, const Color(0xFF2E7D32)),
            const SizedBox(width: 8),
            _summaryCard('کل تولید', '$totProd', Icons.factory_outlined,
                const Color(0xFFCB001D)),
            const SizedBox(width: 8),
            _summaryCard('تولید امروز', '$totProdToday',
                Icons.today_outlined, const Color(0xFF1565C0)),
            const SizedBox(width: 8),
            _summaryCard('فروش امروز', '$totSoldToday',
                Icons.shopping_cart_outlined, const Color(0xFFE65100)),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: const Color(0xFFCB001D).withOpacity(0.08),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFCB001D).withOpacity(0.08),
                        const Color(0xFFCB001D).withOpacity(0.02),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                    ),
                  ),
                  child: Row(
                    children: [
                      _hCell('نوع تولید', 140),
                      _hCell('سایز', 70),
                      _hCell('ضخامت', 70),
                      _hCell('باقی مانده', 90),
                      _hCell('کل تولید', 80),
                      _hCell('تولید امروز', 80),
                      _hCell('هفته', 65),
                      _hCell('ماه', 65),
                      _hCell('فروش امروز', 80),
                      _hCell('هفته', 65),
                      _hCell('ماه', 65),
                      _hCell('وزن باقی مانده', 110),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: data.length,
                    itemBuilder: (_, i) {
                      final s = data[i];
                      final isEven = i % 2 == 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: isEven
                              ? Colors.white
                              : const Color(0xFFCB001D).withOpacity(0.03),
                          border: Border(
                            bottom: BorderSide(
                                color: Colors.grey.shade100, width: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            _dCell(
                              s.productionType.isEmpty
                                  ? '—'
                                  : s.productionType,
                              140,
                              bold: true,
                              color: const Color(0xFFCB001D),
                            ),
                            _dCell(s.size.isEmpty ? '-' : s.size, 70,
                                bold: true),
                            _dCell(s.thickness.isEmpty ? '-' : s.thickness, 70,
                                bold: true),
                            _badgeCell('${s.remainingKhada}', 90,
                                const Color(0xFF2E7D32)),
                            _dCell('${s.producedKhada}', 80,
                                color: const Color(0xFF1A1A2E), bold: true),
                            _dCell(
                                s.producedToday > 0
                                    ? '${s.producedToday}'
                                    : '—',
                                80,
                                color: const Color(0xFF1565C0),
                                bold: s.producedToday > 0),
                            _dCell(
                                s.producedWeek > 0 ? '${s.producedWeek}' : '—',
                                65,
                                color: const Color(0xFF1565C0)),
                            _dCell(
                                s.producedMonth > 0
                                    ? '${s.producedMonth}'
                                    : '—',
                                65,
                                color: const Color(0xFF1565C0)),
                            _dCell(
                                s.soldToday > 0 ? '${s.soldToday}' : '—', 80,
                                color: const Color(0xFFE65100),
                                bold: s.soldToday > 0),
                            _dCell(
                                s.soldWeek > 0 ? '${s.soldWeek}' : '—', 65,
                                color: const Color(0xFFE65100)),
                            _dCell(
                                s.soldMonth > 0 ? '${s.soldMonth}' : '—', 65,
                                color: const Color(0xFFE65100)),
                            _dCell(_fmtWeight(s.remainingWeight, s.unit), 110,
                                color: Colors.grey.shade700),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFCB001D).withOpacity(0.1),
                        const Color(0xFFCB001D).withOpacity(0.04),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: const Color(0xFFCB001D).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 140,
                        child: Text('جمع',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFCB001D),
                            ),
                            textAlign: TextAlign.center),
                      ),
                      const SizedBox(width: 70),
                      const SizedBox(width: 70),
                      _totalCell('$totRemain', 90, const Color(0xFF2E7D32)),
                      _totalCell('$totProd', 80, const Color(0xFF1A1A2E)),
                      _totalCell(
                          '$totProdToday', 80, const Color(0xFF1565C0)),
                      _totalCell('$totProdWeek', 65, const Color(0xFF1565C0)),
                      _totalCell(
                          '$totProdMonth', 65, const Color(0xFF1565C0)),
                      _totalCell(
                          '$totSoldToday', 80, const Color(0xFFE65100)),
                      _totalCell(
                          '$totSoldWeek', 65, const Color(0xFFE65100)),
                      _totalCell(
                          '$totSoldMonth', 65, const Color(0xFFE65100)),
                      const SizedBox(width: 110),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.15), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: color,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hCell(String text, double width) => SizedBox(
        width: width,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );

  Widget _dCell(String text, double width,
      {bool bold = false, Color color = const Color(0xFF1A1A2E)}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          color: color,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _badgeCell(String text, double width, Color color) {
    return SizedBox(
      width: width,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _totalCell(String text, double width, Color color) => SizedBox(
        width: width,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      );
}