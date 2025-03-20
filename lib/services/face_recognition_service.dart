import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class FaceRecognitionService extends ChangeNotifier {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  final _secureStorage = const FlutterSecureStorage();

  List<FaceData> _registeredFaces = [];
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  List<FaceData> get registeredFaces => _registeredFaces;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _loadRegisteredFaces();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _loadRegisteredFaces() async {
    try {
      final String? facesJson = await _secureStorage.read(
        key: 'registered_faces',
      );
      if (facesJson != null) {
        final List<dynamic> facesData = jsonDecode(facesJson);
        _registeredFaces =
            facesData.map((data) => FaceData.fromJson(data)).toList();
      }
    } catch (e) {
      print('Error loading registered faces: $e');
    }
  }

  Future<void> _saveRegisteredFaces() async {
    try {
      final facesJson = jsonEncode(
        _registeredFaces.map((face) => face.toJson()).toList(),
      );
      await _secureStorage.write(key: 'registered_faces', value: facesJson);
      await _loadRegisteredFaces(); // Reload the faces after saving
    } catch (e) {
      print('Error saving registered faces: $e');
    }
  }

  Future<List<Face>> detectFaces(InputImage inputImage) async {
    try {
      return await _faceDetector.processImage(inputImage);
    } catch (e) {
      print('Face detection error: $e');
      return [];
    }
  }

  Future<bool> registerFace(
    String userId,
    String userName,
    InputImage inputImage,
  ) async {
    try {
      final faces = await detectFaces(inputImage);

      if (faces.isEmpty) {
        return false; // No face detected
      }

      if (faces.length > 1) {
        return false; // Multiple faces detected
      }

      final face = faces.first;
      final faceFeatures = _extractFaceFeatures(face);

      // Get the image from the input for thumbnail
      final File imageFile = File(inputImage.filePath!);
      final Uint8List imageBytes = await imageFile.readAsBytes();

      // Create a thumbnail
      final img.Image? originalImage = img.decodeImage(imageBytes);
      final img.Image thumbnail = img.copyResize(originalImage!, width: 100);
      final Uint8List thumbnailBytes = Uint8List.fromList(
        img.encodePng(thumbnail),
      );

      final faceData = FaceData(
        id: userId,
        name: userName,
        faceFeatures: faceFeatures,
        faceThumbnail: base64Encode(thumbnailBytes),
        createdAt: DateTime.now(),
      );

      _registeredFaces.add(faceData);
      await _saveRegisteredFaces();
      notifyListeners();
      return true;
    } catch (e) {
      print('Register face error: $e');
      return false;
    }
  }

  // Map<String, dynamic> _extractFaceFeatures(Face face) {
  //   // Extract relevant features for recognition
  //   return {
  //     'boundingBox': {
  //       'left': face.boundingBox.left,
  //       'top': face.boundingBox.top,
  //       'right': face.boundingBox.right,
  //       'bottom': face.boundingBox.bottom,
  //     },
  //     'landmarks': face.landmarks.map((type, point) =>
  //       MapEntry(type.index.toString(), {'x': point.x, 'y': point.y})),
  //     'contours': face.contours.map((type, points) =>
  //       MapEntry(type.index.toString(),
  //         points.map((p) => {'x': p.x, 'y': p.y}).toList())),
  //     'trackingId': face.trackingId,
  //     'headEulerAngleX': face.headEulerAngleX,
  //     'headEulerAngleY': face.headEulerAngleY,
  //     'headEulerAngleZ': face.headEulerAngleZ,
  //   };
  // }

  Map<String, dynamic> _extractFaceFeatures(Face face) {
    return {
      'boundingBox': {
        'left': face.boundingBox.left,
        'top': face.boundingBox.top,
        'right': face.boundingBox.right,
        'bottom': face.boundingBox.bottom,
      },
      'landmarks': (face.landmarks ?? {}).map(
        (type, point) => MapEntry(
          type.index.toString(),
          point != null ? {'x': point.position.x, 'y': point.position.y} : null,
        ),
      ),
      'contours': (face.contours ?? {}).map(
        (type, contour) => MapEntry(
          type.index.toString(),
          contour?.points?.map((p) => {'x': p.x, 'y': p.y}).toList() ?? [],
        ),
      ),
      'trackingId': face.trackingId ?? -1, // Default value if null
      'headEulerAngleX': face.headEulerAngleX ?? 0.0,
      'headEulerAngleY': face.headEulerAngleY ?? 0.0,
      'headEulerAngleZ': face.headEulerAngleZ ?? 0.0,
    };
  }

  Future<VerificationResult> verifyFace(InputImage inputImage) async {
    try {
      final faces = await detectFaces(inputImage);

      if (faces.isEmpty) {
        return VerificationResult(
          isVerified: false,
          message: 'No face detected',
        );
      }

      if (faces.length > 1) {
        return VerificationResult(
          isVerified: false,
          message: 'Multiple faces detected',
        );
      }

      final Face detectedFace = faces.first;
      final detectedFeatures = _extractFaceFeatures(detectedFace);

      // Find the best match
      FaceData? bestMatch;
      double bestSimilarity = 0;

      for (final registeredFace in _registeredFaces) {
        final similarity = _calculateFaceSimilarity(
          detectedFeatures,
          registeredFace.faceFeatures,
        );

        if (similarity > bestSimilarity && similarity > 0.7) {
          bestSimilarity = similarity;
          bestMatch = registeredFace;
        }
      }

      if (bestMatch != null) {
        print(
          'Best match found: ${bestMatch.name} with similarity $bestSimilarity',
        );
        return VerificationResult(
          isVerified: true,
          message: 'Face verified',
          matchedUser: bestMatch,
          similarity: bestSimilarity,
        );
      } else {
        print('No matching face found');
        return VerificationResult(
          isVerified: false,
          message: 'No matching face found',
        );
      }
    } catch (e) {
      print('Verify face error: $e');
      return VerificationResult(
        isVerified: false,
        message: 'Error during verification: $e',
      );
    }
  }

  double _calculateFaceSimilarity(
    Map<String, dynamic> features1,
    Map<String, dynamic> features2,
  ) {
    // This is a simplified similarity calculation
    // In a real app, you would use a more sophisticated algorithm

    // Compare head angles
    final angleXDiff =
        (features1['headEulerAngleX'] - features2['headEulerAngleX']).abs();
    final angleYDiff =
        (features1['headEulerAngleY'] - features2['headEulerAngleY']).abs();
    final angleZDiff =
        (features1['headEulerAngleZ'] - features2['headEulerAngleZ']).abs();

    // If angles are too different, it's likely not the same person
    if (angleXDiff > 15 || angleYDiff > 15 || angleZDiff > 15) {
      return 0.0;
    }

    // Calculate similarity based on landmarks
    double landmarkSimilarity = 0.0;
    int landmarkCount = 0;

    features1['landmarks'].forEach((key, value1) {
      if (features2['landmarks'].containsKey(key)) {
        final value2 = features2['landmarks'][key];
        final xDiff = (value1['x'] - value2['x']).abs();
        final yDiff = (value1['y'] - value2['y']).abs();

        // Normalize by bounding box size for scale invariance
        final width1 =
            features1['boundingBox']['right'] -
            features1['boundingBox']['left'];
        final height1 =
            features1['boundingBox']['bottom'] -
            features1['boundingBox']['top'];

        final normalizedDiff = (xDiff / width1 + yDiff / height1) / 2;
        landmarkSimilarity += (1 - normalizedDiff);
        landmarkCount++;
      }
    });

    if (landmarkCount == 0) return 0.0;
    return landmarkSimilarity / landmarkCount;
  }

  Future<bool> deleteFace(String userId) async {
    try {
      _registeredFaces.removeWhere((face) => face.id == userId);
      await _saveRegisteredFaces();
      notifyListeners();
      return true;
    } catch (e) {
      print('Delete face error: $e');
      return false;
    }
  }

  // Clean up resources
  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }
}

class FaceData {
  final String id;
  final String name;
  final Map<String, dynamic> faceFeatures;
  final String faceThumbnail; // Base64 encoded thumbnail
  final DateTime createdAt;

  FaceData({
    required this.id,
    required this.name,
    required this.faceFeatures,
    required this.faceThumbnail,
    required this.createdAt,
  });

  factory FaceData.fromJson(Map<String, dynamic> json) {
    return FaceData(
      id: json['id'],
      name: json['name'],
      faceFeatures: json['faceFeatures'],
      faceThumbnail: json['faceThumbnail'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'faceFeatures': faceFeatures,
      'faceThumbnail': faceThumbnail,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class VerificationResult {
  final bool isVerified;
  final String message;
  final FaceData? matchedUser;
  final double similarity;

  VerificationResult({
    required this.isVerified,
    required this.message,
    this.matchedUser,
    this.similarity = 0.0,
  });
}
