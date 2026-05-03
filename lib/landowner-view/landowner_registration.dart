// TODO Get timestamp on submission, set state active and attach user's Cognito userID
// TODO Convert final formData to JSON object
// TODO add back button to top of registration to allow cancelling halfway through

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../auth/auth.dart';

class LandownerRegistration extends StatelessWidget {
  final User user;
  const LandownerRegistration({super.key, required this.user});

  @override
  Widget build(BuildContext context) {  
    return MaterialApp(
      title: 'Landholder registration',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color.fromRGBO(245, 245, 237, 1),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromRGBO(46, 165, 107, 1)),
        useMaterial3: true,
      ),
      home: LandownerFormTabs(user: user),
    );
  }
}

class LandownerFormTabs extends StatefulWidget {
  const LandownerFormTabs({super.key, required this.user});

  final User user;

  @override
  _LandownerFormTabs createState() => _LandownerFormTabs();
}

class _LandownerFormTabs extends State<LandownerFormTabs> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormBuilderState>();
  final _phoneFieldKey = GlobalKey<FormBuilderFieldState>();

  late TabController _tabController;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    setState(() {
      _currentTab = _tabController.index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(245, 245, 237, 1),
      appBar: AppBar(
        title: const Text('List your property for browse gathering'),
        backgroundColor: const Color.fromRGBO(245, 245, 237, 1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pushNamed(
              '/request-board',
              arguments: {'user': widget.user},
            );
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Land details'),
            Tab(text: 'Availability'),
            Tab(text: 'Preferences'),
          ],
        ),
      ),
      body: FormBuilder(
        key: _formKey,
        child: TabBarView(
          controller: _tabController,
          children: [
            LandDetailsTab(formKey: _formKey, phoneFieldKey: _phoneFieldKey),
            AvailabilityTab(formKey: _formKey, phoneFieldKey: _phoneFieldKey),
            PreferencesTab(formKey: _formKey, phoneFieldKey: _phoneFieldKey),
          ],
        ),
      ),
      floatingActionButton: _buildNavigationButtons(),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (_currentTab > 0)
          ElevatedButton(onPressed: _goToPreviousTab, child: const Text('Back')),
        const SizedBox(width: 10),
        if (_currentTab < 2)
          ElevatedButton(onPressed: _goToNextTab, child: const Text('Next')),
        if (_currentTab == 2)
          ElevatedButton(onPressed: _submitForm, child: const Text('Submit')),
      ],
    );
  }

  void _goToNextTab() {
    if (_formKey.currentState!.validate()) {
      _tabController.animateTo(_currentTab + 1);
    } else if (_currentTab == 1) {
      if (!_formKey.currentState!.fields['daysData']!.validate() ||
          !_formKey.currentState!.fields['timesData']!.validate()) {
      } else if (!_formKey.currentState!.fields['browseData']!.validate() ||
          !_formKey.currentState!.fields['address']!.validate() ||
          !_formKey.currentState!.fields['postcode']!.validate() ||
          !_formKey.currentState!.fields['phone']!.validate()) {
        _tabController.animateTo(_currentTab - 1);
      }
    }
  }

  void _goToPreviousTab() {
    _tabController.animateTo(_currentTab - 1);
  }

  void _submitForm() async {
    final user = widget.user;

    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final formData = _formKey.currentState!.value;

      final finalPayload = {
        ...formData,
        'userID': '${user.claims['username']}',
        'landownerName': '${widget.user.claims['given_name']} ${widget.user.claims['family_name']}',
        'isActive': 'True',
        'timestamp': DateTime.now().toIso8601String(),
      };

      try {
        // debugPrint(jsonEncode(finalPayload));
        final response = await http.post(
          Uri.parse('https://uuy1e4eofl.execute-api.us-east-1.amazonaws.com/landownerAPI'),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer ${user.idToken}"
          },
          body: jsonEncode(finalPayload),
        );
        
        // For debugging, you can print the response status and body
        // if (response.statusCode == 201) {
        //   final responseData = await jsonDecode(response.body);
        //   debugPrint('Registration created for userID: ${responseData['userID']}');
        // } else {
        //   debugPrint('Server error: ${response.statusCode}');
        //   debugPrint(response.body);
        // }
      } catch (error) {
        debugPrint('Failed to send registration data: $error');
      }

      Navigator.of(context, rootNavigator: true).pushNamed(
        '/request-board',
        arguments: {'user': user},
      );
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Inputs Missing/Invalid'),
            content: const Text('Please check all fields are filled out correctly.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      _tabController.animateTo(_currentTab - 2);
    }
  }
}

class LandDetailsTab extends StatefulWidget {
  final GlobalKey<FormBuilderState> formKey;
  final GlobalKey<FormBuilderFieldState> phoneFieldKey;

  const LandDetailsTab({required this.formKey, required this.phoneFieldKey, super.key});

  @override
  _LandDetailsTabState createState() => _LandDetailsTabState();
}

class _LandDetailsTabState extends State<LandDetailsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          FormBuilderCheckboxGroup<String>(
            name: 'browseData',
            decoration: const InputDecoration(
              labelText: 'What browse do you have on your property?',
              contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
            ),
            validator: FormBuilderValidators.compose([FormBuilderValidators.required()]),
            options: [
              'Banksia',
              'Callistemon',
              'Camellia',
              'Correa',
              'Manna Gum',
              'Blue Gum',
              'Grevillea',
              'Lilly Pilly'
            ]
                .map((browse) => FormBuilderFieldOption(value: browse, child: Text(browse)))
                .toList(growable: false),
            controlAffinity: ControlAffinity.leading,
            orientation: OptionsOrientation.wrap,
            onChanged: (val) => print(val),
          ),

          const SizedBox(height: 16),
          FormBuilderTextField(
            name: 'address',
            decoration: const InputDecoration(
              labelText: 'Address',
              contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
            ),
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(),
              FormBuilderValidators.street(),
            ]),
            onChanged: (val) => print(val),
          ),

          const SizedBox(height: 16),
          FormBuilderTextField(
            name: 'postcode',
            decoration: const InputDecoration(
              labelText: 'Postcode',
              contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
            ),
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(),
              FormBuilderValidators.integer(),
              FormBuilderValidators.equalLength(4),
              FormBuilderValidators.positiveNumber(),
            ]),
            onChanged: (val) => print(val),
          ),

          const SizedBox(height: 16),
          FormBuilderTextField(
            name: 'accessDetails',
            decoration: const InputDecoration(
              labelText: 'Please detail how to access your property (optional)',
              hintText: 'e.g. Access via the front gate, follow the path to the right.',
              contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
            ),
            onChanged: (val) => print(val),
          ),

          const SizedBox(height: 16),
          FormBuilderTextField(
            key: widget.phoneFieldKey,
            name: 'phone',
            decoration: const InputDecoration(
              labelText: 'Phone number',
              contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
            ),
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(),
              FormBuilderValidators.phoneNumber(),
              FormBuilderValidators.equalLength(10),
            ]),
            onChanged: (val) => print(val),
          ),
        ],
      ),
    );
  }
}

class AvailabilityTab extends StatefulWidget {
  final GlobalKey<FormBuilderState> formKey;
  final GlobalKey<FormBuilderFieldState> phoneFieldKey;
  const AvailabilityTab({required this.formKey, required this.phoneFieldKey});

  @override
  _AvalabilityTabState createState() => _AvalabilityTabState();
}

class _AvalabilityTabState extends State<AvailabilityTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          FormBuilderCheckboxGroup<String>(
            name: 'daysData',
            decoration: const InputDecoration(
              labelText: 'What days is your property open to browsing?',
              contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
            ),
            validator: FormBuilderValidators.compose([FormBuilderValidators.required()]),
            options: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
                .map((value) => FormBuilderFieldOption(value: value, child: Text(value)))
                .toList(growable: false),
            controlAffinity: ControlAffinity.leading,
            orientation: OptionsOrientation.wrap,
            onChanged: (val) => print(val),
          ),

          const SizedBox(height: 16),
          FormBuilderCheckboxGroup<String>(
            name: 'timesData',
            decoration: const InputDecoration(
              labelText: 'What time of day are you open to browsing?',
              contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
            ),
            validator: FormBuilderValidators.compose([FormBuilderValidators.required()]),
            options: [
              'Morning (8am - 11am)',
              'Noon (11am - 1pm)',
              'Afternoon (1pm - 5pm)',
              'Evening (5pm - 8pm)'
            ]
                .map((value) => FormBuilderFieldOption(value: value, child: Text(value)))
                .toList(growable: false),
            controlAffinity: ControlAffinity.leading,
            orientation: OptionsOrientation.wrap,
            onChanged: (val) => print(val),
          ),
        ],
      ),
    );
  }
}

class PreferencesTab extends StatefulWidget {
  final GlobalKey<FormBuilderState> formKey;
  final GlobalKey<FormBuilderFieldState> phoneFieldKey;

  const PreferencesTab({required this.formKey, required this.phoneFieldKey});

  @override
  _PreferencesTabState createState() => _PreferencesTabState();
}

class _PreferencesTabState extends State<PreferencesTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const SizedBox(height: 16),
          FormBuilderRadioGroup<bool>(
            name: 'warningRequired',
            initialValue: true,
            decoration: const InputDecoration(
              labelText: 'Do you require advance warning from Gatherers on entering your land?',
              contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
            ),
            validator: FormBuilderValidators.compose([FormBuilderValidators.required()]),
            options: const [
              FormBuilderFieldOption(value: true, child: Text('Yes')),
              FormBuilderFieldOption(value: false, child: Text('No')),
            ],
            controlAffinity: ControlAffinity.leading,
            orientation: OptionsOrientation.wrap,
            onChanged: (val) => print(val),
          ),

          const SizedBox(height: 16),
          FormBuilderTextField(
            name: 'restrictions',
            decoration: const InputDecoration(
              labelText: 'Restrictions (optional)',
              hintText: 'e.g. Do not touch the gumtree near the north fence.',
              contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
            ),
            maxLines: 4,
            maxLength: 500,
            valueTransformer: (text) {
              final t = (text ?? '').trim();
              return t.isEmpty ? null : t;
            },
            onChanged: (val) {
              debugPrint(val);
            },
          ),

          const SizedBox(height: 16),
          FormBuilderTextField(
            name: 'extraDetails',
            decoration: const InputDecoration(
              labelText: 'Please add extra details here (optional)',
              hintText: 'Any specific instructions or notes for gatherers.',
              contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
            ),
            onChanged: (val) => print(val),
          ),
          const SizedBox(height: 16),
          FormBuilderCheckbox(
            name: 'privatePropertyAcknowledgement',
            title: const Text(
              'I acknowledge that the property I am registering is privately owned and not located on public or Crown land. '
              'I understand that only private properties may be listed on this platform.',
              style: TextStyle(fontSize: 14),
            ),
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.equal(
                true,
                errorText: 'You must accept this disclaimer to proceed.',
              ),
            ]),
          ),
        ],
      ),
    );
  }
}