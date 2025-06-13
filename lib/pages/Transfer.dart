import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Custom formatter for account numbers (adds hyphens after every 4 digits)
class AccountNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Only allow digits
    final newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // If deleting, just return the filtered value
    if (newText.length < oldValue.text.replaceAll(RegExp(r'[^0-9]'), '').length) {
      return TextEditingValue(
        text: _formatAccountNumber(newText),
        selection: TextSelection.collapsed(offset: _formatAccountNumber(newText).length),
      );
    }

    // Format with hyphens
    final formattedText = _formatAccountNumber(newText);

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }

  String _formatAccountNumber(String text) {
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      // Add hyphen after every 4 digits
      if (i > 0 && i % 4 == 0 && i < 16) {
        buffer.write('-');
      }
      buffer.write(text[i]);

      // Stop after 16 digits (4 groups of 4)
      if (i == 15) break;
    }

    return buffer.toString();
  }
}

class TransferPage extends StatefulWidget {
  const TransferPage({Key? key}) : super(key: key);

  @override
  _TransferPageState createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _receiverNameController = TextEditingController();
  final _purposeController = TextEditingController();

  bool _isLoading = false;
  bool _isVerifyingReceiver = false;
  String? _errorMessage;

  // Current user data
  double _currentBalance = 0.0;
  String _currentAccountNumber = '';
  String _currentUserName = '';

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
    _loadUserData();

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
    _amountController.dispose();
    _accountNumberController.dispose();
    _receiverNameController.dispose();
    _purposeController.dispose();

    for (var controller in _pinControllers) {
      controller.dispose();
    }
    for (var node in _pinFocusNodes) {
      node.dispose();
    }

    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Get user profile data
        final userDoc = await FirebaseFirestore.instance
            .collection('user-data')
            .doc(user.uid)
            .get();

        // Get bank account data
        final bankDoc = await FirebaseFirestore.instance
            .collection('bank-account')
            .doc(user.uid)
            .get();

        if (userDoc.exists && bankDoc.exists) {
          setState(() {
            _currentUserName = userDoc.data()?['name'] ?? 'User';
            _currentAccountNumber = bankDoc.data()?['account-number'] ?? '';
            _currentBalance = (bankDoc.data()?['balance'] ?? 0).toDouble();
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = "User data not found.";
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = "No user is currently signed in";
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _errorMessage = "Error: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyReceiverAccount() async {
    if (_accountNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter receiver\'s account number')),
      );
      return;
    }

    setState(() {
      _isVerifyingReceiver = true;
    });

    try {
      // Query Firestore to find the account with the given account number
      final querySnapshot = await FirebaseFirestore.instance
          .collection('bank-account')
          .where('account-number', isEqualTo: _accountNumberController.text)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account number not found')),
        );
        setState(() {
          _isVerifyingReceiver = false;
          _receiverNameController.clear();
        });
        return;
      }

      // Get the user ID from the bank account document
      final receiverUserId = querySnapshot.docs.first.id;

      // Get the user's name from the user-data collection
      final userDoc = await FirebaseFirestore.instance
          .collection('user-data')
          .doc(receiverUserId)
          .get();

      if (userDoc.exists) {
        final receiverName = userDoc.data()?['name'] ?? 'Unknown User';
        setState(() {
          _receiverNameController.text = receiverName;
          _isVerifyingReceiver = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receiver user data not found')),
        );
        setState(() {
          _isVerifyingReceiver = false;
          _receiverNameController.clear();
        });
      }
    } catch (e) {
      print('Error verifying receiver account: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() {
        _isVerifyingReceiver = false;
        _receiverNameController.clear();
      });
    }
  }

  void _showPinVerificationDialog() {
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
                'Please enter your 4-digit PIN to confirm the transfer',
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
                _verifyPinAndTransfer(pin);
              },
              child: const Text('Confirm'),
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

  Future<void> _verifyPinAndTransfer(String enteredPin) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Verify PIN
        final userDoc = await FirebaseFirestore.instance
            .collection('user-data')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User data not found')),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }

        final storedPin = userDoc.data()?['pin'];

        if (storedPin != enteredPin) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incorrect PIN')),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // PIN is correct, proceed with transfer
        await _processTransfer();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No user is currently signed in')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error verifying PIN: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _processTransfer() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No user is currently signed in')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Parse amount
      final amount = double.parse(_amountController.text);

      // Check if user has sufficient balance
      if (amount > _currentBalance) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insufficient funds')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Find receiver's account
      final receiverQuery = await FirebaseFirestore.instance
          .collection('bank-account')
          .where('account-number', isEqualTo: _accountNumberController.text)
          .limit(1)
          .get();

      if (receiverQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receiver account not found')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final receiverDoc = receiverQuery.docs.first;
      final receiverId = receiverDoc.id;
      final receiverBalance = (receiverDoc.data()['balance'] ?? 0).toDouble();

      // Start a batch write to ensure atomicity
      final batch = FirebaseFirestore.instance.batch();

      // Update sender's balance
      final senderRef = FirebaseFirestore.instance
          .collection('bank-account')
          .doc(user.uid);
      batch.update(senderRef, {
        'balance': _currentBalance - amount,
      });

      // Update receiver's balance
      final receiverRef = FirebaseFirestore.instance
          .collection('bank-account')
          .doc(receiverId);
      batch.update(receiverRef, {
        'balance': receiverBalance + amount,
      });

      // Create transaction record for sender (withdrawal)
      final senderTransactionRef = FirebaseFirestore.instance.collection('transactions').doc();
      batch.set(senderTransactionRef, {
        'userId': user.uid,
        'type': 'withdraw',
        'amount': amount,
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'Transfer to ${_receiverNameController.text} (${_accountNumberController.text})',
        'purpose': _purposeController.text.isNotEmpty ? _purposeController.text : 'Transfer',
        'receiverId': receiverId,
        'receiverName': _receiverNameController.text,
        'receiverAccountNumber': _accountNumberController.text,
      });

      // Create transaction record for receiver (deposit)
      final receiverTransactionRef = FirebaseFirestore.instance.collection('transactions').doc();
      batch.set(receiverTransactionRef, {
        'userId': receiverId,
        'type': 'deposit',
        'amount': amount,
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'Transfer from $_currentUserName ($_currentAccountNumber)',
        'purpose': _purposeController.text.isNotEmpty ? _purposeController.text : 'Transfer',
        'senderId': user.uid,
        'senderName': _currentUserName,
        'senderAccountNumber': _currentAccountNumber,
      });

      // Commit the batch
      await batch.commit();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully transferred ${_formatCurrency(amount)} to ${_receiverNameController.text}'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear form
      _amountController.clear();
      _accountNumberController.clear();
      _receiverNameController.clear();
      _purposeController.clear();

      // Reload user data to update balance
      await _loadUserData();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error processing transfer: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    String amountStr = amount.toStringAsFixed(2);
    List<String> parts = amountStr.split('.');

    // Format money with comma
    String wholeNumber = parts[0];
    String result = '';

    for (int i = 0; i < wholeNumber.length; i++) {
      if (i > 0 && (wholeNumber.length - i) % 3 == 0) {
        result += ',';
      }
      result += wholeNumber[i];
    }

    // Add decimal part back
    return '₱$result.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton.outlined(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        title: const Text(
          "Transfer Money",
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text("Error: $_errorMessage"))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF204887),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Available Balance",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatCurrency(_currentBalance),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Account: $_currentAccountNumber",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Amount Field
              const Text(
                "Amount",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  prefixText: '₱ ',
                  hintText: '0.00',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  try {
                    double amount = double.parse(value);
                    if (amount <= 0) {
                      return 'Amount must be greater than zero';
                    }
                    if (amount > _currentBalance) {
                      return 'Insufficient funds';
                    }
                  } catch (e) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Receiver Account Number Field with auto-formatting
              const Text(
                "Receiver's Account Number",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _accountNumberController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        AccountNumberFormatter(),
                      ],
                      decoration: InputDecoration(
                        hintText: '1111-2222-3333-4444',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter receiver\'s account number';
                        }
                        // Check if the account number has the correct format (16 digits + 3 hyphens)
                        if (value.replaceAll('-', '').length != 16) {
                          return 'Please enter a valid 16-digit account number';
                        }
                        if (value == _currentAccountNumber) {
                          return 'Cannot transfer to your own account';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 50, // Match the height of the TextFormField
                    child: ElevatedButton(
                      onPressed: _isVerifyingReceiver ? null : _verifyReceiverAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007BA4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: _isVerifyingReceiver
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Text(
                        'Verify',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Receiver Name Field
              const Text(
                "Receiver's Name",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _receiverNameController,
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Verify account number to see name',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                  fillColor: Colors.grey[200],
                  filled: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please verify receiver\'s account number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Purpose Field (Optional)
              const Text(
                "Purpose (Optional)",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _purposeController,
                decoration: InputDecoration(
                  hintText: 'E.g., Rent payment, Gift, etc.',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                ),
              ),

              const SizedBox(height: 30),

              // Transfer Button
              Container(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                    if (_formKey.currentState!.validate()) {
                      _showPinVerificationDialog();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007BA4),
                    disabledBackgroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    "Transfer Money",
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

class UserData {
  final String name;
  final String accountNumber;
  final double balance;

  UserData({
    required this.name,
    required this.accountNumber,
    required this.balance,
  });
}
