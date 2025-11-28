import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'package:xthreads_mobile/services/api_service.dart';

class ThreadDetailScreen extends StatefulWidget {
  final Map<String, dynamic> thread;

  const ThreadDetailScreen({super.key, required this.thread});

  @override
  State<ThreadDetailScreen> createState() => _ThreadDetailScreenState();
}

class _ThreadDetailScreenState extends State<ThreadDetailScreen> {
  final TextEditingController _replyController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isPosting = false;
  bool _isLoadingReplies = true;
  List<dynamic> _replies = [];
  Map<String, dynamic>? _threadDetail;
  String? _replyingToUsername;
  int? _replyingToId;

  @override
  void initState() {
    super.initState();
    _loadThreadDetail();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadThreadDetail() async {
    setState(() => _isLoadingReplies = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/threads/${widget.thread['id']}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _threadDetail = data['data']['thread'];
          _replies = data['data']['replies'] ?? [];
        });
      } else {
        throw Exception('Failed to load thread detail');
      }
    } catch (e) {
      _showSnackbar('Error loading thread: ${e.toString()}');
    } finally {
      setState(() => _isLoadingReplies = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1440,
      );

      if (pickedFile != null) {
        setState(() => _selectedImage = File(pickedFile.path));
      }
    } catch (e) {
      _showSnackbar('Error selecting image: ${e.toString()}');
    }
  }

  Future<void> _postReply() async {
    if (_replyController.text.isEmpty && _selectedImage == null) {
      _showSnackbar('Please enter text or select an image');
      return;
    }

    setState(() => _isPosting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/threads'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['content'] = _replyController.text;
      request.fields['parent_thread_id'] = (_replyingToId ?? widget.thread['id']).toString();

      if (_selectedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', _selectedImage!.path),
        );
      }

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 201) {
        _replyController.clear();
        setState(() {
          _selectedImage = null;
          _replyingToUsername = null;
          _replyingToId = null;
        });
        await _loadThreadDetail();
        _showSnackbar('Reply posted successfully!');
      } else {
        throw jsonDecode(responseData)['message'] ?? 'Failed to post reply';
      }
    } catch (e) {
      _showSnackbar('Error posting reply: ${e.toString()}');
    } finally {
      setState(() => _isPosting = false);
    }
  }

  Future<void> _toggleLike(int threadId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/threads/$threadId/toggle-like'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        await _loadThreadDetail();
      }
    } catch (e) {
      _showSnackbar('Error toggling like: ${e.toString()}');
    }
  }

  // Navigate to reply detail (nested)
  void _navigateToReplyDetail(Map<String, dynamic> reply) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ThreadDetailScreen(thread: reply),
      ),
    ).then((_) => _loadThreadDetail());
  }

  Widget _buildProfilePhoto(String? photoUrl, String username, {double radius = 20}) {
    if (photoUrl == null || photoUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF6366F1),
        child: Text(
          username[0].toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.7,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF374151),
      child: ClipOval(
        child: Image.network(
          photoUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: const Color(0xFF6366F1),
              child: Center(
                child: Text(
                  username[0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: radius * 0.7,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildImageWidget(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 200,
            color: const Color(0xFF374151),
            child: const Center(
              child: Icon(Icons.error, color: Colors.red),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(String timeString) {
    final dateTime = DateTime.parse(timeString);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) return '${(difference.inDays / 365).floor()}y';
    if (difference.inDays > 30) return '${(difference.inDays / 30).floor()}mo';
    if (difference.inDays > 0) return '${difference.inDays}d';
    if (difference.inHours > 0) return '${difference.inHours}h';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m';
    return 'Just now';
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _setReplyingTo(String username, int threadId) {
    setState(() {
      _replyingToUsername = username;
      _replyingToId = threadId;
      _replyController.text = '@$username ';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: const Text(
          'Thread',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingReplies
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildThreadCard(_threadDetail ?? widget.thread, isMainThread: true),
                      
                      const SizedBox(height: 16),
                      
                      if (_replies.isNotEmpty)
                        const Divider(color: Color(0xFF374151), thickness: 1),
                      
                      if (_replies.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Replies (${_replies.length})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      
                      ..._replies.map((reply) => _buildReplyCard(reply)).toList(),
                    ],
                  ),
                ),
                
                _buildReplyInputBox(),
              ],
            ),
    );
  }

  Widget _buildThreadCard(Map<String, dynamic> thread, {bool isMainThread = false}) {
    final user = thread['user'];
    
    return Container(
      padding: EdgeInsets.all(isMainThread ? 20 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMainThread 
              ? const Color(0xFF6366F1).withOpacity(0.3)
              : const Color(0xFF374151).withOpacity(0.5),
          width: isMainThread ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildProfilePhoto(
                user['photo_profile'] ?? user['photo'],
                user['username'],
                radius: isMainThread ? 28 : 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['username'],
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isMainThread ? 18 : 16,
                      ),
                    ),
                    Text(
                      '@${user['username']}',
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatTime(thread['created_at']),
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            thread['content'],
            style: TextStyle(
              color: Colors.white,
              fontSize: isMainThread ? 16 : 15,
              height: 1.5,
            ),
          ),
          if (thread['image'] != null) ...[
            const SizedBox(height: 12),
            _buildImageWidget(thread['image']),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionButton(
                Icons.chat_bubble_outline,
                thread['replies_count']?.toString() ?? '0',
              ),
              _buildActionButton(
                Icons.repeat,
                thread['reposts_count']?.toString() ?? '0',
              ),
              _buildActionButton(
                thread['is_liked'] == true ? Icons.favorite : Icons.favorite_border,
                thread['likes_count']?.toString() ?? '0',
                color: thread['is_liked'] == true ? const Color(0xFFEC4899) : null,
                onTap: () => _toggleLike(thread['id']),
              ),
              _buildActionButton(Icons.share, ''),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyCard(Map<String, dynamic> reply) {
    final user = reply['user'];
    final repliesCount = reply['replies_count'] ?? 0;
    
    return GestureDetector(
      onTap: repliesCount > 0 ? () => _navigateToReplyDetail(reply) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937).withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF374151).withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildProfilePhoto(
                  user['photo_profile'],
                  user['username'],
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            user['username'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '@${user['username']}',
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatTime(reply['created_at']),
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              reply['content'],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (reply['image'] != null) ...[
              const SizedBox(height: 8),
              _buildImageWidget(reply['image']),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _buildActionButton(
                  Icons.chat_bubble_outline,
                  repliesCount > 0 ? repliesCount.toString() : '',
                  isSmall: true,
                  onTap: repliesCount > 0 
                      ? () => _navigateToReplyDetail(reply)
                      : () => _setReplyingTo(user['username'], reply['id']),
                ),
                const SizedBox(width: 24),
                _buildActionButton(
                  reply['is_liked'] == true ? Icons.favorite : Icons.favorite_border,
                  reply['likes_count']?.toString() ?? '0',
                  isSmall: true,
                  color: reply['is_liked'] == true ? const Color(0xFFEC4899) : null,
                  onTap: () => _toggleLike(reply['id']),
                ),
                if (repliesCount > 0) ...[
                  const SizedBox(width: 24),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Color(0xFF6366F1),
                    size: 14,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String count, {
    Color? color,
    bool isSmall = false,
    VoidCallback? onTap,
  }) {
    final widget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: color ?? const Color(0xFF9CA3AF),
          size: isSmall ? 16 : 20,
        ),
        if (count.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(
            count,
            style: TextStyle(
              color: const Color(0xFF9CA3AF),
              fontSize: isSmall ? 11 : 12,
            ),
          ),
        ],
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: widget,
      );
    }

    return widget;
  }

  Widget _buildReplyInputBox() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF374151).withOpacity(0.5),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingToUsername != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFF374151).withOpacity(0.3),
                child: Row(
                  children: [
                    const Icon(
                      Icons.reply,
                      color: Color(0xFF818CF8),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Replying to @$_replyingToUsername',
                        style: const TextStyle(
                          color: Color(0xFF818CF8),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      color: const Color(0xFF9CA3AF),
                      onPressed: () {
                        setState(() {
                          _replyingToUsername = null;
                          _replyingToId = null;
                          _replyController.clear();
                        });
                      },
                    ),
                  ],
                ),
              ),
            if (_selectedImage != null)
              Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.all(12),
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF374151).withOpacity(0.5),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _selectedImage!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    right: 20,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImage = null),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF374151).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFF4B5563).withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _replyController,
                              maxLines: null,
                              maxLength: 280,
                              decoration: const InputDecoration(
                                hintText: 'Write a reply...',
                                hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                                border: InputBorder.none,
                                counterText: '',
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.image,
                              color: Color(0xFF818CF8),
                              size: 22,
                            ),
                            onPressed: _pickImage,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: IconButton(
                      onPressed: _isPosting ||
                              (_replyController.text.isEmpty && _selectedImage == null)
                          ? null
                          : _postReply,
                      icon: _isPosting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}