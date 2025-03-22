import 'package:flutter/material.dart';
import 'package:flowrite_banking/pages/Transfer.dart';
import 'package:flowrite_banking/pages/Card.dart';
import 'package:flowrite_banking/pages/Transactions.dart';
import 'package:flowrite_banking/pages/Profile.dart';

// Create a separate widget for the dashboard content
class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Welcome back!",
                      style: TextStyle(color: Colors.white),
                    ),
                    Text(
                      "Diana Aurellano ",
                      style: TextStyle(color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton.outlined(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.notifications,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 167),
                  color: Colors.white,
                  child: const Column(
                    children: [
                      SizedBox(height: 80),
                      //   ActionButtons
                      // ActionButtons(),
                      SizedBox(height: 30),
                      //   TransactionList
                      TransactionList()
                    ],
                  ),
                ),
                const Positioned(
                  top: 20,
                  left: 25,
                  right: 25,
                  child: CreditCard(),
                )
              ],
            ),
          )
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
    const ProfilePage(), // Placeholder for Profile
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: currentIndex == 0 ? const Color(0xFF204887) : Colors.white,
      body: pages[currentIndex],
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
            tabItem(Icons.person, "Profile", 4),
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
            title: Text("Gym"),
            subtitle: Text("Payment"),
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

