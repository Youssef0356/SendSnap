import 'dart:io';
import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../services/file_handler.dart';
import '../services/local_storage_service.dart';
import '../widgets/ambient_background.dart';
import '../widgets/bouncing_card.dart';
import '../widgets/glass_container.dart';
import '../widgets/media_viewer_modal.dart';

class ReceivedFilesScreen extends StatefulWidget {
  const ReceivedFilesScreen({super.key});

  @override
  State<ReceivedFilesScreen> createState() => _ReceivedFilesScreenState();
}

class _ReceivedFilesScreenState extends State<ReceivedFilesScreen> {
  List<LocalItem> _files = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReceivedFiles();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReceivedFiles() async {
    setState(() => _isLoading = true);
    final items = await LocalStorageService.getItems(category: StorageCategory.received);
    if (mounted) {
      setState(() {
        _files = items.where((i) => !i.isDirectory).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteFile(LocalItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete File?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete "${item.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final f = File(item.path);
        if (await f.exists()) {
          await f.delete();
        }
        _loadReceivedFiles();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting file: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  int get _totalBytes => _files.fold(0, (acc, item) => acc + item.size);

  @override
  Widget build(BuildContext context) {
    final filtered = _searchQuery.isEmpty
        ? _files
        : _files.where((f) => f.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  _buildHeader(context),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: _buildSearchBar(),
                  ),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : filtered.isEmpty
                            ? _buildEmptyState()
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                itemCount: filtered.length,
                                separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  return _buildFileCard(filtered[index]);
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          BouncingCard(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Received Files',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${_files.length} ${_files.length == 1 ? 'file' : 'files'} • ${FileHandler.formatFileSize(_totalBytes)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _loadReceivedFiles,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (val) => setState(() => _searchQuery = val.trim()),
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          icon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
          hintText: 'Search received files...',
          hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7), fontSize: 14),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFileCard(LocalItem item) {
    return GestureDetector(
      onTap: () => _openItem(item),
      child: GlassContainer(
        blur: 20,
        opacity: 0.75,
        borderRadius: 18,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _buildLeading(item),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.formattedSize} • ${_formatDate(item.modified)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            // Open button
            BouncingCard(
              onTap: () => _openItem(item),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.accent, AppColors.primary]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Open', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
              onPressed: () => _deleteFile(item),
            ),
          ],
        ),
      ),
    );
  }

  void _openItem(LocalItem item) {
    if (item.isImage) {
      MediaViewerModal.show(context, item: item);
    } else {
      FileHandler.openFile(item.path);
    }
  }

  Widget _buildLeading(LocalItem item) {
    if (item.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Image.file(
            File(item.path),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildGenericIcon(item),
          ),
        ),
      );
    }
    return _buildGenericIcon(item);
  }

  Widget _buildGenericIcon(LocalItem item) {
    Color bg;
    Color fg;
    IconData icon;

    if (item.isVideo) {
      bg = Colors.pink.withValues(alpha: 0.15);
      fg = Colors.pink;
      icon = Icons.videocam_rounded;
    } else if (item.isAudio) {
      bg = Colors.deepPurple.withValues(alpha: 0.15);
      fg = Colors.deepPurple;
      icon = Icons.headphones_rounded;
    } else if (item.extension == '.pdf') {
      bg = Colors.red.withValues(alpha: 0.15);
      fg = Colors.red;
      icon = Icons.picture_as_pdf_rounded;
    } else if (item.extension == '.apk') {
      bg = Colors.green.withValues(alpha: 0.15);
      fg = Colors.green;
      icon = Icons.android_rounded;
    } else {
      bg = AppColors.primary.withValues(alpha: 0.15);
      fg = AppColors.primary;
      icon = Icons.insert_drive_file_rounded;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: fg, size: 22),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_download_rounded, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.35)),
          const SizedBox(height: 14),
          const Text(
            'No Received Files Yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Files received from nearby devices will be saved and managed right here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
