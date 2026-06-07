import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:meditrack/services/chat_service.dart';

enum NotifType { message, emergency, dispatch, system }

class AppNotification {
  final String    id;
  final String    title;
  final String    body;
  final NotifType type;
  final DateTime  time;
  bool            isRead;
  final String?   chatEmail;
  final String?   chatName;

  AppNotification({
    required this.id, required this.title, required this.body,
    required this.type, required this.time,
    this.isRead = false, this.chatEmail, this.chatName,
  });
}

class NotificationProvider extends ChangeNotifier {
  final List<AppNotification> _notifications = [];
  String?   _myEmail;
  StreamSubscription<ChatMessage>? _sub;

  List<AppNotification> get all {
    final list = List<AppNotification>.from(_notifications);
    list.sort((a, b) => b.time.compareTo(a.time));
    return list;
  }

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void init(String myEmail) {
    _myEmail = myEmail;
    debugPrint('[NotifProvider] init called with myEmail=$myEmail');

    _sub?.cancel();
    _sub = chatService.messageStream.listen(_onMessage);
    debugPrint('[NotifProvider] subscribed to messageStream');
  }

  void _onMessage(ChatMessage msg) {
    debugPrint('[NotifProvider] _onMessage: from=${msg.senderEmail} to=${msg.receiverEmail} myEmail=$_myEmail content=${msg.content}');

    // Only notify about messages addressed TO me
    if (msg.receiverEmail != _myEmail) {
      debugPrint('[NotifProvider] SKIPPED — receiverEmail(${msg.receiverEmail}) != myEmail($_myEmail)');
      return;
    }
    if (msg.senderEmail == _myEmail) {
      debugPrint('[NotifProvider] SKIPPED — my own message');
      return;
    }

    final notifId = msg.id != 0
        ? 'msg_${msg.id}'
        : 'msg_${msg.senderEmail}_${msg.sentAt.millisecondsSinceEpoch}';

    if (_notifications.any((n) => n.id == notifId)) {
      debugPrint('[NotifProvider] SKIPPED — duplicate notifId=$notifId');
      return;
    }

    debugPrint('[NotifProvider] ADDING notification from ${msg.senderName}');
    add(AppNotification(
      id:        notifId,
      title:     msg.senderName.isNotEmpty ? msg.senderName : msg.senderEmail,
      body:      msg.content,
      type:      NotifType.message,
      time:      msg.sentAt,
      chatEmail: msg.senderEmail,
      chatName:  msg.senderName.isNotEmpty ? msg.senderName : msg.senderEmail,
    ));
  }

  void add(AppNotification notif) {
    _notifications.add(notif);
    notifyListeners();
  }

  void addEmergency(String patientName, String detail) {
    add(AppNotification(
      id:    'emg_${DateTime.now().millisecondsSinceEpoch}',
      title: '🚨 Emergency — $patientName',
      body:  detail,
      type:  NotifType.emergency,
      time:  DateTime.now(),
    ));
  }

  void addDispatch(String message) {
    add(AppNotification(
      id:   'dsp_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Ambulance Dispatch',
      body:  message,
      type:  NotifType.dispatch,
      time:  DateTime.now(),
    ));
  }

  // Called by FCM service when a push notification arrives
  void addFromFcm({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) {
    final type = switch (data['type'] as String?) {
      'emergency' => NotifType.emergency,
      'dispatch'  => NotifType.dispatch,
      'chat'      => NotifType.message,
      _           => NotifType.system,
    };

    // For chat notifications, senderEmail and senderName come from FCM data
    final senderEmail = data['senderEmail'] as String?;
    final senderName  = data['senderName']  as String? ?? title;

    debugPrint('[NotifProvider] addFromFcm: senderEmail=$senderEmail senderName=$senderName');

    add(AppNotification(
      id:        'fcm_${DateTime.now().millisecondsSinceEpoch}',
      title:     senderName,
      body:      body,
      type:      type,
      time:      DateTime.now(),
      chatEmail: senderEmail,
      chatName:  senderName,
    ));
  }

  void markRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) { _notifications[idx].isRead = true; notifyListeners(); }
  }

  void remove(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  void markAllRead() {
    for (final n in _notifications) n.isRead = true;
    notifyListeners();
  }

  void dismissMessagesFrom(String email) {
    bool changed = false;
    for (final n in _notifications) {
      if (n.type == NotifType.message && n.chatEmail == email && !n.isRead) {
        n.isRead = true;
        changed  = true;
      }
    }
    if (changed) notifyListeners();
  }

  void clear() { _notifications.clear(); notifyListeners(); }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}