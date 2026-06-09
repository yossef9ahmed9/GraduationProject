import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/services/api_service.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/services/chat_service.dart';
import 'package:meditrack/services/notification_provider.dart';
import 'package:meditrack/theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final String otherEmail;
  final String otherName;

  const ChatScreen({super.key, required this.otherEmail, required this.otherName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_Msg> _messages = [];
  final Set<int> _seenIds = {};
  StreamSubscription<ChatMessage>? _sub;
  bool _loading = true;
  String _myEmail = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final auth  = context.read<AuthProvider>();
    _myEmail    = auth.user?.email ?? '';
    final token = auth.user?.token ?? '';

    // Always connect with the correct token and email
    await chatService.connect(token, _myEmail);

    // Load history using the auth token directly
    final history = await chatService.getHistoryWithToken(widget.otherEmail, token, _myEmail);
    if (!mounted) return;

    debugPrint('[ChatScreen] myEmail=$_myEmail otherEmail=${widget.otherEmail} history=${history.length} msgs token=${token.substring(0, 20)}...');
    for (final m in history) {
      debugPrint('[ChatScreen] msg: sender=${m.senderEmail} isMine=${m.senderEmail == _myEmail} content=${m.content}');
    }

    for (final m in history) {
      if (m.id != 0) _seenIds.add(m.id);
      _messages.add(_Msg(
        id:          m.id,
        content:     m.content,
        isMine:      m.senderEmail == _myEmail,
        sentAt:      m.sentAt,
        senderName:  m.senderName,
        senderEmail: m.senderEmail,
      ));
    }
    setState(() => _loading = false);
    _scrollToBottom();

    // Listen to real-time messages
    _sub = chatService.messageStream.listen((msg) {
      // Only care about messages in this conversation
      final mine  = msg.senderEmail == _myEmail && msg.receiverEmail == widget.otherEmail;
      final theirs = msg.senderEmail == widget.otherEmail && msg.receiverEmail == _myEmail;
      if (!mine && !theirs) return;

      // Dedup by server-assigned ID
      if (msg.id != 0 && _seenIds.contains(msg.id)) return;
      if (msg.id != 0) _seenIds.add(msg.id);

      if (mine) {
        // Replace the matching optimistic bubble
        final idx = _messages.lastIndexWhere(
                (m) => m.id == 0 && m.isMine && m.content == msg.content);
        if (idx != -1) {
          setState(() => _messages[idx] = _Msg.fromChat(msg, _myEmail));
          return;
        }
      }

      setState(() => _messages.add(_Msg.fromChat(msg, _myEmail)));
      _scrollToBottom();
    });

    // Dismiss any notifications from this person
    if (mounted) {
      context.read<NotificationProvider>().dismissMessagesFrom(widget.otherEmail);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _reloadHistory() async {
    final auth  = context.read<AuthProvider>();
    final token = auth.user?.token ?? '';
    final history = await chatService.getHistoryWithToken(widget.otherEmail, token, _myEmail);
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _seenIds.clear();
      for (final m in history) {
        if (m.id != 0) _seenIds.add(m.id);
        _messages.add(_Msg.fromChat(m, _myEmail));
      }
    });
    _scrollToBottom();
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    // Optimistic bubble
    setState(() => _messages.add(_Msg(
      id: 0, content: text, isMine: true, sentAt: DateTime.now(),
      senderName: '', senderEmail: _myEmail,
    )));
    _scrollToBottom();
    await chatService.sendMessage(widget.otherEmail, text);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isDark ? AppColors.darkAccentMuted : AppColors.accentMuted,
            child: Text(
              widget.otherName.isNotEmpty ? widget.otherName[0].toUpperCase() : '?',
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkAccent : AppColors.accent),
            ),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.otherName,
                style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600)),
            Text(
              chatService.isConnected ? 'Online' : 'Connecting…',
              style: GoogleFonts.dmSans(fontSize: 11,
                  color: chatService.isConnected
                      ? (isDark ? AppColors.darkBadgeGreenTxt : AppColors.badgeGreenTxt)
                      : (isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
            ),
          ]),
        ]),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) async {
              if (value == 'clear') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Clear conversation'),
                    content: const Text('Clear all messages on your side only?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true),
                          child: const Text('Clear', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  await apiService.clearConversation(widget.otherEmail);
                  setState(() => _messages.clear());
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(children: [
                  Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Clear conversation', style: TextStyle(color: Colors.red)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
              ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 48,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
                const SizedBox(height: 12),
                Text('Say hello!', style: GoogleFonts.dmSans(fontSize: 15,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
              ]))
              : ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            itemCount: _messages.length,
            itemBuilder: (_, i) {
              final msg = _messages[i];
              return _BubbleWidget(
                msg: msg,
                onDeleteForMe: msg.isMine && msg.id != 0
                    ? () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete for me'),
                            content: const Text('Hide this message only for you?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.orange))),
                            ],
                          ),
                        );
                        if (confirm == true && mounted) {
                          final res = await apiService.deleteMessage(msg.id);
                          if (res.ok && mounted) {
                            setState(() => _messages.removeWhere((m) => m.id == msg.id));
                          }
                        }
                      }
                    : null,
                onDeleteForEveryone: msg.isMine && msg.id != 0
                    ? () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete for everyone'),
                            content: const Text('Remove this message for both sides?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true && mounted) {
                          final res = await apiService.deleteMessageForEveryone(msg.id);
                          if (res.ok && mounted) {
                            await _reloadHistory();
                          }
                        }
                      }
                    : null,
              );
            },
          ),
        ),
        // Input bar
        Material(
          color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(
                    color: isDark ? AppColors.darkBorderColor : AppColors.borderColor)),
              ),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    minLines: 1, maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Type a message…',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F2F8),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: isDark ? AppColors.darkAccent : AppColors.accent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: _send,
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Internal message model (keeps isMine stable) ──────────────

class _Msg {
  final int      id;
  final String   content;
  final bool     isMine;
  final DateTime sentAt;
  final String   senderName;
  final String   senderEmail;

  const _Msg({
    required this.id, required this.content, required this.isMine,
    required this.sentAt, required this.senderName, required this.senderEmail,
  });

  // Build from REST response (isMine already set by server)
  factory _Msg.fromChat(ChatMessage m, String myEmail) => _Msg(
    id:          m.id,
    content:     m.content,
    isMine:      m.isMine || m.senderEmail == myEmail, // belt + suspenders
    sentAt:      m.sentAt,
    senderName:  m.senderName,
    senderEmail: m.senderEmail,
  );
}

// ── Bubble widget — WhatsApp / Messenger style ────────────────

class _BubbleWidget extends StatelessWidget {
  final _Msg msg;
  final VoidCallback? onDeleteForMe;
  final VoidCallback? onDeleteForEveryone;
  const _BubbleWidget({super.key, required this.msg, this.onDeleteForMe, this.onDeleteForEveryone});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMine = msg.isMine;
    final time   = '${msg.sentAt.hour.toString().padLeft(2,'0')}:'
        '${msg.sentAt.minute.toString().padLeft(2,'0')}';

    return GestureDetector(
      onLongPress: (onDeleteForMe != null || onDeleteForEveryone != null) ? () {
        showModalBottomSheet(
          context: context,
          builder: (_) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (onDeleteForMe != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.orange),
                  title: const Text('Delete for me'),
                  onTap: () { Navigator.pop(context); onDeleteForMe!(); },
                ),
              if (onDeleteForEveryone != null)
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                  title: const Text('Delete for everyone', style: TextStyle(color: Colors.red)),
                  onTap: () { Navigator.pop(context); onDeleteForEveryone!(); },
                ),
              ListTile(
                leading: const Icon(Icons.close_rounded),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ]),
          ),
        );
      } : null,
      child: Padding(
      // More space between messages from different people
      padding: EdgeInsets.only(
        top: 2, bottom: 2,
        left: isMine ? 60 : 0,   // mine pushed right
        right: isMine ? 0 : 60,  // theirs pushed left
      ),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for incoming messages
          if (!isMine) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: isDark ? AppColors.darkBadgeBlueBg : AppColors.badgeBlueBg,
              child: Text(
                msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : '?',
                style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkBadgeBlueTxt : AppColors.badgeBlueTxt),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // Bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: isMine
                    ? (isDark ? AppColors.darkAccent : AppColors.accent)
                    : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F2F8)),
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(18),
                  topRight:    const Radius.circular(18),
                  bottomLeft:  Radius.circular(isMine ? 18 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                    blurRadius: 4, offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender name for incoming (group chat feel)
                  if (!isMine && msg.senderName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(msg.senderName,
                          style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkAccent : AppColors.accent)),
                    ),

                  // Message text
                  Text(msg.content,
                      style: GoogleFonts.dmSans(fontSize: 14.5,
                          color: isMine ? Colors.white
                              : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary))),

                  // Time + status
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(time,
                          style: GoogleFonts.dmSans(fontSize: 10.5,
                              color: isMine ? Colors.white60
                                  : (isDark ? AppColors.darkTextTertiary : AppColors.textTertiary))),
                      if (isMine) ...[
                        const SizedBox(width: 3),
                        Icon(
                          msg.id == 0 ? Icons.access_time_rounded : Icons.done_all_rounded,
                          size: 13,
                          color: Colors.white60,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

      if (isMine) const SizedBox(width: 6),
        ],
      ),
      ),
    );
  }
}