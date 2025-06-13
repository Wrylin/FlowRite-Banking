import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flowrite_banking/pages/Dashboard.dart';

class CreatePinPage extends StatefulWidget {
  final String userId;

  const CreatePinPage({Key? key, required this.userId}) : super(key: key);

  @override
  _CreatePinPageState createState() => _CreatePinPageState();
}

class _CreatePinPageState extends State<CreatePinPage> {
  final List<TextEditingController> _pinControllers = List.generate(
    4,
        (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    4,
        (index) => FocusNode(),
  );

  // Keep track of the previous text in each field to detect backspace
  final List<String> _previousTexts = List.generate(4, (index) => "");

  String _errorMessage = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Set up listeners for each controller
    for (int i = 0; i < 4; i++) {
      final index = i; // Capture the index for the closure
      _pinControllers[index].addListener(() {
        // Store current text for comparison
        String currentText = _pinControllers[index].text;

        // If text is deleted (current length < previous length)
        if (currentText.isEmpty && _previousTexts[index].isNotEmpty && index > 0) {
          // This means backspace was pressed on an empty field
          _focusNodes[index - 1].requestFocus();

          // Optional: Position cursor at the end of the previous field
          _pinControllers[index - 1].selection = TextSelection.fromPosition(
            TextPosition(offset: _pinControllers[index - 1].text.length),
          );
        }

        // Update previous text
        _previousTexts[index] = currentText;

        // Clear error message when any field changes
        _checkAllFieldsFilled();
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _pinControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          "Create PIN",
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Create a 4-digit PIN",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text(
                "You'll use this PIN to access your account",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  4,
                      (index) => _buildPinField(index),
                ),
              ),
              SizedBox(height: 16),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                  ),
                ),
              SizedBox(height: 40),
              _isLoading
                  ? CircularProgressIndicator(
                color: Color(0xFF007BA4),
              )
                  : Container(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitPin,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      "Create PIN",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF007BA4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinField(int index) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _pinControllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        obscureText: true,
        decoration: InputDecoration(
          counterText: "",
          border: InputBorder.none,
        ),
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        onChanged: (value) {
          if (value.isNotEmpty && index < 3) {
            // Move to next field when a digit is entered
            _focusNodes[index + 1].requestFocus();
          }
        },
        // Add a key listener to detect backspace
        onEditingComplete: () {
          // This helps with keyboard handling
          if (index < 3) {
            _focusNodes[index + 1].requestFocus();
          }
        },
      ),
    );
  }

  void _checkAllFieldsFilled() {
    setState(() {
      _errorMessage = '';
    });
  }

  void _submitPin() async {
    // Check if all fields are filled
    for (var controller in _pinControllers) {
      if (controller.text.isEmpty) {
        setState(() {
          _errorMessage = 'Please enter all 4 digits';
        });
        return;
      }
    }

    // Combine PIN digits
    String pin = _pinControllers.map((controller) => controller.text).join();

    // Validate PIN (all digits should not be the same)
    if (_allDigitsSame(pin)) {
      setState(() {
        _errorMessage = 'PIN cannot be all the same digits';
      });
      return;
    }

    // Show loading indicator
    setState(() {
      _isLoading = true;
    });

    try {
      // Save PIN to Firestore
      await FirebaseFirestore.instance
          .collection('user-data')
          .doc(widget.userId)
          .update({
        'pin': pin,
        'pinCreatedAt': FieldValue.serverTimestamp(),
      });

      // Navigate to dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardPage(),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error creating PIN. Please try again.';
      });
      print('Error creating PIN: $e');
    }
  }

  bool _allDigitsSame(String pin) {
    if (pin.length != 4) return false;
    return pin.split('').every((digit) => digit == pin[0]);
  }
}
