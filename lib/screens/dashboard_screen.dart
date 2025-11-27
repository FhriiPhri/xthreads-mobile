import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';

import 'package:xthreads_mobile/screens/login_screen.dart';
import 'package:xthreads_mobile/screens/profile_screen.dart';
import 'package:xthreads_mobile/services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _threadController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  int _charCount = 0;
  bool _isPosting = false;
  bool _isLoadingTimeline = true;
  List<dynamic> _timeline = [];
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _loadUserProfile();
    _loadTimeline();
  }

  // Fungsi baru untuk mengambil data profil user
  Future<void> _loadUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse(ApiService.baseUrl + '/auth/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _currentUser = data['data']['user'];
        });
      }
    } catch (e) {
      // Silent fail - akan tetap menggunakan widget.user
    }
  }

  // Helper untuk mendapatkan URL foto profil lengkap
  String _getProfilePhotoUrl(String? photo) {
    if (photo == null || photo.isEmpty) return '';
    return photo;
  }

  // Navigate ke profile page
  void _navigateToProfile(String username) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfilePage(username: username)),
    );
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.post(
        Uri.parse(ApiService.baseUrl + '/auth/logout'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        await prefs.remove('auth_token');

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        throw Exception('Failed to logout');
      }
    } catch (e) {
      _showSnackbar('Error logging out: ${e.toString()}');
    }
  }

  Future<void> _loadTimeline() async {
    setState(() => _isLoadingTimeline = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse(ApiService.baseUrl + '/threads'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        setState(
          () => _timeline = jsonDecode(response.body)['data']['timeline'],
        );
      } else {
        throw Exception('Failed to load timeline');
      }
    } catch (e) {
      _showSnackbar('Error loading timeline: ${e.toString()}');
    } finally {
      setState(() => _isLoadingTimeline = false);
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

  Future<void> _postThread() async {
    if (_threadController.text.isEmpty && _selectedImage == null) {
      _showSnackbar('Please enter text or select an image');
      return;
    }

    setState(() => _isPosting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiService.baseUrl + '/threads'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['content'] = _threadController.text;

      if (_selectedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', _selectedImage!.path),
        );
      }

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 201) {
        _threadController.clear();
        setState(() {
          _selectedImage = null;
          _charCount = 0;
        });
        await _loadTimeline();
        _showSnackbar('Thread posted successfully!');
      } else {
        throw jsonDecode(responseData)['message'] ?? 'Failed to post thread';
      }
    } catch (e) {
      _showSnackbar('Error posting thread: ${e.toString()}');
    } finally {
      setState(() => _isPosting = false);
    }
  }

  // Tambahan: ambil semua repost untuk thread dan tampilkan di bottom sheet
  Future<void> _fetchAndShowReposts(dynamic threadId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/threads/$threadId/reposts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reposts = data['data'] ?? [];

        // Debug: lihat struktur response
        print('Reposts Response: $reposts');

        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF0B1220),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (context) {
            return SizedBox(
              height: 400,
              child: reposts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'No reposts yet',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: reposts.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Colors.grey),
                      itemBuilder: (context, index) {
                        final r = reposts[index];

                        // Debug print setiap item
                        print('Repost item $index: $r');

                        // Coba cari user dari berbagai struktur kemungkinan
                        String username = 'Unknown';
                        if (r is Map<String, dynamic>) {
                          // Kemungkinan 1: nested user object
                          if (r['user'] is Map &&
                              r['user']['username'] != null) {
                            username = r['user']['username'];
                          }
                          // Kemungkinan 2: reposted_by object
                          else if (r['reposted_by'] is Map &&
                              r['reposted_by']['username'] != null) {
                            username = r['reposted_by']['username'];
                          }
                          // Kemungkinan 3: direct username field
                          else if (r['username'] != null) {
                            username = r['username'];
                          }
                        }

                        final createdAt = (r['created_at'] ?? '').toString();

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF6366F1),
                            child: Text(
                              username.isNotEmpty
                                  ? username[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            username,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            createdAt.isNotEmpty ? _formatTime(createdAt) : '',
                            style: const TextStyle(color: Color(0xFF9CA3AF)),
                          ),
                        );
                      },
                    ),
            );
          },
        );
      } else {
        throw Exception('Failed to fetch reposts');
      }
    } catch (e) {
      _showSnackbar('Error fetching reposts: ${e.toString()}');
    }
  }

  // Tambahan: toggle repost (post/delete) lalu reload timeline
  Future<void> _toggleRepost(dynamic threadId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/threads/$threadId/toggle-repost'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        await _loadTimeline();
        _showSnackbar('Repost updated');
      } else {
        final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        throw Exception(body['message'] ?? 'Failed to toggle repost');
      }
    } catch (e) {
      _showSnackbar('Error toggling repost: ${e.toString()}');
    }
  }

  // Tambahan: toggle like (post/delete) lalu reload timeline
  Future<void> _toggleLike(dynamic threadId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      // Menggunakan endpoint toggle-like untuk efisiensi
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/threads/$threadId/toggle-like'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Setelah berhasil, muat ulang timeline untuk memperbarui UI
        await _loadTimeline();
        // Feedback ke pengguna (opsional, bisa dihilangkan)
        // _showSnackbar('Like status updated');
      } else {
        final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        throw Exception(body['message'] ?? 'Failed to toggle like');
      }
    } catch (e) {
      _showSnackbar('Error toggling like: ${e.toString()}');
    }
  }

  Widget _buildImageWidget(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return const SizedBox.shrink();

    return Image.network(
      imageUrl,
      width: double.infinity,
      height: 200,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          height: 200,
          color: const Color(0xFF374151),
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      height: 200,
      color: const Color(0xFF374151),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(height: 8),
            Text('Failed to load image', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  // Widget untuk menampilkan foto profil dengan navigation
  Widget _buildProfilePhoto(
    String? photoUrl,
    String username, {
    double radius = 20,
    VoidCallback? onTap,
  }) {
    final fullPhotoUrl = _getProfilePhotoUrl(photoUrl);

    Widget avatarWidget;

    if (fullPhotoUrl.isEmpty) {
      avatarWidget = CircleAvatar(
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
    } else {
      avatarWidget = CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF374151),
        child: ClipOval(
          child: Image.network(
            fullPhotoUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
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

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatarWidget);
    }

    return avatarWidget;
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

  @override
  Widget build(BuildContext context) {
    final currentUsername =
        _currentUser?['username'] ?? widget.user['username'];
    final currentPhoto = _currentUser?['photo_profile'];

    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadUserProfile();
          await _loadTimeline();
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Home',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _navigateToProfile(currentUsername),
                    child: Text(
                      'Welcome back, $currentUsername!',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF111827),
              pinned: true,
              floating: true,
              actions: [
                IconButton(
                  icon: _buildProfilePhoto(
                    currentPhoto,
                    currentUsername,
                    radius: 16,
                  ),
                  onPressed: () => _navigateToProfile(currentUsername),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: _logout,
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF374151).withOpacity(0.5),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfilePhoto(
                          currentPhoto,
                          currentUsername,
                          onTap: () => _navigateToProfile(currentUsername),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _threadController,
                            maxLines: 3,
                            maxLength: 280,
                            onChanged: (value) =>
                                setState(() => _charCount = value.length),
                            decoration: const InputDecoration(
                              hintText: "What's happening?",
                              hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedImage != null)
                      Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 12),
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
                                height: 200,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 20,
                            right: 20,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedImage = null),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: _pickImage,
                              icon: const Icon(
                                Icons.image,
                                color: Color(0xFF818CF8),
                                size: 24,
                              ),
                            ),
                            Text(
                              '$_charCount/280',
                              style: TextStyle(
                                color: _charCount > 280
                                    ? const Color(0xFFF87171)
                                    : const Color(0xFF9CA3AF),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed:
                              _isPosting ||
                                  (_threadController.text.isEmpty &&
                                      _selectedImage == null)
                              ? null
                              : _postThread,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                          ),
                          child: _isPosting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Post',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoadingTimeline)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_timeline.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline,
                        color: Color(0xFF818CF8),
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No threads yet',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Be the first to post something!',
                        style: TextStyle(color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = _timeline[index];
                  final isRepost = item['type'] == 'repost';
                  final thread = isRepost ? item : item;
                  final user = isRepost ? item['original_user'] : item['user'];

                  return Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2937).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF374151).withOpacity(0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isRepost)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.repeat,
                                  color: Color(0xFF818CF8),
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${item['reposted_by']['username']} reposted',
                                  style: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildProfilePhoto(
                              user['photo_profile'],
                              user['username'],
                              radius: 24,
                              onTap: () => _navigateToProfile(user['username']),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => _navigateToProfile(
                                          user['username'],
                                        ),
                                        child: Text(
                                          user['username'],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: () => _navigateToProfile(
                                          user['username'],
                                        ),
                                        child: Text(
                                          '@${user['username']}',
                                          style: const TextStyle(
                                            color: Color(0xFF9CA3AF),
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _formatTime(thread['created_at']),
                                        style: const TextStyle(
                                          color: Color(0xFF9CA3AF),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    thread['content'],
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  if (thread['image'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: _buildImageWidget(
                                          thread['image'],
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildActionButton(
                                        Icons.chat_bubble_outline,
                                        thread['replies_count'].toString(),
                                      ),
                                      // Ganti tombol repost supaya bisa tap untuk fetch dan longPress untuk toggle
                                      GestureDetector(
                                        onTap: () =>
                                            _toggleRepost(thread['id']),
                                        onLongPress: () =>
                                            _fetchAndShowReposts(thread['id']),
                                        child: _buildActionButton(
                                          Icons.repeat,
                                          (thread['reposts_count'] ?? 0)
                                              .toString(),
                                          color:
                                              (thread['is_reposted'] ??
                                                  thread['reposted_by_me'] ??
                                                  false)
                                              ? const Color(0xFF10B981)
                                              : null,
                                        ),
                                      ),

                                      // Aksi Like/Favorite
                                      GestureDetector(
                                        onTap: () => _toggleLike(thread['id']),
                                        child: _buildActionButton(
                                          thread['is_liked'] ==
                                                  true // Menggunakan == true lebih eksplisit untuk boolean
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          thread['likes_count'].toString(),
                                          color: thread['is_liked'] == true
                                              ? const Color(0xFFEC4899)
                                              : null,
                                        ),
                                      ),

                                      _buildActionButton(Icons.share, ''),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }, childCount: _timeline.length),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String count, {Color? color}) {
    return Row(
      children: [
        Icon(icon, color: color ?? const Color(0xFF9CA3AF), size: 20),
        if (count.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(
            count,
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
          ),
        ],
      ],
    );
  }
}
