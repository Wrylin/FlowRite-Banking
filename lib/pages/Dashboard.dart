import 'package:flutter/material.dart';
import 'package:flowrite_banking/pages/Transfer.dart';
import 'package:flowrite_banking/pages/Card.dart';
import 'package:flowrite_banking/pages/Transactions.dart';
import 'package:flowrite_banking/pages/Settings.dart';

class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Card at the top
          const Padding(
            padding: EdgeInsets.fromLTRB(25.0, 20.0, 25.0, 0),
            child: CreditCard(),
          ),

          // Welcome text below card and centered
          const SizedBox(height: 20),
          const Center(
            child: Column(
              children: [
                Text(
                  "Welcome back!",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                Text(
                  "Diana Aurellano",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold
                  ),
                ),
              ],
            ),
          ),
           SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: const Column(
                children: [
                  SizedBox(height: 25),
                  TransactionList(),
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

  final List<Widget> pages = [
    const DashboardContent(), // Use the separate content widget
    const CardPage(),
    const TransferPage(),
    const TransactionPage(),
    const SettingsPage(), // Placeholder for Setting
  ];

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
        color: Color(0xFFE8F2FF),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            tabItem(Icons.home, "Home", 0),
            tabItem(Icons.credit_card, "Cards", 1),
            FloatingActionButton(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => TransferPage()));
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
            color: currentIndex == index ? Color(0xFF204887) : Color(0xFF7092CA),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: currentIndex == index ? Theme
                .of(context)
                .primaryColor : Color(0xFF7092CA)),
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

class TransactionList extends StatelessWidget {
  const TransactionList({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListView(
        children:  [
          const  Padding(
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