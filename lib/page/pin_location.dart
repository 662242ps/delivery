// pin_location_page.dart
import 'dart:async';
import 'dart:developer';
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

  bool _isMapReady = false;

  // จะสร้างแผนที่ก็ต่อเมื่อรู้พิกัดจริงครั้งแรก
  LatLng? _mapCenter;

  // จุดผู้ใช้ (จุดดำ) และตำแหน่งหมุดที่เลือก (หมุดแดง)
  LatLng? _myLocation;
  LatLng? _pin;

  static const _headerH = 56.0;
  static const _brandRed = Color(0xFFE96356);

  @override
  void initState() {
    super.initState();
    // พอเข้าหน้าให้หาพิกัดจริงก่อน แล้วค่อยสร้างแผนที่ (จะไม่เด้งไปจุดอื่นก่อน)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _goToMyLocation(autoSetPin: true, moveCamera: false);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
    final p = _parseLatLng(_searchCtrl.text);
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'รูปแบบไม่ถูกต้อง ใส่: ละติจูด, ลองจิจูด เช่น 16.24637, 103.25182',
          ),
        ),
      );
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
      _mapCenter ??= here; // ใช้เป็นศูนย์กลางตอนสร้างแผนที่ครั้งแรก
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
          content: Text('แตะแผนที่เพื่อวางหมุด หรือกรอกพิกัดให้ถูกต้อง'),
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
                      // MarkerLayer เดียว: จุดดำก่อน -> หมุดแดงทับ (ให้หมุดอยู่บน)
                      MarkerLayer(
                        rotate: false, // << หมุด/จุดจะตั้งตรงขนานกับจอตลอด
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
                                offset: const Offset(
                                  0,
                                  -12,
                                ), // ยกหัวหมุดให้ปลายชี้พิกัดจริง
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

          // ===== Search box (lat,lng) =====
          Positioned(
            top: searchTop,
            left: 12,
            right: 12,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(28),
              child: TextField(
                controller: _searchCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: InputDecoration(
                  hintText: 'เช่น 16.24637, 103.25182',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'ไปยังพิกัด',
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

          // ===== Confirm button (ล่างขวา) =====
          Positioned(
            right: 16,
            bottom: 24, // << อยู่ล่างสุด
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

          // ===== GPS target (วางเหนือปุ่มยืนยันเล็กน้อย) =====
          Positioned(
            right: 16,
            bottom: 24 + 60, // << ยกขึ้นเหนือปุ่มยืนยัน ~60px
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
