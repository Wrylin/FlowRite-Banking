import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({Key? key}) : super(key: key);

  @override
  _SecurityPageState createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // PIN controllers
  final List<TextEditingController> _currentPinControllers = List.generate(4, (index) => TextEditingController());
  final List<TextEditingController> _newPinControllers = List.generate(4, (index) => TextEditingController());
  final List<TextEditingController> _confirmPinControllers = List.generate(4, (index) => TextEditingController());

  // Focus nodes for PIN fields
  final List<FocusNode> _currentPinFocusNodes = List.generate(4, (index) => FocusNode());
  final List<FocusNode> _newPinFocusNodes = List.generate(4, (index) => FocusNode());
  final List<FocusNode> _confirmPinFocusNodes = List.generate(4, (index) => FocusNode());

  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isUpdatingPassword = false;
  bool _isUpdatingPin = false;

  // Expansion states
  bool _isPasswordSectionExpanded = false;
  bool _isPinSectionExpanded = false;

  @override
  void initState() {
    super.initState();
    _setupPinListeners();
  }

  void _setupPinListeners() {
    // Setup listeners for current PIN
    for (int i = 0; i < 4; i++) {
      final index = i;
      _currentPinControllers[index].addListener(() {
        if (_currentPinControllers[index].text.isNotEmpty && index < 3) {
          _currentPinFocusNodes[index + 1].requestFocus();
        }
      });

      _newPinControllers[index].addListener(() {
        if (_newPinControllers[index].text.isNotEmpty && index < 3) {
          _newPinFocusNodes[index + 1].requestFocus();
        }
      });

      _confirmPinControllers[index].addListener(() {
        if (_confirmPinControllers[index].text.isNotEmpty && index < 3) {
          _confirmPinFocusNodes[index + 1].requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    for (var controller in _currentPinControllers) {
      controller.dispose();
    }
    for (var controller in _newPinControllers) {
      controller.dispose();
    }
    for (var controller in _confirmPinControllers) {
      controller.dispose();
    }

    for (var node in _currentPinFocusNodes) {
      node.dispose();
    }
    for (var node in _newPinFocusNodes) {
      node.dispose();
    }
    for (var node in _confirmPinFocusNodes) {
      node.dispose();
    }

    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all password fields')),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match')),
      );
      return;
    }

    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters long')),
      );
      return;
    }

    setState(() {
      _isUpdatingPassword = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Reauthenticate user
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _currentPasswordController.text,
        );

        await user.reauthenticateWithCredential(credential);

        // Update password
        await user.updatePassword(_newPasswordController.text);

        // Update password in Firestore if you store it there
        await FirebaseFirestore.instance
            .collection('user-data')
            .doc(user.uid)
            .update({
          'pass': _newPasswordController.text,
          'passwordUpdatedAt': FieldValue.serverTimestamp(),
        });

        // Clear form
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Collapse the section after successful update
        setState(() {
          _isPasswordSectionExpanded = false;
        });
      }
    } catch (e) {
      String errorMessage = 'Failed to update password';
      if (e.toString().contains('wrong-password')) {
        errorMessage = 'Current password is incorrect';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUpdatingPassword = false;
      });
    }
  }

  Future<void> _updatePin() async {
    // Check if all PIN fields are filled
    String currentPin = _currentPinControllers.map((c) => c.text).join();
    String newPin = _newPinControllers.map((c) => c.text).join();
    String confirmPin = _confirmPinControllers.map((c) => c.text).join();

    if (currentPin.length != 4 || newPin.length != 4 || confirmPin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all PIN fields')),
      );
      return;
    }

    if (newPin != confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New PINs do not match')),
      );
      return;
    }

    if (_allDigitsSame(newPin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN cannot be all the same digits')),
      );
      return;
    }

    setState(() {
      _isUpdatingPin = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Get current PIN from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('user-data')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          throw Exception('User data not found');
        }

        final storedPin = userDoc.data()?['pin'];

        if (storedPin != currentPin) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Current PIN is incorrect'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isUpdatingPin = false;
          });
          return;
        }

        // Update PIN in Firestore
        await FirebaseFirestore.instance
            .collection('user-data')
            .doc(user.uid)
            .update({
          'pin': newPin,
          'pinUpdatedAt': FieldValue.serverTimestamp(),
        });

        // Clear form
        for (var controller in _currentPinControllers) {
          controller.clear();
        }
        for (var controller in _newPinControllers) {
          controller.clear();
        }
        for (var controller in _confirmPinControllers) {
          controller.clear();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Collapse the section after successful update
        setState(() {
          _isPinSectionExpanded = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update PIN: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUpdatingPin = false;
      });
    }
  }

  bool _allDigitsSame(String pin) {
    if (pin.length != 4) return false;
    return pin.split('').every((digit) => digit == pin[0]);
  }

  Widget _buildPinField(TextEditingController controller, FocusNode focusNode, int index) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade50,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
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
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    required String hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: !isVisible,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF007BA4)),
              borderRadius: BorderRadius.circular(12),
            ),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                isVisible ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey.shade600,
              ),
              onPressed: onToggleVisibility,
            ),
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey.shade500),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Security Settings",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: Colors.black,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Password Section Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent, // This removes the divider lines
                ),
                child: ExpansionTile(
                  initiallyExpanded: _isPasswordSectionExpanded,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _isPasswordSectionExpanded = expanded;
                    });
                  },
                  tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  childrenPadding: EdgeInsets.zero, // Remove default padding
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007BA4).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      color: Color(0xFF007BA4),
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    "Change Password",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    "Update your account password",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        children: [
                          _buildPasswordField(
                            label: "Current Password",
                            controller: _currentPasswordController,
                            isVisible: _isCurrentPasswordVisible,
                            onToggleVisibility: () {
                              setState(() {
                                _isCurrentPasswordVisible = !_isCurrentPasswordVisible;
                              });
                            },
                            hintText: "Enter current password",
                          ),
                          const SizedBox(height: 20),
                          _buildPasswordField(
                            label: "New Password",
                            controller: _newPasswordController,
                            isVisible: _isNewPasswordVisible,
                            onToggleVisibility: () {
                              setState(() {
                                _isNewPasswordVisible = !_isNewPasswordVisible;
                              });
                            },
                            hintText: "Enter new password",
                          ),
                          const SizedBox(height: 20),
                          _buildPasswordField(
                            label: "Confirm New Password",
                            controller: _confirmPasswordController,
                            isVisible: _isConfirmPasswordVisible,
                            onToggleVisibility: () {
                              setState(() {
                                _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                              });
                            },
                            hintText: "Confirm new password",
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isUpdatingPassword ? null : _updatePassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF007BA4),
                                disabledBackgroundColor: Colors.grey.shade300,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: _isUpdatingPassword
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                                  : const Text(
                                "Update Password",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // PIN Section Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent, // This removes the divider lines
                ),
                child: ExpansionTile(
                  initiallyExpanded: _isPinSectionExpanded,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _isPinSectionExpanded = expanded;
                    });
                  },
                  tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  childrenPadding: EdgeInsets.zero, // Remove default padding
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF204887).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.pin_outlined,
                      color: Color(0xFF204887),
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    "Change PIN",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    "Update your 4-digit security PIN",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Current PIN",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(
                              4,
                                  (index) => _buildPinField(_currentPinControllers[index], _currentPinFocusNodes[index], index),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "New PIN",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(
                              4,
                                  (index) => _buildPinField(_newPinControllers[index], _newPinFocusNodes[index], index),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "Confirm New PIN",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(
                              4,
                                  (index) => _buildPinField(_confirmPinControllers[index], _confirmPinFocusNodes[index], index),
                            ),
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isUpdatingPin ? null : _updatePin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF204887),
                                disabledBackgroundColor: Colors.grey.shade300,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: _isUpdatingPin
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                                  : const Text(
                                "Update PIN",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Security Tips Card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.lightbulb_outline,
                            color: Colors.amber,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Security Tips",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSecurityTip("Use a strong password with at least 8 characters"),
                    _buildSecurityTip("Don't use the same PIN for multiple accounts"),
                    _buildSecurityTip("Change your credentials regularly"),
                    _buildSecurityTip("Never share your PIN with anyone"),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityTip(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}