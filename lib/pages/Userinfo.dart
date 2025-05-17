import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserPage extends StatefulWidget {
  @override
  _UserPageState createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  final nameController = TextEditingController();
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;
  String? profileImageUrl;
  File? _imageFile;
  bool isPasswordVisible = false;

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
    passwordController.dispose();
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
        // Get user profile data
        final userDoc = await FirebaseFirestore.instance
            .collection('user-data')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data()!;

          // Set the text controllers with user data
          nameController.text = data['name'] ?? '';
          usernameController.text = data['username'] ?? '';
          emailController.text = data['email'] ?? '';

          // Don't populate the password field for security reasons
          // But you could set a placeholder if needed
          passwordController.text = ''; // Or use '••••••••' as a placeholder

          // Set profile image URL if available
          setState(() {
            profileImageUrl = data['photoURL'];
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

  Future<void> _saveUserProfile() async {
    // Basic validation
    if (nameController.text.isEmpty || usernameController.text.isEmpty || emailController.text.isEmpty) {
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
        // Check if email is being changed
        bool isEmailChanged = emailController.text != user.email;

        // If email is being changed, we need to reauthenticate first
        if (isEmailChanged) {
          String password = '';

          // If password field is filled, use that
          if (passwordController.text.isNotEmpty) {
            password = passwordController.text;
          } else {
            // Otherwise prompt for current password
            password = await _promptForPassword();
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
          }

          try {
            // Create credential for reauthentication
            AuthCredential credential = EmailAuthProvider.credential(
              email: user.email!,
              password: password,
            );

            // Reauthenticate user
            await user.reauthenticateWithCredential(credential);

            // Now we can update the email
            await user.verifyBeforeUpdateEmail(emailController.text);

            print('Email updated successfully');
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
            } else if (errorMsg.contains('operation-not-allowed')) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Email provider is not enabled in Firebase. Please check your Firebase Console settings.'),
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

        // Update user data in Firestore
        await FirebaseFirestore.instance
            .collection('user-data')
            .doc(user.uid)
            .update({
          'name': nameController.text,
          'username': usernameController.text,
          'email': emailController.text,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update password if provided
        if (passwordController.text.isNotEmpty) {
          await user.updatePassword(passwordController.text);

          // Update password in Firestore if you store it there
          // Note: Storing passwords in Firestore is generally not recommended for security reasons
          await FirebaseFirestore.instance
              .collection('user-data')
              .doc(user.uid)
              .update({
            'pass': passwordController.text, // Only if you need to store it
          });
        }

        // Update profile in Firebase Auth
        await user.updateProfile(displayName: nameController.text);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
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
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 75,
                          backgroundImage: _imageFile != null
                              ? FileImage(_imageFile!) as ImageProvider
                              : (profileImageUrl != null && profileImageUrl!.isNotEmpty
                              ? NetworkImage(profileImageUrl!) as ImageProvider
                              : const AssetImage('assets/images/profile_placeholder.jpg')),
                        ),
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
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Tap to change profile picture",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Column(
                children: <Widget>[
                  inputField(label: "Full Name", controller: nameController),
                  inputField(label: "Username", controller: usernameController),
                  inputField(label: "Email", controller: emailController),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        "Password",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 5),
                      TextField(
                        controller: passwordController,
                        obscureText: !isPasswordVisible,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          border: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                isPasswordVisible = !isPasswordVisible;
                              });
                            },
                          ),
                          hintText: "Leave blank to keep current password",
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

// textfield
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
