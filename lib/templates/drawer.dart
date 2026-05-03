import 'package:flutter/material.dart';
import '../auth/auth.dart';
import '../donate.dart';

class UserDrawer extends StatefulWidget {
  const UserDrawer({
    super.key, 
    required this.username, 
    required this.user,
    required this.currentRoute,
  });

  final User user;
  final String username;
  final String currentRoute;

  @override
  State<UserDrawer> createState() => _UserDrawer();
}

class _UserDrawer extends State<UserDrawer> {
  GestureTapCallback drawerButton(String page, User user) {
    return () {
      setState(() {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pushNamed(page, arguments: {'user': widget.user});
      });
      Navigator.pop(context);
    };
  }

  Widget buildTile(BuildContext context, String title, String path, IconData icon) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: drawerButton(path, widget.user),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = widget.currentRoute;

    return Drawer(
      backgroundColor: const Color.fromRGBO(245, 245, 237, 1),
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(color: Color.fromRGBO(46, 165, 107, 1)),
            child: Text(
              'Hi ${widget.username}',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),

          buildTile(context, 'Your account', '/profile', Icons.account_circle),
          buildTile(context, 'Library', '/education', Icons.book),

          if (currentRoute == '/request-board')  ...[
            buildTile(context, 'Make an order', '/caretaker', Icons.add_shopping_cart),
            buildTile(context, 'Register as a Landholder', '/landowner-registration', Icons.person_add),
          ],

          if (currentRoute == '/caretaker')  ...[
            buildTile(context, 'View request board', '/request-board', Icons.list),
            buildTile(context, 'Register as a Landholder', '/landowner-registration', Icons.person_add),
          ],

          if (currentRoute == '/landowner')  ...[
            buildTile(context, 'View request board', '/request-board', Icons.list),
            buildTile(context, 'Make an order', '/caretaker', Icons.add_shopping_cart),
            buildTile(context, 'Register as a Landholder', '/landowner-registration', Icons.person_add),
          ],

          if (currentRoute == '/profile')  ...[
            buildTile(context, 'View request board', '/request-board', Icons.list),
            buildTile(context, 'Make an order', '/caretaker', Icons.add_shopping_cart),
            buildTile(context, 'Register as a Landholder', '/landowner-registration', Icons.person_add),
          ],

          Divider(),
          buildTile(context, 'Support / Donate', '/donate', Icons.volunteer_activism),
        ],
      ),
    );
  }
}
