import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Centralized map navigation launcher for opening external turn-by-turn directions.
Future<void> launchMapDirections(
  double latitude,
  double longitude, {
  String? label,
}) async {
  final encodedLabel = Uri.encodeComponent(label ?? 'Stasiun Target');
  
  // Platform specific & fallback URIs
  // 1. Google Navigation intent (direct to Navigation mode on Android)
  final googleNavUri = Uri.parse('google.navigation:q=$latitude,$longitude&mode=d');
  
  // 2. Google Maps Universal web/intent link in directions mode
  final googleDirUri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&destination_place_id=$encodedLabel',
  );

  // 3. Apple Maps / generic geo URI fallback
  final geoUri = Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude($encodedLabel)');

  try {
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (await canLaunchUrl(googleNavUri)) {
        await launchUrl(googleNavUri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (await canLaunchUrl(googleDirUri)) {
      await launchUrl(googleDirUri, mode: LaunchMode.externalApplication);
      return;
    }

    await launchUrl(geoUri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('Error launching map directions: $e');
    // Final fallback attempt directly forcing external browser/app for standard web maps link
    try {
      await launchUrl(googleDirUri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

/// Directions to a free-text destination query (e.g. an address or place
/// name the user typed in) rather than a known station's coordinates. Lets
/// Google Maps' own geocoder resolve [destinationQuery] — this app never
/// attempts its own address geocoding.
Future<void> launchMapDirectionsToQuery(
  double originLat,
  double originLng,
  String destinationQuery,
) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLng'
    '&destination=${Uri.encodeComponent(destinationQuery)}',
  );
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('Error launching map directions to query: $e');
  }
}
