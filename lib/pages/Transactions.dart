import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flowrite_banking/pages/Dashboard.dart';

class TransactionPage extends StatefulWidget {
  const TransactionPage({super.key});

  @override
  _TransactionPageState createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  final TextEditingController _amountController = TextEditingController();
  bool isLoading = true;
  bool isProcessing = false;
  String? errorMessage;
  UserData? userData;
  String transactionType = 'deposit'; // default to deposit
  bool hasTransactions = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkTransactionsCollection();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _checkTransactionsCollection() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final transactionsRef = FirebaseFirestore.instance.collection('transactions');
        final query = await transactionsRef.limit(1).get();
        setState(() {
          hasTransactions = query.docs.isNotEmpty;
        });
      }
    } catch (e) {
      print('Error checking transactions collection: $e');
      setState(() {
        hasTransactions = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // get user profile data
        final userDoc = await FirebaseFirestore.instance
            .collection('user-data')
            .doc(user.uid)
            .get();

        print("User document exists: ${userDoc.exists}");
        if (userDoc.exists) {
          print("User data: ${userDoc.data()}");
        }

        // get bank Transaction data
        final bankDoc = await FirebaseFirestore.instance
            .collection('bank-account')
            .doc(user.uid)
            .get();

        print("Bank document exists: ${bankDoc.exists}");
        if (bankDoc.exists) {
          print("Bank data: ${bankDoc.data()}");
        }

        if (userDoc.exists && bankDoc.exists) {
          final name = userDoc.data()?['name'] ?? 'User';
          final accountNumber = bankDoc.data()?['Transaction-number'] ?? '1111-2222-3333-4440';
          final balance = (bankDoc.data()?['balance'] ?? 0).toDouble();

          setState(() {
            userData = UserData(
              name: name,
              accountNumber: accountNumber,
              balance: balance,
            );
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = "User data not found.";
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = "No user is currently signed in";
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

  Future<void> _processTransaction() async {
    // validate amount
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    double amount;
    try {
      amount = double.parse(_amountController.text);
      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Amount must be greater than zero')),
        );
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    // check if withdrawal is possible
    if (transactionType == 'withdraw' && userData != null && amount > userData!.balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient funds')),
      );
      return;
    }

    setState(() {
      isProcessing = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && userData != null) {
        // Calculate new balance
        double newBalance = userData!.balance;
        if (transactionType == 'deposit') {
          newBalance += amount;
        } else {
          newBalance -= amount;
        }

        // update balance in firestore
        await FirebaseFirestore.instance
            .collection('bank-account')
            .doc(user.uid)
            .update({
          'balance': newBalance,
        });

        // add transaction record
        await FirebaseFirestore.instance
            .collection('transactions')
            .add({
          'userId': user.uid,
          'type': transactionType,
          'amount': amount,
          'timestamp': FieldValue.serverTimestamp(),
          'description': transactionType == 'deposit' ? 'Deposit' : 'Withdrawal',
        });

        setState(() {
          hasTransactions = true;
        });

        // reload user data
        await _loadUserData();

        // clear amount field
        _amountController.clear();

        // show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                transactionType == 'deposit'
                    ? 'Successfully deposited ₱${amount.toStringAsFixed(2)}'
                    : 'Successfully withdrew ₱${amount.toStringAsFixed(2)}'
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error processing transaction: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    String amountStr = amount.toStringAsFixed(2);
    List<String> parts = amountStr.split('.');

    // format money with comma
    String wholeNumber = parts[0];
    String result = '';

    for (int i = 0; i < wholeNumber.length; i++) {
      if (i > 0 && (wholeNumber.length - i) % 3 == 0) {
        result += ',';
      }
      result += wholeNumber[i];
    }

    // add decimal part back
    return '₱$result.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          "Account",
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        elevation: 0,
        leading: IconButton.outlined(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            Navigator.pushReplacement
              (context, MaterialPageRoute(builder: (context) => const DashboardPage()),);
          },
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text("Error: $errorMessage"))
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // balance Card
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
                      "Current Balance",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatCurrency(userData?.balance ?? 0),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Account: ${userData?.accountNumber ?? ''}",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // transaction type selector
              const Text(
                "Transaction Type",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          transactionType = 'deposit';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: transactionType == 'deposit'
                              ? const Color(0xFF007BA4)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            "Deposit",
                            style: TextStyle(
                              color: transactionType == 'deposit'
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          transactionType = 'withdraw';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: transactionType == 'withdraw'
                              ? const Color(0xFF007BA4)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            "Withdraw",
                            style: TextStyle(
                              color: transactionType == 'withdraw'
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // input amount
              const Text(
                "Amount",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
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
              ),

              const SizedBox(height: 30),

              // process button
              Container(
                padding: const EdgeInsets.only(top: 3, left: 3),
                width: double.infinity,
                child: MaterialButton(
                  minWidth: double.infinity,
                  height: 60,
                  onPressed: isProcessing ? null : _processTransaction,
                  color: const Color(0xFF007BA4),
                  disabledColor: Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: isProcessing
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Text(
                    transactionType == 'deposit' ? "Deposit Now" : "Withdraw Now",
                    style: const TextStyle(
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
