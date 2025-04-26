import 'package:flutter/material.dart';
import '../models/link.dart';
import '../services/database_helper.dart';
import 'link_detail_page.dart';
import 'package:animations/animations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/url_utils.dart';
import '../services/view_mode_service.dart';

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  List<Link> _archivedLinks = [];
  bool _isLoading = true;
  ThemeMode _themeMode = ThemeMode.system;
  static const String _themeModeKey = 'themeMode';
  bool _isGridView = true;

  // Add these new variables
  Set<int> _selectedItems = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _loadViewMode();
    _loadArchivedLinks();
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

  Future<void> _loadArchivedLinks() async {
    setState(() => _isLoading = true);
    final links = await DatabaseHelper.instance.getAllLinks(archived: true);
    setState(() {
      _archivedLinks = links;
      _isLoading = false;
    });
  }

  void _toggleSelection(int? linkId) {
    if (linkId == null) return;
    
    setState(() {
      if (_selectedItems.contains(linkId)) {
        _selectedItems.remove(linkId);
        if (_selectedItems.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedItems.add(linkId);
        _isSelectionMode = true;
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedItems.length == _archivedLinks.length) {
        // If all items are selected, unselect all
        _selectedItems.clear();
        _isSelectionMode = false;
      } else {
        // Otherwise, select all items
        _selectedItems = _archivedLinks.map((link) => link.id!).toSet();
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _unarchiveSelected() async {
    for (final id in _selectedItems) {
      await DatabaseHelper.instance.updateArchiveStatus(id, false);
    }
    setState(() {
      _selectedItems.clear();
      _isSelectionMode = false;
    });
    _loadArchivedLinks();
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
        title: _isSelectionMode
          ? Text(
              '${_selectedItems.length} selected',
              style: TextStyle(
                fontFamily: 'AppFont',
                color: isDarkMode ? Colors.white : baseColorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            )
          : Text(
              'Archive',
              style: TextStyle(
                fontFamily: 'AppFont',
                color: isDarkMode ? Colors.white : baseColorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
        backgroundColor: baseColorScheme.primaryContainer,
        foregroundColor: baseColorScheme.onPrimaryContainer,
        actions: [
          if (_archivedLinks.isNotEmpty) ...[
            IconButton(
              icon: Icon(_selectedItems.length == _archivedLinks.length 
                ? Icons.deselect 
                : Icons.select_all),
              onPressed: _selectAll,
            ),
            if (_isSelectionMode)
              IconButton(
                icon: const Icon(Icons.unarchive),
                onPressed: _unarchiveSelected,
              ),
          ],
        ],
        leading: _isSelectionMode
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _selectedItems.clear();
                  _isSelectionMode = false;
                });
              },
            )
          : null,
      ),
      // Modify the body to handle selection
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
              : _archivedLinks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.archive_outlined,
                            size: 80,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No archived links',
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
      // Add FAB for unarchive when items are selected
      floatingActionButton: _selectedItems.isNotEmpty
        ? FloatingActionButton.extended(
            onPressed: _unarchiveSelected,
            icon: const Icon(Icons.unarchive),
            label: const Text('Unarchive'),
          )
        : null,
    );
  }

  Widget _buildGridView(bool isDarkMode, ColorScheme colorScheme) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,  // Updated to match home page ratio
        crossAxisSpacing: 12,     // Match home page spacing
        mainAxisSpacing: 12,      // Match home page spacing
      ),
      itemCount: _archivedLinks.length,
      itemBuilder: (context, index) {
        final link = _archivedLinks[index];
        final isSelected = _selectedItems.contains(link.id);
        
        return OpenContainer(
          transitionDuration: const Duration(milliseconds: 250),
          openBuilder: (context, _) => LinkDetailPage(link: link),
          closedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          closedColor: Colors.transparent,
          closedBuilder: (context, openContainer) => InkWell(
            onLongPress: () => _toggleSelection(link.id),
            onTap: _isSelectionMode
              ? () => _toggleSelection(link.id)
              : openContainer,
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
                                  Text(
                                    "Archived: ${_formatDate(link.createdAt)}",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDarkMode
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
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
                              if (link.tags.isNotEmpty) ...[
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: link.tags
                                      .split(',')
                                      .take(2)
                                      .map((tag) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDarkMode
                                                  ? colorScheme.primary.withOpacity(0.15)
                                                  : colorScheme.primaryContainer,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: colorScheme.primary.withOpacity(0.1),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              tag.trim(),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: isDarkMode
                                                    ? colorScheme.primary
                                                    : colorScheme.primary.withOpacity(0.8),
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ],
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
      itemCount: _archivedLinks.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final link = _archivedLinks[index];
        final isSelected = _selectedItems.contains(link.id);
        
        return InkWell(
          onLongPress: () => _toggleSelection(link.id),
          onTap: _isSelectionMode
            ? () => _toggleSelection(link.id)
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LinkDetailPage(link: link),
                  ),
                ).then((_) => _loadArchivedLinks());
              },
          child: Stack(
            children: [
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                color: isDarkMode ? Colors.grey[850] : colorScheme.primaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: colorScheme.primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? colorScheme.primary.withOpacity(0.2)
                                  : colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _getIconForLink(link.url),
                              size: 20,
                              color: isDarkMode
                                  ? colorScheme.primary
                                  : colorScheme.onSecondaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  link.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode
                                        ? Colors.white
                                        : colorScheme.onPrimaryContainer,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Archived: ${_formatDate(link.createdAt)}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: isDarkMode
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: MediaQuery.of(context).size.width - 64,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.grey[800]
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          link.url,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode
                                ? Colors.blue[200]
                                : colorScheme.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (link.tags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: link.tags
                              .split(',')
                              .take(3)
                              .map((tag) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? colorScheme.primary.withOpacity(0.3)
                                          : colorScheme.tertiaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      tag.trim(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: isDarkMode
                                            ? Colors.white
                                            : colorScheme.onTertiaryContainer,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
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
