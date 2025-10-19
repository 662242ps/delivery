/// ค่าคงที่และเครื่องมือสำหรับสถานะของงานจัดส่ง
class DeliveryStatus {
  DeliveryStatus._();

  static const waitingForRider = 'รอไรเดอร์มารับสินค้า';
  static const riderAccepted = 'ไรเดอร์รับงาน';
  static const riderPickedUp = 'ไรเดอร์รับสินค้าแล้วและกำลังเดินทางไปส่ง';
  static const delivered = 'ไรเดอร์นำส่งสินค้าแล้ว';

  /// สถานะที่ถือว่ายังอยู่ระหว่างดำเนินการ (ใช้ในหน้า "กำลังจัดส่ง")
  static const active = <String>{waitingForRider, riderAccepted, riderPickedUp};

  /// สถานะที่เกี่ยวข้องกับการติดตามบนแผนที่ (ระหว่างรอหรือกำลังจัดส่ง)
  static const mapRelated = <String>{
    waitingForRider,
    riderAccepted,
    riderPickedUp,
  };

  /// สถานะที่ถือว่าส่งสำเร็จเรียบร้อยแล้ว (ใช้ในหน้า "ประวัติ")
  static const completed = <String>{delivered};

  /// Alias จากข้อมูลเก่า/ชื่อที่สั้นลง เพื่อให้รองรับฐานข้อมูลเดิม
  static const Map<String, String> _aliases = {
    'รอไรเดอร์': waitingForRider,
    'รอไรเดอร์มารับสินค้า': waitingForRider,
    'ไรเดอร์รับงาน': riderAccepted,
    'ไรเดอร์รับงาน (กำลังเดินทางมารับสินค้า)': riderAccepted,
    'ไรเดอร์รับสินค้าแล้ว': riderPickedUp,
    'ไรเดอร์รับสินค้าแล้วและกำลังเดินทางไปส่ง': riderPickedUp,
    'จัดส่งสำเร็จ': delivered,
    'ไรเดอร์นำส่งสินค้าแล้ว': delivered,
  };

  /// รวม alias และสถานะจริงทั้งหมด
  static final Set<String> allValues = {
    ..._aliases.keys,
    waitingForRider,
    riderAccepted,
    riderPickedUp,
    delivered,
  };

  /// คืนค่าชื่อสถานะให้เป็นมาตรฐานเดียวกัน
  static String normalize(String? status) {
    if (status == null) return waitingForRider;
    final trimmed = status.trim();
    return _aliases[trimmed] ?? trimmed;
  }

  static bool isActive(String? status) {
    final normalized = normalize(status);
    return active.contains(normalized);
  }

  static bool isCompleted(String? status) {
    final normalized = normalize(status);
    return completed.contains(normalized);
  }

  static bool isMapRelated(String? status) {
    final normalized = normalize(status);
    return mapRelated.contains(normalized);
  }

  /// สำหรับการเรียงลำดับ status ในหน้า "กำลังจัดส่ง" ให้ตรงลำดับไทม์ไลน์
  static const List<String> activeOrder = [
    waitingForRider,
    riderAccepted,
    riderPickedUp,
  ];

  static int compare(String? a, String? b) {
    final na = normalize(a);
    final nb = normalize(b);
    final indexA = activeOrder.indexOf(na);
    final indexB = activeOrder.indexOf(nb);
    if (indexA >= 0 && indexB >= 0) return indexA.compareTo(indexB);
    if (indexA >= 0) return -1;
    if (indexB >= 0) return 1;
    return na.compareTo(nb);
  }
}

extension DeliveryStatusIterableExt on Iterable<String> {
  /// จัดเรียงตามลำดับไทม์ไลน์สถานะ ถ้าไม่พบให้เรียงตามตัวอักษรปกติ
  List<String> sortedByTimeline() {
    final sorted = toList();
    sorted.sort(DeliveryStatus.compare);
    return sorted;
  }
}
