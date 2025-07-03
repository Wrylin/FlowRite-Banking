import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';

class UserPage extends StatefulWidget {
  @override
  _UserPageState createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  final nameController = TextEditingController();
  final usernameController = TextEditingController();
  final emailController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;
  String? profileImageBase64;
  String? googlePhotoURL;
  File? _imageFile;
  bool _isGoogleUser = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    nameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        _isGoogleUser = user.providerData.any((provider) => provider.providerId == 'google.com');

        final userDoc = await FirebaseFirestore.instance
            .collection('user-data')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data()!;

          nameController.text = data['name'] ?? '';
          usernameController.text = data['username'] ?? '';
          emailController.text = data['email'] ?? '';

          setState(() {
            profileImageBase64 = data['profileImageBase64'];
            googlePhotoURL = data['photoURL']; // Load Google photo URL
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
      print('Error loading user data: $e');
      setState(() {
        errorMessage = "Error: $e";
        isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      // Show options for camera or gallery
      final ImageSource? source = await _showImageSourceDialog();

      if (source != null) {
        await _pickImageFromSource(source);
      }
    } catch (e) {
      print('Error in image selection: $e');
      _showErrorSnackBar('Error selecting image source');
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Opening image picker...'),
            ],
          ),
        ),
      );

      // Use the most stable image picker method
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );

      // Close loading dialog
      Navigator.of(context).pop();

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);

        // Validate file exists and is readable
        if (await imageFile.exists()) {
          await _cropImage(imageFile);
        } else {
          _showErrorSnackBar('Selected image file is not accessible');
        }
      } else {
        print('No image selected');
      }
    } catch (e) {
      // Close loading dialog if it's still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      print('Error with image picker: $e');
      _showErrorSnackBar('Unable to access camera/gallery. Error: ${e.toString()}');
    }
  }

  Future<void> _cropImage(File imageFile) async {
    try {
      // Show cropping dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Opening image cropper...'),
            ],
          ),
        ),
      );

      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Square crop
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Picture',
            toolbarColor: const Color(0xFF204887),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
            ],
            showCropGrid: true,
            cropGridRowCount: 3,
            cropGridColumnCount: 3,
            cropGridColor: Colors.white,
            cropGridStrokeWidth: 2,
            cropFrameColor: const Color(0xFF204887),
            cropFrameStrokeWidth: 3,
            activeControlsWidgetColor: const Color(0xFF204887),
            dimmedLayerColor: Colors.black.withOpacity(0.8),
            backgroundColor: Colors.black,
          ),
          IOSUiSettings(
            title: 'Crop Profile Picture',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            rotateButtonsHidden: false,
            rotateClockwiseButtonHidden: false,
            hidesNavigationBar: false,
            rectX: 0,
            rectY: 0,
            rectWidth: 300,
            rectHeight: 300,
          ),
        ],
      );

      // Close loading dialog
      Navigator.of(context).pop();

      if (croppedFile != null) {
        final File croppedImageFile = File(croppedFile.path);
        await _processSelectedImage(croppedImageFile);
      } else {
        print('Image cropping cancelled');
      }
    } catch (e) {
      // Close loading dialog if it's still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      print('Error cropping image: $e');
      _showErrorSnackBar('Error cropping image: ${e.toString()}');
    }
  }

  Future<void> _processSelectedImage(File imageFile) async {
    try {
      // Show processing dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Processing image...'),
            ],
          ),
        ),
      );

      // Read and validate the image
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(imageBytes);

      if (image != null) {
        final int width = image.width;
        final int height = image.height;

        print('Cropped image dimensions: ${width}x${height}');

        // Resize to 300x300 for consistency and optimization
        final img.Image resizedImage = img.copyResize(
          image,
          width: 300,
          height: 300,
          interpolation: img.Interpolation.linear,
        );

        // Get app documents directory for saving processed image
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        final String processedImagePath = '${appDocDir.path}/profile_image_${DateTime.now().millisecondsSinceEpoch}.jpg';

        // Save the resized image
        final List<int> resizedBytes = img.encodeJpg(resizedImage, quality: 85);
        final File processedFile = File(processedImagePath);
        await processedFile.writeAsBytes(resizedBytes);

        // Store image path in SharedPreferences for persistence
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('temp_profile_image_path', processedImagePath);

        // Close processing dialog
        Navigator.of(context).pop();

        setState(() {
          _imageFile = processedFile;
        });

        _showSuccessSnackBar('Image cropped and processed successfully (${width}x${height} → 300x300)');
      } else {
        Navigator.of(context).pop();
        _showErrorSnackBar('Invalid image format. Please select a valid image file.');
      }
    } catch (e) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      print('Error processing image: $e');
      _showErrorSnackBar('Error processing image: $e');
    }
  }

  Future<void> _clearTempImage() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? tempImagePath = prefs.getString('temp_profile_image_path');

      if (tempImagePath != null) {
        final File tempFile = File(tempImagePath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        await prefs.remove('temp_profile_image_path');
      }
    } catch (e) {
      print('Error clearing temp image: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<String?> _convertImageToBase64(File imageFile) async {
    try {
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final String base64String = base64Encode(imageBytes);

      // Check size limit (800KB)
      if (base64String.length > 800000) {
        throw Exception('Image is too large after processing. Please try a smaller image.');
      }

      return base64String;
    } catch (e) {
      print('Error converting image to Base64: $e');
      throw e;
    }
  }

  Future<String> _promptForPassword() async {
    final passwordController = TextEditingController();
    String password = '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Current Password'),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Enter your current password',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                password = passwordController.text;
                Navigator.of(context).pop(true);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    return password;
  }

  Future<bool> _reauthenticateGoogleUser() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.currentUser!.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      print('Error reauthenticating Google user: $e');
      return false;
    }
  }

  Future<void> _saveUserProfile() async {
    if (nameController.text.isEmpty || usernameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    if (_isGoogleUser && emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email field cannot be empty')),
      );
      return;
    }

    if (!_isGoogleUser && emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        String? newImageBase64;
        if (_imageFile != null) {
          try {
            newImageBase64 = await _convertImageToBase64(_imageFile!);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error processing image: $e'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() {
              isSaving = false;
            });
            return;
          }
        }

        if (_isGoogleUser) {
          bool reauthenticated = await _reauthenticateGoogleUser();
          if (!reauthenticated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Authentication required. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() {
              isSaving = false;
            });
            return;
          }

          Map<String, dynamic> updateData = {
            'name': nameController.text,
            'username': usernameController.text,
            'updatedAt': FieldValue.serverTimestamp(),
          };

          if (newImageBase64 != null) {
            updateData['profileImageBase64'] = newImageBase64;
            // Clear photoURL when user uploads custom image
            updateData['photoURL'] = null;
          }

          await FirebaseFirestore.instance
              .collection('user-data')
              .doc(user.uid)
              .update(updateData);

          await user.updateProfile(displayName: nameController.text);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          bool isEmailChanged = emailController.text != user.email;

          if (isEmailChanged) {
            String password = await _promptForPassword();
            if (password.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password is required to update email'),
                  backgroundColor: Colors.red,
                ),
              );
              setState(() {
                isSaving = false;
              });
              return;
            }

            try {
              AuthCredential credential = EmailAuthProvider.credential(
                email: user.email!,
                password: password,
              );

              await user.reauthenticateWithCredential(credential);
              await user.updateEmail(emailController.text);
              print('Email updated in Firebase Auth successfully');

            } catch (e) {
              print('Error during reauthentication or email update: $e');
              String errorMsg = e.toString();

              if (errorMsg.contains('wrong-password')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Incorrect password. Please try again.'),
                    backgroundColor: Colors.red,
                  ),
                );
              } else if (errorMsg.contains('email-already-in-use')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('This email is already in use by another account.'),
                    backgroundColor: Colors.red,
                  ),
                );
              } else if (errorMsg.contains('invalid-email')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid email address.'),
                    backgroundColor: Colors.red,
                  ),
                );
              } else if (errorMsg.contains('requires-recent-login')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('For security reasons, please log out and log back in before changing your email.'),
                    backgroundColor: Colors.red,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to update email: $errorMsg'),
                    backgroundColor: Colors.red,
                  ),
                );
              }

              setState(() {
                isSaving = false;
              });
              return;
            }
          }

          Map<String, dynamic> updateData = {
            'name': nameController.text,
            'username': usernameController.text,
            'email': emailController.text,
            'updatedAt': FieldValue.serverTimestamp(),
          };

          if (newImageBase64 != null) {
            updateData['profileImageBase64'] = newImageBase64;
          }

          await FirebaseFirestore.instance
              .collection('user-data')
              .doc(user.uid)
              .update(updateData);

          await user.updateProfile(displayName: nameController.text);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEmailChanged
                  ? 'Profile and email updated successfully. You can now login with your new email.'
                  : 'Profile updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }

        if (newImageBase64 != null) {
          setState(() {
            profileImageBase64 = newImageBase64;
            googlePhotoURL = null; // Clear Google photo when custom image is uploaded
            _imageFile = null;
          });

          // Clear temp image after successful save
          await _clearTempImage();
        }
      }
    } catch (e) {
      print('Error saving user profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  Widget _buildProfileImage() {
    ImageProvider? imageProvider;

    // Priority: 1. New image file, 2. Base64 image, 3. Google photo URL, 4. Placeholder
    if (_imageFile != null) {
      imageProvider = FileImage(_imageFile!);
      print('Using new image file');
    } else if (profileImageBase64 != null && profileImageBase64!.isNotEmpty) {
      try {
        Uint8List imageBytes = base64Decode(profileImageBase64!);
        imageProvider = MemoryImage(imageBytes);
        print('Using Base64 profile image');
      } catch (e) {
        print('Error decoding Base64 image: $e');
        imageProvider = const AssetImage('assets/images/profile_placeholder.jpg');
      }
    } else if (googlePhotoURL != null && googlePhotoURL!.isNotEmpty) {
      if (googlePhotoURL!.startsWith('http')) {
        imageProvider = NetworkImage(googlePhotoURL!);
        print('Using Google profile image: $googlePhotoURL');
      } else {
        // Fallback: try to decode as Base64 if it's not a URL
        try {
          Uint8List imageBytes = base64Decode(googlePhotoURL!);
          imageProvider = MemoryImage(imageBytes);
          print('Using Base64 from photoURL field');
        } catch (e) {
          print('Error decoding photoURL as Base64: $e');
          imageProvider = const AssetImage('assets/images/profile_placeholder.jpg');
        }
      }
    } else {
      imageProvider = const AssetImage('assets/images/profile_placeholder.jpg');
      print('Using placeholder image');
    }

    return CircleAvatar(
      radius: 75,
      backgroundImage: imageProvider,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton.outlined(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        title: const Text(
          "Edit Account",
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text("Error: $errorMessage"))
          : SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          height: MediaQuery.of(context).size.height - 80,
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              Column(
                children: <Widget>[
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        _buildProfileImage(),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF204887),
                              shape: BoxShape.circle,
                              border: Border.all(
                                width: 2,
                                color: Colors.white,
                              ),
                            ),
                            child: const Icon(
                              Icons.crop,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isGoogleUser
                        ? "Tap to replace Google photo with custom image"
                        : "Tap to crop and change profile picture",
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_imageFile != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "New cropped image ready to save (300x300)",
                            style: TextStyle(
                              color: Colors.green.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              Column(
                children: <Widget>[
                  inputField(label: "Full Name", controller: nameController),
                  inputField(label: "Username", controller: usernameController),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Email",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: _isGoogleUser ? Colors.grey : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 5),
                      TextField(
                        controller: emailController,
                        enabled: !_isGoogleUser,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          border: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          fillColor: _isGoogleUser ? Colors.grey.shade100 : null,
                          filled: _isGoogleUser,
                        ),
                        style: TextStyle(
                          color: _isGoogleUser ? Colors.grey.shade600 : Colors.black,
                        ),
                      ),
                      if (_isGoogleUser)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.blue.shade600,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "Email cannot be changed for Google accounts. To change your email, update it in your Google account settings.",
                                  style: TextStyle(
                                    color: Colors.blue.shade600,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.only(top: 3, left: 3),
                child: MaterialButton(
                  minWidth: double.infinity,
                  height: 60,
                  onPressed: isSaving ? null : _saveUserProfile,
                  color: const Color(0xFF204887),
                  disabledColor: Colors.grey,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50)),
                  child: isSaving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    "Save Changes",
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget inputField({
  required String label,
  bool obscureText = false,
  required TextEditingController controller,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(label,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.black87)),
      const SizedBox(height: 5),
      TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 10),
          enabledBorder:
          OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
          border:
          OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
        ),
      ),
      const SizedBox(height: 10),
    ],
  );
}