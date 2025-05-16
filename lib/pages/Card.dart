import 'package:flutter/material.dart';
import 'package:flowrite_banking/pages/Dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CardPage extends StatefulWidget {
  const CardPage({super.key});

  @override
  _CardPageState createState() => _CardPageState();
}

class _CardPageState extends State<CardPage> {
  UserData? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
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
          setState(() => isLoading = false);
        }
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton.outlined(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const DashboardPage()));
          },
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
          ),
        ),
        title: const Text(
          "Cards",
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // BackCard
              BackCard(userData: userData),
              const SizedBox(height: 25),
              // FrontCard
              FrontCard(userData: userData),
              const SizedBox(height: 30),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text(
                  "Add new card",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[100]!),
                    fixedSize: const Size(double.maxFinite, 55),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)
                    ),
                    backgroundColor: Colors.grey[100],
                    foregroundColor: Colors.black
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class FrontCard extends StatelessWidget {
  final UserData? userData;

  const FrontCard({super.key, this.userData});

  @override
  Widget build(BuildContext context) {
    // Format account number with asterisks
    String formattedAccountNumber = userData?.accountNumber ?? "**** **** **** 2534";
    if (formattedAccountNumber.length > 4) {
      String lastFour = formattedAccountNumber.substring(formattedAccountNumber.length - 4);
      formattedAccountNumber = "**** **** **** $lastFour";
    }

    return Container(
        height: 240,
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              userData?.name ?? 'User',
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white
                              ),
                            ),
                            const Text(
                              '3/25',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey
                              ),
                            ),
                          ],
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
}


class BackCard extends StatelessWidget {
  final UserData? userData;

  const BackCard({super.key, this.userData});

  @override
  Widget build(BuildContext context) {
    // Format account number with asterisks
    String formattedAccountNumber = userData?.accountNumber ?? "**** **** **** 2534";
    if (formattedAccountNumber.length > 4) {
      String lastFour = formattedAccountNumber.substring(formattedAccountNumber.length - 4);
      formattedAccountNumber = "**** **** **** $lastFour";
    }

    return Container(
      height: 240,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: const Color(0xFF204887)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
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
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedAccountNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                    const Text(
                      "11/16",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Text(
                  userData?.name ?? 'User',
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
