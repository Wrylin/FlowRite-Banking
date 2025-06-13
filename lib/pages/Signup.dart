import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flowrite_banking/pages/Login.dart';
import 'package:flutter/material.dart';
// import 'package:flowrite_banking/pages/Dashboard.dart';
import 'package:flowrite_banking/pages/CreatePin.dart';
import 'package:flowrite_banking/AuthService.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _auth = AuthService();
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back_ios,
            size: 20,
            color: Colors.black,),
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 40),
          height: MediaQuery.of(context).size.height - 90,
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              Column(
                children: <Widget>[
                  Text("Sign up",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,

                      )),
                  SizedBox(height: 30),
                  Text("Create an account",
                    style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700]),
                  ),
                ],
              ),
              Column(
                children: <Widget>[
                  inputFile(label: "Full Name", controller: nameController),
                  inputFile(label: "Username", controller: usernameController),
                  inputFile(label: "Email", controller: emailController),
                  inputFile(label: "Password", obscureText: true, controller: passwordController),
                ],
              ),
              Column(
                children: [
                  Container(
                    padding: EdgeInsets.only(top: 3, left: 3),
                    child: MaterialButton(
                      minWidth: double.infinity,
                      height: 60,
                      onPressed: () {
                        _signupfunc();
                      },
                      color: Color(0xFF007BA4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50)),
                      child: Text(
                        "Sign up",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  MaterialButton(
                    minWidth: double.infinity,
                    height: 60,
                    onPressed: () async {
                      final user = await _auth.signInWithGoogle();
                      if (user != null) {
                        log("Signed in with Google successfully");
                        await _saveGoogleUserData(user);
                        // Navigate to PIN creation page instead of Dashboard
                        Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => CreatePinPage(userId: user.uid)
                            )
                        );
                      }
                    },
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                      side: BorderSide(color: Colors.grey),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/google_logo.png',
                          height: 24,
                        ),
                        SizedBox(width: 10),
                        Text(
                          "Sign in with Google",
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text("Already have an account?"),
                  GestureDetector(
                    child: Text(" Login",
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            color: Color(0xFF204887)
                        )),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => LoginPage()));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  _signupfunc() async {
    final user = await _auth.createUserWithEmailAndPassword(emailController.text, passwordController.text);
    if (user != null) {
      log("User Created Successfully");
      await _savedUserData(user.uid);
      // Navigate to PIN creation page instead of Dashboard
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => CreatePinPage(userId: user.uid)
          )
      );
    }
    else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A User with this email already exists.')),
      );
    }
  }

  Future<String> _generateAccountNumber() async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;

    // Query the bank-account collection to find the highest account number
    QuerySnapshot accountsSnapshot = await firestore
        .collection('bank-account')
        .orderBy('account-number', descending: true)
        .limit(1)
        .get();

    int nextCounter = 1000; // Default starting value

    if (accountsSnapshot.docs.isNotEmpty) {
      // Extract the last 4 digits from the highest account number
      String highestAccountNumber = accountsSnapshot.docs.first.get('account-number') as String;
      String lastFourDigits = highestAccountNumber.split('-').last;

      try {
        // Parse the last 4 digits and increment by 1
        nextCounter = int.parse(lastFourDigits) + 1;
      } catch (e) {
        // If parsing fails, use the default value
        log('Error parsing account number: $e');
      }
    }

    // Format account number as 1111-2222-3333-XXXX
    return '1111-2222-3333-${nextCounter.toString().padLeft(4, '0')}';
  }

  _savedUserData(String userid) async {
    FirebaseFirestore users = FirebaseFirestore.instance;
    FirebaseFirestore bankacc = FirebaseFirestore.instance;
    //checking if there is an existing user
    final existingUser = await users
        .collection('user-data')
        .where('email', isEqualTo: emailController.text)
        .limit(1)
        .get();
    if (existingUser.docs.isEmpty) {
      //no user with the email
      await users.collection('user-data')
          .doc(userid)
          .set({
        'name': nameController.text,
        'username': usernameController.text,
        'email': emailController.text,
        'pass': passwordController.text,
      });

      // Generate unique account number
      String accountNumber = await _generateAccountNumber();

      await bankacc.collection('bank-account')
          .doc(userid)
          .set({
        'account-number': accountNumber,
        'balance': 1000,
      });
      print('User added with account number: $accountNumber');
    }
    else {
      //user already exists
      print('A User with this email already exists.');
    }
  }


  _saveGoogleUserData(User user) async {
    FirebaseFirestore userG = FirebaseFirestore.instance;
    // Check if user already exists
    final existingUser = await userG
        .collection('user-data')
        .doc(user.uid)
        .get();

    if (!existingUser.exists) {
      // Save user data
      await userG.collection('user-data')
          .doc(user.uid)
          .set({
        'name': user.displayName ?? 'Google User',
        'username': user.email?.split('@')[0] ?? 'user_${user.uid.substring(0, 5)}',
        'email': user.email ?? '',
        'photoURL': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Generate unique account number
      String accountNumber = await _generateAccountNumber();

      // Create bank account
      await userG.collection('bank-account')
          .doc(user.uid)
          .set({
        'account-number': accountNumber,
        'balance': 1000,
      });

      log('Google user data saved with account number: $accountNumber');
    } else {
      log('Google user already exists.');
    }
  }
}

// text field widget
Widget inputFile({required String label, bool obscureText = false, required TextEditingController controller}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: Colors.black87,
        ),
      ),
      SizedBox(height: 5),
      TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 10),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
          ),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
          ),
        ),
      ),
      SizedBox(height: 10),
    ],
  );
}
