import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Utility class for loading images from Firebase Storage
class ImageLoader {
  // Simple memory cache for download URLs
  static final Map<String, String> _urlCache = {};
  
  /// Get download URL for an image path
  /// Handles both storage paths and full URLs
  /// Implements caching to avoid repeated Firebase calls
  static Future<String?> getImageUrl(String imagePath) async {
    try {
      // Check if it's already a full URL (starts with http)
      if (imagePath.startsWith('http')) {
        return imagePath;
      }
      
      // Check cache first
      if (_urlCache.containsKey(imagePath)) {
        return _urlCache[imagePath];
      }
      
      // If it's a storage path, get the download URL
      final ref = FirebaseStorage.instance.ref().child(imagePath);
      final downloadUrl = await ref.getDownloadURL();
      
      // Cache the URL
      _urlCache[imagePath] = downloadUrl;
      
      return downloadUrl;
    } catch (e) {
      debugPrint("❌ Error loading image URL for path '$imagePath': $e");
      return null;
    }
  }
  
  /// Clear the URL cache (useful for memory management)
  static void clearCache() {
    _urlCache.clear();
  }
  
  /// Get cache size for debugging
  static int getCacheSize() {
    return _urlCache.length;
  }
}
