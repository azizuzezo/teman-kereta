import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tk_components.dart';
import '../../../domain/entities/social_models.dart';
import '../../forum/presentation/forum_format.dart';
import '../../forum/presentation/widgets/forum_skeletons.dart';
import 'widgets/user_row_tile.dart';

class UserSearchPage extends StatefulWidget {
  const UserSearchPage({super.key});

  @override
  State<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends State<UserSearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  int _requestId = 0;
  String _lastQuery = '';
  List<UserSummary>? _results;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// What is actually sent to the server: no leading "@", no characters that
  /// could break the filter string.
  String _normalized(String raw) =>
      sanitizeSearchQuery(raw.trim().replaceFirst(RegExp('^@+'), ''));

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = _normalized(value);
    if (query.isEmpty) {
      _requestId++;
      setState(() {
        _results = null;
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    final id = ++_requestId;
    _lastQuery = query;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows =
          await Supabase.instance.client
                  .from('users')
                  .select('id, username, display_name, avatar_url')
                  .or('username.ilike.%$query%,display_name.ilike.%$query%')
                  .limit(30)
              as List<dynamic>;
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = rows
            .map((row) => UserSummary.fromJson(row as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } on Object {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = 'Pencarian gagal. Periksa koneksimu, lalu coba lagi.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(TkRadius.control),
      borderSide: BorderSide.none,
    );
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cari nama atau @username',
              fillColor: tk.surfaceAlt,
              border: fieldBorder,
              enabledBorder: fieldBorder,
              focusedBorder: fieldBorder,
              isDense: true,
              prefixIcon: Icon(Icons.search_rounded, color: tk.textMuted),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Hapus pencarian',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _controller.clear();
                        _onChanged('');
                      },
                    ),
            ),
          ),
        ),
      ),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    final tk = context.tk;
    if (_loading) {
      return const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: UserRowSkeleton(),
      );
    }
    if (_error != null) {
      return TkErrorState(
        title: 'Pencarian gagal',
        message: _error!,
        onRetry: () => _search(_lastQuery),
      );
    }
    final results = _results;
    if (results == null) {
      return const AppEmptyState(
        icon: Icons.person_search_outlined,
        title: 'Cari teman satu jalur',
        message: 'Ketik nama atau username untuk menemukan pengguna.',
      );
    }
    if (results.isEmpty) {
      return const AppEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Tidak ada yang cocok',
        message: 'Coba kata lain atau periksa ejaan username.',
      );
    }
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: results.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, indent: 72, color: tk.border),
      itemBuilder: (context, index) => UserRowTile(user: results[index]),
    );
  }
}
