import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'forum_controller.dart';
import 'widgets/mentions.dart';

const _maxBodyLength = 2000;

class ForumPostComposerPage extends ConsumerStatefulWidget {
  const ForumPostComposerPage({super.key});

  @override
  ConsumerState<ForumPostComposerPage> createState() =>
      _ForumPostComposerPageState();
}

class _ForumPostComposerPageState extends ConsumerState<ForumPostComposerPage> {
  final _bodyController = TextEditingController();
  Uint8List? _imageBytes;
  String? _lineId;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _imageBytes = bytes);
  }

  Future<void> _submit() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty) {
      setState(() => _error = 'Tulis sesuatu dulu sebelum posting.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await ref
        .read(forumControllerProvider.notifier)
        .createPost(body, imageBytes: _imageBytes, lineId: _lineId);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _submitting = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _maxBodyLength - _bodyController.text.length;
    final lineOptions = ref.watch(forumLineOptionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Postingan baru'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Posting'),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            if (_error != null) ...<Widget>[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _bodyController,
              maxLength: _maxBodyLength,
              maxLines: 8,
              minLines: 4,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText:
                    'Apa yang terjadi di perjalananmu hari ini? '
                    'Ketik @ untuk menandai pengguna lain.',
                counterText: '$remaining karakter tersisa',
              ),
            ),
            MentionSuggestions(controller: _bodyController),
            const SizedBox(height: 12),
            if (_imageBytes != null)
              Stack(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _imageBytes!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: IconButton.filled(
                      onPressed: () => setState(() => _imageBytes = null),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Tambah foto'),
              ),
            const SizedBox(height: 16),
            lineOptions.when(
              loading: () => const SizedBox.shrink(),
              error: (error, stack) => const SizedBox.shrink(),
              data: (lines) {
                if (lines.isEmpty) return const SizedBox.shrink();
                return DropdownButtonFormField<String?>(
                  initialValue: _lineId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tandai lintas (opsional)',
                    prefixIcon: Icon(Icons.route_outlined),
                  ),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Tidak ditandai'),
                    ),
                    for (final line in lines)
                      DropdownMenuItem<String?>(
                        value: line.id,
                        child: Text(line.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) => setState(() => _lineId = value),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
