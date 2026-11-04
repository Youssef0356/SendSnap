import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../services/local_storage_service.dart';
import '../services/permission_service.dart';
import '../services/file_handler.dart';
import 'bouncing_card.dart';
import 'glass_container.dart';

class InAppFilePickerSheet extends StatefulWidget {
  final bool allowMultiple;

  const InAppFilePickerSheet({
    super.key,
    this.allowMultiple = true,
  });

  /// Opens the picker sheet as a full-height glass modal and returns selected Files.
  static Future<List<File>?> show(BuildContext context, {bool allowMultiple = true}) {
    return showModalBottomSheet<List<File>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => InAppFilePickerSheet(allowMultiple: allowMultiple),
    );
  }

  @override
  State<InAppFilePickerSheet> createState() => _InAppFilePickerSheetState();
}

class _InAppFilePickerSheetState extends State<InAppFilePickerSheet> {
  StorageCategory _selectedCategory = StorageCategory.downloads;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedPaths = {};
  
  List<LocalItem> _items = [];
  bool _isLoading = true;
  String _searchQuery = '';
  
  // Folder navigation inside StorageCategory.files
  String? _currentDirPath;
  final List<String> _dirHistory = [];

  final PermissionService _permService = PermissionService();
  bool _hasFullStorageAccess = true;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoad();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionsAndLoad() async {
    final granted = await _permService.hasManageExternalStoragePermission();
    if (mounted) {
      setState(() {
        _hasFullStorageAccess = granted;
      });
      _loadCategory(_selectedCategory);
    }
  }

  Future<void> _openSystemPicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: widget.allowMultiple,
        type: FileType.any,
      );
      if (result != null && result.paths.isNotEmpty) {
        final files = result.paths
            .whereType<String>()
            .map((p) => File(p))
            .where((f) => f.existsSync())
            .toList();
        if (files.isNotEmpty && mounted) {
          Navigator.of(context).pop(files);
        }
      }
    } catch (e) {
      debugPrint('[InAppFilePickerSheet] Error opening system picker: $e');
    }
  }

  Future<void> _loadCategory(StorageCategory category, {String? targetDir}) async {
    setState(() {
      _isLoading = true;
      _selectedCategory = category;
      if (targetDir != null) {
        _currentDirPath = targetDir;
      }
    });

    final list = await LocalStorageService.getItems(
      category: category,
      currentDirectoryPath: _currentDirPath,
    );

    if (mounted) {
      setState(() {
        _items = list;
        _isLoading = false;
      });
    }
  }

  void _onCategorySelected(StorageCategory category) {
    if (_selectedCategory == category && category != StorageCategory.files) return;
    _dirHistory.clear();
    _currentDirPath = null;
    _searchController.clear();
    _searchQuery = '';
    _loadCategory(category);
  }

  void _enterDirectory(String dirPath) {
    if (_currentDirPath != null) {
      _dirHistory.add(_currentDirPath!);
    }
    _currentDirPath = dirPath;
    _loadCategory(StorageCategory.files, targetDir: dirPath);
  }

  void _navigateUp() {
    if (_dirHistory.isNotEmpty) {
      final prev = _dirHistory.removeLast();
      _currentDirPath = prev;
      _loadCategory(StorageCategory.files, targetDir: prev);
    } else {
      _currentDirPath = null;
      _loadCategory(StorageCategory.files);
    }
  }

  void _toggleSelect(String path) {
    setState(() {
      if (!widget.allowMultiple) {
        _selectedPaths.clear();
        _selectedPaths.add(path);
      } else {
        if (_selectedPaths.contains(path)) {
          _selectedPaths.remove(path);
        } else {
          _selectedPaths.add(path);
        }
      }
    });
  }

  int _calculateTotalSelectedSize() {
    int total = 0;
    for (final pth in _selectedPaths) {
      try {
        final f = File(pth);
        if (f.existsSync()) {
          total += f.lengthSync();
        }
      } catch (_) {}
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final totalBytes = _calculateTotalSelectedSize();

    // Filter by search query
    final filteredItems = _searchQuery.isEmpty
        ? _items
        : _items.where((i) => i.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Container(
      height: size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 30,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: Column(
          children: [
            // Drag handle & Header
            _buildHeader(context),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: _buildSearchBar(),
            ),

            // Category Chips
            _buildCategoryTabs(),

            // Storage Permission Warning Banner if missing
            if (!_hasFullStorageAccess && _selectedCategory == StorageCategory.files)
              _buildPermissionBanner(),

            // Breadcrumb if in folder view
            if (_selectedCategory == StorageCategory.files && _currentDirPath != null)
              _buildBreadcrumbs(),

            // Item List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredItems.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: filteredItems.length,
                          separatorBuilder: (ctx, idx) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final isSelected = _selectedPaths.contains(item.path);
                            return _buildItemRow(item, isSelected);
                          },
                        ),
            ),

            // Floating Selection Action Bar
            if (_selectedPaths.isNotEmpty)
              _buildBottomBar(totalBytes),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
      child: Column(
        children: [
          // Drag pill
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.folder_copy_rounded, color: AppColors.primary, size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Local Storage & Files',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.file_open_rounded, color: AppColors.primary),
                tooltip: 'Open Phone File Explorer / Gallery',
                onPressed: _openSystemPicker,
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val.trim()),
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          icon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
          hintText: 'Filter files in this tab...',
          hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7), fontSize: 14),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    final categories = [
      (StorageCategory.downloads, 'Downloads', Icons.download_rounded),
      (StorageCategory.photos, 'Photos', Icons.photo_library_rounded),
      (StorageCategory.videos, 'Videos', Icons.movie_creation_rounded),
      (StorageCategory.audio, 'Audio', Icons.music_note_rounded),
      (StorageCategory.documents, 'Docs', Icons.description_rounded),
      (StorageCategory.received, 'Received', Icons.cloud_download_rounded),
      (StorageCategory.files, 'Storage', Icons.phone_android_rounded),
    ];

    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (ctx, idx) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategory == cat.$1;

          return BouncingCard(
            onTap: () => _onCategorySelected(cat.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(colors: [AppColors.accent, AppColors.primary])
                    : null,
                color: isSelected ? null : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.black.withValues(alpha: 0.06),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    cat.$3,
                    size: 16,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cat.$2,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBreadcrumbs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surface.withValues(alpha: 0.5),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward_rounded, size: 20, color: AppColors.primary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _navigateUp,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _currentDirPath ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_special_rounded, color: AppColors.warning, size: 24),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Grant All Files Access to browse all phone subfolders.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () async {
              await _permService.requestStorageManagementIfNeeded();
              _checkPermissionsAndLoad();
            },
            child: const Text('Grant', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning)),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(LocalItem item, bool isSelected) {
    return BouncingCard(
      onTap: () {
        if (item.isDirectory) {
          _enterDirectory(item.path);
        } else {
          _toggleSelect(item.path);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.04),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Preview thumbnail or Icon
            _buildItemLeading(item),
            const SizedBox(width: 12),

            // Name and metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.isDirectory
                        ? 'Folder'
                        : '${item.formattedSize} • ${_formatDate(item.modified)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Selection indicator or Folder Chevron
            if (item.isDirectory)
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20)
            else
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemLeading(LocalItem item) {
    if (item.isDirectory) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.folder_rounded, color: Colors.amber, size: 26),
      );
    }

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
    } else if (item.extension == '.zip' || item.extension == '.rar' || item.extension == '.7z') {
      bg = Colors.teal.withValues(alpha: 0.15);
      fg = Colors.teal;
      icon = Icons.folder_zip_rounded;
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
          Icon(Icons.folder_off_rounded, size: 54, color: AppColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty ? 'No files match "$_searchQuery"' : 'No files found in this category',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openSystemPicker,
            icon: const Icon(Icons.file_open_rounded, size: 18),
            label: const Text('Browse Phone File Explorer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(int totalBytes) {
    return GlassContainer(
      blur: 25,
      opacity: 0.88,
      borderRadius: 0,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      borderColor: Colors.white.withValues(alpha: 0.3),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_selectedPaths.length} ${_selectedPaths.length == 1 ? 'file' : 'files'} selected',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  FileHandler.formatFileSize(totalBytes),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() => _selectedPaths.clear()),
              child: const Text('Clear', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            BouncingCard(
              onTap: () {
                final files = _selectedPaths.map((p) => File(p)).where((f) => f.existsSync()).toList();
                Navigator.of(context).pop(files);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accent, AppColors.primary],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Select (${_selectedPaths.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
