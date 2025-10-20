import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_4/utils/delivery_status.dart';

class DeliveryRecord {
  DeliveryRecord(this.snapshot)
      : id = snapshot.id,
        data = snapshot.data();

  final QueryDocumentSnapshot<Map<String, dynamic>> snapshot;
  final String id;
  final Map<String, dynamic> data;

  String? get statusRaw => data['status']?.toString();
  String get status => DeliveryStatus.normalize(statusRaw);
  String? get senderId => data['userid_sender']?.toString();
  String? get receiverId {
    final byField = data['userid_receiver'];
    if (byField != null && byField.toString().isNotEmpty) {
      return byField.toString();
    }
    final legacy = data['receiverid'];
    return legacy?.toString();
  }

  String? get riderId => data['riderid']?.toString();
  String? get senderAddressId => data['addressid_sender']?.toString();
  String? get receiverAddressId => data['addressid_receiver']?.toString();
  String? get receiverPhone => data['phone_receiver']?.toString();
  String? get senderPhone => data['phone_sender']?.toString();
  String? get receiverName => data['receiver_name']?.toString();
  String? get senderName => data['sender_name']?.toString();
  String? get detail => data['detail']?.toString();
  String? get pictureStatus1 => data['picture_status1']?.toString();

  int get amount {
    final value = data['amount'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 1;
  }

  Timestamp? get createdAtTs => data['created_at'] as Timestamp?;
  Timestamp? get updatedAtTs => data['updated_at'] as Timestamp?;

  DateTime? get createdAt => createdAtTs?.toDate();
  DateTime? get updatedAt => updatedAtTs?.toDate();

  bool get isActive => DeliveryStatus.isActive(statusRaw);
  bool get isCompleted => DeliveryStatus.isCompleted(statusRaw);
  bool get isMapRelated => DeliveryStatus.isMapRelated(statusRaw);
}

class UserSummary {
  const UserSummary({required this.id, required this.name, required this.phone, this.pictureUrl});

  final String id;
  final String name;
  final String phone;
  final String? pictureUrl;

  factory UserSummary.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? {};
    return UserSummary(
      id: snap.id,
      name: data['name']?.toString() ?? '-',
      phone: data['phone']?.toString() ?? '-',
      pictureUrl: data['picture']?.toString(),
    );
  }
}

class AddressSummary {
  const AddressSummary({
    required this.id,
    required this.address,
    required this.lat,
    required this.lng,
  });

  final String id;
  final String address;
  final double? lat;
  final double? lng;

  factory AddressSummary.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? {};
    return AddressSummary(
      id: snap.id,
      address: data['address']?.toString() ?? '-',
      lat: _toDouble(data['lat']),
      lng: _toDouble(data['lng']),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
