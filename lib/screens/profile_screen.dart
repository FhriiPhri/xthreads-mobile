import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  final String? username;

  const ProfilePage({Key? key, this.username}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  static const String baseUrl = "http://127.0.0.1:8000/api";

  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  List<dynamic> _timeline = [];
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

      // Get current user data first
      final meResponse = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (meResponse.statusCode == 200) {
        final meData = jsonDecode(meResponse.body);
        final currentUsername = meData['data']?['user']?['username'] ?? '';

        // Check if viewing own profile or someone else's
        final targetUsername = widget.username ?? currentUsername;
        _isOwnProfile = targetUsername == currentUsername;

        // Get profile data
        final profileResponse = await http.get(
          Uri.parse('$baseUrl/users/$targetUsername'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );

        if (profileResponse.statusCode == 200) {
          final profileData = jsonDecode(profileResponse.body);

          setState(() {
            _userData = profileData['data']?['user'];
            _timeline = profileData['data']?['timeline'] ?? [];
            _isFollowing = profileData['data']?['is_following'] ?? false;
            _isLoading = false;
          });
        } else {
          throw Exception('Gagal memuat profil');
        }
      } else {
        throw Exception('Gagal memuat data user');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _followUser() async {
    if (_userData == null) return;

    try {
      final token = await _getToken();
      if (token == null) throw Exception('Token tidak ditemukan');

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
          _userData!['followers_count'] = (_userData!['followers_count'] ?? 0) + 1;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berhasil follow user')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _unfollowUser() async {
    if (_userData == null) return;

    try {
      final token = await _getToken();
      if (token == null) throw Exception('Token tidak ditemukan');

      final response = await http.delete(
        Uri.parse('$baseUrl/users/${_userData!['username']}/unfollow'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _isFollowing = false;
          _userData!['followers_count'] = (_userData!['followers_count'] ?? 1) - 1;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berhasil unfollow user')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _likeThread(int threadId, int index) async {
    if (_timeline.isEmpty) return;

    try {
      final token = await _getToken();
      if (token == null) throw Exception('Token tidak ditemukan');

      final response = await http.post(
        Uri.parse('$baseUrl/threads/$threadId/like'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _timeline[index]['likes_count'] = (_timeline[index]['likes_count'] ?? 0) + 1;
          _timeline[index]['is_liked'] = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _unlikeThread(int threadId, int index) async {
    if (_timeline.isEmpty) return;

    try {
      final token = await _getToken();
      if (token == null) throw Exception('Token tidak ditemukan');

      final response = await http.delete(
        Uri.parse('$baseUrl/threads/$threadId/unlike'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _timeline[index]['likes_count'] = (_timeline[index]['likes_count'] ?? 1) - 1;
          _timeline[index]['is_liked'] = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _userData == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F0F),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF3B82F6),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildProfileHeader(),
                const SizedBox(height: 16),
                _buildTabBar(),
                const SizedBox(height: 16),
              ],
            ),
          ),
          _buildTabContent(),
        ],
      ),
    );
  }

  // ===================== WIDGETS ===================== //

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
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
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
    final photo = _userData?['photo'];
    final bio = _userData?['bio'];
    final location = _userData?['location'];
    final createdAt = _userData?['created_at'];
    final isModerator = _userData?['is_moderator'] ?? false;
    final followingCount = _userData?['following_count'] ?? 0;
    final followersCount = _userData?['followers_count'] ?? 0;
    final threadsCount = _userData?['threads_count'] ?? 0;
    final likesCount = _userData?['likes_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
          ),

          // Profile Info
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar & Actions
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
                      // Username
                      Row(
                        children: [
                          Text(
                            username,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
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

                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildStat('Following', followingCount),
                          const SizedBox(width: 24),
                          _buildStat('Followers', followersCount),
                          const SizedBox(width: 24),
                          _buildStat('Threads', threadsCount),
                          const SizedBox(width: 24),
                          _buildStat('Likes', likesCount),
                        ],
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
        onPressed: () {
          // TODO: Navigate to edit profile
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
      onPressed: () {
        if (_isFollowing) {
          _unfollowUser();
        } else {
          _followUser();
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: _isFollowing ? const Color(0xFF374151) : const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      child: Text(_isFollowing ? 'Following' : 'Follow'),
    );
  }

  Widget _buildStat(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF374151).withOpacity(0.5)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Color(0xFF3B82F6),
              width: 2,
            ),
          ),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF6B7280),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Threads'),
          Tab(text: 'Replies'),
          Tab(text: 'Media'),
          Tab(text: 'Likes'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (_timeline.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No threads yet',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              );
            }

            final thread = _timeline[index];
            return Card(
              color: const Color(0xFF1A1A1A),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: Text(
                  thread['title'] ?? 'Untitled',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  thread['body'] ?? '',
                  style: const TextStyle(color: Colors.grey),
                ),
                trailing: IconButton(
                  icon: Icon(
                    thread['is_liked'] == true ? Icons.favorite : Icons.favorite_border,
                    color: thread['is_liked'] == true ? Colors.red : Colors.white,
                  ),
                  onPressed: () {
                    final id = thread['id'];
                    if (thread['is_liked'] == true) {
                      _unlikeThread(id, index);
                    } else {
                      _likeThread(id, index);
                    }
                  },
                ),
              ),
            );
          },
          childCount: _timeline.isEmpty ? 1 : _timeline.length,
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }
}