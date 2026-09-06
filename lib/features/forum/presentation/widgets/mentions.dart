import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/app_environment.dart';

/// Matches an `@username` mention inside post/comment text.
///
/// Kept deliberately in step with the username rule enforced when an account
/// picks one (`^[a-z0-9_]{3,10}$` — see `edit_username_dialog.dart`): a
/// mention can only ever refer to a username that could actually exist, so
/// an email address or a stray "@" in prose is never highlighted. The
/// leading `(?<![\w@])` stops the "@handle" inside `mail@handle.com` from
/// matching.
final mentionPattern = RegExp(r'(?<![\w@])@([a-z0-9_]{3,10})\b');

/// One candidate in the `@` autocomplete list.
class MentionCandidate {
  const MentionCandidate({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
}

/// Looks up accounts whose username or display name starts with/contains
/// [query], for the `@` autocomplete. Returns nothing when Supabase is
/// disabled (mock builds) or the lookup fails — the composer degrades to
/// plain typing rather than showing an error, since a mention is a
/// convenience, not something a post depends on.
Future<List<MentionCandidate>> searchMentionCandidates(String query) async {
  if (!AppEnvironment.supabaseEnabled) {
    return const <MentionCandidate>[];
  }
  final trimmed = query.trim().toLowerCase();
  try {
    var request = Supabase.instance.client
        .from('users')
        .select('id, username, display_name, avatar_url')
        .not('username', 'is', null);
    if (trimmed.isNotEmpty) {
      request = request.or(
        'username.ilike.$trimmed%,display_name.ilike.%$trimmed%',
      );
    }
    final rows = await request.limit(8);
    return <MentionCandidate>[
      for (final row in rows as List<dynamic>)
        if ((row as Map<String, dynamic>)['username'] case final String username)
          MentionCandidate(
            id: row['id'] as String,
            username: username,
            displayName: row['display_name'] as String?,
            avatarUrl: row['avatar_url'] as String?,
          ),
    ];
  } on Object {
    return const <MentionCandidate>[];
  }
}

/// Resolves a bare username to its account id so a tapped mention can open
/// that person's profile. Null when nobody owns the handle (a mention of a
/// username that never existed, or one since changed).
Future<String?> resolveMentionedUserId(String username) async {
  if (!AppEnvironment.supabaseEnabled) {
    return null;
  }
  try {
    final row = await Supabase.instance.client
        .from('users')
        .select('id')
        .eq('username', username.toLowerCase())
        .maybeSingle();
    return row?['id'] as String?;
  } on Object {
    return null;
  }
}

/// Renders body text with every `@username` highlighted and tappable.
///
/// Used for both posts and comments so a mention behaves identically
/// wherever it is written. A mention whose owner can't be resolved stays
/// styled but simply does nothing on tap — better than silently rendering
/// it as plain text, which would make the author think it never registered.
class MentionText extends StatefulWidget {
  const MentionText(this.text, {this.style, super.key});

  final String text;
  final TextStyle? style;

  @override
  State<MentionText> createState() => _MentionTextState();
}

class _MentionTextState extends State<MentionText> {
  final List<TapGestureRecognizerHolder> _recognizers =
      <TapGestureRecognizerHolder>[];

  @override
  void dispose() {
    for (final holder in _recognizers) {
      holder.dispose();
    }
    super.dispose();
  }

  Future<void> _openMention(String username) async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final userId = await resolveMentionedUserId(username);
    if (!mounted) return;
    if (userId == null) {
      messenger
          .showSnackBar(
            SnackBar(content: Text('Pengguna @$username tidak ditemukan.')),
          )
          .closed
          .ignore();
      return;
    }
    unawaited(router.push('/social/user/$userId'));
  }

  @override
  Widget build(BuildContext context) {
    for (final holder in _recognizers) {
      holder.dispose();
    }
    _recognizers.clear();

    final baseStyle = widget.style ?? Theme.of(context).textTheme.bodyMedium;
    final mentionStyle = baseStyle?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w700,
    );

    final spans = <InlineSpan>[];
    var index = 0;
    for (final match in mentionPattern.allMatches(widget.text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: widget.text.substring(index, match.start)));
      }
      final username = match.group(1)!;
      final holder = TapGestureRecognizerHolder(() => _openMention(username));
      _recognizers.add(holder);
      spans.add(
        TextSpan(
          text: '@$username',
          style: mentionStyle,
          recognizer: holder.recognizer,
        ),
      );
      index = match.end;
    }
    if (index < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(index)));
    }

    return Text.rich(TextSpan(style: baseStyle, children: spans));
  }
}

/// Tiny wrapper so [MentionText] can dispose the recognizers it creates —
/// a `TapGestureRecognizer` handed to a `TextSpan` leaks its listener
/// otherwise.
class TapGestureRecognizerHolder {
  TapGestureRecognizerHolder(VoidCallback onTap) {
    recognizer = TapGestureRecognizer()..onTap = onTap;
  }

  late final TapGestureRecognizer recognizer;

  void dispose() => recognizer.dispose();
}


/// The `@…` the caret is currently sitting inside, if any: [start] is the
/// offset of the `@` itself, [query] is what has been typed after it.
///
/// Returns null the moment the token stops looking like a username being
/// typed — a space, punctuation, more than the 10 characters a username can
/// hold, or an `@` glued to a preceding word (an email address). That is
/// what stops the suggestion list from popping up over ordinary prose.
({int start, String query})? activeMentionToken(TextEditingValue value) {
  final selection = value.selection;
  if (!selection.isValid || !selection.isCollapsed) return null;
  final caret = selection.baseOffset;
  if (caret < 0 || caret > value.text.length) return null;
  final text = value.text;
  final wordCharacter = RegExp(r'[A-Za-z0-9_]');
  for (var i = caret - 1; i >= 0; i -= 1) {
    final character = text[i];
    if (character == '@') {
      if (i > 0 && RegExp(r'[A-Za-z0-9_@]').hasMatch(text[i - 1])) return null;
      final query = text.substring(i + 1, caret);
      if (query.length > 10) return null;
      return (start: i, query: query);
    }
    if (!wordCharacter.hasMatch(character)) return null;
  }
  return null;
}

/// Replaces the `@…` token the caret is in with a chosen username, leaving
/// the caret after the trailing space so the writer can keep typing.
void applyMentionSelection(
  TextEditingController controller,
  int start,
  String username,
) {
  final caret = controller.selection.baseOffset;
  final text = controller.text;
  final replacement = '@$username ';
  controller.value = TextEditingValue(
    text: text.substring(0, start) + replacement + text.substring(caret),
    selection: TextSelection.collapsed(offset: start + replacement.length),
  );
}

/// Drop-in suggestion list for any `TextField` whose controller is passed
/// in: shows matching accounts while an `@…` is being typed, and collapses
/// to nothing otherwise.
///
/// Written as a sibling widget rather than a wrapper around the field so
/// the two very different layouts that need it — the full-page composer and
/// the single-line comment bar — can each place it where it fits.
class MentionSuggestions extends StatefulWidget {
  const MentionSuggestions({required this.controller, super.key});

  final TextEditingController controller;

  @override
  State<MentionSuggestions> createState() => _MentionSuggestionsState();
}

class _MentionSuggestionsState extends State<MentionSuggestions> {
  Timer? _debounce;
  List<MentionCandidate> _candidates = const <MentionCandidate>[];
  int? _tokenStart;
  String? _lastQuery;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final token = activeMentionToken(widget.controller.value);
    if (token == null) {
      _debounce?.cancel();
      _lastQuery = null;
      if (_candidates.isNotEmpty || _tokenStart != null) {
        setState(() {
          _candidates = const <MentionCandidate>[];
          _tokenStart = null;
        });
      }
      return;
    }
    _tokenStart = token.start;
    if (token.query == _lastQuery) return;
    _lastQuery = token.query;
    // Debounced so a fast typist issues one lookup, not one per keystroke.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final results = await searchMentionCandidates(token.query);
      if (!mounted) return;
      // The caret may have moved on while the lookup was in flight.
      if (activeMentionToken(widget.controller.value)?.query != token.query) {
        return;
      }
      setState(() => _candidates = results);
    });
  }

  @override
  Widget build(BuildContext context) {
    final start = _tokenStart;
    if (start == null || _candidates.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.only(top: 4),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 216),
        child: ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: _candidates.length,
          itemBuilder: (context, index) {
            final candidate = _candidates[index];
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundImage:
                    candidate.avatarUrl != null && candidate.avatarUrl!.isNotEmpty
                        ? NetworkImage(candidate.avatarUrl!)
                        : null,
                child: candidate.avatarUrl == null || candidate.avatarUrl!.isEmpty
                    ? Text(
                        candidate.username.characters.first.toUpperCase(),
                        style: const TextStyle(fontSize: 12),
                      )
                    : null,
              ),
              title: Text('@${candidate.username}'),
              subtitle: candidate.displayName == null ||
                      candidate.displayName!.isEmpty
                  ? null
                  : Text(
                      candidate.displayName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              onTap: () {
                applyMentionSelection(
                  widget.controller,
                  start,
                  candidate.username,
                );
                setState(() {
                  _candidates = const <MentionCandidate>[];
                  _tokenStart = null;
                });
              },
            );
          },
        ),
      ),
    );
  }
}
