import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import '../services/database_helper.dart';
import 'dart:async';
import '../services/config.dart';

class AddClothingScreen extends StatefulWidget {
  const AddClothingScreen({super.key});
  @override
  State<AddClothingScreen> createState() => _AddClothingScreenState();
}

class _AddClothingScreenState extends State<AddClothingScreen> {
  File? _image;
  bool _loading = false;
  Map<String, dynamic>? _result;
  final _picker = ImagePicker();

  // Change this to your Mac's local IP when testing on real device
  static const String _baseUrl = AppConfig.baseUrl;

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      _image = File(picked.path);
      _result = null;
    });
    await _classify();
  }

  Future<void> _classify() async {
    if (_image == null) return;
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/classify'));
      request.files.add(await http.MultipartFile.fromPath('image', _image!.path));
      request.headers['Connection'] = 'keep-alive';
      final response = await request.send().timeout(const Duration(seconds: 60));
      final body = await response.stream.bytesToString();
      if (!mounted) return;
      setState(() => _result = json.decode(body));
    } catch (e) {
      if (!mounted) return;
      setState(() => _result = {'error': 'Could not connect to server. Make sure Flask is running.'});
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F4),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: const Icon(Icons.close, size: 22, color: Color(0xFF241A0E)),
                  ),
                  const Spacer(),
                  Text('Add Clothing',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF241A0E))),
                  const Spacer(),
                  const Icon(Icons.flash_auto_outlined, size: 22, color: Color(0xFF241A0E)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Camera preview area
                    GestureDetector(
                      onTap: () => _pickImage(ImageSource.camera),
                      child: Container(
                        width: double.infinity,
                        height: 320,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4DFCB),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: _image != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Image.file(_image!, fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.photo_camera_outlined, size: 48, color: Color(0xFF241A0E)),
                                  const SizedBox(height: 12),
                                  Text('Tap to take photo',
                                      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF4C4546))),
                                  const SizedBox(height: 4),
                                  Text('Use a plain background for best results',
                                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF7E7576))),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Gallery and flip buttons
                    Row(
                      children: [
                        Expanded(
                          child: _actionButton(
                            icon: Icons.photo_library_outlined,
                            label: 'Upload',
                            onTap: () => _pickImage(ImageSource.gallery),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _actionButton(
                            icon: Icons.flip_camera_ios_outlined,
                            label: 'Flip',
                            onTap: () => _pickImage(ImageSource.camera),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Result area
                    if (_loading)
                      Column(
                        children: [
                          const CircularProgressIndicator(color: Colors.black),
                          const SizedBox(height: 12),
                          Text('Analyzing Look...',
                              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF4C4546))),
                        ],
                      ),
                    if (_result != null && !_loading) ...[
                      if (_result!['error'] != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFDAD6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(_result!['error'],
                              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF93000A))),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('AI Tags',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: const Color(0xFF7E7576))),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _tag(_result!['type'] ?? ''),
                                  if (_result!['color'] != null)
                                    _tag(_result!['color']),
                                  if (_result!['confidence'] != null)
                                    _tag('${_result!['confidence']}% match'),
                                ],
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                 onPressed: () async {
                                  await DatabaseHelper.instance.insertItem({
                                    'type': _result!['type'],
                                    'color': _result!['color'] ?? 'unknown',
                                    'confidence': _result!['confidence'],
                                    'imagePath': _image!.path,
                                    'dateAdded': DateTime.now().toIso8601String(),
                                  });
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('${_result!['type']} added to closet!'),
                                        backgroundColor: Colors.black,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    );
                                    setState(() {
                                      _image = null;
                                      _result = null;
                                    });
                                  }
                                },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                                  ),
                                  child: Text('Add to Closet',
                                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF4DFCB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF241A0E)),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF241A0E))),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF4DFCB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF241A0E))),
    );
  }
}