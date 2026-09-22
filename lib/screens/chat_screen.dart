import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';
import '../config/app_config.dart';
import '../services/websocket_service.dart';
import '../services/api_service.dart';
import '../services/chat_unread_service.dart';
import '../services/chat_notification_service.dart';

/// Real-time Chat Screen - InDrive style
class ChatScreen extends StatefulWidget {
  final String orderId;
  final String otherUserName;
  final String otherUserRole; // 'rider' or 'customer'
  final String currentUserRole; // 'rider' or 'customer'

  const ChatScreen({
    super.key,
    required this.orderId,
    required this.otherUserName,
    required this.otherUserRole,
    required this.currentUserRole,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isUploading = false;
  StreamSubscription? _messageSub;
  StreamSubscription? _typingSub;
  DateTime? _lastTypingSent;

  @override
  void initState() {
    super.initState();
    // Chat messages are broadcast to the `order:{orderId}` room. Other
    // screens (map/track) usually join it via watchOrder(), but chat can
    // be opened on its own, so make sure this socket is in the room too —
    // joining twice is harmless.
    WebSocketService.instance.watchOrder(widget.orderId);
    // While this chat is open its messages are seen — no unread badge.
    ChatUnreadService.instance.setActiveOrder(widget.orderId);
    ChatUnreadService.instance.markOrderRead(widget.orderId);
    // Pause background chat notifications while the chat is on screen;
    // they resume (and keep working with the app closed) when it closes.
    ChatNotificationService.startWatch(widget.orderId, widget.currentUserRole);
    _loadMessages();
    _listenToMessages();
  }

  @override
  void dispose() {
    ChatUnreadService.instance.setActiveOrder(null);
    ChatNotificationService.stopWatch(widget.orderId, widget.currentUserRole);
    _messageController.dispose();
    _scrollController.dispose();
    _messageSub?.cancel();
    _typingSub?.cancel();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final history = await ApiService.getChatHistory(widget.orderId);
      if (!mounted) return;
      setState(() {
        _messages.addAll(history.map((m) => ChatMessage(
              id: (m['id'] ?? '').toString(),
              message: (m['message'] ?? '').toString(),
              senderRole: (m['senderRole'] ?? 'customer').toString(),
              imageUrl: (m['imageUrl'] ?? '').toString().isEmpty
                  ? null
                  : (m['imageUrl'] as String),
              timestamp: DateTime.tryParse((m['createdAt'] ?? '').toString()) ?? DateTime.now(),
              isSent: true,
              isConfirmed: true,
            )));
      });
      _scrollToBottom();
    } catch (e) {
      print('Error loading messages: $e');
    }
  }

  /// Pick an image from gallery/camera, upload it, then send as a message.
  Future<void> _sendImage() async {
    if (_isUploading) return;

    // Gallery ya camera — modal se choice
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Send Photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ImageSourceTile(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ImageSourceTile(
                      icon: Icons.photo_camera_rounded,
                      label: 'Camera',
                      onTap: () => Navigator.pop(ctx, ImageSource.camera),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (picked == null) return;

      setState(() => _isUploading = true);

      // Upload to server first — returns a public URL
      final url = await ApiService.uploadImage(picked.path, type: 'chat');

      if (!mounted) return;
      setState(() => _isUploading = false);

      // Send as a chat message carrying the imageUrl
      if (WebSocketService.instance.isConnected) {
        WebSocketService.instance.sendChatMessage(
          orderId: widget.orderId,
          message: '',
          senderRole: widget.currentUserRole,
          imageUrl: url,
        );
        // Optimistic bubble (confirmed when the server echo arrives)
        setState(() {
          _messages.add(ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            message: '',
            senderRole: widget.currentUserRole,
            imageUrl: url,
            timestamp: DateTime.now(),
            isSent: true,
            isConfirmed: false,
          ));
        });
        _scrollToBottom();
      } else {
        // REST fallback
        await ApiService.sendChatMessage(
          orderId: widget.orderId,
          message: '',
          senderRole: widget.currentUserRole,
          imageUrl: url,
        );
        setState(() {
          _messages.add(ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            message: '',
            senderRole: widget.currentUserRole,
            imageUrl: url,
            timestamp: DateTime.now(),
            isSent: true,
            isConfirmed: true,
          ));
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  /// Resolve a server-relative /uploads/... URL against the API origin.
  String _resolveImageUrl(String url) {
    if (url.startsWith('http')) return url;
    return '${AppConfig.wsBaseUrl}$url';
  }

  void _listenToMessages() {
    // Listen for real-time messages via WebSocket
    _messageSub = WebSocketService.instance.chatMessageStream.listen((data) {
      if (data['orderId'] != widget.orderId) return;

      // The server broadcasts to the whole room (including us). If this is
      // the echo of our own send, merge server data (real id/timestamp)
      // into the optimistic bubble instead of adding a duplicate.
      final senderRole = (data['senderRole'] ?? '').toString();
      final serverId = (data['id'] ?? '').toString();
      if (senderRole == widget.currentUserRole) {
        final idx = _messages.indexWhere(
          (m) => !m.isConfirmed && m.message == (data['message'] ?? ''),
        );
        // Image messages: match by pending image URL instead of text
        final imgIdx = _messages.indexWhere(
          (m) => !m.isConfirmed && m.imageUrl != null,
        );
        final matchIdx = idx != -1 ? idx : imgIdx;
        if (matchIdx != -1) {
          setState(() {
            _messages[matchIdx] = _messages[matchIdx].copyWith(
              isSent: true,
              isConfirmed: true,
              id: serverId.isNotEmpty ? serverId : _messages[matchIdx].id,
              timestamp: DateTime.tryParse((data['createdAt'] ?? '').toString()) ??
                  _messages[matchIdx].timestamp,
            );
          });
          return;
        }
      }

      setState(() {
        _messages.add(ChatMessage(
          id: serverId.isNotEmpty
              ? serverId
              : DateTime.now().millisecondsSinceEpoch.toString(),
          message: (data['message'] ?? '').toString(),
          senderRole: senderRole.isEmpty ? 'customer' : senderRole,
          senderName: (data['senderName'] ?? '').toString(),
          imageUrl: (data['imageUrl'] ?? '').toString().isEmpty
              ? null
              : (data['imageUrl'] as String),
          timestamp:
              DateTime.tryParse((data['createdAt'] ?? '').toString()) ??
                  DateTime.now(),
          isSent: true,
          isConfirmed: true,
        ));
      });
      _scrollToBottom();
    });

    // Real typing indicator from the other side
    _typingSub = WebSocketService.instance.chatTypingStream.listen((data) {
      if (data['orderId'] != widget.orderId) return;
      if ((data['senderRole'] ?? '') == widget.currentUserRole) return;
      setState(() => _isTyping = data['isTyping'] == true);
      if (data['isTyping'] == true) {
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _isTyping = false);
        });
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final tempMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: text,
      senderRole: widget.currentUserRole,
      timestamp: DateTime.now(),
      isSent: false,
      isConfirmed: false,
    );

    setState(() {
      _messages.add(tempMessage);
      _messageController.clear();
    });
    _scrollToBottom();

    try {
      // Send via WebSocket (server persists + broadcasts to the room).
      // Fallback: REST endpoint if the socket is disconnected.
      if (WebSocketService.instance.isConnected) {
        WebSocketService.instance.sendChatMessage(
          orderId: widget.orderId,
          message: text,
          senderRole: widget.currentUserRole,
        );
      } else {
        await ApiService.sendChatMessage(
          orderId: widget.orderId,
          message: text,
          senderRole: widget.currentUserRole,
        );
        setState(() {
          final index = _messages.indexWhere((m) => m.id == tempMessage.id);
          if (index != -1) _messages[index] = _messages[index].copyWith(isSent: true);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(16, statusBarHeight + 12, 16, 12),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(color: AppColors.orange.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                // Avatar
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(
                    widget.otherUserRole == 'rider' ? Icons.delivery_dining : Icons.person,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.otherUserName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.otherUserRole == 'rider' ? 'Your Delivery Partner' : 'Customer',
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
                // Call button
                GestureDetector(
                  onTap: () {
                    // Implement call functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('📞 Calling...'), backgroundColor: AppColors.orange),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.phone, color: AppColors.orange, size: 22),
                  ),
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isTyping) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),

          // Input area
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, keyboardHeight > 0 ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Attach photo button
                  GestureDetector(
                    onTap: _isUploading ? null : _sendImage,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.orangePale,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.orange,
                              ),
                            )
                          : const Icon(Icons.add_photo_alternate_rounded,
                              color: AppColors.orange, size: 22),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Quick replies button
                  GestureDetector(
                    onTap: _showQuickReplies,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.orangePale,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.bolt_rounded, color: AppColors.orange, size: 22),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Text input
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(fontSize: 14, color: AppColors.darkGray),
                        ),
                        maxLines: 4,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendMessage(),
                        onChanged: (text) {
                          // Typing indicator (throttled)
                          if (text.trim().isEmpty) return;
                          final now = DateTime.now();
                          if (_lastTypingSent == null ||
                              now.difference(_lastTypingSent!) >
                                  const Duration(seconds: 2)) {
                            _lastTypingSent = now;
                            WebSocketService.instance.sendChatTyping(
                              orderId: widget.orderId,
                              senderRole: widget.currentUserRole,
                              isTyping: true,
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Send button
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isMe = message.senderRole == widget.currentUserRole;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.otherUserRole == 'rider' ? Icons.delivery_dining : Icons.person,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isMe ? AppColors.primaryGradient : null,
                    color: isMe ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isMe
                            ? AppColors.orange.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.imageUrl != null) ...[
                        // Attached image — tappable full-screen viewer
                        GestureDetector(
                          onTap: () => _openImageViewer(_resolveImageUrl(message.imageUrl!)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220, maxHeight: 260),
                              child: Image.network(
                                _resolveImageUrl(message.imageUrl!),
                                fit: BoxFit.cover,
                                loadingBuilder: (ctx, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    width: 180,
                                    height: 140,
                                    color: Colors.grey.shade200,
                                    child: const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  );
                                },
                                errorBuilder: (ctx, _, __) => Container(
                                  width: 180,
                                  height: 100,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image_rounded,
                                      color: Colors.grey, size: 36),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (message.message.trim().isNotEmpty) const SizedBox(height: 6),
                      ],
                      if (message.message.trim().isNotEmpty)
                        Text(
                          message.message,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            color: isMe ? Colors.white : Colors.black87,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.timestamp),
                      style: const TextStyle(fontSize: 11, color: AppColors.darkGray),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.isConfirmed
                            ? Icons.done_all
                            : (message.isSent ? Icons.done_all : Icons.access_time),
                        size: 14,
                        color: message.isConfirmed
                            ? Colors.blue
                            : (message.isSent ? AppColors.orange : AppColors.darkGray),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// Full-screen image viewer with pinch-zoom
  void _openImageViewer(String url) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: Scaffold(
            backgroundColor: Colors.black.withValues(alpha: 0.95),
            body: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    maxScale: 4,
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_rounded, size: 48, color: Colors.white54),
                          SizedBox(height: 12),
                          Text('Image unavailable', style: TextStyle(color: Colors.white54, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircleAvatar(
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.otherUserRole == 'rider' ? Icons.delivery_dining : Icons.person,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) => Padding(
                padding: EdgeInsets.only(left: index > 0 ? 4 : 0),
                child: _TypingDot(delay: index * 200),
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline, size: 36, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'Start a conversation',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.black),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to ${widget.otherUserName}',
            style: const TextStyle(fontSize: 14, color: AppColors.darkGray),
          ),
        ],
      ),
    );
  }

  void _showQuickReplies() {
    final replies = widget.currentUserRole == 'rider'
        ? [
            '👋 Hello! I\'m on my way',
            '⏱️ I\'ll be there in 5 minutes',
            '📍 I\'m at the pickup location',
            '✅ Order picked up, heading to you now',
            '🚪 I\'m outside',
            '👍 Thank you!',
          ]
        : [
            '👋 Hello',
            '⏱️ How long will it take?',
            '📍 Can you see my location?',
            '🚪 Please ring the doorbell',
            '📞 Please call me when you arrive',
            '👍 Thank you!',
          ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Quick Replies',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            ...replies.map((reply) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _messageController.text = reply;
                  _sendMessage();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.orangePale.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.orange.withValues(alpha: 0.2)),
                  ),
                  child: Text(reply, style: const TextStyle(fontSize: 14)),
                ),
              ),
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class ChatMessage {
  final String id;
  final String message;
  final String senderRole;
  final String senderName;
  final DateTime timestamp;
  final bool isSent;

  /// Optional attached image (server or absolute URL)
  final String? imageUrl;

  /// False while the send is in flight (pending clock icon);
  /// true once the server echo confirms delivery.
  final bool isConfirmed;

  ChatMessage({
    required this.id,
    required this.message,
    required this.senderRole,
    required this.timestamp,
    required this.isSent,
    this.senderName = '',
    this.isConfirmed = false,
    this.imageUrl,
  });

  ChatMessage copyWith({
    bool? isSent,
    bool? isConfirmed,
    String? id,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      message: message,
      senderRole: senderRole,
      senderName: senderName,
      imageUrl: imageUrl,
      timestamp: timestamp ?? this.timestamp,
      isSent: isSent ?? this.isSent,
      isConfirmed: isConfirmed ?? this.isConfirmed,
    );
  }
}

class _ImageSourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImageSourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.orangePale.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.orange, size: 32),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.orange,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
