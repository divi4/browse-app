import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../templates/drawer.dart';
import '../auth/auth.dart';
import '../auth/config.dart';
import '../auth/user_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:change_case/change_case.dart';
import 'package:google_maps_places_autocomplete_widgets/address_autocomplete_widgets.dart';
import 'dart:convert';

import 'package:form_builder_validators/form_builder_validators.dart';

import '../models/image.dart';
import '../models/request.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ProfileRoute extends StatelessWidget {

  final User user;
  const ProfileRoute({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${user.claims['given_name'].toString().toCapitalCase()}\'s profile',
      theme: ThemeData(
        listTileTheme: const ListTileThemeData(textColor: Colors.black),
        scaffoldBackgroundColor: const Color.fromRGBO(245, 245, 237, 1),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromRGBO(46, 165, 107, 1)),
        useMaterial3: true,
      ),
      home: Profile(title: '${user.claims['given_name'].toString().toCapitalCase()}\'s profile', user: user),
    );
  }
}

class Profile extends StatefulWidget {
  const Profile({
    super.key,
    required this.title,
    required this.user,
  });

  final String title;
  final User user;

  @override
  State<Profile> createState() => _Profile();
}

class _Profile extends State<Profile> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _loadProfileFromS3();
  }

  final S3ImageManager s3Manager = S3ImageManager(
    region: 'us-east-1', 
    bucketName: 'profile-pictures33'
  );

  File? _profileImage;

  Future<void> _loadProfileFromS3() async {
    try {
      await s3Manager.getS3Image(widget.user.claims['picture']);
    } catch (e) {
      debugPrint('Error loading from S3: $e');
    }
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No image selected')),
        );
      }
      return;
    }

    final image = File(picked.path);
    setState(() {
      _profileImage = image;
    });

    await _onImageSelected(image);
  }

  Future<void> _onImageSelected(File? image) async {
    try {
      if (image != null) {
        await s3Manager.putS3Image(widget.user.claims['picture']);
        await _loadProfileFromS3();
      }
    } catch (e) {
      debugPrint('Error updating profile picture: $e');
    }
  }

  void showEditDialogOne(String key) {
    TextEditingController firstController = TextEditingController(
      text: key != 'birthdate' && key != 'picture' && key != 'email'
          ? widget.user.claims[key].toString().toCapitalCase()
          : widget.user.claims[key].toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${key.split('_').join(' ').toCapitalCase()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: firstController,
              decoration: InputDecoration(labelText: key.split('_').join(' ').toCapitalCase()),
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (oldValue, newValue) {
                    return key != 'birthdate' && key != 'picture' && key != 'email'
                        ? newValue.copyWith(text: newValue.text.toCapitalCase())
                        : newValue;
                  },
                )
              ],
              autovalidateMode: AutovalidateMode.always,
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.required(),
                getValidatorForKeys(key)
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              setState(() {
                widget.user.claims[key] = firstController.text.toLowerCase();
              });
              if (mounted) Navigator.pop(context);
              updateUserAttributes({key: firstController.text.toLowerCase()});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void showEditDialogTwo(String key1, String key2, String editDialog) {
    TextEditingController firstController =
        TextEditingController(text: widget.user.claims[key1].toString().toCapitalCase());
    TextEditingController secondController =
        TextEditingController(text: widget.user.claims[key2].toString().toCapitalCase());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $editDialog'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: firstController,
              decoration: InputDecoration(labelText: key1.split('_').join(' ').toCapitalCase()),
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (oldValue, newValue) =>
                      newValue.copyWith(text: newValue.text.toCapitalCase()),
                )
              ],
              autovalidateMode: AutovalidateMode.always,
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.required(),
                getValidatorForKeys(key1)
              ]),
            ),
            TextFormField(
              controller: secondController,
              decoration: InputDecoration(labelText: key2.split('_').join(' ').toCapitalCase()),
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (oldValue, newValue) =>
                      newValue.copyWith(text: newValue.text.toCapitalCase()),
                )
              ],
              autovalidateMode: AutovalidateMode.always,
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.required(),
                getValidatorForKeys(key2)
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              setState(() {
                widget.user.claims[key1] = firstController.text.toLowerCase();
                widget.user.claims[key2] = secondController.text.toLowerCase();
              });
              if (mounted) Navigator.pop(context);
              updateUserAttributes({
                key1: firstController.text.toLowerCase(),
                key2: secondController.text.toLowerCase(),
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ===== ADDRESS EDIT DIALOG WITH AUTOCOMPLETE =====
  void _showAddressEditDialog() {
    final TextEditingController addressController = TextEditingController();
    String selectedAddress = '';
    String selectedStreetNumber = '';
    String selectedStreet = '';
    String selectedSuburb = '';
    String selectedState = '';
    String selectedPostcode = '';

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Address'),
              content: SizedBox(
                width: MediaQuery.of(dialogContext).size.width * 0.9,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Start typing your address and select from the suggestions',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    AddressAutocompleteTextField(
                      mapsApiKey: 'AIzaSyCC1vW62OlRZFFo1skbh9q-zLVVkWKT484',
                      controller: addressController,
                      decoration: const InputDecoration(
                        hintText: 'Enter your address',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      componentCountry: 'au',
                      language: 'en',
                      onSuggestionClick: (Place placeDetails) {
                        setDialogState(() {
                          selectedAddress = placeDetails.formattedAddress ?? '';
                          selectedStreetNumber = placeDetails.streetNumber ?? '';
                          selectedStreet = placeDetails.street ?? '';
                          selectedSuburb = placeDetails.city ?? '';
                          selectedState = placeDetails.stateShort ?? '';
                          selectedPostcode = placeDetails.zipCode ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    if (selectedAddress.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Selected: $selectedAddress',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (selectedAddress.isNotEmpty) {
                      _updateUserAddress(
                        address: selectedAddress,
                        streetNumber: selectedStreetNumber,
                        street: selectedStreet,
                        suburb: selectedSuburb,
                        state: selectedState,
                        postCode: selectedPostcode,
                      );
                      Navigator.pop(dialogContext);
                    } else {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Please select a valid address from the suggestions'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _buildAddressSummary() {
    return buildAddressSummaryFromClaims(widget.user.claims);
  }

  // ===== UPDATE USER ADDRESS IN COGNITO =====
  Future<void> _updateUserAddress({
    required String address,
    required String streetNumber,
    required String street,
    required String suburb,
    required String state,
    required String postCode,
  }) async {
    // Build the full address string
    final fullAddress = '$streetNumber $street, $suburb, $state $postCode';

    try {
      // Show loading indicator using the app-level messenger key.
      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Updating address...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Update local claims first
      setState(() {
        widget.user.claims['address'] = fullAddress;
        widget.user.claims['custom:suburb'] = suburb;
        widget.user.claims['custom:state'] = state;
        widget.user.claims['custom:streetNumber'] = streetNumber;
        widget.user.claims['custom:street'] = street;
        widget.user.claims['custom:postcode'] = postCode;
      });

      // Update in Cognito
      await updateUserAttributes({
        'address': fullAddress,
        'custom:suburb': suburb,
        'custom:state': state,
        'custom:streetNumber': streetNumber,
        'custom:street': street,
        'custom:postcode': postCode,
      });

      // Save updated claims to local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_attributes_${widget.user.username}', json.encode(widget.user.claims));

      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Address updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating address: $e');
      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Failed to update address: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  FormFieldValidator<String> getValidatorForKeys(String key) {
    switch (key) {
      case 'birthdate':
        return FormBuilderValidators.datePast();
      case 'email':
        return FormBuilderValidators.email();
      case 'picture':
        return FormBuilderValidators.fileSize(5000000);
      case 'custom:role':
        return FormBuilderValidators.match(RegExp(r"^Gatherer$|^Caretaker$|^Landholder$"));
      case 'given_name':
        return FormBuilderValidators.firstName();
      case 'family_name':
        return FormBuilderValidators.lastName();
      default:
        throw ('No validator available');
    }
  }

  @override
  Widget build(BuildContext context) {
    final String appTitle =
        '${widget.user.claims['given_name'].toString().toCapitalCase()}\'s profile';

    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: ThemeData(
        listTileTheme: const ListTileThemeData(textColor: Colors.black),
        scaffoldBackgroundColor: const Color.fromRGBO(245, 245, 237, 1),
        colorScheme:
            ColorScheme.fromSeed(seedColor: const Color.fromRGBO(46, 165, 107, 1)),
        useMaterial3: true,
      ),
      title: appTitle,
      home: SafeArea(
        minimum: const EdgeInsets.all(12.0),
        child: Scaffold(
          backgroundColor: const Color.fromRGBO(245, 245, 237, 1),
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: Text(appTitle),
          ),
          drawer: UserDrawer(
            username: widget.user.claims['given_name'].toString().toCapitalCase(),
            user: widget.user,
            currentRoute: '/profile',
          ),

          // Profile body
          body: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                        'Name: ${widget.user.claims['given_name'].toString().toCapitalCase()} ${widget.user.claims['family_name'].toString().toCapitalCase()}'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      showEditDialogTwo('given_name', 'family_name', 'Name');
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text('Birthdate: ${widget.user.claims['birthdate']}'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      showEditDialogOne('birthdate');
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 200.0,
                      width: 300.0,
                      child: Center(
                        child: _profileImage != null
                            ? Image.file(_profileImage!)
                            : Image.asset('assets/images/default_profile_pic.jpg'),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: _pickProfileImage,
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text('Email: ${widget.user.claims['email']}'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      showEditDialogOne('email');
                    },
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    'Email verified? ${widget.user.claims['email_verified'].toString().toCapitalCase()}'),
              ),
              Row(
                children: [
                  const Icon(Icons.place, size: 14),
                  const Text(
                    "Your address: ",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: Text(
                      _buildAddressSummary(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      _showAddressEditDialog();
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                        'Role: ${widget.user.claims['custom:role'].toString().toCapitalCase()}'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      showEditDialogOne('custom:role');
                    },
                  ),
                ],
              ),

              // I added: show restrictions info for Landowner
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Card(
                  color: const Color.fromRGBO(240, 240, 235, 1),
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Restrictions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (widget.user.claims['restrictions'] == null ||
                                  widget.user.claims['restrictions'].toString().trim().isEmpty)
                              ? 'No restrictions provided.'
                              : widget.user.claims['restrictions']
                                  .toString()
                                  .toCapitalCase(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> updateUserAttributes(Map<String, String> attributes) async {
  final config = await loadConfig();
  final authService = UserPoolAuthService(config.userPoolID, config.clientID);
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? password = prefs.getString('password');

  final success = await authService.updateUserAttributes(attributes, password!);

  if (success) {
    debugPrint('Attributes updated successfully');
  } else {
    debugPrint("Attributes weren't updated");
  }
}