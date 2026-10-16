import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/domain/entities/social_models.dart';
import 'package:teman_kereta/features/forum/presentation/forum_format.dart';
import 'package:teman_kereta/features/forum/presentation/forum_models.dart';
import 'package:teman_kereta/features/forum/presentation/widgets/mentions.dart';

void main() {
  group('compactCount', () {
    test('keeps small numbers as they are', () {
      expect(compactCount(0), '0');
      expect(compactCount(950), '950');
      expect(compactCount(999), '999');
    });

    test('uses rb with one decimal under 10 rb', () {
      expect(compactCount(1000), '1 rb');
      expect(compactCount(1250), '1,2 rb');
      expect(compactCount(9999), '9,9 rb');
    });

    test('drops the decimal from 10 rb and never rounds into jt', () {
      expect(compactCount(10000), '10 rb');
      expect(compactCount(15400), '15 rb');
      expect(compactCount(999999), '999 rb');
    });

    test('uses jt for millions', () {
      expect(compactCount(1000000), '1 jt');
      expect(compactCount(2300000), '2,3 jt');
    });
  });

  group('forumAuthorLabel', () {
    test('falls back to a generic name without an author', () {
      final label = forumAuthorLabel(null);
      expect(label.name, 'Pengguna Teman Kereta');
      expect(label.handle, isNull);
    });

    test('shows display name and @username together', () {
      final label = forumAuthorLabel(
        const UserSummary(id: '1', username: 'siti_r', displayName: 'Siti'),
      );
      expect(label.name, 'Siti');
      expect(label.handle, '@siti_r');
    });

    test('does not repeat the handle when there is no display name', () {
      final label = forumAuthorLabel(
        const UserSummary(id: '1', username: 'siti_r', displayName: '  '),
      );
      expect(label.name, '@siti_r');
      expect(label.handle, isNull);
    });
  });

  group('sanitizeSearchQuery', () {
    test('removes characters that break a PostgREST filter', () {
      expect(sanitizeSearchQuery('a,b(c)%d*'), 'a b c  d');
      expect(sanitizeSearchQuery('  budi  '), 'budi');
    });
  });

  group('ForumFeedFilter', () {
    test('starts inactive', () {
      expect(ForumFeedFilter.all.isActive, isFalse);
    });

    test('line and following-only combine and clear independently', () {
      final filter = ForumFeedFilter.all
          .withLine('bogor')
          .withFollowingOnly(value: true);
      expect(filter.lineId, 'bogor');
      expect(filter.followingOnly, isTrue);
      expect(filter.isActive, isTrue);

      final noLine = filter.withLine(null);
      expect(noLine.lineId, isNull);
      expect(noLine.followingOnly, isTrue);
      expect(noLine.isActive, isTrue);

      expect(noLine.withFollowingOnly(value: false), ForumFeedFilter.all);
    });

    test('compares by value', () {
      expect(
        const ForumFeedFilter(lineId: 'x'),
        const ForumFeedFilter(lineId: 'x'),
      );
      expect(
        const ForumFeedFilter(lineId: 'x') == const ForumFeedFilter(),
        isFalse,
      );
    });
  });

  group('splitMentions', () {
    test('splits plain text and mentions, preserving all text', () {
      const text = 'Halo @budi_k, KRL telat. cc @sinta';
      final segments = splitMentions(text);
      expect(segments.map((s) => s.text).join(), text);
      expect(
        segments.where((s) => s.username != null).map((s) => s.username),
        <String?>['budi_k', 'sinta'],
      );
    });

    test('ignores emails and handles that cannot exist', () {
      for (final text in <String>[
        'kirim ke mail@budi.com',
        'hai @ab',
        '@@xyz',
      ]) {
        expect(
          splitMentions(text).where((s) => s.username != null),
          isEmpty,
          reason: text,
        );
      }
    });

    test('returns one plain segment when there is no mention', () {
      final segments = splitMentions('Peron 3 penuh');
      expect(segments, hasLength(1));
      expect(segments.single.username, isNull);
    });
  });
}
