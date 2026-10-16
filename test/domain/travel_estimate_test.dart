import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/domain/usecases/travel_estimate.dart';

void main() {
  group('estimateTravel', () {
    test('uses the documented walking and vehicle speeds with the detour factor',
        () {
      const straight = 3000.0;
      final estimate = estimateTravel(straight);

      final road = straight * TravelSpeeds.detourFactor;
      final walkPerMinute = TravelSpeeds.walkKmh * 1000 / 60;
      final ridePerMinute = TravelSpeeds.vehicleKmh * 1000 / 60;
      expect(estimate.walkMinutes, (road / walkPerMinute).ceil());
      expect(estimate.rideMinutes, (road / ridePerMinute).ceil());
      expect(estimate.walkMinutes, greaterThan(estimate.rideMinutes));
    });

    test('speed constants stay in a believable range', () {
      expect(TravelSpeeds.walkKmh, inInclusiveRange(4.0, 5.5));
      expect(TravelSpeeds.vehicleKmh, inInclusiveRange(15, 35));
    });

    test('never rounds down to 0 minutes', () {
      final estimate = estimateTravel(0);
      expect(estimate.walkMinutes, 1);
      expect(estimate.rideMinutes, 1);
    });

    test('negative or NaN distance is treated as 0', () {
      expect(estimateTravel(-50).walkMinutes, 1);
      expect(estimateTravel(double.nan).walkMinutes, 1);
    });

    test('far away positions are flagged as not reliable', () {
      expect(estimateTravel(2000).isReliable, isTrue);
      expect(estimateTravel(TravelSpeeds.maxEstimateMeters).isReliable, isTrue);
      // The emulator default location in the US is ~14,000 km from Jakarta.
      expect(estimateTravel(13963200).isReliable, isFalse);
    });

    test('the vehicle is only suggested when walking is a real effort', () {
      expect(estimateTravel(200).showRide, isFalse);
      expect(estimateTravel(3000).showRide, isTrue);
    });
  });

  group('formatMinutes', () {
    test('short durations stay in minutes', () {
      expect(formatMinutes(1), '1 mnt');
      expect(formatMinutes(37), '37 mnt');
      expect(formatMinutes(59), '59 mnt');
    });

    test('long durations use hours', () {
      expect(formatMinutes(60), '1 j');
      expect(formatMinutes(65), '1 j 5 mnt');
      expect(formatMinutes(125), '2 j 5 mnt');
    });
  });

  group('formatEstimateLine', () {
    test('shows walk and vehicle on one compact line', () {
      final estimate = TravelEstimate(
        distanceMeters: 3000,
        walkMinutes: 37,
        rideMinutes: 5,
      );
      expect(
        formatEstimateLine(estimate),
        '37 mnt jalan kaki · 5 mnt naik kendaraan',
      );
    });

    test('drops the vehicle part for a short walk', () {
      final estimate = estimateTravel(250);
      expect(formatEstimateLine(estimate), contains('jalan kaki'));
      expect(formatEstimateLine(estimate), isNot(contains('kendaraan')));
    });

    test('is null when the distance is too large to estimate honestly', () {
      expect(formatEstimateLine(estimateTravel(13963200)), isNull);
    });

    test('never contains an em dash', () {
      expect(formatEstimateLine(estimateTravel(3000)), isNot(contains('—')));
    });
  });

  group('formatDistance', () {
    test('meters below 1 km', () {
      expect(formatDistance(450.4), '450 m');
      expect(formatDistance(0), '0 m');
    });

    test('kilometers use a decimal comma', () {
      expect(formatDistance(3120), '3,1 km');
      expect(formatDistance(1000), '1,0 km');
    });

    test('huge distances drop the decimals', () {
      expect(formatDistance(48200), '48 km');
    });
  });
}
