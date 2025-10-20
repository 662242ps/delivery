import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_4/utils/delivery_lookup.dart';
import 'package:flutter_application_4/utils/delivery_models.dart';
import 'package:flutter_application_4/utils/delivery_status.dart';
import 'package:flutter_application_4/widgets/delivery_card.dart';

class DeliveryStreamList extends StatelessWidget {
  const DeliveryStreamList({
    super.key,
    required this.stream,
    required this.lookup,
    required this.searchText,
    required this.isSender,
    required this.onTap,
    required this.filter,
    required this.emptyMessage,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final DeliveryLookupCache lookup;
  final String searchText;
  final bool isSender;
  final ValueChanged<DeliveryRecord> onTap;
  final bool Function(DeliveryRecord) filter;
  final String emptyMessage;

  String _searchPhone(DeliveryRecord record) {
    if (isSender) {
      return record.receiverPhone ?? '';
    }
    return record.senderPhone ?? '';
  }

  Future<String> _resolvePrimaryValue(DeliveryRecord record) async {
    if (isSender) {
      final name = record.receiverName;
      if (name != null && name.isNotEmpty) {
        return '$name | ${record.receiverPhone ?? '-'}';
      }
      final user = await lookup.getUser(record.receiverId);
      return '${user?.name ?? '-'} | ${user?.phone ?? record.receiverPhone ?? '-'}';
    } else {
      final name = record.senderName;
      if (name != null && name.isNotEmpty) {
        return '$name | ${record.senderPhone ?? '-'}';
      }
      final user = await lookup.getUser(record.senderId);
      return '${user?.name ?? '-'} | ${user?.phone ?? record.senderPhone ?? '-'}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final records = docs
            .map((doc) => DeliveryRecord(doc))
            .where(filter)
            .toList()
          ..sort((a, b) {
            final cmp = DeliveryStatus.compare(a.status, b.status);
            if (cmp != 0) return cmp;
            final at = a.updatedAt ?? a.createdAt;
            final bt = b.updatedAt ?? b.createdAt;
            if (at != null && bt != null) {
              return bt.compareTo(at);
            }
            return b.id.compareTo(a.id);
          });

        final query = searchText.trim();
        final filtered = query.isEmpty
            ? records
            : records.where((record) {
                final phone = _searchPhone(record);
                return phone.contains(query);
              }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text(emptyMessage),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final record = filtered[index];
            return FutureBuilder<String>(
              future: _resolvePrimaryValue(record),
              builder: (context, snapshot) {
                final value = snapshot.data ??
                    (isSender
                        ? record.receiverPhone ?? '-'
                        : record.senderPhone ?? '-');
                final label = isSender ? 'ผู้รับ:' : 'ผู้ส่ง:';
                return DeliveryCard(
                  record: record,
                  primaryLabel: label,
                  primaryValue: value,
                  statusLabel: record.status,
                  onTap: () => onTap(record),
                );
              },
            );
          },
        );
      },
    );
  }
}
