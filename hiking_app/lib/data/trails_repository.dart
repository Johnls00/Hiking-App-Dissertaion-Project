import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:gpx/gpx.dart';

class TrailsRepository {
  Future<List<Map<String, dynamic>>> fetchAllTrails() async {
    try {
      final trailsCollection = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default',).collection('trails');

      // Execute the query to get documents
      final querySnapshot = await trailsCollection.get();

      print("✅ Fetched ${querySnapshot.docs.length} trails");

      // Return list of trail data maps with document IDs
      List<Map<String, dynamic>> trails = [];
      for (final doc in querySnapshot.docs.where((doc) => !doc.id.startsWith('__'))) {
        final data = doc.data();
        data['id'] = doc.id; // Add document ID to the data
        
        // Fetch images from separate collection
        try {
          final images = await fetchTrailImages(doc.id);
          data['images'] = images;
        } catch (e) {
          print("⚠️ Failed to fetch images for trail ${doc.id}: $e");
          data['images'] = [];
        }
        
        trails.add(data);
      }
      
      return trails;
    } catch (e) {
      print("❌ Error fetching trails: $e");
      rethrow;
    }
  }

  Future<List<String>> fetchTrailImages(String trailId) async {
    try {
      final imagesCollection = FirebaseFirestore.instance
          .collection('trails')
          .doc(trailId)
          .collection('images');
      
      final querySnapshot = await imagesCollection.get();
      
      List<String> imageUrls = [];
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final imageUrl = data['url'] ?? '';
        if (imageUrl.isNotEmpty) {
          imageUrls.add(imageUrl);
        }
      }
      
      return imageUrls;
    } catch (e) {
      print("❌ Error fetching trail images: $e");
      return [];
    }
  }

  Future<Gpx> loadGpxFromFirestoreDoc(String trailGpxUrl) async {
    return await _retryOperation(() async {
      print("🔍 Starting GPX download for trail: $trailGpxUrl");

      // 2) Build a Storage ref from URL or path
      final ref = (trailGpxUrl.startsWith('gs://') || trailGpxUrl.startsWith('http'))
          ? FirebaseStorage.instance.refFromURL(trailGpxUrl)
          : FirebaseStorage.instance.ref(trailGpxUrl);

      print("🗂️ Storage reference created, starting download...");

      // 3) Download bytes with shorter timeout and progress tracking
      final bytes = await ref.getData()
          .timeout(Duration(seconds: 15), onTimeout: () {
            print("⏰ GPX download timed out for $trailGpxUrl");
            throw Exception('GPX download timed out');
          });
          
      if (bytes == null) {
        print("❌ No bytes received for GPX file");
        throw Exception('Failed to download GPX bytes');
      }

      print("✅ Downloaded ${bytes.length} bytes");

      // 4) Parse GPX
      print("🔨 Parsing GPX data...");
      final xml = utf8.decode(bytes);
      final gpx = GpxReader().fromString(xml);
      print("✅ GPX parsed successfully");
      
      return gpx;
    });
  }

  Future<T> _retryOperation<T>(Future<T> Function() operation, {int maxRetries = 2}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print("🔄 Attempt $attempt of $maxRetries");
        return await operation().timeout(Duration(seconds: 20));
      } catch (e) {
        print("🔄 Attempt $attempt failed: $e");
        
        if (attempt == maxRetries) {
          print("❌ All attempts failed, giving up");
          throw e; // Re-throw on final attempt
        }
        
        // Shorter backoff since we're already timing out quickly
        print("⏳ Waiting before retry...");
        await Future.delayed(Duration(seconds: attempt));
      }
    }
    throw Exception('All retry attempts failed');
  }
Future<List<String>> fetchTrailImageUrls(String trailId) async {
  // Use the correct default database id
  final fs = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: '(default)', // ← note the parentheses
  );

  // Optional: order images if you store 'order' or 'createdAt'
  final query = fs
      .collection('trails')
      .doc(trailId)
      .collection('images')
      .orderBy('order', descending: false);

  final snap = await query.get(const GetOptions(source: Source.server));
  if (snap.docs.isEmpty) return const [];

  final urls = <String>[];
  for (final doc in snap.docs) {
    final data = doc.data();
    final raw = (data['url'] ?? data['path'] ?? '').toString().trim();
    if (raw.isEmpty) return [
                'https://external-content.duckduckgo.com/iu/?u=https%3A%2F%2Fstatic.vecteezy.com%2Fsystem%2Fresources%2Fpreviews%2F005%2F720%2F408%2Foriginal%2Fcrossed-image-icon-picture-not-available-delete-picture-symbol-free-vector.jpg&f=1&nofb=1&ipt=35d0cda0ed3aa16562fc22367471b7cb514d1c55cb5768ceeb35f7107c4924c1'
              ];

    // Turn gs:// or plain path into a downloadable https URL
    if (raw.startsWith('gs://') || raw.startsWith('http')) {
      final ref = FirebaseStorage.instance.refFromURL(raw);
      final dl = await ref.getDownloadURL();
      urls.add(dl);
    } else {
      // Plain bucket path like "images/abc.jpg"
      final ref = FirebaseStorage.instance.ref(raw);
      final dl = await ref.getDownloadURL();
      urls.add(dl);
    }
  }
  return urls;
}

  // Convenience: single image (e.g., first)
  Future<String?> getPrimaryImageUrl(String trailId) async {
    final urls = await fetchTrailImageUrls(trailId);
    return urls.isEmpty ? null : urls.first;
  }
}
