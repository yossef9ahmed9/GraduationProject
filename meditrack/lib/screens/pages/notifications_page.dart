import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/services/notification_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';
import 'package:meditrack/screens/chat_screen.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final notifs = context.watch<NotificationProvider>();
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final all     = notifs.all;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notifs.unreadCount > 0)
            TextButton(
              onPressed: notifs.markAllRead,
              child: Text('Mark all read',
                  style: GoogleFonts.dmSans(fontSize: 13,
                      color: isDark ? AppColors.darkAccent : AppColors.accent)),
            ),
        ],
      ),
      body: all.isEmpty
          ? const EmptyState(
          message: 'No notifications yet',
          icon: Icons.notifications_none_rounded)
          : ListView.separated(
        itemCount: all.length,
        separatorBuilder: (_, __) => Divider(height: 1,
            color: isDark ? AppColors.darkBorderColor : AppColors.borderColor),
        itemBuilder: (_, i) => _NotifTile(notif: all[i]),
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final AppNotification notif;
  const _NotifTile({required this.notif});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final notifPr = context.read<NotificationProvider>();

    IconData icon; Color iconBg, iconFg;
    switch (notif.type) {
      case NotifType.message:
        icon   = Icons.chat_bubble_outline_rounded;
        iconBg = isDark ? AppColors.darkBadgeBlueBg   : AppColors.badgeBlueBg;
        iconFg = isDark ? AppColors.darkBadgeBlueTxt  : AppColors.badgeBlueTxt;
        break;
      case NotifType.emergency:
        icon   = Icons.warning_amber_rounded;
        iconBg = isDark ? AppColors.darkBadgeRedBg    : AppColors.badgeRedBg;
        iconFg = isDark ? AppColors.darkBadgeRedTxt   : AppColors.badgeRedTxt;
        break;
      case NotifType.dispatch:
        icon   = Icons.emergency_outlined;
        iconBg = isDark ? AppColors.darkBadgeAmberBg  : AppColors.badgeAmberBg;
        iconFg = isDark ? AppColors.darkBadgeAmberTxt : AppColors.badgeAmberTxt;
        break;
      default:
        icon   = Icons.notifications_outlined;
        iconBg = isDark ? AppColors.darkBgCard        : AppColors.bgCard;
        iconFg = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    }

    return InkWell(
      onTap: () {
        if (notif.type == NotifType.message &&
            notif.chatEmail != null &&
            notif.chatName  != null) {
          debugPrint('[NotifTile] Opening chat — chatEmail=${notif.chatEmail} chatName=${notif.chatName}');
          // Remove only this notification
          notifPr.remove(notif.id);
          // Navigate to chat — history loads automatically in ChatScreen
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ChatScreen(
              otherEmail: notif.chatEmail!,
              otherName:  notif.chatName!,
            ),
          ));
        } else {
          notifPr.markRead(notif.id);
        }
      },
      child: Container(
        color: notif.isRead
            ? Colors.transparent
            : (isDark
            ? AppColors.darkAccent.withOpacity(0.06)
            : AppColors.accent.withOpacity(0.05)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 40, height: 40,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20, color: iconFg)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(notif.title,
                  style: GoogleFonts.dmSans(fontSize: 13,
                      fontWeight: notif.isRead ? FontWeight.w400 : FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary))),
              if (!notif.isRead)
                Container(width: 8, height: 8,
                    decoration: BoxDecoration(
                        color: isDark ? AppColors.darkAccent : AppColors.accent,
                        shape: BoxShape.circle)),
            ]),
            const SizedBox(height: 2),
            Text(notif.body, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(_formatTime(notif.time),
                style: GoogleFonts.dmSans(fontSize: 11,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
          ])),
        ]),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    if (diff.inDays    <  7) return '${diff.inDays}d ago';
    return '${t.day}/${t.month}/${t.year}';
  }
}