import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xthreads_mobile/screens/profile_screen.dart';
import 'package:xthreads_mobile/services/api_service.dart';

class FollowersFollowingScreen extends StatefulWidget {
  final String username;
  final int initialTab; // 0 = followers, 1 = following

  const FollowersFollowingScreen({
    Key? key,
    required this.username,
    this.initialTab = 0,
  }) : super(key: key);

  @override
  State<FollowersFollowingScreen> createState() =>
      _FollowersFollowingScreenState();
}

class _FollowersFollowingScreenState extends State<FollowersFollowingScreen>
    with SingleTickerProviderStateMixin {
  static const String baseUrl = ApiService.baseUrl;

  late TabController _tabController;
  bool _isLoadingFollowers = true;
  bool _isLoadingFollowing = true;
  List<dynamic> _followers = [];
  List<dynamic> _following = [];
  Set<int> _followingIds = {}; // Track who current user is following

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadFollowers();
    _loadFollowing();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _loadFollowers() async {
    try {
      final token = await _getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('$baseUrl/users/${widget.username}/followers'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _followers = data['data']['followers'] ?? [];
          _isLoadingFollowers = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingFollowers = false);
      _showSnackbar('Error loading followers: $e');
    }
  }

  Future<void> _loadFollowing() async {
    try {
      final token = await _getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('$baseUrl/users/${widget.username}/following'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> followingList = data['data']['following'] ?? [];

        setState(() {
          _following = followingList;

          // INI YANG PALING PENTING! Isi _followingIds dari data yang di-load
          _followingIds = followingList
              .map((user) => user['id'] as int)
              .toSet();

          _isLoadingFollowing = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingFollowing = false);
      _showSnackbar('Error loading following: $e');
    }
  }

  Future<void> _toggleFollow(
    String username,
    int userId,
    bool isFollowing,
  ) async {
    try {
      final token = await _getToken();
      if (token == null) return;

      final response = await http.post(
        Uri.parse('$baseUrl/users/$username/toggle-follow'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          if (isFollowing) {
            _followingIds.remove(userId);
          } else {
            _followingIds.add(userId);
          }
        });
      }
    } catch (e) {
      _showSnackbar('Error: $e');
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _navigateToProfile(String username) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfilePage(username: username)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '@${widget.username}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const Text(
              'Connections',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Column(
            children: [
              // Garis pemisah tipis (optional)
              Container(height: 0.5, color: const Color(0xFF374151)),

              TabBar(
                controller: _tabController,
                indicator: const UnderlineTabIndicator(
                  borderSide: BorderSide(color: Colors.white, width: 5.0),
                  insets: EdgeInsets.symmetric(horizontal: 40),
                ),
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF9CA3AF),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Followers'), // ← HILANGIN ANGKA!
                  Tab(text: 'Following'), // ← HILANGIN ANGKA!
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildFollowersList(), _buildFollowingList()],
      ),
    );
  }

  Widget _buildFollowersList() {
    if (_isLoadingFollowers) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
      );
    }

    if (_followers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937).withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline,
                size: 64,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No followers yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'When someone follows this account,\nthey\'ll appear here',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFollowers,
      color: const Color(0xFF3B82F6),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _followers.length,
        itemBuilder: (context, index) {
          final follower = _followers[index];
          return _buildUserCard(follower, isFollowerTab: true);
        },
      ),
    );
  }

  Widget _buildFollowingList() {
    if (_isLoadingFollowing) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
      );
    }

    if (_following.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937).withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_add_outlined,
                size: 64,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Not following anyone yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'When this account follows someone,\nthey\'ll appear here',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFollowing,
      color: const Color(0xFF3B82F6),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _following.length,
        itemBuilder: (context, index) {
          final followedUser = _following[index];
          return _buildUserCard(followedUser, isFollowerTab: false);
        },
      ),
    );
  }

  Widget _buildUserCard(
    Map<String, dynamic> user, {
    required bool isFollowerTab,
  }) {
    final username = user['username'] ?? '';
    final photo = user['photo'];
    final userId = user['id'];
    final followedAt = user['followed_at'];

    // Check if current user is following this person
    final isFollowing = _followingIds.contains(userId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1F2937).withOpacity(0.5),
            const Color(0xFF374151).withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF374151).withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToProfile(username),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar with gradient border
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF1A1A1A),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundImage: photo != null
                          ? NetworkImage(photo)
                          : null,
                      backgroundColor: const Color(0xFF3B82F6),
                      child: photo == null
                          ? Text(
                              username[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
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
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '@$username',
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 13,
                            ),
                          ),
                          if (followedAt != null) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.circle,
                              size: 4,
                              color: Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatFollowedAt(followedAt),
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Follow button
                _buildFollowButton(username, userId, isFollowing),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFollowButton(String username, int userId, bool isFollowing) {
    if (isFollowing) {
      return OutlinedButton(
        onPressed: () {
          // Tampilkan dialog konfirmasi unfollow (mirip Threads asli)
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1F2937),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Unfollow @$username?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: const Text(
                'Their posts will no longer show up in your For You timeline.',
                style: TextStyle(color: Color(0xFF9CA3AF)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _toggleFollow(username, userId, true);
                  },
                  child: const Text(
                    'Unfollow',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: Color(0xFF374151), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
        child: const Text(
          'Following',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      );
    }

    // Kalau belum following → button gradient biru-ungu
    return ElevatedButton(
      onPressed: () => _toggleFollow(username, userId, false),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: const Text(
          'Follow',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  String _formatFollowedAt(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 365) {
        return '${(difference.inDays / 365).floor()}y ago';
      } else if (difference.inDays > 30) {
        return '${(difference.inDays / 30).floor()}mo ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else {
        return 'Just now';
      }
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
