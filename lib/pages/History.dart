import 'package:flutter/material.dart';
import 'package:flowrite_banking/pages/Dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool isLoading = true;
  List<Map<String, dynamic>> transactions = [];
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // query transactions collection for the current user's transactions
        final querySnapshot = await FirebaseFirestore.instance
            .collection('transactions')
            .where('userId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true) // most recent first
            .get();

        final loadedTransactions = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
            'timestamp': data['timestamp'] != null
                ? (data['timestamp'] as Timestamp).toDate()
                : DateTime.now(),
          };
        }).toList();

        setState(() {
          transactions = loadedTransactions;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "No user is currently signed in";
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading transactions: $e');
      setState(() {
        errorMessage = "Error: $e";
        isLoading = false;
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

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton.outlined(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => DashboardPage()));
          },
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        title: const Text(
          "Activity",
          style: TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton.outlined(
            onPressed: () {
              // refresh transactions when the user taps this button
              _loadTransactions();
            },
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text("Error: $errorMessage"))
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(
                  3,
                      (index) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      width: 340,
                      height: 75,
                      decoration: BoxDecoration(
                        color: (index % 2 == 0) ? const Color(0xFF204887) : Color(0xFF007BA4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            const Text(
                              "Alipay Cards",
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            const Text(
                              "**** 2534",
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 12.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 15,
                                    backgroundColor: Colors.white.withOpacity(0.8),
                                  ),
                                  Transform.translate(
                                    offset: const Offset(-10, 0),
                                    child: CircleAvatar(
                                      radius: 15,
                                      backgroundColor: Colors.white.withOpacity(0.8),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "History",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  "${transactions.length} Transactions",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF007BA4),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Scrollable part - Transactions list
          transactions.isEmpty
              ? const Expanded(
            child: Center(
              child: Text(
                "No transactions found",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          )
              : Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final transaction = transactions[index];
                final isDeposit = transaction['type'] == 'deposit';
                final amount = (transaction['amount'] as num).toDouble();
                final date = transaction['timestamp'] as DateTime;
                final description = transaction['description'] as String? ??
                    (isDeposit ? 'Deposit' : 'Withdrawal');

                return Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: const Color.fromARGB(255, 239, 243, 245),
                        child: Icon(
                          isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                          color: isDeposit ? Colors.green : const Color(0xFF007BA4),
                        ),
                      ),
                      title: Text(
                        description,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(_formatDate(date)),
                      trailing: Text(
                        "${isDeposit ? '+' : '-'}${_formatCurrency(amount)}",
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: isDeposit ? Colors.green : Colors.black,
                        ),
                      ),
                    ),
                    if (index < transactions.length - 1)
                      Divider(color: Colors.grey[200]),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}