import 'package:flutter/material.dart';
import 'package:flowrite_banking/pages/Welcome.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.all(25),
              child: Text(
                "Profile",
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(0, 20, 0, 15),
              child: CircleAvatar(
                radius: 100,
                backgroundImage: AssetImage('assets/profileImage.webp'),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
                padding: EdgeInsets.fromLTRB(0, 20, 0, 15),
                child: Text(
                  "Diana Aurellano",
                  style: TextStyle(
                      color: Colors.grey[500],
                      fontWeight: FontWeight.bold,
                      fontSize: 24),
                )),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(15, 25, 15, 0),
              child: Column(
                // ignore: prefer_const_literals_to_create_immutables
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color.fromARGB(255, 239, 243, 245),
                      child: Icon(
                        Icons.person,
                        size: 22,
                        color: Color(0xFF007BA4),
                      ),
                    ),
                    title: Text("My Account"),
                    trailing: Icon(Icons.arrow_forward_ios),
                  ),
                  Divider(color: Colors.grey[200]),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color.fromARGB(255, 239, 243, 245),
                      child: Icon(
                        Icons.payment_outlined,
                        size: 22,
                        color: Color(0xFF007BA4),
                      ),
                    ),
                    title: Text("My Banking Details"),
                    trailing: Icon(Icons.arrow_forward_ios),
                  ),
                  Divider(color: Colors.grey[200]),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color.fromARGB(255, 239, 243, 245),
                      child: Icon(
                        Icons.group,
                        size: 22,
                        color: Color(0xFF007BA4),
                      ),
                    ),
                    title: Text("Referrer Program"),
                    trailing: Icon(Icons.arrow_forward_ios),
                  ),
                  Divider(color: Colors.grey[200]),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color.fromARGB(255, 239, 243, 245),
                      child: Icon(
                        Icons.question_answer,
                        size: 22,
                        color: Color(0xFF007BA4),
                      ),
                    ),
                    title: Text("FAQs"),
                    trailing: Icon(Icons.question_mark),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.all(15),
              child: ElevatedButton(
                style: ButtonStyle(
                    backgroundColor:
                    MaterialStateProperty.all<Color>(Color(0xFF204887)),),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => WelcomePage()));
                },
                child: Text(
                  "Log Out",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          )
        ],
      ));
  }
}