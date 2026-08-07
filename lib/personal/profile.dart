import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../templates/drawer.dart';
import '../auth/auth.dart';
import '../auth/config.dart';
import '../auth/user_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:change_case/change_case.dart';

import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../models/image.dart';
import 'dart:io';

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
      print('Error loading from S3: $e');
    }
  }

  void _onImageSelected(File? image) async {
    try {
      await s3Manager.putS3Image(widget.user.claims['picture']);
      await _loadProfileFromS3();
    } catch (e) {
      print('Error updating profile picture: $e');
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
      case 'custom:suburb':
        return FormBuilderValidators.compose([
          FormBuilderValidators.required(),
          FormBuilderValidators.match(
            RegExp(r"^[A-Za-z][A-Za-z\s'-]*$"),
            errorText: 'Please enter a suburb name',
          ),
        ]);
      case 'custom:address':
        return FormBuilderValidators.street(
          regex: RegExp(
            r"^(?![A-Za-z]*0|\(?LOT0000)([a-zA-Z0-9\/\(\)]*)\s?(?!0)[1-9]*[0-9]*\s[a-zA-Z']+\s[a-zA-Z]+$",
          ),
        );
      default:
        throw ('No validator available');
    }
  }

  @override
  Widget build(BuildContext context) {
    final String appTitle =
        '${widget.user.claims['given_name'].toString().toCapitalCase()}\'s profile';

    return MaterialApp(
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
                    onPressed: () {
                      ImagePickerWidget(
                        onImageSelected: _onImageSelected,
                      );
                    },
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
                        '${widget.user.claims['custom:address'].toString().toCapitalCase()}, ${widget.user.claims['custom:suburb'].toString().toCapitalCase()}'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      showEditDialogTwo('custom:address', 'custom:suburb', 'Address');
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
    print("Attributes updated successfully");
  } else {
    print("Attributes weren't updated");
  }
}