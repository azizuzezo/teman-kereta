import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../domain/entities/social_models.dart';
import 'widgets/user_row_tile.dart';

class UserSearchPage extends StatefulWidget {
  const UserSearchPage({super.key});

  @override
  State<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends State<UserSearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<UserSummary>? _results;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = null;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
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
      if (!mounted) return;
      setState(() {
        _results = rows
            .map((row) => UserSummary.fromJson(row as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal mencari pengguna. Coba lagi.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          decoration: const InputDecoration(
            hintText: 'Cari username atau nama...',
            border: InputBorder.none,
          ),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Terjadi kendala',
        message: _error!,
      );
    }
    final results = _results;
    if (results == null) {
      return const AppEmptyState(
        icon: Icons.person_search_outlined,
        title: 'Cari pengguna',
        message: 'Ketik username atau nama tampilan untuk mulai mencari.',
      );
    }
    if (results.isEmpty) {
      return const AppEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Tidak ditemukan',
        message: 'Tidak ada pengguna yang cocok dengan pencarianmu.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: results.length,
      itemBuilder: (context, index) => UserRowTile(user: results[index]),
    );
  }
}
