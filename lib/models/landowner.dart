import 'landowner_browse.dart';
import 'landowner_days.dart';
import 'landowner_times.dart';

class Landowner {
  Landowner({
    required this.userID,
    required this.landownerName,
    required this.isActive,
    required this.timestamp,
    required this.browseData,
    required this.address,
    required this.suburb,
    this.accessDetails,
    required this.phone,
    required this.daysData,
    required this.timesData,
    required this.warningRequired,
    this.extraDetails,
    this.restrictions,
  });

  // ? Allows null
  // final means it can't be changed later
  final String userID;
  final String landownerName;
  bool isActive;
  final String timestamp;
  List<LandownerBrowse> browseData;
  String address;
  String suburb;
  String? accessDetails;
  String phone;
  List<LandownerDays> daysData;
  List<LandownerTimes> timesData;
  bool warningRequired;
  String? extraDetails;
  String? restrictions;

  // Helper method to create an empty request
  factory Landowner.empty() {
    return Landowner(
      userID: '',
      landownerName: '',
      isActive: false,
      timestamp: '',
      browseData: [],
      address: '',
      suburb: '',
      accessDetails: '',
      phone: '',
      daysData: [],
      timesData: [],
      warningRequired: false,
      extraDetails: '',
      restrictions: '',
    );
  }

  // Helper methods
  // Gets browse names as a list
  List<String> getBrowseNames() {
    return browseData.map((a) => a.browse_Name).toList();
  }

  // Gets days as a list
  List<String> getDays() {
    return daysData.map((a) => a.days).toList();
  }

  // Gets times as a list
  List<String> getTimes() {
    return timesData.map((a) => a.times).toList();
  }

  set updateState(bool newState) {
    isActive = newState;
  }

  static List<LandownerBrowse> _parseBrowseItems(dynamic itemsData) {
    if (itemsData == null || itemsData is! List<dynamic>) {
      return [];
    }

    return itemsData.map((item) {
      try {
        if (item is String) {
          return LandownerBrowse(browse_Name: item);
        } else {
          print('Wrong browse item type: ${item.runtimeType}');
          return LandownerBrowse(browse_Name: '');
        }
      } catch (e) {
        print('Error parsing browse item: $e');
        return LandownerBrowse(browse_Name: '');
      }
    }).toList();
  }

  static List<LandownerDays> _parseDayItems(dynamic itemsData) {
    if (itemsData == null || itemsData is! List<dynamic>) {
      return [];
    }

    return itemsData.map((item) {
      try {
        if (item is String) {
          return LandownerDays(days: item);
        } else {
          print('Wrong day item type: ${item.runtimeType}');
          return LandownerDays(days: '');
        }
      } catch (e) {
        print('Error parsing day item: $e');
        return LandownerDays(days: '');
      }
    }).toList();
  }

  static List<LandownerTimes> _parseTimeItems(dynamic itemsData) {
    if (itemsData == null || itemsData is! List<dynamic>) {
      return [];
    }

    return itemsData.map((item) {
      try {
        if (item is String) {
          return LandownerTimes(times: item);
        } else {
          print('Wrong time item type: ${item.runtimeType}');
          return LandownerTimes(times: '');
        }
      } catch (e) {
        print('Error parsing time item: $e');
        return LandownerTimes(times: '');
      }
    }).toList();
  }

  factory Landowner.fromJson(Map<String, dynamic> requestJson) {
    try {
      return Landowner(
        userID: requestJson['userID']?.toString() ?? '',
        landownerName: requestJson['landownerName']?.toString() ?? '',
        isActive: requestJson['isActive'] ?? '0',
        timestamp: requestJson['timestamp']?.toString() ?? '',
        browseData: _parseBrowseItems(requestJson['browseData']),
        address: requestJson['address']?.toString() ?? '',
        suburb: requestJson['suburb']?.toString() ?? '',
        accessDetails: requestJson['accessDetails']?.toString(),
        phone: requestJson['phone']?.toString() ?? '',
        daysData: _parseDayItems(requestJson['daysData']),
        timesData: _parseTimeItems(requestJson['timesData']),
        warningRequired: requestJson['warningRequired'] ?? '0',
        extraDetails: requestJson['extraDetails']?.toString(),
        restrictions: requestJson['restrictions']?.toString(),
      );
    } catch (e) {
      print('Error parsing Landowner: $e');
      return Landowner.empty();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'userID': userID,
      'landownerName': landownerName,
      'isActive': isActive,
      'timestamp': timestamp,
      'address': address,
      'suburb': suburb,
      'phone': phone,
      'warningRequired': warningRequired,
      'accessDetails': accessDetails,
      'extraDetails': extraDetails,
      'restrictions': restrictions,
      'browseData': browseData.map((e) => e.toJson()).toList(),
      'daysData': daysData.map((e) => e.toJson()).toList(),
      'timesData': timesData.map((e) => e.toJson()).toList(),
    };
  }
}