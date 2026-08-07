import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

import '../templates/drawer.dart';
import '../auth/auth.dart';

import '../models/landowner.dart';
import '../models/landowner_response.dart';

class LandownerRoute extends StatelessWidget {

  final User user;
  final List<String> browseFilter;
  // Added for snackbar handling
  final bool uploadSuccess;

 const LandownerRoute({super.key, required this.user, required this.browseFilter, this.uploadSuccess = false});
 
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Landholder Profiles',
      theme: ThemeData(
        listTileTheme: const ListTileThemeData(textColor: Colors.black),
        scaffoldBackgroundColor: const Color.fromRGBO(245, 245, 237, 1),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromRGBO(46, 165, 107, 1)),
        useMaterial3: true,
      ),
      // Set username of Gatherer here
      home: LandownerHomePage(title: 'Places to find browse', user: user, browseFilter: browseFilter, uploadSuccess: this.uploadSuccess),
    );
  }
}

class LandownerHomePage extends StatefulWidget {
  const LandownerHomePage({
    super.key,
    required this.title,
    required this.user,
    required this.browseFilter,
    this.uploadSuccess = false,
  });

  final String title;
  final User user;
  final List<String> browseFilter;
  final bool uploadSuccess;
  @override
  State<LandownerHomePage> createState() => _RequestBoardState();
}

Future<List<Landowner>> fetchRequests(User user) async {
  try {
    final response = await http.get(
      Uri.parse('https://uuy1e4eofl.execute-api.us-east-1.amazonaws.com/landownerAPI'),
      headers: {
        "Authorization": "Bearer ${user.idToken}"
      },
    );

    final Map<String, dynamic> responseData = json.decode(response.body);

    final LandOwnerResponse requestResponse = LandOwnerResponse.fromJson(responseData);
    if (response.statusCode == 200) {
      // Requests returned as an array
      return requestResponse.items; 

    } else {
      throw Exception('Failed to load requests: ${response.statusCode}');
    }
  } catch(e) {
    throw Exception('Error: $e');
  }
}

class _RequestBoardState extends State<LandownerHomePage>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  late Future<List<Landowner>> futureRequests;


  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    futureRequests = fetchRequests(widget.user);
    _fadeController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Start animations
    _fadeController.forward();
  }
  
  // Args passed from Request board initial state widget
  // String animal = animal.animal_Name
  // String browse = item.plant_Name
  // int quantity = item.quantity
  // String suburb = request.suburb
  Widget requestTile(Landowner request, User user) {
    bool isBrowseGTTwo = request.getBrowseNames().length > 2 ? true : false;

    return Hero(
      tag: request.userID,
      // Note if splash effects are needed, will need to change Card() to Material(), this will cause the margin to be lost
      child: Card(
        elevation: 4,
        child: ListTile(
          leading: CircleAvatar(
            backgroundImage: AssetImage(
              'assets/images/${request.userID}.jpg',
            ),
            radius: 20,
          ),
          title: Text('${request.landownerName.split(' ')[0]}\'s property'),
          subtitle: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gets the smallest of either the browses or 2 to ensure only a max of two browse are listed on the requestTile
                for (int i = 0; i < min(request.getBrowseNames().length, 2); i++)
                  Text(
                    (isBrowseGTTwo && i == 1)
                      ? '${request.getBrowseNames()[i]} +${request.getBrowseNames().length - 2} more'
                      : '${request.getBrowseNames()[i]}',
                    )
              ],
            ),
          trailing: Column(
            children: [
              // TODO have this track when request.isActive = false
              Text(
                "${formatTimelapse(getTimelapse(request.timestamp))} ago",
                style: isStale(getTimelapse(request.timestamp)) 
                  ? TextStyle(color: Colors.red)
                  : TextStyle(color: Colors.black)
              ),
              Text('Suburb: ${request.suburb}'),
          ]),
          tileColor: const Color.fromARGB(255, 246, 251, 244),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<Widget>(
                // Redirects from board to a landowner profile
                builder:
                    (BuildContext context) => LandownerProfile(
                      title: 'Landholder Profile',
                      request: request,
                    ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  // Landowner profiles overview board initial state
  Widget build(BuildContext context) {
    const String appTitle = 'Nearby places to find browse';
    final String username = widget.user.claims['given_name'];

    return MaterialApp(
      theme: ThemeData(
        listTileTheme: const ListTileThemeData(textColor: Colors.black),
        scaffoldBackgroundColor: const Color.fromRGBO(245, 245, 237, 1),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromRGBO(46, 165, 107, 1)),
        useMaterial3: true,
      ),
      title: appTitle,
      // SafeArea ensures that the view isn't obstructed by phone notch/status bar/bezel
      home: SafeArea(
        minimum: const EdgeInsets.all(12.0),
        child: Scaffold(
          backgroundColor: const Color.fromRGBO(245, 245, 237, 1),
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: Text(appTitle),
          ),
          drawer: UserDrawer(username: username, user: widget.user, currentRoute: '/landowner'),
          // Profile board area
          body: FutureBuilder<List<Landowner>>(
            
            future: futureRequests,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Center(child: Text('Snapshot Error: ${snapshot.error}'));
              }
              
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text('No requests found'));
              }
              if (widget.uploadSuccess == true)
                   {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Listing successfully created/updated!'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                });
              }
              

              List<Landowner> allListings = snapshot.data!;

              // Filter the listings before build
              // Returns any listings that match at least one of the browse in browseFilter and is currently active
              final List<Landowner> filteredListings = allListings.where((sublist) {
                return sublist.browseData.any((item) => widget.browseFilter.contains(item.getBrowseName())) && sublist.isActive;
              }).toList();

              // Sort listings by suburb name, prioritising the user's suburb when available.
              final String userSuburb = (widget.user.claims['custom:suburb'] ?? '').toString().toLowerCase();

              filteredListings.sort((a, b) {
                final String aSuburb = a.suburb.toLowerCase();
                final String bSuburb = b.suburb.toLowerCase();

                if (aSuburb == userSuburb && bSuburb != userSuburb) {
                  return -1;
                }
                if (aSuburb != userSuburb && bSuburb == userSuburb) {
                  return 1;
                }

                return aSuburb.compareTo(bSuburb);
              });

              // Empties the allListings array
              allListings.clear();

              return ListView.builder(
                itemCount: filteredListings.length,
                itemBuilder: (context, index) {
                  final request = filteredListings[index];
                  
                  return requestTile(request, widget.user);
                },
              );
            }
          ),
        ),
      ),
    );
  }
}

class LandownerProfile extends StatefulWidget {
  const LandownerProfile({
    super.key,
    required this.title,
    required this.request,
  });

  final String title;
  final Landowner request;
  
  @override
  State<LandownerProfile> createState() => _LandownerProfileState();
}

class _LandownerProfileState extends State<LandownerProfile> {
  bool _showAddress = false;
  bool _showPhone = false;

  Widget header(Landowner request) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 100,
          height: 100,
          child: Image(
            image: AssetImage('assets/images/${request.userID}.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'Property contact: ${request.landownerName}', // TODO Need to give proper padding
                style: TextStyle(color: Color.fromARGB(235, 16, 17, 17)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget browsePanel(browses) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: IntrinsicWidth(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.all(Radius.circular(15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                offset: Offset.zero,
                blurRadius: 4,
                spreadRadius: 3,
              ),
            ]
          ),
          child: Padding(
            padding: EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle(
                  style: TextStyle(
                    color: const Color.fromARGB(255, 230, 230, 230),
                  ),
                  child: Text(
                    "Browse Available",
                    style: TextStyle(
                      fontWeight: FontWeight.bold
                    ),
                  )
                ),
                for (int i = 0; i < widget.request.getBrowseNames().length; i++)
                  Text(
                    '${widget.request.getBrowseNames()[i]}',
                    style: TextStyle(color: Color.fromARGB(255, 230, 230, 230))
                    ),
              ],
            )
          )
        )
      )
    );
  }

  Widget landownerAddress(address, suburb) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place, size: 14),
              Text(
               "Landholder's address:",
                style: TextStyle(fontWeight: FontWeight.bold),
                ),
            ], 
          ),
          _showAddress
            ? SelectableText("$address, $suburb")
            // Will probably reimplement this to dynamically call for address once request accepted, for security
            // TODO lookup suburb for address once request accepted
            : SelectableText("(Revealed upon pressing contact below)\nSuburb: $suburb"),
        ]
      ),
    );
  }

  Widget phoneNumber(phone) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone_android_outlined, size: 14),
              Text(
                "Phone:",
                style: TextStyle(fontWeight: FontWeight.bold),
                ),
            ], 
          ),
          _showPhone
              ? Text("$phone")
              : Text("To contact the landholder, please click 'contact' below to reveal their phone number"),
        ]
      ),
    );
  }

  Widget visitingTimes(List<String> days, List<String> times) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.time_to_leave, size: 14),
              Text(
                "Days and times available:",
                style: TextStyle(fontWeight: FontWeight.bold),
                ),
            ], 
          ),
          Text('Days: ${days.join(' - ')}'),
          Text('Times: ${times.join(', ')}'),
          ],
        ),
      );
    }

  Widget accessDetails(String? details) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Column(
        // Need this to force left alignment of children
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.call_to_action_outlined, size: 14),
              Text(
                "Property access details:", 
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ], 
          ),
          Text(
            '$details',
            ),
        ]
      ),
    );
  }


  Widget extraDetails(String? details) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Column(
        // Need this to force left alignment of children
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 14),
              Text(
                "Extra details:", 
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ], 
          ),
          Text(
            '$details',
            ),
        ]
      ),
    );
  }

  Widget advanceWarning(preference) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Column(
        // Need this to force left alignment of children
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notification_add, size: 14),
              Text(
                "Advance warning needed?", 
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ], 
          ),
          Text(
            preference
            ? "Yes"
            : "No",
            ),
        ]
      ),
    );
  }

  Widget timelapse(request) {
    return Align(
      alignment: Alignment.centerLeft,
      child: RichText(
        text: TextSpan(
          children: [
            WidgetSpan(child: Icon(Icons.timelapse, size: 14)),
            // TODO use a timestamp here
            TextSpan(
              text: " Active ${formatTimelapse(getTimelapse(request.timestamp))} ago",
              style: isStale(getTimelapse(request.timestamp)) 
                ? TextStyle(color: Colors.red)
                : TextStyle(color: Colors.black)
            ),
          ],
        ),
      ),
    );
  }

  Widget contactButton(request) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Flexible(
          child: TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Color.fromARGB(218, 166, 247, 146),
              minimumSize: Size(101, 38),
              padding: EdgeInsets.symmetric(horizontal: 16),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(7)),
              ),
            ),
            onPressed: () {
              // Accept button action
              setState(() {
                _showAddress = true;
                _showPhone = true;
              });
            },
            child: Text(
              'Contact Landholder',
              style: TextStyle(color: Color.fromRGBO(0, 4, 7, 0.881)),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  // Builder for detail requests
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(245, 245, 237, 1),
      appBar: AppBar(title: Text('${widget.request.landownerName.split(' ')[0]}\'s profile')),
      // Detailed request view
      body: ListView(
        padding: EdgeInsets.only(left: 30.0),
        children: <Widget>[
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              header(widget.request),
              SizedBox(
                height: 20.0,
              ), 
              // TODO update phone to arg
              phoneNumber(widget.request.phone),
              const SizedBox(
                height: 15.0,
              ), // TODO May need to change this to a relative unit
              browsePanel(widget.request.getBrowseNames()),
              const SizedBox(
                height: 15.0,
              ),
              landownerAddress(widget.request.address, widget.request.suburb),
              const SizedBox(
                height: 10.0,
              ),
              timelapse(widget.request),
              const SizedBox(height: 10.0),
              visitingTimes(widget.request.getDays(), widget.request.getTimes()),
              const SizedBox(height: 10.0),
              accessDetails(widget.request.accessDetails),
              const SizedBox(height: 10.0),              
              advanceWarning(widget.request.warningRequired),
              const SizedBox(height: 10.0),
              extraDetails(widget.request.extraDetails),
              const SizedBox(height: 20.0),
              contactButton(widget.request),
              const SizedBox(height: 10.0),
            ],
          ),
        ],
      ),
    );
  }
}

String getTimelapse(requestTime) {
  // Will need to handle parsing better once dealing with different timezones, use toUTC or toLocal?
  DateTime parsedDate = DateTime.parse(requestTime);
  Duration difference = DateTime.now().difference(parsedDate);
  int parsedDifference = difference.inSeconds;

  int daysElapsed = parsedDifference ~/ (24 * 3600);
  int hoursElapsed = (parsedDifference % (24 * 3600)) ~/ 3600;
  int minutesElapsed = (parsedDifference % 3600) ~/ 60;

  String timelapse = '${daysElapsed}:${hoursElapsed}:${minutesElapsed}';

  return timelapse;
}

String formatTimelapse(timelapse) {
  List<int> timeParts = timelapse.split(":").map<int>((str) => int.parse(str)).toList();

  int daysElapsed = timeParts[0];
  int hourElapsed = timeParts[1];
  int minElapsed = timeParts[2];

  if(daysElapsed != 0) {
    timelapse = '${daysElapsed} days';
  } else {
    if(hourElapsed != 0) {
      timelapse = '${hourElapsed}h ${minElapsed}m';
      
    } else {
      timelapse = '${minElapsed}m';
    }
  }

  return timelapse;
}

bool isStale(timelapse) {

  List<int> timeParts = timelapse.split(":").map<int>((str) => int.parse(str)).toList();

  // timeParts[0] = Days elapsed
  return timeParts[0] > 90;
}
