import 'package:url_launcher/url_launcher.dart';

class MapsHelper {
  /// Open Google Maps at coordinates (works on web + mobile).
  static Future<bool> openLocation({
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    final query = label == null || label.isEmpty
        ? '$latitude,$longitude'
        : Uri.encodeComponent('$label@$latitude,$longitude');
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    // Prefer geo: on native if available — fall back to https
    final geo = Uri.parse('geo:$latitude,$longitude?q=$query');
    if (await canLaunchUrl(geo)) {
      return launchUrl(geo, mode: LaunchMode.externalApplication);
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> openDirections({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
