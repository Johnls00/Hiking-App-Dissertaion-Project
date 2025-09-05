import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hiking_app/auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hiking_app/models/user.dart';
import 'package:hiking_app/utilities/user_profile_manager.dart';
import 'package:hiking_app/utilities/saved_trails_manager.dart';
import 'package:hiking_app/widgets/navigation_bar_bottom_main.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  User? _user;
  bool _isLoading = true;
  late TabController _tabController;
  List<SavedTrail> _recordedTrails = [];
  List<SavedTrail> _favoriteTrails = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      // Debug the user profile state
      await UserProfileManager.debugUserProfile();

      User? user = await UserProfileManager.loadUserProfile();

      debugPrint('Loaded user profile: ${user?.toJson()}');

      // Only create a default user if NO profile exists at all
      if (user == null) {
        final hasProfile = await UserProfileManager.hasUserProfile();
        if (!hasProfile) {
          debugPrint('No user profile found, creating default user');
          user = await UserProfileManager.createDefaultUser(
            name: 'Hiker',
            email: 'hiker@example.com',
          );
        } else {
          debugPrint(
            'Profile file exists but failed to load, trying to recalculate stats',
          );
          // If file exists but failed to load, try to recalculate stats
          user = await UserProfileManager.recalculateUserStats();
          if (user == null) {
            debugPrint(
              'Recalculation failed, creating new user as last resort',
            );
            user = await UserProfileManager.createDefaultUser(
              name: 'Hiker',
              email: 'hiker@example.com',
            );
          }
        }
      }

      // Load trails
      final allTrails = await SavedTrailsManager.getSavedTrails();
      final favoriteTrailIds = user.favoriteTrailIds;

      setState(() {
        _user = user;
        _recordedTrails = allTrails;
        _favoriteTrails = allTrails
            .where((trail) => favoriteTrailIds.contains(trail.id))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    }
  }

  Future<void> _updateProfilePicture() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        final updatedUser = await UserProfileManager.updateProfilePicture(
          image.path,
        );
        if (updatedUser != null) {
          setState(() {
            _user = updatedUser;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile picture updated!')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile picture: $e')),
        );
      }
    }
  }

  Future<void> _editProfile() async {
    if (_user == null) return;

    final nameController = TextEditingController(text: _user!.name);
    final emailController = TextEditingController(text: _user!.email);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'name': nameController.text.trim(),
                'email': emailController.text.trim(),
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      final updatedUser = _user!.copyWith(
        name: result['name']!,
        email: result['email']!,
      );
      await UserProfileManager.saveUserProfile(updatedUser);
      setState(() {
        _user = updatedUser;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated!')));
      }
    }

    nameController.dispose();
    emailController.dispose();
  }

  Future<void> _toggleFavorite(SavedTrail trail) async {
    if (_user == null) return;

    try {
      final isFavorited = _user!.favoriteTrailIds.contains(trail.id);
      User? updatedUser;

      if (isFavorited) {
        updatedUser = await UserProfileManager.removeFromFavorites(trail.id);
      } else {
        updatedUser = await UserProfileManager.addToFavorites(trail.id);
      }

      if (updatedUser != null) {
        final favoriteTrailIds = updatedUser.favoriteTrailIds;
        setState(() {
          _user = updatedUser;
          _favoriteTrails = _recordedTrails
              .where((trail) => favoriteTrailIds.contains(trail.id))
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating favorites: $e')));
      }
    }
  }

  Future<void> signOut() async {
    await Auth().signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_user == null) {
      return Scaffold(body: const Center(child: Text('Error loading profile')));
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(onPressed: _editProfile, icon: const Icon(Icons.edit)),
          IconButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          // Profile Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(
                    context,
                  ).primaryColor.withAlpha((255 * 0.2).toInt()), // 20% opacity
                  Theme.of(
                    context,
                  ).primaryColor.withAlpha((255 * 0.05).toInt()), // 5% opacity
                ],
              ),
            ),
            child: Column(
              children: [
                // Profile Picture
                GestureDetector(
                  onTap: _updateProfilePicture,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: _user!.profileImagePath != null
                            ? FileImage(File(_user!.profileImagePath!))
                            : null,
                        child: _user!.profileImagePath == null
                            ? const Icon(Icons.person, size: 50)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _user!.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _user!.email,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                Text(
                  'Member since ${_user!.joinDate.day}/${_user!.joinDate.month}/${_user!.joinDate.year}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

          // Stats Cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Trails',
                    '${_user!.stats.totalTrailsRecorded}',
                    Icons.route,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Distance',
                    '${_user!.stats.totalDistanceKm.toStringAsFixed(1)} km',
                    Icons.straighten,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Streak',
                    '${_user!.stats.currentStreak}',
                    Icons.local_fire_department,
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Recorded Trails'),
              Tab(text: 'Favorite Trails'),
            ],
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Recorded Trails Tab
                _recordedTrails.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.route, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No recorded trails yet'),
                            Text('Start recording your first hike!'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _recordedTrails.length,
                        itemBuilder: (context, index) {
                          final trail = _recordedTrails[index];
                          final isFavorited = _user!.favoriteTrailIds.contains(
                            trail.id,
                          );
                          return _buildTrailListItem(trail, isFavorited);
                        },
                      ),

                // Favorite Trails Tab
                _favoriteTrails.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.favorite_border,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text('No favorite trails yet'),
                            Text(
                              'Tap the heart icon on trails to add them to favorites!',
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _favoriteTrails.length,
                        itemBuilder: (context, index) {
                          final trail = _favoriteTrails[index];
                          return _buildTrailListItem(trail, true);
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MainBottomNavigationBar(currentIndex: 3),
    );
  }

  Widget _buildTrailListItem(SavedTrail trail, bool isFavorited) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withAlpha((255 * 0.1).toInt()),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.hiking, color: Colors.green, size: 24),
        ),
        title: Text(
          trail.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (trail.location.isNotEmpty) ...[
              Text(trail.location),
              const SizedBox(height: 4),
            ],
            Text(
              '${trail.distanceKm.toStringAsFixed(1)} km • ${trail.formattedDuration}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            isFavorited ? Icons.favorite : Icons.favorite_border,
            color: isFavorited ? Colors.red : Colors.grey,
          ),
          onPressed: () => _toggleFavorite(trail),
        ),
        isThreeLine: trail.location.isNotEmpty,
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 24, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
