import 'package:flutter/material.dart';
import 'package:flowrite_banking/pages/Dashboard.dart';
import 'package:flowrite_banking/pages/Signup.dart';
import 'package:flowrite_banking/pages/CreatePin.dart';
import 'package:flowrite_banking/AuthService.dart';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = AuthService();
  final usernameOrEmailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  String? errorMessage;
  bool isPasswordVisible = false;

  // PIN verification controllers
  final List<TextEditingController> _pinControllers = List.generate(
    4,
        (index) => TextEditingController(),
  );
  final List<FocusNode> _pinFocusNodes = List.generate(
    4,
        (index) => FocusNode(),
  );
  final List<String> _previousPinTexts = List.generate(4, (index) => "");

  @override
  void initState() {
    super.initState();

    // Set up listeners for PIN backspace detection
    for (int i = 0; i < 4; i++) {
      final index = i;
      _pinControllers[index].addListener(() {
        String currentText = _pinControllers[index].text;

        if (currentText.isEmpty && _previousPinTexts[index].isNotEmpty && index > 0) {
          _pinFocusNodes[index - 1].requestFocus();
          _pinControllers[index - 1].selection = TextSelection.fromPosition(
            TextPosition(offset: _pinControllers[index - 1].text.length),
          );
        }

        _previousPinTexts[index] = currentText;
      });
    }
  }

  @override
  void dispose() {
    usernameOrEmailController.dispose();
    passwordController.dispose();

    for (var controller in _pinControllers) {
      controller.dispose();
    }
    for (var node in _pinFocusNodes) {
      node.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.black),
        ),
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  Column(
                    children: <Widget>[
                      const Text("Login",
                          style: TextStyle(
                              fontSize: 30, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Text("Login to your account",
                          style: TextStyle(
                              fontSize: 15, color: Colors.grey[700])),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      children: <Widget>[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              "Username or Email",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 5),
                            TextField(
                              controller: usernameOrEmailController,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                                enabledBorder:
                                OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                                border:
                                OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                                hintText: "Enter username or email",
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
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
                                hintText: "Enter password",
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                        if (errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.only(top: 3, left: 3),
                          child: MaterialButton(
                            minWidth: double.infinity,
                            height: 60,
                            onPressed: isLoading ? null : _loginFunc,
                            color: const Color(0xFF007BA4),
                            disabledColor: Colors.grey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: isLoading
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : const Text(
                              "Login",
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        MaterialButton(
                          minWidth: double.infinity,
                          height: 60,
                          onPressed: isLoading ? null : _signInWithGoogle,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                            side: const BorderSide(color: Colors.grey),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/google_logo.png',
                                height: 24,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                "Login with Google",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Text("Don't have an account?"),
                      GestureDetector(
                        child: const Text(
                          " Sign up",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            color: Color(0xFF204887),
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => SignupPage()),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show PIN verification dialog
  void _showPinVerificationDialog(String userId) {
    // Reset PIN controllers
    for (var controller in _pinControllers) {
      controller.clear();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Enter PIN',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please enter your 4-digit PIN to complete login',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  4,
                      (index) => _buildPinField(index),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  isLoading = false;
                });
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Combine PIN digits
                String pin = _pinControllers.map((controller) => controller.text).join();

                if (pin.length != 4) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter all 4 digits')),
                  );
                  return;
                }

                Navigator.of(context).pop();
                _verifyPinAndLogin(userId, pin);
              },
              child: const Text('Verify'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPinField(int index) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _pinControllers[index],
        focusNode: _pinFocusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        obscureText: true,
        decoration: const InputDecoration(
          counterText: "",
          border: InputBorder.none,
        ),
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 3) {
            _pinFocusNodes[index + 1].requestFocus();
          }
        },
      ),
    );
  }

  // Verify PIN and complete login
  Future<void> _verifyPinAndLogin(String userId, String enteredPin) async {
    try {
      // Get user document to verify PIN
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('user-data')
          .doc(userId)
          .get();

      if (userDoc.exists && userDoc.data() is Map<String, dynamic>) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        String? storedPin = userData['pin'];

        if (storedPin == null) {
          // User doesn't have a PIN, navigate to CreatePinPage
          log("User doesn't have PIN, navigating to CreatePinPage");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => CreatePinPage(userId: userId)),
          );
        } else if (storedPin == enteredPin) {
          // PIN is correct, navigate to Dashboard
          log("PIN verified successfully, navigating to Dashboard");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardPage()),
          );
        } else {
          // PIN is incorrect
          setState(() {
            errorMessage = "Incorrect PIN. Please try again.";
            isLoading = false;
          });
        }
      } else {
        // User document not found
        setState(() {
          errorMessage = "User data not found. Please try again.";
          isLoading = false;
        });
      }
    } catch (e) {
      log("Error verifying PIN: $e");
      setState(() {
        errorMessage = "Error verifying PIN: ${e.toString()}";
        isLoading = false;
      });
    }
  }

  // Modified navigation method to show PIN dialog
  Future<void> _navigateAfterLogin(String userId) async {
    try {
      // Check if user has created a PIN
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('user-data')
          .doc(userId)
          .get();

      if (userDoc.exists && userDoc.data() is Map<String, dynamic>) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

        if (userData.containsKey('pin') && userData['pin'] != null) {
          // User has PIN, show PIN verification dialog
          log("User has PIN, showing PIN verification dialog");
          _showPinVerificationDialog(userId);
        } else {
          // User doesn't have PIN, navigate to CreatePinPage
          log("User doesn't have PIN, navigating to CreatePinPage");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => CreatePinPage(userId: userId)),
          );
        }
      } else {
        // Something went wrong, show error
        log("User document not found or invalid");
        setState(() {
          errorMessage = "User data not found. Please try again.";
          isLoading = false;
        });
      }
    } catch (e) {
      log("Error checking PIN status: $e");
      setState(() {
        errorMessage = "Error: ${e.toString()}";
        isLoading = false;
      });
    }
  }

  Future<void> _loginFunc() async {
    // basic validation
    if (usernameOrEmailController.text.isEmpty || passwordController.text.isEmpty) {
      setState(() {
        errorMessage = "Please enter both username/email and password";
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final user = await _auth.loginUser(
        usernameOrEmailController.text,
        passwordController.text,
      );

      if (user != null) {
        log("User Logged In Successfully");
        // Use the modified navigation method that shows PIN dialog
        await _navigateAfterLogin(user.uid);
      } else {
        setState(() {
          errorMessage = "Invalid username/email or password";
          isLoading = false;
        });
      }
    } catch (e) {
      log("Login error: $e");
      setState(() {
        errorMessage = "Login failed: ${e.toString()}";
        isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final user = await _auth.signInWithGoogle();
      if (user != null) {
        log("Signed in with Google successfully");
        // Use the modified navigation method that shows PIN dialog
        await _navigateAfterLogin(user.uid);
      } else {
        setState(() {
          errorMessage = "Google sign-in failed";
          isLoading = false;
        });
      }
    } catch (e) {
      log("Google sign-in error: $e");
      setState(() {
        errorMessage = "Google sign-in failed: ${e.toString()}";
        isLoading = false;
      });
    }
  }
}