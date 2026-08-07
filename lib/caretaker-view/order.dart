import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:change_case/change_case.dart';

import '../templates/drawer.dart';
import '../auth/auth.dart';

class CaretakerRoute extends StatelessWidget {
  final User user;
  const CaretakerRoute({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Order Request',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color.fromRGBO(245, 245, 237, 1),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromRGBO(46, 165, 107, 1)),
        useMaterial3: true,
      ),
      // Set username of caretaker here
      home: CaretakerHomePage(title: 'Order Request', user: user),
    );
  }
}

class DeliveryItem {
  final String browseName;
  final String browseAmount;
  final String amountType;
  bool isSelected;

  DeliveryItem({
    required this.browseName,
    required this.browseAmount,
    required this.amountType,

    this.isSelected = false,
  });
}

class CaretakerHomePage extends StatefulWidget {
  CaretakerHomePage({super.key, required this.title, required this.user});
  
  final String title;
  final User user;

  @override
  State<CaretakerHomePage> createState() => _CaretakerHomePageState();
}

class _CaretakerHomePageState extends State<CaretakerHomePage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormBuilderState>();
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = 
    GlobalKey<ScaffoldMessengerState>();

  // List of delivery items
  List<DeliveryItem> _deliveryItems = [];

  String selectedDrawerPage = '';

  GestureTapCallback drawerButton(String page) {
    return () {
      setState(() {
        selectedDrawerPage = page;
      });
      Navigator.pop(context);
    };
  }

  bool disabledOnAddItem = true;

  @override
  Widget build(BuildContext context) {
    const String appTitle = 'Order';
    final String username = widget.user.claims['given_name'].toString().toCapitalCase();

    return MaterialApp(
      theme: ThemeData(
        scaffoldBackgroundColor: const Color.fromRGBO(245, 245, 237, 1),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromRGBO(46, 165, 107, 1)),
        useMaterial3: true,
      ),
      title: appTitle,
      // SafeArea ensures that the view isn't obstructed by phone notch/status bar/bezel
      home: SafeArea(
        minimum: const EdgeInsets.all(12.0),
        child: ScaffoldMessenger(
          key: scaffoldMessengerKey,
          child: Scaffold(
            backgroundColor: const Color.fromRGBO(245, 245, 237, 1),
            appBar: AppBar(
              backgroundColor: Theme.of(context).colorScheme.inversePrimary,
              title: Text(appTitle),
            ),
            drawer: UserDrawer(
              username: username,
              user: widget.user,
              currentRoute: '/caretaker'
            ),
            body: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: FormBuilder(
                key: _formKey, 
                child: ListView(
                children: [
                  SizedBox(height:16),
                  FormBuilderTextField(
                    name: 'caretakerName',
                    initialValue: "${widget.user.claims['given_name'].toString().toCapitalCase()} ${widget.user.claims['family_name'].toString().toCapitalCase()}",
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
                    ),
                    validator: FormBuilderValidators.compose(
                        [
                          FormBuilderValidators.required(),
                          // Full name regex matches two or more words and handles cases such as O'Connor and Eastman-Smart
                          FormBuilderValidators.match(
                            RegExp(r"^[a-zA-Z]+([-' ][a-zA-Z]+)*\s+[a-zA-Z]+([-' ][a-zA-Z]+)*$"), 
                            errorText: 'Please enter your first and last name'
                          )
                        ]),
                    onChanged: (val) {
                        print(val); // Print the text value write into TextField
                    },
                  ),
                  SizedBox(height:16),
                  FormBuilderTextField(
                      name: 'address',
                      initialValue: widget.user.claims['custom:address'].toString().toCapitalCase(),
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
                      ),
                      validator: FormBuilderValidators.compose(
                          [
                            FormBuilderValidators.required(),
                            // Regex will pass following variations: 407/82 Hay St, A314/1 O'Brien Street, (LOT1022) 60 Johnston Rd, 17 Jump St, LOT1022 Johnston Rd, (LOT1022) Johnston Rd
                            // Regex uses negative lookaheads in the optional 1st group and 2nd group to not pass if there's a 0 in the format 0/1, A0/1, (LOT0000), LOT0000 or 0
                            // More advanced validation will require an API
                            FormBuilderValidators.street(regex: RegExp(r"^(?![A-Za-z]*0|\(?LOT0000)([a-zA-Z0-9\/\(\)]*)\s?(?!0)[1-9]*[0-9]*\s[a-zA-Z']+\s[a-zA-Z]+$")),
                            FormBuilderValidators.minWordsCount(3)
                          ]),
                      onChanged: (val) {
                          print(val); // Print the text value write into TextField
                      },
                  ),
                  SizedBox(height:16),
                  FormBuilderTextField(
                      name: 'suburb',
                      initialValue: "${widget.user.claims['custom:suburb']}",
                      decoration: const InputDecoration(
                        labelText: 'Suburb',
                        contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
                      ),
                      validator: FormBuilderValidators.compose(
                          [
                            FormBuilderValidators.required(),
                          ]),
                      onChanged: (val) {
                          print(val); // Print the text value write into TextField
                      },
                  ),
                  SizedBox(height:16),
                  FormBuilderTextField(
                    name: 'requestDetails',
                    decoration: const InputDecoration(
                      labelText: 'Please add additional requests to your request here (Optional)',
                      contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
                    ),
                    onChanged: (val) {
                        print(val); // Print the text value write into TextField
                    },
                  ),
                  SizedBox(height:16),
                  FormBuilderDropdown<String>(
                    name: 'animal_ID', 
                    initialValue: 'Ring-tailed Possum',
                    // Prevents changing of animal after a user clicks 'Add delivery item' button
                    enabled: disabledOnAddItem,
                    decoration: InputDecoration(
                      labelText: 'Animal',
                      hintText: 'Select Animal'
                    ),
                    items: ['Koala','Ring-tailed Possum', 'Brush-tailed Possum', 'Kangaroo', 'Wombat', 'Kookaburra']
                      .map((animal) => DropdownMenuItem(
                            alignment: AlignmentDirectional.center,
                            value: animal,
                            child: Text(animal),
                          ))
                      .toList(growable: false),
                    validator: FormBuilderValidators.compose(
                      [FormBuilderValidators.required()]
                    ),
                    onChanged: (selectedAnimal) {
                      print(selectedAnimal); // Print the text value write into TextField
                    },
                  ),
                  SizedBox(height:16),
                  FormBuilderDropdown<String>(
                    name: 'browseData', 
                    initialValue: 'Manna Gum (Eucalyptus viminalis)',
                    decoration: const InputDecoration(
                      labelText: 'Browse',
                      hintText: 'Select Browse'
                    ),
                    items: ['Tasmanian Blue Gum (Eucalyptus globulus)', 'Manna Gum (Eucalyptus viminalis)', 'Banksia','Callistemon', 'Camellia', 'Correa', 'Grevillea', 'Lilly Pilly', 'Mealworms']
                      .map((browse) => DropdownMenuItem(
                            alignment: AlignmentDirectional.center,
                            value: browse,
                            child: Text(browse),
                          ))
                      .toList(growable: false),
                    validator: FormBuilderValidators.compose(
                        [FormBuilderValidators.required()]
                    ),
                    onChanged: (val) {
                      print(val); // Print the text value write into TextField
                    },
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: 
                          FormBuilderTextField(
                            name: 'browseAmount',
                            initialValue: '1',
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              hintText: 'Enter amount of browse needed'
                            ),
                            validator: FormBuilderValidators.compose(
                                [
                                  FormBuilderValidators.required(),
                                  FormBuilderValidators.integer(),
                                  FormBuilderValidators.positiveNumber(),
                                  FormBuilderValidators.between(1, 50)
                                ]),
                            onChanged: (val) {
                                print(val); // Print the text value write into TextField
                            },
                        )
                      ),
                      Flexible(
                        child:
                        FormBuilderDropdown<String>(
                          name: 'amountType', 
                          initialValue: 'branch/es',
                          decoration: const InputDecoration(
                            labelText: 'Amount type',
                            hintText: 'Select quantity type'
                          ),
                          items: ['branch/es', 'bucket/s']
                            .map((amountType) => DropdownMenuItem(
                                  alignment: AlignmentDirectional.centerStart,
                                  value: amountType,
                                  child: Text(amountType),
                                ))
                            .toList(growable: false),
                          validator: FormBuilderValidators.compose(
                              [FormBuilderValidators.required()]
                          ),
                          onChanged: (val) {
                            print(val); // Print the text value write into TextField
                          },
                        )
                      )
                    ]
                  ),
                  ..._deliveryItems.map((item) {
                    // Returns a list of browse added so far to the order
                    return ListTile(
                      // Formats each DeliveryItem object in the deliveryItems list in a string format
                      title: Text("${item.browseName}: ${item.browseAmount} ${item.amountType}"),

                      trailing: Checkbox(
                        value: item.isSelected,
                        onChanged: (bool? newValue) {
                          setState(() {
                            item.isSelected = newValue!;
                          });
                        },
                      ),
                    );
                  }),
                  SizedBox(height: 8),
                  // Add delivery item button
                  ElevatedButton(
                    onPressed: () {
                          // This adds to the order request list - not sent to database yet
                          _addDeliveryItem();                   
                    },
                    child: Text('Add delivery item'),
                  ),
                  SizedBox(height: 8),
                  // Remove selected delivery item button
                  ElevatedButton(
                    onPressed: () {
                      if (_deliveryItems.isNotEmpty) {
                        setState(() {
                          // Removes all delivery items that are currently selected
                          _deliveryItems.removeWhere((item) => item.isSelected);
                        });
                      }
                    },
                    child: const Text('Remove selected items'),
                  ),
                  SizedBox(height: 32),
                  // Button to send data to the DynamoDB Server via AWS Gateway
                  ElevatedButton(
                    onPressed: () async {
                      _submitForm();
                    },
                    child: Text('Submit order'),
                  ),
                  SizedBox(height: 32),
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void showSnack(String title) {
    final snackbar = SnackBar(
      content: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.primary,
    );
    scaffoldMessengerKey.currentState!.showSnackBar(snackbar);
  }

  void _addDeliveryItem() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final formData = _formKey.currentState!.value;

      final newItem = DeliveryItem(
        browseName: formData['browseData'],
        browseAmount: formData['browseAmount'],
        amountType: formData['amountType'],
      );

      setState(() {
        disabledOnAddItem = false;
        _deliveryItems.add(newItem);
      });
    } else {
      debugPrint('Please select a browse, amount and a quantity type');
      debugPrint(
        'browseName: ${_formKey.currentState!.fields['browseData']},\nbrowseAmount: ${_formKey.currentState!.fields['browseAmount']},\namountType: ${_formKey.currentState!.fields['amountType']}'
      );
    }
  }

  void _submitForm() async {
    // Validates the fields including whether the delivery item list has an item in it
    if (_formKey.currentState!.validate() && _deliveryItems.isNotEmpty) {
      _formKey.currentState!.save();

      final formData = _formKey.currentState!.value;

      List<Map<String, dynamic>> items =
        _deliveryItems
            .map(
              (item) => {
                // TODO Browse names currently too long, will need to fix ListTiles in request.dart
                'name': item.browseName,
                // Quantity needs to be an int in database
                'quantity': int.parse(item.browseAmount),
                'type': item.amountType,
              },
            )
            .toList();

      final finalPayload = {
        ...formData,
        'request_ID': "Request_${DateTime.now().millisecondsSinceEpoch}",
        'timestamp': DateTime.now().toIso8601String(),
        "assigned_User_ID": null,
        'requester_ID': widget.user.claims['username'],
        'status_Num': 1,
        'delivery_items': items,
      };

      try {
        // Send HTTP POST request
        debugPrint(jsonEncode(finalPayload));
        final response = await http.post(
          Uri.parse('https://uuy1e4eofl.execute-api.us-east-1.amazonaws.com/requestsAPI'),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer ${widget.user.idToken}"
          },
          body: jsonEncode(finalPayload),
        );

        // Checks if request was successful (status code 201)
        if (response.statusCode == 201) {
          final responseData = jsonDecode(response.body);

          debugPrint('Request ${responseData['items']?[0]?['request_ID']} successfully sent');

          // Clear form once data sent successfully
          _formKey.currentState!.reset();
          
          // setState triggers a rebuild of the widget tree to update based on these updated variables 
          setState(() {
            // Re-enables animal field for a new order
            disabledOnAddItem = true;

            // Empties delivery items list for a new order
            _deliveryItems = [];
          });
          showSnack('Request order ${responseData['items']?[0]?['request_ID']} sent successfully');
        } else {
          debugPrint('Server error: ${response.statusCode}');
          debugPrint(response.body);
          showSnack('Something went wrong. Status code: ${response.statusCode}');
        }
      } catch (error) {
        debugPrint('Failed to send registration data: $error');
        showSnack('Something went wrong. Please try again. Error: $error');
      }
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Inputs Missing/Invalid'),
            content: Text('Please check all fields are filled out correctly.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

}