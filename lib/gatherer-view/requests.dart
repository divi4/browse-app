import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';

import '../templates/drawer.dart';
import '../templates/browseList.dart';
import '../auth/auth.dart';
import '../auth/user_service.dart';
import '../auth/config.dart';

import '../models/request.dart';
import '../models/response.dart';

import 'package:change_case/change_case.dart';
import 'package:shared_preferences/shared_preferences.dart';


class GathererRoute extends StatelessWidget {

  final User user;
  const GathererRoute({super.key, required this.user});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Requests',
      theme: ThemeData(
        listTileTheme: const ListTileThemeData(textColor: Colors.black),
        scaffoldBackgroundColor: const Color.fromRGBO(245, 245, 237, 1),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromRGBO(46, 165, 107, 1)),
        useMaterial3: true,
      ),
      // Set username of Gatherer here
      home: GathererHomePage(title: 'Request Board', user: user),
    );
  }
}

class GathererHomePage extends StatefulWidget {
  const GathererHomePage({
    super.key,
    required this.title,
    required this.user,
  });

  final String title;
  final User user;

  @override
  State<GathererHomePage> createState() => _RequestBoardState();
}

Future<List<Request>> fetchRequests(User user) async {
  print('ID Token: ${user.idToken}');
  print('Access Token: ${user.accessToken}');
  try {
    final response = await http.get(
      Uri.parse('https://uuy1e4eofl.execute-api.us-east-1.amazonaws.com/requestsAPI'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${user.idToken}",
      },
    );

    final Map<String, dynamic> responseData = json.decode(response.body);

    final Response requestResponse = Response.fromJson(responseData);
    
    if (response.statusCode == 200) {
      // Requests returned as an array
      return requestResponse.items; 

    } else {
      throw Exception('Failed to load requests: ${response.statusCode} - ${response.body}');
    }
  } catch(e) {
    throw Exception('Error: $e');
  }
}

class _RequestBoardState extends State<GathererHomePage> with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  late Future<List<Request>>? futureRequests;

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadRequests();
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

  void _loadRequests() {
    setState(() {
      futureRequests = fetchRequests(widget.user);
    });
  }

  // Args passed from Request board initial state widget
  // String animal = animal.animal_Name
  // String browse = item.plant_Name
  // int quantity = item.quantity
  // int postcode = request.postcode
  Widget requestTile(Request request, User user, bool isWip) {
    Color tileColor;

    // CHANGED: Highlight requests created by the user 
    if (request.requester_ID == user.claims['username']) {
      tileColor = const Color.fromARGB(255, 173, 216, 230); // Light blue
    } else if (isWip) {
      tileColor = const Color.fromARGB(255, 255, 224, 156); // Orange-ish
    } else {
      tileColor = const Color.fromARGB(255, 246, 251, 244); // Default green-ish
    }

    return Hero(
      tag: request.request_ID,
      // Note if splash effects are needed, will need to change Card() to Material(), this will cause the margin to be lost
      child: Card(
        elevation: 4,
        child: ListTile(
          leading: CircleAvatar(
            // Split and join the animal string so we can avoid 'space in path' issues when searching the image
            backgroundImage: AssetImage(
              'assets/images/${request.animal_ID.toLowerCase().split(" ").join("-")}.jpg',
            ),
            radius: 20,
          ),
          title: Text(request.animal_ID),
          subtitle: BrowseTileList(browses: request.getBrowseNames(), quantities: request.getBrowseQuantities()),
          trailing: Column(
            children: [
              Text(
                "${formatTimelapse(getTimelapse(request.timestamp))} ago",
                style: isStale(getTimelapse(request.timestamp)) 
                  ? TextStyle(color: Colors.red)
                  : TextStyle(color: Colors.black)
              ),
              Text('Postcode: ${request.postcode}'),
          ]),
          tileColor: tileColor,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<Widget>(
                // Redirects from board to a detailed request page
                builder:
                    (BuildContext context) => DetailedRequest(
                      title: 'Request Details',
                      request: request,
                      user: user,
                    ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  // Request board initial state
  Widget build(BuildContext context) {
    // *************************************
    // JSON parsed and variables initialised
    // Set json file to parse here
    // Args across gatherer's side of app are updated from here
    // *************************************
    // Request = jsonToObject(testRequestJson); // Pass the Json, returning a 3 objects, request, item and animal

    const String appTitle = 'Requests';
    final String username = widget.user.claims['given_name'].toString().toCapitalCase();
    // TODO iterate over requests here

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
            // Icon to move to caretaker order request page
            actions: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                tooltip: 'Make a order request',
                onPressed: () {
                  Navigator.of(
                    context,
                    rootNavigator: true,
                  ).pushNamed(
                    '/caretaker', 
                    arguments: {'user': widget.user},
                    );
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit_location_outlined),
                tooltip: 'List/Register a listing',
                onPressed: () {
                  Navigator.of(
                    context,
                    rootNavigator: true,
                  ).pushNamed(
                    '/landowner-registration', 
                    arguments: {'user': widget.user},
                    );
                },
              ),
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Explore browse',
                onPressed: () {
                  Navigator.of(
                    context,
                    rootNavigator: true,
                  ).pushNamed(
                    '/education'
                    );
                },
              ),
            ],
          ),
          drawer: UserDrawer(username: username, user: widget.user,),
          // Request board area
          body: FutureBuilder<List<Request>>(
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
              
              List<Request> allRequests = snapshot.data!;

              // Filter the requests before build
              final filteredRequests = allRequests.where((request) {
                final currentUser =  widget.user.claims['username'] ?? '';
                final isUserAssigned = request.assigned_User_ID == currentUser;

                return isActive(request.status_Num) || isUserAssigned;
              }).toList();

              // Sorts listing by postcode low to high after subtracting user's postcode
              // This assumes that the lowest postcode number to the user is actually closest geographically
              int userLocation = int.parse(widget.user.claims['custom:postcode']);
              filteredRequests.sort((a,b) {
                int c = max(a.postcode, userLocation) - min(a.postcode, userLocation);
                int d = max(b.postcode, userLocation) - min(b.postcode, userLocation);
                return c.compareTo(d);
              });

              // Moves requests that are WIP (status_Num = 2) to top of list above posted requests (status_Num = 1)
              filteredRequests.sort((a,b) {
                return b.status_Num.compareTo(a.status_Num);
              });

              return ListView.builder(
                itemCount: filteredRequests.length,
                itemBuilder: (context, index) {
                  final request = filteredRequests[index];
                  final isWip = !isActive(request.status_Num);
                  
                  return requestTile(request, widget.user, isWip);
                },
              );
            }
          ),
        ),
      ),
    );
  }
}

class DetailedRequest extends StatefulWidget {
  const DetailedRequest({
    super.key,
    required this.title,
    required this.request,
    required this.user,
  });

  final String title;
  final Request request;
  final User user;
  
  @override
  State<DetailedRequest> createState() => _DetailedRequestState();
}

class _DetailedRequestState extends State<DetailedRequest> {

Future<void> _maybeShowOfflineNotice() async {
  final prefs = await SharedPreferences.getInstance();
  final shown = prefs.getBool('offlineNoticeShown') ?? false;

  if (!shown) {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Offline reminder'),
          content: const Text(
            'Please screenshot this request and the relevant landholder listings and browse pages. '
            'Some images may not load without mobile reception when gathering browse.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    await prefs.setBool('offlineNoticeShown', true);
  }
}

  Future<void> _maybeShowEnvironmentalCareNotice() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('environmentalCareNoticeShown') ?? false;

    if (!shown) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Gather responsibly'),
            content: const Text(
              'Please respect the integrity of the plants by taking only what is necessary so the plant can regenerate. '
              'Clean and disinfect your tools and bags before and after gathering to avoid spreading plant diseases or pests.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      await prefs.setBool('environmentalCareNoticeShown', true);
    }
  }

  Widget header(Request request) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 100,
          height: 100,
          child: Image(
            // Split and join the animal string so we can avoid 'space in path' issues when searching the image
            image: AssetImage('assets/images/${request.animal_ID.toLowerCase().split(" ").join("-")}.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'Animal: ${request.animal_ID}', // TODO Need to give proper padding
                style: TextStyle(
                  color: Color.fromARGB(235, 16, 17, 17),
                  fontWeight: FontWeight.bold,
                  ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'Caretaker: ${request.caretakerName}', // TODO Need to give proper padding
                style: TextStyle(
                  color: Color.fromARGB(235, 16, 17, 17),
                  fontWeight: FontWeight.bold,
                  ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget disclaimer() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orangeAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        label: const Text(
          'Legal Disclaimer',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Important Legal Notice'),
                content: const Text(
                  'Gatherers are reminded that browse must only be collected '
                  'from private property with the owner’s permission. '
                  'Collecting from Crown land (public or state land) is illegal '
                  'and may result in legal action.\n\n'
                  'Always verify property ownership and obtain consent before gathering.',
                ),
                actions: [
                  TextButton(
                    child: const Text('I Understand'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget browsePanel(browses, quantities, types) {
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
                    "Browse Needed",
                    style: TextStyle(
                      fontWeight: FontWeight.bold
                    ),
                  )
                ),
                BrowseQuantityList(browses: browses, quantities: quantities, types: types, fontColor:Color.fromARGB(255, 230, 230, 230)),
              ],
            )
          )
        )
      )
    );
  }

  Widget requestDetails(details) {
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
                "Request Details:", 
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ], 
          ),
          Text(
            details,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              inherit: false,
              ),
            ),
        ]
      ),
    );
  }

  Widget deliveryAddress(address, postcode) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place, size: 14),
              Text(
                "Delivery address:",
                style: TextStyle(fontWeight: FontWeight.bold),
                ),
            ], 
          ),
          isShowAddress(widget.request, widget.user)
            ? SelectableText("$address, $postcode")
            : SelectableText("Postcode: $postcode"),
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
            TextSpan(
              text: " Submitted ${formatTimelapse(getTimelapse(request.timestamp))} ago",
              style: isStale(getTimelapse(request.timestamp)) 
                ? TextStyle(color: Colors.red)
                : TextStyle(color: Colors.black)
            ),
          ],
        ),
      ),
    );
  }

  Widget requestButtons(request) {
    return Padding(
      padding: EdgeInsets.fromLTRB(15, 0, 15, 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
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
              onPressed: () async {
                await _maybeShowOfflineNotice(); 
                await _maybeShowEnvironmentalCareNotice();
                
                setState(() {
                  request.assignGatherer = widget.user.claims['username'];
                  request.updateState = 2;
                  
                  // Sends updated request to database        
                  updateRequest(request);
                  });
                  },
              child: Text(
                'Accept',
                style: TextStyle(color: Color.fromRGBO(0, 4, 7, 0.881)),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Flexible(
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Color.fromARGB(218, 250, 250, 250),
                side: BorderSide(color: Colors.black12),
                minimumSize: Size(101, 38),
                padding: EdgeInsets.symmetric(horizontal: 16),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(7)),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'Close',
                style: TextStyle(color: Color.fromRGBO(0, 4, 7, 0.881)),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget showListings(browseFilter) {
    return TextButton.icon(
      icon: const Icon(Icons.edit_location_outlined),
      label: Text('See nearby browse'),
      onPressed: () {
          Navigator.of(
            context,
            rootNavigator: true,
          ).pushNamed(
            '/landowner', 
            arguments: {'user': widget.user, 'browseFilter': browseFilter},
            );
        },
      );
  }

  // Builder for detail requests
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(245, 245, 237, 1),
      appBar: AppBar(title: Text('${widget.request.animal_ID} request')),
      // Detailed request view
      body: ListView(
        padding: EdgeInsets.only(left: 30.0),
        children: <Widget>[
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              header(widget.request),
              const SizedBox(height: 10.0), // TODO May need to change this to a relative unit
              disclaimer(),
              const SizedBox(height: 10.0),
              browsePanel(widget.request.getBrowseNames(), widget.request.getBrowseQuantities(), widget.request.getBrowseTypes()),
              const SizedBox(height: 10.0),
              Align(
                alignment: Alignment.bottomLeft,
                child: IntrinsicWidth(
                  child: Container(
                    decoration: BoxDecoration(
                    color: Color.fromARGB(255, 247, 234, 118),
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
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          deliveryAddress(widget.request.address.toString().toCapitalCase(), widget.request.postcode),
                          const SizedBox(height: 10.0),
                          widget.request.requestDetails != null ? requestDetails(widget.request.requestDetails): Container(),
                          const SizedBox(height: 10.0),
                          timelapse(widget.request),
                        ]
                      )
                    )
                  ),
                ),
              ),
              const SizedBox(height: 20.0),
              // Checks if the user viewing isn't the creator of the request and that the request isn't WIP, if both true then show the accept button
              (widget.user.claims['username'] != widget.request.requester_ID) && (widget.request.status_Num != 2) ? requestButtons(widget.request): Container(),
              // Checks if the user viewing isn't the creator of the reuqest and that the request IS a WIP, if both true then show landholders with the browse listed on request
              (widget.user.claims['username'] != widget.request.requester_ID) && (widget.request.status_Num == 2) ? showListings(widget.request.getBrowseNames()): Container(),
            ],
          ),
        ],
      ),
    );
  }
}

// Could prob shorten this
bool isActive(state) {
  if(state == 1) {
    return true;
  } else {
    return false;
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
  // timeParts[1] = Hours elapsed
  return timeParts[0] > 0 || timeParts[1] > 15;
}

void updateRequest(Request updatedRequest) async {
  try {
    final response = await http.patch(
      Uri.parse(
        'https://uuy1e4eofl.execute-api.us-east-1.amazonaws.com/requestsAPI/${updatedRequest.request_ID}/2'
        ),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(updatedRequest.toJson()),
    );
    final responseData = jsonDecode(response.body);
    // Checks if request was successful (status code 201)
    if (response.statusCode == 200) {
      print(
        'Update successfully updated $responseData',
      );
    } else {
      print('Server Error: ${response.statusCode}');
      debugPrint(response.body);
    }
  } 
  catch(e) {
    print('Failed to update request: $e');
  }
}

bool isShowAddress(Request request, User user) {
  // Checks if the user is the one that is working on the request
  if(!isActive(request.status_Num) && user.claims['username'] == request.assigned_User_ID) {
    return true;
  }
  // Checks if the user is the one that created the request
  if (user.claims['username'] == request.requester_ID) {
    return false;
  }  
  else {
    return false;
  }
}