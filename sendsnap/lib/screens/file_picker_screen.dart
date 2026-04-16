import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../theme/app_theme.dart';
import '../models/device.dart';
import '../models/transfer_file.dart';
import '../providers/transfer_provider.dart';
import '../providers/device_provider.dart';
import '../providers/connection_provider.dart';
import '../widgets/file_tile.dart';

class FilePickerScreen extends ConsumerStatefulWidget {
  const FilePickerScreen({super.key});

  @override
  ConsumerState<FilePickerScreen> createState() => _FilePickerScreenState();
}

class _FilePickerScreenState extends ConsumerState<FilePickerScreen> {
  final List<TransferFile> _selectedFiles = [];
  bool _isPicking = false;

  NearbyDevice? get _targetDevice =>
      ModalRoute.of(context)?.settings.arguments as NearbyDevice?;

  int get _totalSize => _selectedFiles.fold(0, (sum, f) => sum + f.size);

  String get _formattedTotalSize {
    final size = _totalSize;
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _pickFiles() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.any);
      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.path != null) {
            final stat = await File(file.path!).stat();
            final tf = TransferFile(name: file.name, path: file.path!, size: stat.size);
            if (!_selectedFiles.any((f) => f.path == tf.path)) _selectedFiles.add(tf);
          }
        }
        setState(() {});
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally { if (mounted) setState(() => _isPicking = false); }
  }

  void _removeFile(int i) { setState(() => _selectedFiles.removeAt(i)); }

  Future<void> _sendFiles() async {
    if (_selectedFiles.isEmpty || _targetDevice == null) return;
    
    if (mounted) {
      Navigator.pushNamed(context, '/transfer');
    }
    await ref.read(activeTransferProvider.notifier).sendFiles(target: _targetDevice!, files: _selectedFiles);
  }

  @override
  Widget build(BuildContext context) {
    final target = _targetDevice;
    return Scaffold(
      backgroundColor: SendSnapTheme.foundation,
      appBar: AppBar(backgroundColor: SendSnapTheme.foundation,
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded), color: SendSnapTheme.accent),
        title: Text(target != null ? 'Send to ${target.name}' : 'Pick Files', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          _PickButton(icon: Icons.attach_file_rounded, label: 'Files', onTap: _pickFiles, isLoading: _isPicking),
        ])),
        Expanded(child: _selectedFiles.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 72, height: 72, decoration: BoxDecoration(color: SendSnapTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)), child: Icon(Icons.folder_open_rounded, color: SendSnapTheme.primary.withValues(alpha: 0.5), size: 34)),
              const SizedBox(height: 20), const Text('No files selected', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8), Text('Tap the button above to pick files', style: TextStyle(color: SendSnapTheme.accent.withValues(alpha: 0.5), fontSize: 13)),
            ]))
          : ListView.builder(padding: const EdgeInsets.only(bottom: 100), itemCount: _selectedFiles.length, itemBuilder: (_, i) => FileTile(file: _selectedFiles[i], onRemove: () => _removeFile(i)))),
        _buildSendBar(),
      ]),
    );
  }

  Widget _buildSendBar() {
    final has = _selectedFiles.isNotEmpty;
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: SendSnapTheme.surface, border: Border(top: BorderSide(color: SendSnapTheme.accent.withValues(alpha: 0.1)))),
      child: SafeArea(child: SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: has ? _sendFiles : null,
        style: ElevatedButton.styleFrom(backgroundColor: has ? SendSnapTheme.primary : SendSnapTheme.surface, foregroundColor: has ? Colors.white : SendSnapTheme.accent.withValues(alpha: 0.3), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
        child: Text(has ? 'Send ${_selectedFiles.length} ${_selectedFiles.length == 1 ? 'file' : 'files'} ($_formattedTotalSize)' : 'Select files to send', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      ))),
    );
  }
}

class _PickButton extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap; final bool isLoading;
  const _PickButton({required this.icon, required this.label, required this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(onTap: isLoading ? null : onTap, child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18), decoration: BoxDecoration(color: SendSnapTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: SendSnapTheme.accent.withValues(alpha: 0.1))),
      child: Column(children: [
        isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: SendSnapTheme.primary)) : Icon(icon, color: SendSnapTheme.primary, size: 26),
        const SizedBox(height: 8), Text(label, style: TextStyle(color: SendSnapTheme.accent.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    )));
  }
}
