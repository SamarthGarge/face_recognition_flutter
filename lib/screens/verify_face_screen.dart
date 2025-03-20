// lib/screens/verify_face_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import '../services/face_recognition_service.dart';

class VerifyFaceScreen extends StatefulWidget {
  const VerifyFaceScreen({super.key});

  @override
  _VerifyFaceScreenState createState() => _VerifyFaceScreenState();
}

class _VerifyFaceScreenState extends State<VerifyFaceScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _isFrontCamera = true;
  File? _capturedImage;
  
  VerificationResult? _verificationResult;
  
  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }
  
  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      await _initializeCamera();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera permission is required')),
      );
      Navigator.pop(context);
    }
  }
  
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      
      if (_cameras.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No cameras available')),
        );
        return;
      }
      
      // Find front camera
      final frontCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );
      
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      
      await _cameraController!.initialize();
      
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      print('Camera initialization error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize camera: $e')),
      );
    }
  }
  
  Future<void> _switchCamera() async {
    if (_cameras.length <= 1) return;
    
    setState(() {
      _isFrontCamera = !_isFrontCamera;
      _isCameraInitialized = false;
    });
    
    await _cameraController?.dispose();
    
    final newCamera = _isFrontCamera
      ? _cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras.first,
        )
      : _cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras.first,
        );
    
    _cameraController = CameraController(
      newCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    
    await _cameraController!.initialize();
    
    setState(() {
      _isCameraInitialized = true;
    });
  }
  
  Future<void> _captureAndVerify() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    
    try {
      setState(() {
        _isProcessing = true;
        _verificationResult = null;
      });
      
      final XFile image = await _cameraController!.takePicture();
      
      setState(() {
        _capturedImage = File(image.path);
      });
      
      // Verify the captured face
      final service = Provider.of<FaceRecognitionService>(context, listen: false);
      final InputImage inputImage = InputImage.fromFilePath(_capturedImage!.path);
      
      final result = await service.verifyFace(inputImage);
      
      setState(() {
        _verificationResult = result;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  
  void _resetVerification() {
    setState(() {
      _capturedImage = null;
      _verificationResult = null;
    });
  }
  
  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Verify Face'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (!_isCameraInitialized && _capturedImage == null)
              SizedBox(
                height: 400,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_capturedImage != null)
              _buildResultSection()
            else
              _buildCameraSection(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCameraSection() {
    return Column(
      children: [
        SizedBox(
          height: 400,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CameraPreview(_cameraController!),
              Positioned(
                bottom: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton(
                      heroTag: 'switchCamera',
                      onPressed: _switchCamera,
                      mini: true,
                      child: Icon(Icons.flip_camera_ios, color: Colors.blue),
                    ),
                    SizedBox(width: 20),
                    FloatingActionButton(
                      heroTag: 'verifyImage',
                      onPressed: _isProcessing ? null : _captureAndVerify,
                      child: _isProcessing 
                        ? CircularProgressIndicator(color: Colors.white)
                        : Icon(Icons.camera, color: Colors.blue),
                    ),
                  ],
                ),
              ),
              // Face outline guide
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(125),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Position your face within the circle and tap the camera button to verify',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
  
  Widget _buildResultSection() {
    return Column(
      children: [
        SizedBox(
          height: 400,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.file(
                _capturedImage!,
                fit: BoxFit.cover,
                height: 400,
                width: double.infinity,
              ),
              if (_isProcessing)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              if (_verificationResult != null)
                _buildVerificationResultCard()
              else
                SizedBox(
                  height: 100,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _resetVerification,
                icon: Icon(Icons.refresh, color: Colors.white),
                label: Text('Try Again', style: TextStyle(color: Colors.white),),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildVerificationResultCard() {
    final result = _verificationResult!;
    final bool isVerified = result.isVerified;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isVerified ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            isVerified
              ? Lottie.asset(
                  'assets/animations/verification_success.json',
                  width: 100,
                  height: 100,
                  repeat: false,
                )
              : Lottie.asset(
                  'assets/animations/verification_failed.json',
                  width: 100,
                  height: 100,
                  repeat: false,
                ),
            SizedBox(height: 16),
            Text(
              isVerified ? 'Verification Successful' : 'Verification Failed',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isVerified ? Colors.green : Colors.red,
              ),
            ),
            SizedBox(height: 8),
            Text(
              result.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            if (isVerified && result.matchedUser != null) ...[
              SizedBox(height: 16),
              Text(
                'Welcome, ${result.matchedUser!.name}!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Similarity: ${(result.similarity * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
