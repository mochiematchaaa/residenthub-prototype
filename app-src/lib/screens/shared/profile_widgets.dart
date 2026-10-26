// Profile photo picker.

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/doc_files.dart';
import '../../widgets/widgets.dart';

/// Profile picture with Change and Remove buttons. The picture is kept in the
/// app only (it is not uploaded anywhere).
class ProfilePhotoEditor extends StatelessWidget {
  final String initials;
  final Uint8List? photo;
  final void Function(Uint8List?) onChange;
  const ProfilePhotoEditor({super.key, required this.initials, required this.photo, required this.onChange});

  Future<void> _pick(BuildContext context) async {
    try {
      final b = await pickPhoto();
      if (b != null) onChange(b);
    } on FormatException catch (e) {
      if (context.mounted) msg(context, e.message);
    } catch (_) {
      if (context.mounted) msg(context, 'Could not open that picture.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Avatar(initials, size: 84, photo: photo),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _pick(context),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(photo == null ? 'Add photo' : 'Change photo'),
              ),
              if (photo != null)
                TextButton(
                  onPressed: () => onChange(null),
                  child: const Text('Remove photo'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
