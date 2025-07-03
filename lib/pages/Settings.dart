import 'package:flutter/material.dart';
import 'package:flowrite_banking/pages/Welcome.dart';
import 'package:flowrite_banking/AuthService.dart';
import 'package:flowrite_banking/pages/Userinfo.dart';
import 'package:flowrite_banking/pages/Security.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flowrite_banking/pages/Analytics.dart';
import 'dart:convert';
import 'dart:typed_data';

class UserProfile {
  final String name;
  final String email;
  final String? photoURL;
  final String? profileImageBase64; // Add this field
  final String username;

  UserProfile({
    required this.name,
    required this.email,
    this.photoURL,
    this.profileImageBase64, // Add this parameter
    required this.username,
  });
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool isLoading = true;
  String? errorMessage;
  UserProfile? userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Get user profile data from user-data collection
        final userDoc = await FirebaseFirestore.instance
            .collection('user-data')
            .doc(user.uid)
            .get();

        print("User document exists: ${userDoc.exists}");
        if (userDoc.exists) {
          print("User data: ${userDoc.data()}");

          final data = userDoc.data()!;
          setState(() {
            userProfile = UserProfile(
              name: data['name'] ?? 'User',
              email: data['email'] ?? '',
              photoURL: data['photoURL'], // Keep for Google users
              profileImageBase64: data['profileImageBase64'], // Add this line
              username: data['username'] ?? '',
            );
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = "User profile not found";
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = "No user is signed in";
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');
      setState(() {
        errorMessage = "Error: $e";
        isLoading = false;
      });
    }
  }

  Widget _buildProfileAvatar() {
    ImageProvider? imageProvider;

    // First check for Base64 image (from manual upload)
    if (userProfile?.profileImageBase64 != null && userProfile!.profileImageBase64!.isNotEmpty) {
      try {
        Uint8List imageBytes = base64Decode(userProfile!.profileImageBase64!);
        imageProvider = MemoryImage(imageBytes);
        print('Using Base64 profile image');
      } catch (e) {
        print('Error decoding Base64 image: $e');
        imageProvider = const AssetImage('assets/images/profile_placeholder.jpg');
      }
    }
    // Then check for URL image (from Google)
    else if (userProfile?.photoURL != null && userProfile!.photoURL!.isNotEmpty) {
      if (userProfile!.photoURL!.startsWith('http')) {
        imageProvider = NetworkImage(userProfile!.photoURL!);
        print('Using network profile image: ${userProfile!.photoURL}');
      } else {
        // Fallback: try to decode as Base64 if it's not a URL
        try {
          Uint8List imageBytes = base64Decode(userProfile!.photoURL!);
          imageProvider = MemoryImage(imageBytes);
          print('Using Base64 from photoURL field');
        } catch (e) {
          print('Error decoding photoURL as Base64: $e');
          imageProvider = const AssetImage('assets/images/profile_placeholder.jpg');
        }
      }
    }
    // Default placeholder
    else {
      imageProvider = const AssetImage('assets/images/profile_placeholder.jpg');
      print('Using placeholder image');
    }

    return CircleAvatar(
      radius: 100,
      backgroundImage: imageProvider,
    );
  }

  bool _hasProfileImage() {
    return (userProfile?.profileImageBase64 != null && userProfile!.profileImageBase64!.isNotEmpty) ||
        (userProfile?.photoURL != null && userProfile!.photoURL!.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text("Error: $errorMessage"))
          : ListView(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 15),
              child: _hasProfileImage()
                  ? _buildProfileAvatar()
                  : const CircleAvatar(
                radius: 100,
                backgroundImage: AssetImage('assets/images/profile_placeholder.jpg'),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 5),
              child: Text(
                userProfile?.name ?? "User",
                style: TextStyle(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 24),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
              child: Text(
                userProfile?.email ?? "",
                style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 16),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 25, 15, 0),
              child: Column(
                children: [
                  ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => UserPage()),
                      ).then((_) {
                        // Refresh user data when returning from UserPage
                        _loadUserProfile();
                      });
                    },
                    leading: const CircleAvatar(
                      backgroundColor: Color.fromARGB(255, 239, 243, 245),
                      child: Icon(
                        Icons.person,
                        size: 22,
                        color: Color(0xFF007BA4),
                      ),
                    ),
                    title: const Text("My Account"),
                    trailing: const Icon(Icons.arrow_forward_ios),
                  ),
                  Divider(color: Colors.grey[200]),
                  ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AnalyticsPage()),
                      );
                    },
                    leading: const CircleAvatar(
                      backgroundColor: Color.fromARGB(255, 239, 243, 245),
                      child: Icon(
                        Icons.analytics_outlined,
                        size: 22,
                        color: Color(0xFF007BA4),
                      ),
                    ),
                    title: const Text("Financial Analytics"),
                    trailing: const Icon(Icons.arrow_forward_ios),
                  ),
                  Divider(color: Colors.grey[200]),
                  ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SecurityPage()),
                      );
                    },
                    leading: const CircleAvatar(
                      backgroundColor: Color.fromARGB(255, 239, 243, 245),
                      child: Icon(
                        Icons.security,
                        size: 22,
                        color: Color(0xFF007BA4),
                      ),
                    ),
                    title: const Text("Security"),
                    trailing: const Icon(Icons.arrow_forward_ios),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: ElevatedButton(
                style: ButtonStyle(
                  backgroundColor:
                  MaterialStateProperty.all<Color>(const Color(0xFF204887)),
                ),
                onPressed: () async {
                  await AuthService().signout();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => WelcomePage()),
                        (route) => false,
                  );
                },
                child: const Text(
                  "Sign Out",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}