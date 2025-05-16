import 'package:flutter/material.dart';
import 'package:flowrite_banking/pages/Transfer.dart';
import 'package:flowrite_banking/pages/History.dart';
import 'package:flowrite_banking/pages/Settings.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flowrite_banking/pages/Transactions.dart';

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

class DashboardContent extends StatefulWidget {
  const DashboardContent({super.key});

  @override
  _DashboardContentState createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  UserData? userData;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      print("Current user: ${user?.uid}");

      if (user != null) {
        // Get user profile data
        final userDoc = await FirebaseFirestore.instance
            .collection('user-data')
            .doc(user.uid)
            .get();

        print("User document exists: ${userDoc.exists}");
        if (userDoc.exists) {
          print("User data: ${userDoc.data()}");
        }

        // Get bank account data
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
          final accountNumber = bankDoc.data()?['account-number'] ?? '1023-1000';
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
            errorMessage = "User data not found in Firestore";
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text("Error: $errorMessage", style: const TextStyle(color: Colors.white)))
          : Column(
        children: [
          // Card at the top
          Padding(
            padding: const EdgeInsets.fromLTRB(25.0, 20.0, 25.0, 0),
            child: CreditCard(userData: userData),
          ),

          // Welcome text below card and centered
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                const Text(
                  "Welcome back!",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                Text(
                  userData?.name ?? "User",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: const Column(
                children: [
                  SizedBox(height: 25),
                  HistoryList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int currentIndex = 0;

  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
    pages = [
      const DashboardContent(), // Use the separate content widget
      const TransactionPage(),
      const TransferPage(),
      const HistoryPage(),
      const SettingsPage(), // Placeholder for Setting
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: currentIndex == 0 ? const Color(0xFF204887) : Colors.white,
      body: Container(
        decoration: BoxDecoration(
          color: currentIndex == 0 ? const Color(0xFF204887) : Colors.white,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: pages[currentIndex],
      ),
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFFE8F2FF),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            tabItem(Icons.home, "Home", 0),
            tabItem(Icons.credit_card, "Money", 1),
            FloatingActionButton(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => const TransferPage()));
              },
              backgroundColor: const Color(0xFF007BA4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              child: const Icon(
                Icons.send,
                color: Colors.white,
              ),
            ),
            tabItem(Icons.history, "History", 3),
            tabItem(Icons.settings, "Settings", 4),
          ],
        ),
      ),
    );
  }

  Widget tabItem(IconData icon, String label, int index) {
    return IconButton(
      onPressed: () => onTabTapped(index),
      icon: Column(
        children: [
          Icon(
            icon,
            color: currentIndex == index ? const Color(0xFF204887) : const Color(0xFF7092CA),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: currentIndex == index ? Theme.of(context).primaryColor : const Color(0xFF7092CA)),
          )
        ],
      ),
    );
  }

  void onTabTapped(int index) {
    setState(() {
      currentIndex = index;
    });
  }
}

class HistoryList extends StatelessWidget {
  const HistoryList({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 25.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Today, Mar 28"),
                Row(
                  children: [
                    Text("All Transactions"),
                  ],
                ),
              ],
            ),
          ),
          const ListTile(
            leading: CircleAvatar(
              backgroundColor: Color.fromARGB(255, 239, 243, 245),
              child: Icon(
                Icons.gamepad,
                color: Color(0xFF47A1FF),
              ),
            ),
            title: Text("Steam"),
            subtitle: Text("Purchase"),
            trailing: Text(
              "-\₱450.00",
              // style: TextStyle(color: Colors.red),
            ),
          ),
          Divider(color: Colors.grey[200]),
          const ListTile(
            leading: CircleAvatar(
              backgroundColor: Color.fromARGB(255, 239, 243, 245),
              child: Icon(
                Icons.account_balance,
                color: Color(0xFF204887),
              ),
            ),
            title: Text("Banco De Oro"),
            subtitle: Text("Deposit"),
            trailing: Text(
              "+\₱5,789.00",
              style: TextStyle(color: Color(0xFF204887)),
            ),
          ),
          Divider(color: Colors.grey[200]),
          const ListTile(
            leading: CircleAvatar(
              backgroundColor: Color.fromARGB(255, 239, 243, 245),
              child: Icon(
                Icons.send,
                color: Color(0xFF007BA4),
              ),
            ),
            title: Text("To Arnel Victoria"),
            subtitle: Text("Sent"),
            trailing: Text(
              "-\₱760.00",
              // style: TextStyle(color: Colors.red),
            ),
          )
        ],
      ),
    );
  }
}

class CreditCard extends StatelessWidget {
  final UserData? userData;

  const CreditCard({super.key, this.userData});

  @override
  Widget build(BuildContext context) {
    // Format account number with asterisks
    String formattedAccountNumber = userData?.accountNumber ?? "**** **** **** 2534";
    if (formattedAccountNumber.length > 4) {
      String lastFour = formattedAccountNumber.substring(formattedAccountNumber.length - 4);
      formattedAccountNumber = "**** **** **** $lastFour";
    }

    // Format balance with commas
    String formattedBalance = '₱${_formatCurrency(userData?.balance ?? 50250.00)}';

    return Container(
        height: 220,
        width: 350,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  color: const Color.fromARGB(255, 14, 19, 29),
                  child: Stack(
                    children: [
                      Positioned(
                        bottom: 16,
                        left: 16,
                        child: Text(
                          formattedAccountNumber,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Container(
                  color: const Color(0xFF007BA4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formattedBalance,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white
                          ),
                        ),
                        Row(
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
                        )
                      ],
                    ),
                  ),
                ),
              )
            ],
          ),
        ));
  }

  String _formatCurrency(double amount) {
    // Convert to string and split by decimal point
    String amountStr = amount.toStringAsFixed(2);
    List<String> parts = amountStr.split('.');

    // Format the whole number part with commas
    String wholeNumber = parts[0];
    String result = '';

    for (int i = 0; i < wholeNumber.length; i++) {
      if (i > 0 && (wholeNumber.length - i) % 3 == 0) {
        result += ',';
      }
      result += wholeNumber[i];
    }

    // Add decimal part back
    return '$result.${parts[1]}';
  }
}
