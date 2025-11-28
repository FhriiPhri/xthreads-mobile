import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:xthreads_mobile/screens/edit-profile_screen.dart';
import 'package:xthreads_mobile/screens/followers_screen.dart';
import 'package:xthreads_mobile/services/api_service.dart';
// Import EditProfilePage - adjust path as needed
// import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  final String? username;
  final int? userId;

  const ProfilePage({Key? key, this.username, this.userId}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  static const String baseUrl = ApiService.baseUrl;

  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  List<dynamic> _allThreads = [];
  List<dynamic> _replies = [];
  List<dynamic> _media = [];
  List<dynamic> _likes = [];
  bool _isOwnProfile = false;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadUserData();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _loadUserData() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      final meResponse = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (meResponse.statusCode == 200) {
        final meData = jsonDecode(meResponse.body);

        final currentUsername =
            meData['data']?['user']?['username'] ??
            meData['user']?['username'] ??
            '';
        final currentUserId =
            meData['data']?['user']?['id'] ?? meData['user']?['id'];

        String targetIdentifier;
        if (widget.userId != null) {
          targetIdentifier = widget.userId.toString();
          _isOwnProfile = widget.userId == currentUserId;
        } else if (widget.username != null) {
          targetIdentifier = widget.username!;
          _isOwnProfile = widget.username == currentUsername;
        } else {
          targetIdentifier = currentUserId.toString();
          _isOwnProfile = true;
        }

        final profileResponse = await http.get(
          Uri.parse('$baseUrl/users/$targetIdentifier'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );

        if (profileResponse.statusCode == 200) {
          final profileData = jsonDecode(profileResponse.body);
          final timeline = profileData['data']?['timeline'] ?? [];

          setState(() {
            _userData = profileData['data']?['user'] ?? profileData['user'];
            _allThreads = List.from(timeline);

            // Filter for different tabs
            _replies = timeline.where((t) => t['type'] == 'reply').toList();
            _media = timeline.where((t) => t['image'] != null).toList();
            _likes = timeline.where((t) => t['is_liked'] == true).toList();

            _isFollowing = profileData['data']?['is_following'] ?? false;
            _isLoading = false;
          });
        } else {
          throw Exception('Gagal memuat profil');
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _followUser() async {
    if (_userData == null) return;

    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/users/${_userData!['username']}/follow'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _isFollowing = true;
          _userData!['followers_count'] =
              (_userData!['followers_count'] ?? 0) + 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _unfollowUser() async {
    if (_userData == null) return;

    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/users/${_userData!['username']}/follow'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _isFollowing = false;
          _userData!['followers_count'] =
              (_userData!['followers_count'] ?? 1) - 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _toggleLike(int threadId, int index, String tabType) async {
    try {
      final token = await _getToken();
      if (token == null) return;

      List<dynamic> targetList;
      switch (tabType) {
        case 'threads':
          targetList = _allThreads;
          break;
        case 'media':
          targetList = _media;
          break;
        case 'likes':
          targetList = _likes;
          break;
        default:
          return;
      }

      if (index >= targetList.length) return;

      final isLiked = targetList[index]['is_liked'] == true;
      final url = isLiked
          ? '$baseUrl/threads/$threadId/like'
          : '$baseUrl/threads/$threadId/like';

      final response = isLiked
          ? await http.delete(
              Uri.parse(url),
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
              },
            )
          : await http.post(
              Uri.parse(url),
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
              },
            );

      if (response.statusCode == 200) {
        setState(() {
          targetList[index]['is_liked'] = !isLiked;
          targetList[index]['likes_count'] =
              (targetList[index]['likes_count'] ?? 0) + (isLiked ? -1 : 1);
        });
      }
    } catch (e) {
      print('Error toggling like: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _userData == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F0F),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildProfileHeader(),
                const SizedBox(height: 16),
                _buildTabBar(),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildThreadsList(_allThreads, 'threads'),
            _buildThreadsList(_replies, 'replies'),
            _buildMediaGrid(_media),
            _buildThreadsList(_likes, 'likes'),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final username = _userData?['username'] ?? '';
    final threadsCount = _userData?['threads_count'] ?? 0;

    return SliverAppBar(
      backgroundColor: const Color(0xFF1A1A1A),
      expandedHeight: 60,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          _buildAvatar(32),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                username,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '$threadsCount threads',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final username = _userData?['username'] ?? 'U';
    final coverPhoto = _userData?['cover_photo'];
    final bio = _userData?['bio'];
    final location = _userData?['location'];
    final createdAt = _userData?['created_at'];
    final isModerator = _userData?['is_moderator'] ?? false;
    final followingCount = _userData?['following_count'] ?? 0;
    final followersCount = _userData?['followers_count'] ?? 0;
    final threadsCount = _userData?['threads_count'] ?? 0;
    final likesCount = _userData?['likes_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF374151).withOpacity(0.5)),
      ),
      child: Column(
        children: [
          // Cover Photo
          Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              gradient: coverPhoto == null
                  ? const LinearGradient(
                      colors: [
                        Color(0xFF3B82F6),
                        Color(0xFF8B5CF6),
                        Color(0xFFEC4899),
                      ],
                    )
                  : null,
            ),
            child: coverPhoto != null
                ? ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    child: Image.network(
                      coverPhoto,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  )
                : null,
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -40),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF1A1A1A),
                            width: 4,
                          ),
                        ),
                        child: Stack(
                          children: [
                            _buildAvatar(80),
                            if (isModerator)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEC4899),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF1A1A1A),
                                      width: 3,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Transform.translate(
                      offset: const Offset(0, 40),
                      child: _buildActionButton(),
                    ),
                  ],
                ),

                Transform.translate(
                  offset: const Offset(0, -16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '@$username',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 14,
                        ),
                      ),

                      if (bio != null && bio.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          bio,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (location != null && location.isNotEmpty) ...[
                            const Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              location,
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Joined ${_formatDate(createdAt)}',
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),

                      // GANTI bagian SizedBox(height: 70, ...) dengan kode di bawah ini
                      const SizedBox(height: 16), // jarak sebelum statistik
                      // ==== STATISTIK YANG RESPONSIF & ANTI OVERFLOW ====
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF374151).withOpacity(0.5),
                          ),
                        ),
                        child: IntrinsicHeight(
                          // biar divider ikut tinggi konten
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildClickableStat(
                                  'Following',
                                  followingCount,
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            FollowersFollowingScreen(
                                              username: _userData!['username'],
                                              initialTab: 1,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              _verticalDivider(),
                              Expanded(
                                child: _buildClickableStat(
                                  'Followers',
                                  followersCount,
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            FollowersFollowingScreen(
                                              username: _userData!['username'],
                                              initialTab: 0,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              _verticalDivider(),
                              Expanded(
                                child: _buildClickableStat(
                                  'Threads',
                                  threadsCount,
                                  () {},
                                ),
                              ),
                              _verticalDivider(),
                              Expanded(
                                child: _buildClickableStat(
                                  'Likes',
                                  likesCount,
                                  () {},
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(double size) {
    final username = _userData?['username'] ?? 'U';
    final photo = _userData?['photo'];

    if (photo != null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(photo),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
        ),
      ),
      child: Center(
        child: Text(
          username[0].toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: size / 2.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    if (_isOwnProfile) {
      return ElevatedButton(
        onPressed: () async {
          final updatedUser = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditProfilePage(userData: _userData!),
            ),
          );

          // Update local data immediately with new data from edit page
          if (updatedUser != null && mounted) {
            setState(() {
              _userData = {..._userData!, ...updatedUser};
            });

            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile refreshed successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 1),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF374151),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF4B5563)),
          ),
        ),
        child: const Text('Edit Profile'),
      );
    }

    return ElevatedButton(
      onPressed: _isFollowing ? _unfollowUser : _followUser,
      style: ElevatedButton.styleFrom(
        backgroundColor: _isFollowing
            ? const Color(0xFF374151)
            : const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      child: Text(_isFollowing ? 'Following' : 'Follow'),
    );
  }

  Widget _buildStat(String label, int count, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Text(
              _formatCount(count),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF374151).withOpacity(0.5)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF3B82F6).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: const Color(0xFF3B82F6),
        unselectedLabelColor: const Color(0xFF6B7280),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Threads'),
          Tab(text: 'Replies'),
          Tab(text: 'Media'),
          Tab(text: 'Likes'),
        ],
      ),
    );
  }

  Widget _buildClickableStat(String label, int count, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _formatCount(count),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() =>
      Container(width: 1, height: 36, color: const Color(0xFF374151));

  Widget _buildThreadsList(List<dynamic> threads, String tabType) {
    if (threads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getEmptyIcon(tabType),
              size: 64,
              color: const Color(0xFF374151),
            ),
            const SizedBox(height: 16),
            Text(
              _getEmptyMessage(tabType),
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: threads.length,
      itemBuilder: (context, index) {
        final thread = threads[index];
        return _buildThreadCard(thread, index, tabType);
      },
    );
  }

  Widget _buildThreadCard(
    Map<String, dynamic> thread,
    int index,
    String tabType,
  ) {
    final threadType = thread['type'];
    final isRepost = threadType == 'repost';

    // For repost, get original author and reposter info
    final originalUser = isRepost
        ? (thread['original_user'] ?? {})
        : (thread['user'] ?? {});
    final repostedBy = isRepost ? (thread['reposted_by'] ?? {}) : null;

    final username =
        originalUser['username'] ?? _userData?['username'] ?? 'Unknown';
    final authorPhoto = originalUser['photo'];
    final reposterUsername = repostedBy?['username'];
    final reposterPhoto = repostedBy?['photo'];

    final content = thread['body'] ?? thread['content'] ?? '';
    final image = thread['image'];
    final likesCount = thread['likes_count'] ?? 0;
    final repostsCount = thread['reposts_count'] ?? 0;
    final repliesCount = thread['replies_count'] ?? 0;
    final isLiked = thread['is_liked'] == true;
    final createdAt = thread['created_at'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF374151).withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Repost indicator
            if (isRepost && reposterUsername != null) ...[
              Row(
                children: [
                  const SizedBox(width: 8),
                  const Icon(Icons.repeat, size: 14, color: Color(0xFF6B7280)),
                  const SizedBox(width: 8),
                  // Reposter avatar (small)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF1A1A1A),
                        width: 1.5,
                      ),
                    ),
                    child: reposterPhoto != null
                        ? CircleAvatar(
                            radius: 9,
                            backgroundImage: NetworkImage(reposterPhoto),
                          )
                        : CircleAvatar(
                            radius: 9,
                            backgroundColor: const Color(0xFF8B5CF6),
                            child: Text(
                              reposterUsername[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$reposterUsername reposted',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Original post header
            Row(
              children: [
                // Original author avatar
                CircleAvatar(
                  radius: 20,
                  backgroundImage: authorPhoto != null
                      ? NetworkImage(authorPhoto)
                      : null,
                  backgroundColor: const Color(0xFF3B82F6),
                  child: authorPhoto == null
                      ? Text(
                          username[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _formatTimeAgo(createdAt),
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: Color(0xFF6B7280)),
                  onPressed: () {
                    // TODO: Show options menu
                  },
                ),
              ],
            ),

            // Content
            if (content.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ],

            // Image
            if (image != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  image,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: const Color(0xFF374151),
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Color(0xFF6B7280),
                          size: 48,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // Actions
            const SizedBox(height: 12),
            Row(
              children: [
                _buildActionButton2(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  count: likesCount,
                  color: isLiked ? Colors.red : const Color(0xFF6B7280),
                  onTap: () => _toggleLike(thread['id'], index, tabType),
                ),
                const SizedBox(width: 24),
                _buildActionButton2(
                  icon: Icons.chat_bubble_outline,
                  count: repliesCount,
                  color: const Color(0xFF6B7280),
                  onTap: () {
                    // TODO: Navigate to thread detail
                  },
                ),
                const SizedBox(width: 24),
                _buildActionButton2(
                  icon: Icons.repeat,
                  count: repostsCount,
                  color: const Color(0xFF6B7280),
                  onTap: () {
                    // TODO: Repost
                  },
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.share_outlined,
                    color: Color(0xFF6B7280),
                    size: 20,
                  ),
                  onPressed: () {
                    // TODO: Share
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton2({
    required IconData icon,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Text(
                _formatCount(count),
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMediaGrid(List<dynamic> media) {
    if (media.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Color(0xFF374151),
            ),
            SizedBox(height: 16),
            Text(
              'No media yet',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: media.length,
      itemBuilder: (context, index) {
        final item = media[index];
        final image = item['image'];

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: image != null
              ? Image.network(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF374151),
                      child: const Icon(
                        Icons.broken_image,
                        color: Color(0xFF6B7280),
                      ),
                    );
                  },
                )
              : Container(
                  color: const Color(0xFF374151),
                  child: const Icon(Icons.image, color: Color(0xFF6B7280)),
                ),
        );
      },
    );
  }

  IconData _getEmptyIcon(String tabType) {
    switch (tabType) {
      case 'threads':
        return Icons.article_outlined;
      case 'replies':
        return Icons.chat_bubble_outline;
      case 'likes':
        return Icons.favorite_border;
      default:
        return Icons.inbox_outlined;
    }
  }

  String _getEmptyMessage(String tabType) {
    switch (tabType) {
      case 'threads':
        return 'No threads yet';
      case 'replies':
        return 'No replies yet';
      case 'likes':
        return 'No liked threads yet';
      default:
        return 'Nothing here';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM yyyy').format(date);
    } catch (_) {
      return '';
    }
  }

  String _formatTimeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 365) {
        return '${(difference.inDays / 365).floor()}y';
      } else if (difference.inDays > 30) {
        return '${(difference.inDays / 30).floor()}mo';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m';
      } else {
        return 'now';
      }
    } catch (_) {
      return '';
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
