import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:hiking_app/models/trackpoint.dart';
import 'package:hiking_app/utilities/gpx_file_util.dart';
import 'package:hiking_app/utilities/user_profile_manager.dart';
import 'package:hiking_app/utilities/saved_trails_manager.dart';
import 'package:hiking_app/widgets/round_back_button.dart';

class TrailSaveScreen extends StatefulWidget {
  final List<Trackpoint> recordedTrack;
  final double totalDistance;
  final Duration elapsedTime;

  const TrailSaveScreen({
    super.key,
    required this.recordedTrack,
    required this.totalDistance,
    required this.elapsedTime,
  });

  @override
  State<TrailSaveScreen> createState() => _TrailSaveScreenState();
}

class _TrailSaveScreenState extends State<TrailSaveScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  
  final List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Set default name with timestamp
    final now = DateTime.now();
    _nameController.text = 'Trail_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImages.add(File(image.path));
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (photo != null) {
        setState(() {
          _selectedImages.add(File(photo.path));
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to take photo: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _saveTrail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Get app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final trailsDir = Directory(p.join(directory.path, 'saved_trails'));
      
      // Create trails directory if it doesn't exist
      if (!await trailsDir.exists()) {
        await trailsDir.create(recursive: true);
      }

      // Create trail-specific directory
      final trailName = _nameController.text.trim();
      final trailDir = Directory(p.join(trailsDir.path, trailName));
      await trailDir.create(recursive: true);

      // Save GPX file
      final gpxPath = p.join(trailDir.path, '$trailName.gpx');
      await GpxFileUtil.saveTrackpointsAsGpx(
        widget.recordedTrack,
        gpxPath,
        name: trailName,
      );

      // Save images if any
      final List<String> savedImagePaths = [];
      for (int i = 0; i < _selectedImages.length; i++) {
        final image = _selectedImages[i];
        final extension = p.extension(image.path);
        final imageName = '${trailName}_image_${i + 1}$extension';
        final imagePath = p.join(trailDir.path, imageName);
        
        await image.copy(imagePath);
        savedImagePaths.add(imageName); // Store relative path
      }

      // Save metadata
      await _saveTrailMetadata(trailDir.path, trailName, savedImagePaths);

      // Update user stats
      await _updateUserStats(trailDir.path);

      // Show success message
      if (mounted) {
        _showSuccessDialog(trailName, trailDir.path);
      }

    } catch (e) {
      _showErrorSnackBar('Failed to save trail: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _saveTrailMetadata(String trailDirPath, String trailName, List<String> imagePaths) async {
    final metadataFile = File(p.join(trailDirPath, 'metadata.json'));
    
    final metadata = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': trailName,
      'description': _descriptionController.text.trim(),
      'location': _locationController.text.trim(),
      'created_at': DateTime.now().toIso8601String(),
      'distance_meters': widget.totalDistance,
      'duration_seconds': widget.elapsedTime.inSeconds,
      'points_count': widget.recordedTrack.length,
      'images': imagePaths,
    };

    await metadataFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(metadata),
    );
  }

  Future<void> _updateUserStats(String trailDirPath) async {
    try {
      // Load the saved trail to get its data
      final metadataFile = File(p.join(trailDirPath, 'metadata.json'));
      if (await metadataFile.exists()) {
        final metadataJson = await metadataFile.readAsString();
        final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;
        final savedTrail = SavedTrail.fromJson(metadata, trailDirPath);
        
        // Update user stats
        await UserProfileManager.updateUserStatsWithNewTrail(savedTrail);
      }
    } catch (e) {
      // Log error but don't fail the trail save process
      debugPrint('Error updating user stats: $e');
    }
  }

  void _showSuccessDialog(String trailName, String savedPath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Trail Saved!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trail "$trailName" has been saved successfully.'),
            const SizedBox(height: 12),
            Text('Location: $savedPath', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Text('Points recorded: ${widget.recordedTrack.length}'),
            Text('Distance: ${(widget.totalDistance / 1000).toStringAsFixed(2)} km'),
            Text('Duration: ${_formatDuration(widget.elapsedTime)}'),
            if (_selectedImages.isNotEmpty)
              Text('Images: ${_selectedImages.length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to previous screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const RoundBackButton(),
        title: const Text(
          'Save Trail',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Trail Statistics Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trail Statistics',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          'Distance',
                          '${(widget.totalDistance / 1000).toStringAsFixed(2)} km',
                          Icons.route,
                        ),
                        _buildStatItem(
                          'Duration',
                          _formatDuration(widget.elapsedTime),
                          Icons.timer,
                        ),
                        _buildStatItem(
                          'Points',
                          widget.recordedTrack.length.toString(),
                          Icons.my_location,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Trail Name
              const Text(
                'Trail Name',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Enter trail name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.hiking),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a trail name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Location
              const Text(
                'Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  hintText: 'Enter location (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.location_on),
                ),
              ),

              const SizedBox(height: 20),

              // Description
              const Text(
                'Description',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter trail description (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.description),
                ),
              ),

              const SizedBox(height: 24),

              // Images Section
              const Text(
                'Photos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              // Add Photo Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Selected Images Grid
              if (_selectedImages.isNotEmpty)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(_selectedImages[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
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
                    );
                  },
                ),

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveTrail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSaving
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Saving Trail...'),
                          ],
                        )
                      : const Text(
                          'Save Trail',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.green, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
