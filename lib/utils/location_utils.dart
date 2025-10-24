import 'package:geolocator/geolocator.dart';

/// Helper methods for requesting location permissions and measuring distance.
class LocationUtils {
  const LocationUtils._();

  /// Requests permission (if needed) and returns the current position.
  static Future<Position> ensureCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException('กรุณาเปิดบริการระบุตำแหน่งก่อนใช้งาน');
    }

    LocationPermission permission = await Geolocator.checkPermission();
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
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Returns `true` if [position] is within [maxDistanceMeters] from
  /// ([targetLat], [targetLng]). If the target is missing this will return
  /// `false`.
  static bool isWithinDistance({
    required Position position,
    required double? targetLat,
    required double? targetLng,
    required double maxDistanceMeters,
  }) {
    if (targetLat == null || targetLng == null) {
      return false;
    }
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      targetLat,
      targetLng,
    );
    return distance <= maxDistanceMeters;
  }

  /// Creates a position stream suitable for live tracking on the map.
  static Stream<Position> livePositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    );
  }
}

class LocationException implements Exception {
  const LocationException(this.message);
  final String message;

  @override
  String toString() => message;
}
