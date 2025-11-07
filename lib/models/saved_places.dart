// In: lib/models/saved_place.dart

class SavedPlace {
  final String id;
  final String name; // e.g., 'Home', 'Work'
  final String address;
  final double latitude;
  final double longitude;

  SavedPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  factory SavedPlace.fromMap(String id, Map<String, dynamic> data) {
    return SavedPlace(
      id: id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}