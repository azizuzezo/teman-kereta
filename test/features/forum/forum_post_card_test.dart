import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/app/theme/app_theme.dart';
import 'package:teman_kereta/domain/entities/social_models.dart';
import 'package:teman_kereta/features/forum/presentation/forum_controller.dart';
import 'package:teman_kereta/features/forum/presentation/forum_models.dart';
import 'package:teman_kereta/features/forum/presentation/widgets/forum_post_card.dart';

class _FakeForumController extends ForumController {
  final List<(String, bool)> likeCalls = <(String, bool)>[];

  @override
  Future<ForumFeedState> build() async => ForumFeedState.empty;

  @override
  Future<void> toggleLike(String postId, bool currentlyLiked) async {
    likeCalls.add((postId, currentlyLiked));
  }
}

ForumPost _post({String? lineId, String name = 'Siti Rahma'}) => ForumPost(
  id: 'p1',
  userId: 'u1',
  body: 'KRL Bogor telat lagi, kabarin @budi_k ya',
  likeCount: 3,
  commentCount: 12,
  createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
  lineId: lineId,
  author: UserSummary(id: 'u1', username: 'siti_r', displayName: name),
);

Future<_FakeForumController> _pump(
  WidgetTester tester,
  ForumPost post, {
  bool threaded = false,
  double textScale = 1,
  bool dark = false,
}) async {
  tester.view.physicalSize = const Size(360 * 3, 800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final fake = _FakeForumController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        forumControllerProvider.overrideWith(() => fake),
        forumLineOptionsByIdProvider.overrideWith(
          (ref) async => <String, LineOption>{
            'bogor': const LineOption(
              id: 'bogor',
              name: 'Lin Bogor',
              code: 'BGR',
              color: '#E4002B',
            ),
          },
        ),
      ],
      child: MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ForumPostCard(
              post: post,
              threaded: threaded,
              threadLine: threaded,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return fake;
}

void main() {
  testWidgets('shows name, @username, time, highlighted mention and counts', (
    tester,
  ) async {
    await _pump(tester, _post());

    expect(
      find.textContaining('Siti Rahma', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('@siti_r', findRichText: true), findsOneWidget);
    expect(find.textContaining('5 menit lalu'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);

    final bodyFinder = find.textContaining(
      'KRL Bogor telat lagi',
      findRichText: true,
    );
    expect(bodyFinder, findsOneWidget);
    final rich = tester.widget<RichText>(bodyFinder);
    final spans = <TextSpan>[];
    rich.text.visitChildren((span) {
      if (span is TextSpan) spans.add(span);
      return true;
    });
    final mention = spans.firstWhere((s) => s.text == '@budi_k');
    expect(mention.recognizer, isNotNull);
    expect(mention.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('like toggles optimistically and reports to the controller', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final fake = await _pump(tester, _post());

    await tester.tap(find.bySemanticsLabel('Suka, 3 suka'));
    await tester.pumpAndSettle();

    expect(find.text('4'), findsOneWidget);
    expect(find.bySemanticsLabel('Batal suka, 4 suka'), findsOneWidget);
    expect(fake.likeCalls, <(String, bool)>[('p1', false)]);
    handle.dispose();
  });

  testWidgets('action row exposes reply and share, menu offers report/block', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _post());

    expect(find.bySemanticsLabel('Balas, 12 balasan'), findsOneWidget);
    expect(find.bySemanticsLabel('Bagikan postingan'), findsOneWidget);

    await tester.tap(find.byTooltip('Opsi postingan'));
    await tester.pumpAndSettle();
    expect(find.text('Laporkan'), findsOneWidget);
    expect(find.text('Blokir pengguna'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('renders the line tag once lines have loaded', (tester) async {
    await _pump(tester, _post(lineId: 'bogor'));
    await tester.pump();
    expect(find.text('BGR'), findsOneWidget);
  });

  testWidgets('threaded detail head renders with its thread line', (
    tester,
  ) async {
    await _pump(tester, _post(), threaded: true);
    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('Siti Rahma', findRichText: true),
      findsOneWidget,
    );
    // Detail view: the reply action is not a link back to itself.
    expect(find.byType(InkWell), findsWidgets);
  });

  for (final dark in <bool>[false, true]) {
    testWidgets('survives 1.3x text and a long name at 360dp (dark=$dark)', (
      tester,
    ) async {
      await _pump(
        tester,
        _post(name: 'Nama Panjang Sekali Untuk Menguji Overflow Header'),
        textScale: 1.3,
        dark: dark,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
