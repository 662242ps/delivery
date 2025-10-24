// lib/utils/location_utils.dart
import 'dart:io' show Platform;
import 'package:geolocator/geolocator.dart';

/// Helper methods for requesting location permissions and measuring distance.
class LocationUtils {
  const LocationUtils._();

  /// Requests permission (if needed) and returns the current position.
  static Future<Position> ensureCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException('กรุณาเปิดบริการระบุตำแหน่งก่อนใช้งาน');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException('แอปไม่ได้รับสิทธิ์เข้าถึงตำแหน่ง');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'สิทธิ์ตำแหน่งถูกปฏิเสธถาวร กรุณาเปิดสิทธิ์จากการตั้งค่า',
      );
    }

    return Geolocator.getCurrentPosition(
      // ให้ความแม่นสูงสุดสำหรับการนำทางแบบเรียลไทม์
      desiredAccuracy: LocationAccuracy.bestForNavigation,
    );
  }

  /// Returns `true` if [position] is within [maxDistanceMeters] from
  /// ([targetLat], [targetLng]).
  static bool isWithinDistance({
    required Position position,
    required double? targetLat,
    required double? targetLng,
    required double maxDistanceMeters,
  }) {
    if (targetLat == null || targetLng == null) return false;
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      targetLat,
      targetLng,
    );
    return distance <= maxDistanceMeters;
  }

  /// Creates a high-frequency position stream for smooth map tracking.
  ///
  /// ปรับแต่งได้ผ่านพารามิเตอร์ ถ้าไม่ส่งจะใช้ค่าที่เหมาะกับความ "ลื่น"
  /// - [accuracy] : ค่าเริ่มต้น `bestForNavigation`
  /// - [distanceFilter] : เมตรที่ต้องขยับก่อนจะอัปเดต (0 = ทุกการเปลี่ยนแปลง)
  /// - [androidInterval] : ช่วงเวลาอัปเดตบน Android (iOS ไม่มีตัวนี้)
  static Stream<Position> livePositionStream({
    LocationAccuracy accuracy = LocationAccuracy.bestForNavigation,
    int distanceFilter = 0, // 0 = อัปเดตถี่สุดเท่าที่ OS ให้
    Duration androidInterval = const Duration(milliseconds: 800),
    ActivityType iosActivityType = ActivityType.automotiveNavigation,
    bool iosPauseAutomatically = false,
    bool iosAllowBackground = false,
  }) {
    // บน Android ใช้ AndroidSettings เพื่อกำหนด intervalDuration ได้
    if (Platform.isAndroid) {
      final settings = AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        intervalDuration: androidInterval,
        // ถ้าต้องตามในพื้นหลังจริงๆ อาจต้องเปิด foreground service ด้วย
        // foregroundNotificationConfig: ...
      );
      return Geolocator.getPositionStream(locationSettings: settings);
    }

    // บน iOS ปรับ activityType + distanceFilter เพื่อเร่งความถี่
    if (Platform.isIOS || Platform.isMacOS) {
      final settings = AppleSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        activityType: iosActivityType, // เหมาะกับการขับ/ส่งของ
        pauseLocationUpdatesAutomatically: iosPauseAutomatically,
        allowBackgroundLocationUpdates: iosAllowBackground,
        // showBackgroundLocationIndicator: false, // ปรับตามดีไซน์
      );
      return Geolocator.getPositionStream(locationSettings: settings);
    }

    // แพลตฟอร์มอื่นๆ ใช้ค่า generic
    final settings = LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
    );
    return Geolocator.getPositionStream(locationSettings: settings);
  }
}

class LocationException implements Exception {
  const LocationException(this.message);
  final String message;
  @override
  String toString() => message;
}
