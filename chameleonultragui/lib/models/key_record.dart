import 'dart:typed_data';
import 'package:chameleonultragui/helpers/definitions.dart';

class KeyRecord {
  int? id;
  String uid;
  int sak;
  Uint8List atqa;
  String name;
  String address;
  int entrance;
  double? lat;
  double? lon;
  TagType tag;
  Uint8List data;
  Uint8List ats;
  Uint8List? signature;
  Uint8List? version;
  DateTime createdAt;
  DateTime updatedAt;

  KeyRecord({
    this.id,
    required this.uid,
    required this.sak,
    required this.atqa,
    required this.name,
    required this.address,
    required this.entrance,
    this.lat,
    this.lon,
    required this.tag,
    required this.data,
    required this.ats,
    this.signature,
    this.version,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'sak': sak,
      'atqa': atqa.toList(),
      'name': name,
      'address': address,
      'entrance': entrance,
      'lat': lat,
      'lon': lon,
      'tag': tag.value,
      'data': data.toList(),
      'ats': ats.toList(),
      'signature': signature?.toList(),
      'version': version?.toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory KeyRecord.fromMap(Map<String, dynamic> map) {
    return KeyRecord(
      id: map['id'] as int?,
      uid: map['uid'] as String,
      sak: map['sak'] as int,
      atqa: Uint8List.fromList(List<int>.from(map['atqa'])),
      name: map['name'] as String,
      address: map['address'] as String,
      entrance: map['entrance'] as int,
      lat: map['lat'] as double?,
      lon: map['lon'] as double?,
      tag: getTagTypeByValue(map['tag'] as int),
      data: Uint8List.fromList(List<int>.from(map['data'])),
      ats: Uint8List.fromList(List<int>.from(map['ats'])),
      signature: map['signature'] != null
          ? Uint8List.fromList(List<int>.from(map['signature']))
          : null,
      version: map['version'] != null
          ? Uint8List.fromList(List<int>.from(map['version']))
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  String toJson() {
    return '{"uid":"$uid","sak":$sak,"atqa":[${atqa.join(",")}],"name":"$name","address":"$address","entrance":$entrance,"lat":${lat ?? "null"},"lon":${lon ?? "null"},"tag":${tag.value},"data":[${data.join(",")}],"ats":[${ats.join(",")}]}';
  }

  double? distanceTo(double? toLat, double? toLon) {
    if (lat == null || lon == null || toLat == null || toLon == null) return null;
    return _calculateDistance(lat!, lon!, toLat, toLon);
  }

  static double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    double a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(lat1)) *
            _cos(_toRadians(lat2)) *
            _sin(dLon / 2) *
            _sin(dLon / 2);
    double c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * 3.141592653589793 / 180;
  static double _sin(double x) => _taylorSin(x);
  static double _cos(double x) => _taylorCos(x);
  static double _sqrt(double x) => _newtonSqrt(x);
  static double _atan2(double y, double x) => _taylorAtan2(y, x);

  static double _taylorSin(double x) {
    x = x % (2 * 3.141592653589793);
    double result = x;
    double term = x;
    for (int n = 1; n <= 10; n++) {
      term *= -x * x / ((2 * n) * (2 * n + 1));
      result += term;
    }
    return result;
  }

  static double _taylorCos(double x) {
    x = x % (2 * 3.141592653589793);
    double result = 1;
    double term = 1;
    for (int n = 1; n <= 10; n++) {
      term *= -x * x / ((2 * n - 1) * (2 * n));
      result += term;
    }
    return result;
  }

  static double _newtonSqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  static double _taylorAtan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atan(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 3.141592653589793 / 2;
    if (x == 0 && y < 0) return -3.141592653589793 / 2;
    return 0;
  }

  static double _atan(double x) {
    if (x > 1) return 3.141592653589793 / 2 - _atan(1 / x);
    if (x < -1) return -3.141592653589793 / 2 - _atan(1 / x);
    double result = x;
    double term = x;
    for (int n = 1; n <= 20; n++) {
      term *= -x * x;
      result += term / (2 * n + 1);
    }
    return result;
  }
}

  factory KeyRecord.fromMap(Map<String, dynamic> map) {
    return KeyRecord(
      id: map['id'] as int?,
      uid: map['uid'] as String,
      sak: map['sak'] as int,
      atqa: Uint8List.fromList(List<int>.from(map['atqa'])),
      name: map['name'] as String,
      address: map['address'] as String,
      entrance: map['entrance'] as int,
      lat: map['lat'] as double?,
      lon: map['lon'] as double?,
      tag: TagType.values[map['tag'] as int],
      data: Uint8List.fromList(List<int>.from(map['data'])),
      ats: Uint8List.fromList(List<int>.from(map['ats'])),
      signature: map['signature'] != null
          ? Uint8List.fromList(List<int>.from(map['signature']))
          : null,
      version: map['version'] != null
          ? Uint8List.fromList(List<int>.from(map['version']))
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  String toJson() {
    return '{"uid":"$uid","sak":$sak,"atqa":[${atqa.join(",")}],"name":"$name","address":"$address","entrance":$entrance,"lat":${lat ?? "null"},"lon":${lon ?? "null"},"tag":${tag.index},"data":[${data.join(",")}],"ats":[${ats.join(",")}]}';
  }

  double? distanceTo(double? toLat, double? toLon) {
    if (lat == null || lon == null || toLat == null || toLon == null) return null;
    return _calculateDistance(lat!, lon!, toLat, toLon);
  }

  static double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    double a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(lat1)) *
            _cos(_toRadians(lat2)) *
            _sin(dLon / 2) *
            _sin(dLon / 2);
    double c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * 3.141592653589793 / 180;
  static double _sin(double x) => _taylorSin(x);
  static double _cos(double x) => _taylorCos(x);
  static double _sqrt(double x) => _newtonSqrt(x);
  static double _atan2(double y, double x) => _taylorAtan2(y, x);

  static double _taylorSin(double x) {
    x = x % (2 * 3.141592653589793);
    double result = x;
    double term = x;
    for (int n = 1; n <= 10; n++) {
      term *= -x * x / ((2 * n) * (2 * n + 1));
      result += term;
    }
    return result;
  }

  static double _taylorCos(double x) {
    x = x % (2 * 3.141592653589793);
    double result = 1;
    double term = 1;
    for (int n = 1; n <= 10; n++) {
      term *= -x * x / ((2 * n - 1) * (2 * n));
      result += term;
    }
    return result;
  }

  static double _newtonSqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  static double _taylorAtan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atan(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 3.141592653589793 / 2;
    if (x == 0 && y < 0) return -3.141592653589793 / 2;
    return 0;
  }

  static double _atan(double x) {
    if (x > 1) return 3.141592653589793 / 2 - _atan(1 / x);
    if (x < -1) return -3.141592653589793 / 2 - _atan(1 / x);
    double result = x;
    double term = x;
    for (int n = 1; n <= 20; n++) {
      term *= -x * x;
      result += term / (2 * n + 1);
    }
    return result;
  }
}