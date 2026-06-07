import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:signalr_netcore/signalr_client.dart';

const String _hubUrl = 'http://192.168.1.6:5098/hubs/chat';
const String _base   = 'http://192.168.1.6:5098/api';

// ════════════════════════════════════════════════════════════════
// CHAT MESSAGE MODEL
// ════════════════════════════════════════════════════════════════
class ChatMessage {
  final int      id;
  final String   senderEmail;
  final String   senderName;
  final String   receiverEmail;
  final String   content;
  final DateTime sentAt;
  final bool     isMine;

  const ChatMessage({
    required this.id, required this.senderEmail, required this.senderName,
    required this.receiverEmail, required this.content,
    required this.sentAt, required this.isMine,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j, String myEmail) => ChatMessage(
    id:            j['id']            as int?    ?? 0,
    senderEmail:   j['senderEmail']   as String? ?? '',
    senderName:    j['senderName']    as String? ?? '',
    receiverEmail: j['receiverEmail'] as String? ?? '',
    content:       j['content']       as String? ?? '',
    sentAt:        DateTime.tryParse(j['sentAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    isMine:        (j['isMine'] as bool?) ?? ((j['senderEmail'] as String?) == myEmail),
  );
}

class ConversationSummary {
  final String otherEmail, otherName, lastMessage;
  final DateTime lastSentAt;
  final int unreadCount;
  const ConversationSummary({required this.otherEmail, required this.otherName,
    required this.lastMessage, required this.lastSentAt, required this.unreadCount});
  factory ConversationSummary.fromJson(Map<String, dynamic> j) => ConversationSummary(
    otherEmail:  j['otherEmail']  as String? ?? '',
    otherName:   j['otherName']   as String? ?? '',
    lastMessage: j['lastMessage'] as String? ?? '',
    lastSentAt:  DateTime.tryParse(j['lastSentAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    unreadCount: j['unreadCount'] as int? ?? 0,
  );
}

// ════════════════════════════════════════════════════════════════
// CHAT SERVICE
// ════════════════════════════════════════════════════════════════
class ChatService {
  String? _token;
  String? _myEmail;
  HubConnection? _hub;

  // Broadcast stream — all screens listen to this
  final _msgCtrl = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get messageStream => _msgCtrl.stream;

  bool get isConnected => _hub?.state == HubConnectionState.Connected;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // ── Connect / reconnect ───────────────────────────────────────
  Future<void> connect(String token, String myEmail) async {
    // Always update credentials
    _token   = token;
    _myEmail = myEmail;

    // If token changed (re-login), disconnect first
    if (isConnected && _hub != null) return;

    _hub = HubConnectionBuilder()
        .withUrl(_hubUrl, options: HttpConnectionOptions(
        accessTokenFactory: () async => token))
        .withAutomaticReconnect()
        .build();

    // Push every incoming SignalR message onto the broadcast stream
    _hub!.on('ReceiveMessage', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final data = args[0] as Map<String, dynamic>;
        final msg  = ChatMessage.fromJson(data, _myEmail ?? '');
        if (!_msgCtrl.isClosed) _msgCtrl.add(msg);
      } catch (_) {}
    });

    try {
      await _hub!.start();
    } catch (e) {
      // Connection failed — will retry via withAutomaticReconnect
    }
  }

  Future<void> sendMessage(String receiverEmail, String content) async {
    if (!isConnected) return;
    await _hub!.invoke('SendMessage', args: [receiverEmail, content]);
  }

  Future<void> disconnect() async {
    await _hub?.stop();
    _hub   = null;
    _token = null;
  }

  // Ensure myEmail is set even if already connected
  void ensureEmail(String email) {
    _myEmail = email;
  }

  // ── REST: conversation history ────────────────────────────────
  // Returns messages sorted oldest first — backend already handles isMine
  Future<List<ChatMessage>> getHistory(String otherEmail) async {
    if (_myEmail == null || _token == null) return [];
    return getHistoryWithToken(otherEmail, _token!, _myEmail!);
  }

  // Explicit token/email version — safe to call before connect()
  Future<List<ChatMessage>> getHistoryWithToken(
      String otherEmail, String token, String myEmail) async {
    try {
      final encoded = Uri.encodeComponent(otherEmail);
      final res = await http.get(
        Uri.parse('$_base/chat/history/$encoded'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final list = jsonDecode(res.body) as List;
        return list.map((j) =>
            ChatMessage.fromJson(j as Map<String, dynamic>, myEmail)).toList();
      }
    } catch (_) {}
    return [];
  }

  // ── REST: conversations list ──────────────────────────────────
  Future<List<ConversationSummary>> getConversations() async {
    if (_token == null) return [];
    try {
      final res = await http.get(
        Uri.parse('$_base/chat/conversations'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return (jsonDecode(res.body) as List)
            .map((j) => ConversationSummary.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  void dispose() {
    _msgCtrl.close();
    _hub?.stop();
  }
}

final chatService = ChatService();
