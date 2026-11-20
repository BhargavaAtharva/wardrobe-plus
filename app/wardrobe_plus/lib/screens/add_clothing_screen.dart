import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_client.dart';
import '../services/catalog.dart';
import '../services/database_helper.dart';
import '../services/image_store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Photo -> AI suggests type and colour -> user confirms or corrects -> saved.
class AddClothingScreen extends StatefulWidget {
  final VoidCallback? onAdded;
  const AddClothingScreen({super.key, this.onAdded});
  @override
  State<AddClothingScreen> createState() => _AddClothingScreenState();
}

class _AddClothingScreenState extends State<AddClothingScreen> {
  static const _unsureBelow = 70.0; // AI confidence (%) below which we ask the user to check

  final _picker = ImagePicker();
  File? _image;
  bool _analyzing = false;
  bool _saving = false;
  Map<String, dynamic>? _result;
  ApiException? _error;
  String? _type;
  String? _color;

  Future<void> _pickImage(ImageSource source) async {
    XFile? picked;
    try {
      picked = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 2000);
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(source == ImageSource.camera
            ? 'Camera unavailable (${e.code}). Use Upload instead.'
            : 'Could not open photos (${e.code}). Check photo permissions in Settings.'),
      ));
      return;
    }
    if (picked == null || !mounted) return;
    setState(() {
      _image = File(picked!.path);
      _result = null;
      _error = null;
      _type = null;
      _color = null;
    });
    await _classify();
  }

  Future<void> _classify() async {
    if (_image == null) return;
    setState(() {
      _analyzing = true;
      _error = null;
    });
    try {
      final result = await ApiClient.classify(_image!);
      if (!mounted) return;
      if (result['error'] != null) {
        setState(() => _error = ApiException(result['message'] as String? ?? 'Could not analyse this photo.'));
      } else {
        setState(() {
          _result = result;
          _type = result['type'] as String?;
          final color = result['color'] as String?;
          _color = Catalog.colorNames.contains(color) ? color : null; // "unknown" -> user picks
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  /// Lets the user tag the photo themselves when the server can't be reached.
  void _tagManually() => setState(() {
        _error = null;
        _result = {'manual': true};
        _type = null;
        _color = null;
      });

  Future<void> _save() async {
    if (_image == null || _type == null || _color == null) return;
    setState(() => _saving = true);
    try {
      final stored = await ImageStore.save(_image!);
      final confidence = _result?['manual'] == true || _type != _result?['type'] ? null : _result?['confidence'];
      await DatabaseHelper.instance.insertItem({
        'type': _type,
        'color': _color,
        'confidence': confidence,
        'imagePath': stored,
        'dateAdded': DateTime.now().toIso8601String(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${Catalog.typeLabel(_type)} added to your closet')));
      _reset();
      widget.onAdded?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save the item: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reset() => setState(() {
        _image = null;
        _result = null;
        _error = null;
        _type = null;
        _color = null;
      });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          BrandBar(
            trailing: _image == null
                ? null
                : GestureDetector(onTap: _reset, child: Text('Start over', style: AppText.body(size: 13, color: AppColors.muted))),
          ),
          Text('Add Clothing', style: AppText.title(28)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _analyzing ? null : () => _pickImage(ImageSource.camera),
            child: Container(
              width: double.infinity,
              height: 320,
              decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(28)),
              child: _image != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(28), child: Image.file(_image!, fit: BoxFit.cover))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.photo_camera_outlined, size: 48, color: AppColors.ink),
                        const SizedBox(height: 12),
                        Text('Tap to take a photo', style: AppText.body(color: AppColors.inkSoft)),
                        const SizedBox(height: 4),
                        Text('One item, laid flat. A plain background works best.',
                            style: AppText.body(size: 12, color: AppColors.muted)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _actionButton(Icons.photo_camera_outlined, 'Camera', () => _pickImage(ImageSource.camera))),
            const SizedBox(width: 12),
            Expanded(child: _actionButton(Icons.photo_library_outlined, 'Upload', () => _pickImage(ImageSource.gallery))),
          ]),
          const SizedBox(height: 24),
          if (_analyzing)
            Column(children: [
              const CircularProgressIndicator(color: Colors.black),
              const SizedBox(height: 12),
              Text('Analysing… removing the background and identifying the piece',
                  textAlign: TextAlign.center, style: AppText.body(size: 13, color: AppColors.inkSoft)),
              Text('Busy backgrounds can take up to 15 seconds.',
                  textAlign: TextAlign.center, style: AppText.body(size: 12, color: AppColors.muted)),
            ]),
          if (_error != null && !_analyzing) ...[
            ErrorCard(message: _error!.message, onRetry: _classify, showServerSettings: _error!.serverUnreachable),
            TextButton(onPressed: _tagManually, child: Text('Tag it myself instead', style: AppText.body(size: 13, weight: FontWeight.w600))),
          ],
          if (_result != null && !_analyzing) _resultCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _resultCard() {
    final manual = _result!['manual'] == true;
    final confidence = (_result!['confidence'] as num?)?.toDouble();
    final unsure = !manual && confidence != null && confidence < _unsureBelow;
    final alternatives = (_result!['alternatives'] as List? ?? [])
        .where((a) => (a['confidence'] as num) >= 10)
        .map((a) => Catalog.typeLabel(a['type'] as String?))
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), boxShadow: cardShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(manual ? 'TAG THIS PIECE' : 'AI TAGS — TAP TO CORRECT', style: AppText.label()),
          if (!manual && confidence != null) ...[
            const SizedBox(height: 8),
            Text(
              unsure
                  ? 'Not sure (${confidence.toStringAsFixed(0)}%). Please check the type'
                      '${alternatives.isEmpty ? '' : ' — it could also be ${alternatives.join(' or ')}'}.'
                  : '${confidence.toStringAsFixed(0)}% confident this is a ${Catalog.typeLabel(_result!['type'] as String?).toLowerCase()}.',
              style: AppText.body(size: 13, color: unsure ? AppColors.errorText : AppColors.inkSoft),
            ),
          ],
          const SizedBox(height: 16),
          Text('TYPE', style: AppText.label()),
          const SizedBox(height: 8),
          TypeSelector(selected: _type, onChanged: (t) => setState(() => _type = t)),
          const SizedBox(height: 16),
          Text('COLOUR', style: AppText.label()),
          const SizedBox(height: 8),
          ColorSelector(selected: _color, onChanged: (c) => setState(() => _color = c)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              key: const Key('add-to-closet'),
              onPressed: _type == null || _color == null || _saving ? null : _save,
              style: primaryButton(),
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_type == null || _color == null ? 'Choose a type and colour' : 'Add to Closet',
                      style: AppText.body(size: 15, weight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: _analyzing ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.ink),
            const SizedBox(width: 8),
            Text(label, style: AppText.body(size: 13, weight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
