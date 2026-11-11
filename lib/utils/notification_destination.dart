import 'package:flutter/material.dart';
import '../screens/bill_detail_screen.dart';
import '../screens/group_invitation_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/requests_tab.dart';

Widget? notificationDestination(
    {required String type,
    String? billId,
    String? groupId,
    bool fromInbox = false}) {
  if (type == 'group_invite') {
    return groupId == null || groupId.isEmpty
        ? const RequestsTab()
        : GroupInvitationScreen(groupId: groupId);
  }
  if (type == 'friend_request') return const RequestsTab(initialIndex: 2);
  if (type == 'bill_created' || type == 'bill_paid' || type == 'reminder') {
    if (billId != null && billId.isNotEmpty) {
      return BillDetailScreen(billId: billId);
    }
    if (!fromInbox) return const NotificationsScreen();
  }
  return null;
}
