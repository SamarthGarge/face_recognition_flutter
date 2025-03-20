import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/face_recognition_service.dart';
import 'register_face_screen.dart';
import 'verify_face_screen.dart';
import 'manage_faces_screen.dart';
import 'package:lottie/lottie.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _initializeService();
  }
  
  Future<void> _initializeService() async {
    final service = Provider.of<FaceRecognitionService>(context, listen: false);
    await service.initialize();
    setState(() {
      _isLoading = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Face Recognition'),
        centerTitle: true,
      ),
      body: _isLoading
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset(
                  'assets/animations/face_scanning.json',
                  width: 200,
                  height: 200,
                ),
                SizedBox(height: 20),
                Text('Initializing face recognition...'),
              ],
            ),
          )
        : Consumer<FaceRecognitionService>(
            builder: (context, service, child) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Lottie.asset(
                      'assets/animations/face_recognition.json',
                      width: 250,
                      height: 250,
                    ),
                    SizedBox(height: 40),
                    Text(
                      'Face Recognition App',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Secure authentication using facial recognition',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 60),
                    _buildActionButton(
                      icon: Icon(Icons.person_add_alt_sharp, color: Colors.white),
                      label: 'Register New Face',
                      color: Colors.blue,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RegisterFaceScreen(),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 20),
                    _buildActionButton(
                      icon: Icon(Icons.face_sharp, color: Colors.white),
                      label: 'Verify Face',
                      color: Colors.blue,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VerifyFaceScreen(),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 20),
                    _buildActionButton(
                      icon: Icon(Icons.people_alt_sharp, color: Colors.white),
                      label: 'Manage Registered Faces',
                      color: Colors.blue,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ManageFacesScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }
  
  Widget _buildActionButton({
    required Icon icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 280,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(
          icon.icon,
          color: icon.color,
        ),
        label: Text(
          label,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}