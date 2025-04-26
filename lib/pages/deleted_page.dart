import 'package:flutter/material.dart';
import '../models/link.dart';
import '../services/database_helper.dart';
import 'link_detail_page.dart';
import 'package:animations/animations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/url_utils.dart';
import '../services/view_mode_service.dart';

class DeletedPage extends StatefulWidget {
  const DeletedPage({super.key});

  @override
  State<DeletedPage> createState() => _DeletedPageState();
}

class _DeletedPageState extends State<DeletedPage> {
  List<Link> _deletedLinks = [];
  bool _isLoading = true;
  Set<int> _selectedItems = {};
  ThemeMode _themeMode = ThemeMode.system;
  static const String _themeModeKey = 'themeMode';
  bool _isGridView = true;
  bool _isSelectionMode = false;  // Add this line

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _loadViewMode();
    _loadDeletedLinks();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = ThemeMode.values[prefs.getInt(_themeModeKey) ?? 0];
    });
  }

  Future<void> _loadViewMode() async {
    final isGridView = await ViewModeService.instance.getIsGridView();
    setState(() => _isGridView = isGridView);
  }

  Future<void> _loadDeletedLinks() async {
    setState(() => _isLoading = true);
    final links = await DatabaseHelper.instance.getAllLinks(deleted: true);
    setState(() {
      _deletedLinks = links;
      _isLoading = false;
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedItems.contains(id)) {
        _selectedItems.remove(id);
        if (_selectedItems.isEmpty) {
          _isSelectionMode = false;  // Update selection mode
        }
      } else {
        _selectedItems.add(id);
        _isSelectionMode = true;  // Update selection mode
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedItems.length == _deletedLinks.length) {
        _selectedItems.clear();
      } else {
        _selectedItems = _deletedLinks.map((link) => link.id!).toSet();
      }
    });
  }

  Future<void> _permanentlyDeleteSelected() async {
    final colorScheme = Theme.of(context).colorScheme;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Permanently'),
        content: Text(
          'Are you sure you want to permanently delete ${_selectedItems.length} items?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Convert set to list for deletion
      final idsList = _selectedItems.toList();
      
      // Use the new batch delete method
      await DatabaseHelper.instance.permanentDeleteMultiple(idsList);
      
      setState(() {
        _selectedItems.clear();
      });
      
      _loadDeletedLinks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final baseColorScheme = themeData.colorScheme;
    
    final isDarkMode = _themeMode == ThemeMode.dark || 
        (_themeMode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : baseColorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Trash',
          style: TextStyle(
            fontFamily: 'AppFont',
            color: isDarkMode ? Colors.white : baseColorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: baseColorScheme.primaryContainer,
        foregroundColor: baseColorScheme.onPrimaryContainer,
        actions: [
          if (_deletedLinks.isNotEmpty) ...[
            IconButton(
              icon: Icon(_selectedItems.length == _deletedLinks.length 
                ? Icons.deselect : Icons.select_all),
              onPressed: _selectAll,
            ),
            if (_selectedItems.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_forever),
                color: baseColorScheme.error,
                onPressed: _permanentlyDeleteSelected,
              ),
          ],
        ],
      ),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDarkMode
                    ? [
                        Colors.black,
                        Colors.grey[900]!,
                        Colors.grey[850]!,
                      ]
                    : [
                        baseColorScheme.primary.withOpacity(0.05),
                        baseColorScheme.surface,
                        baseColorScheme.surface,
                      ],
              ),
            ),
          ),
          // Original body content
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _deletedLinks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 80,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Trash is empty',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : _isGridView
                      ? _buildGridView(isDarkMode, baseColorScheme)
                      : _buildListView(isDarkMode, baseColorScheme),
        ],
      ),
    );
  }

  Widget _buildGridView(bool isDarkMode, ColorScheme colorScheme) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _deletedLinks.length,
      itemBuilder: (context, index) {
        final link = _deletedLinks[index];
        final isSelected = _selectedItems.contains(link.id);
        
        return OpenContainer(
          transitionDuration: const Duration(milliseconds: 250),
          openBuilder: (context, _) => LinkDetailPage(link: link),
          closedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          closedColor: Colors.transparent,
          closedBuilder: (context, openContainer) => InkWell(
            onLongPress: () => _toggleSelection(link.id!),
            onTap: _isSelectionMode ? () => _toggleSelection(link.id!) : openContainer,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.grey[900]?.withOpacity(0.7)
                        : colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDarkMode
                          ? colorScheme.primary.withOpacity(0.2)
                          : colorScheme.primary.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: colorScheme.primary.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          color: isDarkMode
                              ? colorScheme.primary.withOpacity(0.1)
                              : colorScheme.primaryContainer.withOpacity(0.5),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? colorScheme.primary.withOpacity(0.2)
                                    : colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.primary.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                _getIconForLink(link.url),
                                size: 20,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    Uri.parse(link.url).host.replaceAll('www.', ''),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDarkMode
                                          ? colorScheme.primary
                                          : colorScheme.primary.withOpacity(0.8),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                link.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.9)
                                      : colorScheme.onSurface,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (link.description.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  link.description,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: isDarkMode
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const Spacer(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    icon: Icon(
                                      Icons.restore,
                                      size: 16,
                                      color: colorScheme.primary,
                                    ),
                                    label: Text(
                                      'Restore',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                    onPressed: () async {
                                      await DatabaseHelper.instance.restore(link.id!);
                                      _loadDeletedLinks();
                                    },
                                  ),
                                  Text(
                                    "Deleted: ${_formatDate(link.createdAt)}",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDarkMode
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isSelectionMode || isSelected)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? colorScheme.primary : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? colorScheme.primary : colorScheme.outline,
                          width: 2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.check,
                          size: 16,
                          color: isSelected ? colorScheme.onPrimary : Colors.transparent,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListView(bool isDarkMode, ColorScheme colorScheme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _deletedLinks.length,
      itemBuilder: (context, index) {
        final link = _deletedLinks[index];
        final isSelected = _selectedItems.contains(link.id);
        
        return OpenContainer(
          transitionDuration: const Duration(milliseconds: 250),
          openBuilder: (context, _) => LinkDetailPage(link: link),
          closedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          closedColor: Colors.transparent,
          closedBuilder: (context, openContainer) => InkWell(
            onLongPress: () => _toggleSelection(link.id!),
            onTap: _isSelectionMode ? () => _toggleSelection(link.id!) : openContainer,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.grey[900]?.withOpacity(0.7)
                        : colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDarkMode
                          ? colorScheme.primary.withOpacity(0.2)
                          : colorScheme.primary.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: colorScheme.primary.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          color: isDarkMode
                              ? colorScheme.primary.withOpacity(0.1)
                              : colorScheme.primaryContainer.withOpacity(0.5),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? colorScheme.primary.withOpacity(0.2)
                                    : colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.primary.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                _getIconForLink(link.url),
                                size: 20,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    Uri.parse(link.url).host.replaceAll('www.', ''),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDarkMode
                                          ? colorScheme.primary
                                          : colorScheme.primary.withOpacity(0.8),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              link.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.9)
                                    : colorScheme.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (link.description.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                link.description,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: Icon(
                                    Icons.restore,
                                    size: 16,
                                    color: colorScheme.primary,
                                  ),
                                  label: Text(
                                    'Restore',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  onPressed: () async {
                                    await DatabaseHelper.instance.restore(link.id!);
                                    _loadDeletedLinks();
                                  },
                                ),
                                Text(
                                  "Deleted: ${_formatDate(link.createdAt)}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDarkMode
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isSelectionMode || isSelected)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? colorScheme.primary : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? colorScheme.primary : colorScheme.outline,
                          width: 2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.check,
                          size: 16,
                          color: isSelected ? colorScheme.onPrimary : Colors.transparent,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getIconForLink(String url) {
    return UrlUtils.getIconForUrl(url);
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}
