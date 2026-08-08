import 'deliveryItems.dart';

Map<String, String> buildAddressClaimProjection(Map<String, dynamic> claims) {
  return {
    'suburb': (claims['custom:suburb'] ?? '').toString().trim(),
    'state': (claims['custom:state'] ?? '').toString().trim(),
    'streetNumber': (claims['custom:streetNumber'] ?? '').toString().trim(),
    'street': (claims['custom:street'] ?? '').toString().trim(),
    'postcode': (claims['custom:postcode'] ?? '').toString().trim(),

  };
}

String buildAddressSummaryFromClaims(Map<String, dynamic> claims) {
  final projection = buildAddressClaimProjection(claims);

  final streetNumber = projection['streetNumber'] ?? '';
  final street = projection['street'] ?? '';
  final suburb = projection['suburb'] ?? '';
  final state = projection['state'] ?? '';
  final postcode = projection['postcode'] ?? '';

  final fullAddress = <String>[];

  if (streetNumber.isNotEmpty) {
    fullAddress.add(streetNumber);
  }

  if (street.isNotEmpty) {
    fullAddress.add(street);
  }

  if (suburb.isNotEmpty) {
    fullAddress.add(suburb);
  }

  if (state.isNotEmpty) {
    fullAddress.add(state);
  }

  if (postcode.isNotEmpty) {
    fullAddress.add(postcode);
  }

  if (fullAddress.isEmpty) {

    return 'Error: No address found.';
  }

  return fullAddress.join(', ');
}

class Request {
  Request({
    required this.caretakerName,
    required this.suburb,
    required this.address,
    this.requestDetails,
    required this.request_ID,
    required this.timestamp,
    this.assigned_User_ID,
    required this.requester_ID,
    required this.status_Num,
    required this.delivery_items,
    required this.animal_ID,
  });

  final String caretakerName;
  final String suburb;
  final String address;
  final String? requestDetails;
  final String request_ID;
  final String timestamp;
  String? assigned_User_ID;
  final String requester_ID;
  int status_Num;
  final List<DeliveryItems> delivery_items;
  final String animal_ID;

  // Helper method to create an empty request
  factory Request.empty() {
    return Request(
      caretakerName: '',
      suburb: '',
      address: '',
      request_ID: '',
      timestamp: '',
      requester_ID: '',
      status_Num: 0,
      delivery_items: [],
      animal_ID: '',
    );
  }

  // Items helper methods
  List<String> getBrowseNames() {
    return delivery_items.map((a) => a.name).toList();
  }

  List<int> getBrowseQuantities() {
    return delivery_items.map((a) => a.quantity).toList();
  }

  List<String> getBrowseTypes() {
    return delivery_items.map((a) => a.type).toList();
  }

  int getState() {
    return status_Num;
  }

  set updateState(int newState) {
    status_Num = newState;
  }

  set assignGatherer(String? newState) {
    if (newState != null && newState.trim().isNotEmpty) {
      assigned_User_ID = newState;
    }
  }

  static List<DeliveryItems> _parseDeliveryItems(dynamic itemsData) {
    if (itemsData == null || itemsData is! List<dynamic>) {
      return [];
    }
  
    return itemsData.map((item) {
      try {
        return DeliveryItems.fromJson(item as Map<String, dynamic>);
      } catch (e) {
        print('/model/request _parseDeliveryItems: Error parsing delivery item: $e');
        // Return a empty DeliveryItems instance if parsing fails
        return DeliveryItems(name: 'Unknown Item', quantity: 0, type: 'branch/es');
      }
    }).toList();  }

  factory Request.fromJson(Map<String, dynamic> requestJson) {
    try {
      return Request(
        caretakerName: requestJson['caretakerName']?.toString() ?? '',
        suburb: requestJson['suburb']?.toString() ?? '',
        address: requestJson['address']?.toString() ?? '',
        requestDetails: requestJson['requestDetails']?.toString(),
        request_ID: requestJson['request_ID']?.toString() ?? '',
        timestamp: requestJson['timestamp']?.toString() ?? '',
        assigned_User_ID: requestJson['assigned_User_ID']?.toString(),
        requester_ID: requestJson['requester_ID']?.toString() ?? '',
        status_Num: (requestJson['status_Num'] as num?)?.toInt() ?? 0,
        delivery_items: _parseDeliveryItems(requestJson['delivery_items']),
        animal_ID: requestJson['animal_ID']?.toString() ?? '',
      );
    } catch (e) {
      print('/model/request Request.fromJson: Error parsing Request: $e');
      return Request.empty();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'request_ID': request_ID,
      'status_Num': status_Num,
      'caretakerName': caretakerName,
      'address': address,
      'suburb': suburb,
      'requestDetails': requestDetails,
      'timestamp': timestamp,
      'animal_ID': animal_ID,
      'assigned_User_ID': assigned_User_ID,
      'requester_ID': requester_ID,
      'delivery_items': delivery_items.map((e) => e.toJson()).toList(),
    };
  }
}