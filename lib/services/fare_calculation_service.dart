import 'dart:math';

class FareCalculationService {
  static const double _baseFare = 2.75;
  static const double _perMile = 1.25;           // Good base for Comfort
  static const double _perMinute = 0.28;
  static const double _bookingFee = 4.25;
  static const double _minTripEarnings = 6.50;

  // Vehicle type multipliers - optimized for Uber-like pricing
  static const double _leisureComfortMultiplier = 1.0;
  static const double _leisurePlusMultiplier = 1.45;   // ~45% premium (realistic for Comfort/Plus tier)
  static const double _leisureExecMultiplier = 2.65;   // ~165% premium (closer to Uber Black / Exec)

  CalculatedFare calculateFare(int distanceInMeters, int durationInSeconds) {
    double distanceInMiles = distanceInMeters * 0.000621371;
    double durationInMinutes = durationInSeconds / 60;

    // Standard calculation + booking fee
    double standardFare = _baseFare +
        (distanceInMiles * _perMile) +
        (durationInMinutes * _perMinute) +
        _bookingFee;

    // Calculate fare for each vehicle type
    double comfortFare = standardFare * _leisureComfortMultiplier;
    double plusFare = standardFare * _leisurePlusMultiplier;
    double execFare = standardFare * _leisureExecMultiplier;

    return CalculatedFare(
      leisureComfort: max(comfortFare, _minTripEarnings),
      leisurePlus: max(plusFare, _minTripEarnings * 1.8),
      leisureExec: max(execFare, _minTripEarnings * 3.2),
    );
  }
}

class CalculatedFare {
  final double leisureComfort;
  final double leisurePlus;
  final double leisureExec;

  CalculatedFare({
    required this.leisureComfort,
    required this.leisurePlus,
    required this.leisureExec,
  });

  /// Retrieves the fare for a specific vehicle type.
  double getFareForVehicle(String vehicleType) {
    switch (vehicleType) {
      case 'Leisure Comfort':
        return leisureComfort;
      case 'Leisure Plus':
        return leisurePlus;
      case 'Leisure Exec':
        return leisureExec;
      default:
        return leisureComfort;
    }
  }
}