import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hiking_app/utilities/saved_trails_manager.dart';

class SavedTrailCard extends StatelessWidget {
  final SavedTrail trail;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const SavedTrailCard({
    super.key,
    required this.trail,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Trail icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.hiking,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Trail name and location
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trail.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (trail.location.isNotEmpty)
                          Text(
                            trail.location,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Delete button
                  if (onDelete != null)
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red,
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Trail statistics
              Row(
                children: [
                  _buildStatChip(
                    icon: Icons.route,
                    label: '${trail.distanceKm.toStringAsFixed(2)} km',
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    icon: Icons.timer,
                    label: trail.formattedDuration,
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    icon: Icons.location_on,
                    label: trail.location,
                  ),
                  if (trail.images.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _buildStatChip(
                      icon: Icons.photo,
                      label: '${trail.images.length}',
                    ),
                  ],
                ],
              ),
              
              // Description
              if (trail.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  trail.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              // Images preview
              if (trail.images.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: trail.images.length,
                    itemBuilder: (context, index) {
                      final imagePath = trail.fullImagePaths[index];
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(File(imagePath)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              
              // Created date
              const SizedBox(height: 8),
              Text(
                'Created: ${_formatDate(trail.createdAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class SavedTrailsList extends StatefulWidget {
  const SavedTrailsList({super.key});

  @override
  State<SavedTrailsList> createState() => _SavedTrailsListState();
}

class _SavedTrailsListState extends State<SavedTrailsList> {
  List<SavedTrail> _savedTrails = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedTrails();
  }

  Future<void> _loadSavedTrails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final trails = await SavedTrailsManager.getSavedTrails();
      setState(() {
        _savedTrails = trails;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading saved trails: $e')),
        );
      }
    }
  }

  Future<void> _deleteTrail(SavedTrail trail) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trail'),
        content: Text('Are you sure you want to delete "${trail.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await SavedTrailsManager.deleteTrail(trail);
      if (success) {
        _loadSavedTrails(); // Refresh the list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted "${trail.name}"')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete trail')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_savedTrails.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.hiking,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No saved trails yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Record a trail to see it here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSavedTrails,
      child: ListView.builder(
        itemCount: _savedTrails.length,
        itemBuilder: (context, index) {
          final trail = _savedTrails[index];
          return SavedTrailCard(
            trail: trail,
            onTap: () {
              // TODO: Navigate to trail details or map view
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Tapped on ${trail.name}')),
              );
            },
            onDelete: () => _deleteTrail(trail),
          );
        },
      ),
    );
  }
}
