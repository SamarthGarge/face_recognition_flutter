import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../services/face_recognition_service.dart';

class RegisterFaceScreen extends StatefulWidget {
  const RegisterFaceScreen({super.key});

  @override
  _RegisterFaceScreenState createState() => _RegisterFaceScreenState();
}

class _RegisterFaceScreenState extends State<RegisterFaceScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _isFrontCamera = true;
  File? _capturedImage;
  
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
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
  
  Future<void> _captureImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    
    try {
      setState(() {
        _isProcessing = true;
      });
      
      final XFile image = await _cameraController!.takePicture();
      
      setState(() {
        _capturedImage = File(image.path);
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to capture image: $e')),
      );
    }
  }
  
  Future<void> _registerFace() async {
    if (!_formKey.currentState!.validate() || _capturedImage == null) {
      return;
    }
    
    try {
      setState(() {
        _isProcessing = true;
      });
      
      final service = Provider.of<FaceRecognitionService>(context, listen: false);
      
      final InputImage inputImage = InputImage.fromFilePath(_capturedImage!.path);
      final String userId = DateTime.now().millisecondsSinceEpoch.toString();
      final String userName = _nameController.text.trim();
      
      final bool success = await service.registerFace(userId, userName, inputImage);
      
      setState(() {
        _isProcessing = false;
      });
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Face registered successfully')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to register face. Please try again.')),
        );
        _resetCapture();
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  
  void _resetCapture() {
    setState(() {
      _capturedImage = null;
    });
  }
  
  @override
  void dispose() {
    _cameraController?.dispose();
    _nameController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Register New Face'),
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
              _buildPreviewSection()
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
                      heroTag: 'captureImage',
                      onPressed: _isProcessing ? null : _captureImage,
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
            'Position your face within the circle and ensure good lighting',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
  
  Widget _buildPreviewSection() {
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
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _resetCapture,
                      icon: Icon(Icons.refresh, color: Colors.white),
                      label: Text('Retake', style: TextStyle(color: Colors.white),),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _registerFace,
                      icon: Icon(Icons.save, color: Colors.white),
                      label: Text('Register', style: TextStyle(color: Colors.white),),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}