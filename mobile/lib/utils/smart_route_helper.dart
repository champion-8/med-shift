import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'number_formatter.dart';

class SmartRouteHelper {
  /// Calculate straight-line distance between two coordinates (Haversine formula)
  /// Returns distance in kilometers
  static double calculateDistance({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final dLat = _degreesToRadians(endLat - startLat);
    final dLng = _degreesToRadians(endLng - startLng);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(startLat)) *
            cos(_degreesToRadians(endLat)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Estimate travel time based on distance
  /// Returns estimated time in minutes
  /// Assumes average speed of 30 km/h in Bangkok traffic
  static int estimateTravelTime({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    double averageSpeed = 30.0, // km/h
  }) {
    final distance = calculateDistance(
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
    );

    final timeInHours = distance / averageSpeed;
    return (timeInHours * 60).ceil(); // Convert to minutes
  }

  /// Check if travel time is acceptable (within threshold)
  static bool isAcceptableTravelTime({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    int maxTravelMinutes = 120, // 2 hours default
  }) {
    final travelTime = estimateTravelTime(
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
    );

    return travelTime <= maxTravelMinutes;
  }

  /// Get travel information as a formatted string
  static String getTravelInfo({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    final distance = calculateDistance(
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
    );

    final travelTime = estimateTravelTime(
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
    );

    return '${NumberFormatter.formatNumber(distance)} km · ~$travelTime mins';
  }

  /// Calculate cost of travel (if using transportation)
  /// Basic calculation: 10 THB per km for motorcycle taxi
  static double estimateTravelCost({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    double costPerKm = 10.0,
  }) {
    final distance = calculateDistance(
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
    );

    return distance * costPerKm;
  }

  /// Get current location of the device
  static Future<Position?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get current position
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  /// Sort jobs by proximity to current location
  static List<T> sortByProximity<T>({
    required List<T> items,
    required double currentLat,
    required double currentLng,
    required double Function(T) getItemLat,
    required double Function(T) getItemLng,
  }) {
    final sortedItems = List<T>.from(items);

    sortedItems.sort((a, b) {
      final distanceA = calculateDistance(
        startLat: currentLat,
        startLng: currentLng,
        endLat: getItemLat(a),
        endLng: getItemLng(a),
      );

      final distanceB = calculateDistance(
        startLat: currentLat,
        startLng: currentLng,
        endLat: getItemLat(b),
        endLng: getItemLng(b),
      );

      return distanceA.compareTo(distanceB);
    });

    return sortedItems;
  }

  /// Convert degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }
}
