import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class PinLocationPage extends StatefulWidget {
  const PinLocationPage({super.key, this.initialZoom = 15.5});

  final double initialZoom;

  @override
  State<PinLocationPage> createState() => _PinLocationPageState();
}

class _PinLocationPageState extends State<PinLocationPage> {
  final MapController _map = MapController();

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _isMapReady = false;

  // จะสร้างแผนที่ก็ต่อเมื่อรู้พิกัดจริงครั้งแรก
  LatLng? _mapCenter;

  // จุดผู้ใช้ (จุดดำ) และตำแหน่งหมุดที่เลือก (หมุดแดง)
  LatLng? _myLocation;
  LatLng? _pin;

  static const _headerH = 56.0;
  static const _brandRed = Color(0xFFE96356);

  // ---------- Suggestions state -----------
  bool _isSearching = false;
  List<_GeoSuggestion> _suggestions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _goToMyLocation(autoSetPin: true, moveCamera: false);
    });

    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /* ======================== Search ======================== */

  void _onSearchChanged() {
    // ถ้าดูเหมือนพิมพ์รูปแบบ lat,lng ให้ไม่ยิง geocoding
    if (_looksLikeLatLng(_searchCtrl.text)) return;

    // debounce เพื่อไม่ยิง API ทุกตัวอักษร
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _runGeocoding(_searchCtrl.text.trim());
    });
  }

  bool _looksLikeLatLng(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return false;
    final norm = t.replaceAll(',', ' ').replaceAll(RegExp(r'\s+'), ' ');
    final parts = norm.split(' ');
    if (parts.length != 2) return false;
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    return lat != null && lng != null;
  }

  Future<void> _runGeocoding(String q) async {
    if (q.isEmpty) {
      setState(() {
        _isSearching = false;
        _suggestions = [];
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      // ใช้ Nominatim (OpenStreetMap)
      // จำกัดประเทศไทย ถ้าต้องการลบตัวกรอง countrycodes=th ออกได้
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeQueryComponent(q)}'
        '&format=json&addressdetails=1&limit=10&countrycodes=th',
      );

      final res = await http.get(
        uri,
        headers: {
          // ใส่ชื่อแอป/อีเมลของคุณตามข้อกำหนดของ Nominatim
          'User-Agent': 'your.app.name/1.0 (contact@example.com)',
        },
      );

      if (res.statusCode == 200) {
        final List data = json.decode(res.body) as List;
        final items = data
            .map((e) {
              final lat = double.tryParse(e['lat']?.toString() ?? '');
              final lon = double.tryParse(e['lon']?.toString() ?? '');
              final name = (e['display_name'] ?? '') as String;
              return (lat != null && lon != null)
                  ? _GeoSuggestion(name: name, point: LatLng(lat, lon))
                  : null;
            })
            .whereType<_GeoSuggestion>()
            .toList();

        if (mounted) {
          setState(() {
            _suggestions = items;
            _isSearching = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _suggestions = [];
            _isSearching = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _isSearching = false;
        });
      }
    }
  }

  void _pickSuggestion(_GeoSuggestion s) {
    FocusScope.of(context).unfocus();
    _searchCtrl.text = s.name;
    setState(() {
      _suggestions = [];
      _isSearching = false;
      _pin = s.point;
      _mapCenter ??= s.point;
    });
    if (_isMapReady) {
      _map.move(s.point, 17);
    }
  }

  /* ======================== Utilities ======================== */

  LatLng? _parseLatLng(String raw) {
    final t = raw.trim();
    final norm = t.replaceAll(',', ' ').replaceAll(RegExp(r'\s+'), ' ');
    final parts = norm.split(' ');
    if (parts.length != 2) return null;

    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90) return null;
    if (lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  }

  Future<void> _goToEnteredLatLng() async {
    // หากเป็นพิกัด lat,lng ให้ไปตามนั้น
    final p = _parseLatLng(_searchCtrl.text);
    if (p == null) {
      // ถ้าไม่ใช่ lat,lng ให้ลอง geocoding ทันที (กันกรณีกดลูกศร)
      await _runGeocoding(_searchCtrl.text.trim());
      return;
    }
    if (_isMapReady) _map.move(p, 17);
    setState(() => _pin = p);
  }

  /// ไปยังตำแหน่งปัจจุบัน
  Future<void> _goToMyLocation({
    bool autoSetPin = false,
    bool moveCamera = true,
  }) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('โปรดเปิด Location Service')),
      );
      return;
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('แอปไม่ได้รับสิทธิ์ตำแหน่ง')),
      );
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    final here = LatLng(pos.latitude, pos.longitude);

    setState(() {
      _myLocation = here;
      _mapCenter ??= here;
      if (autoSetPin) _pin = here;
    });

    if (moveCamera && _isMapReady) {
      _map.move(here, 17.0);
    }
  }

  void _confirm() {
    if (_pin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('แตะแผนที่เพื่อวางหมุด หรือค้นหาพิกัด/สถานที่'),
        ),
      );
      return;
    }
    Navigator.pop(context, _pin);
  }

  /* ======================== Build ======================== */

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final searchTop = topInset + _headerH + 10;

    return Scaffold(
      body: Stack(
        children: [
          // ===== Map =====
          Positioned.fill(
            child: (_mapCenter == null)
                ? const Center(child: CircularProgressIndicator())
                : FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: _mapCenter!,
                      initialZoom: widget.initialZoom,
                      onTap: (tapPos, point) => setState(() => _pin = point),
                      onMapReady: () => setState(() => _isMapReady = true),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.thunderforest.com/cycle/{z}/{x}/{y}.png?apikey=2b365b3e7fb44e1dbf1b700f6327e98a',
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName: 'com.example.app',
                      ),
                      MarkerLayer(
                        rotate: false,
                        markers: [
                          if (_myLocation != null) ...[
                            Marker(
                              point: _myLocation!,
                              width: 44,
                              height: 44,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black54,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            Marker(
                              point: _myLocation!,
                              width: 24,
                              height: 24,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black38,
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (_pin != null)
                            Marker(
                              point: _pin!,
                              width: 60,
                              height: 60,
                              child: Transform.translate(
                                offset: const Offset(0, -12),
                                child: const Icon(
                                  Icons.location_on,
                                  size: 48,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),

          // ===== Header =====
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                height: _headerH,
                decoration: const BoxDecoration(
                  color: _brandRed,
                  border: Border(
                    bottom: BorderSide(color: Colors.black, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.maybePop(context),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.black,
                          size: 26,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'ปักหมุดที่อยู่',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          height: 1.2,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          shadows: [
                            Shadow(
                              blurRadius: 1.5,
                              offset: Offset(0.6, 0.6),
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 38),
                  ],
                ),
              ),
            ),
          ),

          // ===== Search box (ชื่อสถานที่หรือ lat,lng) =====
          Positioned(
            top: searchTop,
            left: 12,
            right: 12,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(28),
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText:
                      'ค้นหาสถานที่/หมู่บ้าน/ตำบล/อำเภอ/จังหวัด หรือพิมพ์ 16.24637, 103.25182',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'ค้นหา/ไปยังพิกัด',
                    onPressed: _goToEnteredLatLng,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: Colors.black26),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: Colors.black26),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(
                      color: Colors.black87,
                      width: 1.5,
                    ),
                  ),
                ),
                onSubmitted: (_) => _goToEnteredLatLng(),
              ),
            ),
          ),

          // ===== Suggestions overlay =====
          if (_isSearching || _suggestions.isNotEmpty)
            Positioned(
              top: searchTop + 56,
              left: 16,
              right: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: _isSearching
                      ? const SizedBox(
                          height: 80,
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: Colors.black12),
                          itemBuilder: (context, i) {
                            final s = _suggestions[i];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.place_outlined),
                              title: Text(
                                s.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _pickSuggestion(s),
                            );
                          },
                        ),
                ),
              ),
            ),

          // ===== Confirm button (ล่างขวา) =====
          Positioned(
            right: 16,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandRed,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.black.withOpacity(0.35),
                      width: 1,
                    ),
                  ),
                  elevation: 6,
                ),
                onPressed: _confirm,
                child: const Text(
                  'ยืนยันการปักหมุด',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),

          // ===== GPS target =====
          Positioned(
            right: 16,
            bottom: 24 + 60,
            child: Material(
              color: _brandRed,
              shape: const CircleBorder(
                side: BorderSide(color: Colors.black54, width: 1),
              ),
              elevation: 6,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _goToMyLocation(autoSetPin: false),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.gps_fixed, size: 28, color: Colors.black),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ======================== model ======================== */

class _GeoSuggestion {
  final String name;
  final LatLng point;
  _GeoSuggestion({required this.name, required this.point});
}
