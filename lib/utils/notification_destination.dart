import 'package:flutter/material.dart';
import '../screens/bill_detail_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/request_screens.dart';

Widget? notificationDestination(
    {required String type,
    String? billId,
    String? groupId,
    bool fromInbox = false}) {
  if (type == 'group_invite') {
    return GroupRequestsScreen(initialGroupId: groupId);
  }
  if (type == 'friend_request') return const FriendRequestsScreen();
  if (type == 'bill_created' || type == 'bill_paid' || type == 'reminder') {
    if (billId != null && billId.isNotEmpty) {
      return BillDetailScreen(billId: billId);
    }
    if (!fromInbox) return const NotificationsScreen();
  }
  return null;
}
