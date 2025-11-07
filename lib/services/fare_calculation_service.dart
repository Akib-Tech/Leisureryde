import 'dart:math';

class FareCalculationService {
  static const double _baseFare = 0.75;
  static const double _perMile = 0.7125;
  static const double _perMinute = 0.0975;
  static const double _minTripEarnings = 3.22;

  // Vehicle type multipliers (example)
  static const double _leisureComfortMultiplier = 1.0;
  static const double _leisurePlusMultiplier = 1.5; // e.g., 50% more expensive
  static const double _leisureExecMultiplier = 2.0; // e.g., 100% more expensive

  CalculatedFare calculateFare(int distanceInMeters, int durationInSeconds) {
    double distanceInMiles = distanceInMeters * 0.000621371;
    double durationInMinutes = durationInSeconds / 60;

    double standardFare = _baseFare +
        (distanceInMiles * _perMile) +
        (durationInMinutes * _perMinute);

    // Calculate fare for each vehicle type
    double comfortFare = standardFare * _leisureComfortMultiplier;
    double plusFare = standardFare * _leisurePlusMultiplier;
    double execFare = standardFare * _leisureExecMultiplier;

    return CalculatedFare(
      leisureComfort: max(comfortFare, _minTripEarnings),
      leisurePlus: max(plusFare, _minTripEarnings * _leisurePlusMultiplier),
      leisureExec: max(execFare, _minTripEarnings * _leisureExecMultiplier),
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
}