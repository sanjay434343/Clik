import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:animations/animations.dart';
import 'package:ukeep/pages/settings_page.dart';
import 'pages/add_link_page.dart';
import 'models/link.dart';
import 'services/database_helper.dart';
import 'pages/link_detail_page.dart';
import 'dart:math';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'pages/archive_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/deleted_page.dart';
import 'utils/url_utils.dart';
import 'services/theme_service.dart';
import 'dart:ui';
import 'pages/favorites_page.dart';  // Add this import at the top
import 'data/tags.dart'; // Add import for TagCategories
import 'services/view_mode_service.dart';

// Move enum to the top level - outside of any class
enum SortOption {
  none,
  dateNewest,
  dateOldest,
  titleAZ,
  titleZA,
  domainAZ
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  // Add GlobalKey for Scaffold
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  late AnimationController _rotationController;
  List<Link> _links = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isGridView = true;
  AppThemeMode _themeMode = AppThemeMode.system;
  bool _useDynamicColors = true;
  bool _isSelectionMode = false;
  Set<int> _selectedLinks = {};
  
  // Add search related variables
  bool _isSearchMode = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Link> _filteredLinks = [];

  // Add filter related variables
  bool _isFilterActive = false;
  Set<String> _selectedTags = {};
  DateTime? _startDate;
  DateTime? _endDate;
  Set<String> _availableTags = {};

  // Add scroll controller and FAB visibility
  final ScrollController _scrollController = ScrollController();
  bool _isFabVisible = true;

  // Remove enum declaration here and replace with just the variable
  SortOption _currentSortOption = SortOption.dateNewest;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _loadThemePreference();
    _loadLinks();
    _loadViewMode();
    
    // Add a listener to update when theme changes
    ThemeService.addListener(_loadThemePreference);
    
    // Add listener for search text changes
    _searchController.addListener(_onSearchChanged);

    // Add scroll listener to hide/show FAB
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    
    // Remove listener when the page is disposed
    ThemeService.removeListener(_loadThemePreference);
    
    // Dispose of the search controller
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();

    // Dispose of scroll controller
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _filterLinks();
    });
  }

  void _filterLinks() {
    if (_searchQuery.isEmpty && !_isFilterActive) {
      _filteredLinks = List.from(_links);
      return;
    }
    
    // Start with all links
    var filtered = List<Link>.from(_links);
    
    // Apply text search if query exists
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      filtered = filtered.where((link) {
        // Check title, description, URL, tags
        final inTitle = link.title.toLowerCase().contains(query);
        final inDescription = link.description.toLowerCase().contains(query);
        final inUrl = link.url.toLowerCase().contains(query);
        final inTags = link.tags.toLowerCase().contains(query);
        
        // Check date and domain
        final dateDay = "${link.createdAt.day}/${link.createdAt.month}/${link.createdAt.year}";
        final dateMonth = _getMonthName(link.createdAt.month).toLowerCase();
        final inDate = dateDay.contains(query) || dateMonth.contains(query);
        final domain = _getDomainFromUrl(link.url).toLowerCase();
        final inDomain = domain.contains(query);
        
        return inTitle || inDescription || inUrl || inTags || inDate || inDomain;
      }).toList();
    }
    
    // Apply tag filter if any tags are selected
    if (_selectedTags.isNotEmpty) {
      filtered = filtered.where((link) {
        if (link.tags.isEmpty) return false;
        final linkTags = link.tags.split(',').map((tag) => tag.trim()).toSet();
        // Check if any of the selected tags are in the link's tags
        return _selectedTags.any((tag) => linkTags.contains(tag));
      }).toList();
    }
    
    // Apply date range filter if date range is selected
    if (_startDate != null || _endDate != null) {
      filtered = filtered.where((link) {
        if (_startDate != null && link.createdAt.isBefore(_startDate!)) {
          return false;
        }
        if (_endDate != null) {
          // Add one day to end date to include the entire end date
          final adjustedEndDate = _endDate!.add(const Duration(days: 1));
          if (link.createdAt.isAfter(adjustedEndDate)) {
            return false;
          }
        }
        return true;
      }).toList();
    }
    
    // Update filtered links
    _filteredLinks = filtered;
    
    // Update filter active status
    _isFilterActive = _selectedTags.isNotEmpty || _startDate != null || _endDate != null;
    
    print('Search with filters: Found ${_filteredLinks.length} results');
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1]; // Months are 1-based, array is 0-based
  }

  Future<void> _loadThemePreference() async {
    final themeMode = await ThemeService.getThemeMode();
    final useDynamicColors = await ThemeService.getUseDynamicColors();
    
    if (mounted) {
      setState(() {
        _themeMode = themeMode;
        _useDynamicColors = useDynamicColors;
      });
    }
  }

  Future<void> _saveThemeMode(AppThemeMode mode) async {
    await ThemeService.setThemeMode(mode);
    // No need to setState here, as _loadThemePreference will be called through the listener
  }

  Future<void> _loadLinks() async {
    setState(() => _isLoading = true);
    try {
      final links = await DatabaseHelper.instance.getAllLinks(archived: false);
      setState(() {
        _links = links;
        _loadAvailableTags(); // Update available tags when links load
        _sortLinks();  // Apply current sorting
        _filterLinks(); // Apply current search filter
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _loadAvailableTags() {
    _availableTags = {};
    for (final link in _links) {
      if (link.tags.isNotEmpty) {
        final tags = link.tags.split(',').map((tag) => tag.trim()).toSet();
        _availableTags.addAll(tags);
      }
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    _rotationController.repeat();
    HapticFeedback.mediumImpact();
    
    await _loadLinks();
    
    setState(() => _isRefreshing = false);
    _rotationController.stop();
  }

  void _onFabPressed() {
    HapticFeedback.mediumImpact();
    _rotationController.forward(from: 0);
  }

  void _toggleSelection(int? linkId) {
    if (linkId == null) return;
    
    setState(() {
      if (_selectedLinks.contains(linkId)) {
        _selectedLinks.remove(linkId);
        if (_selectedLinks.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedLinks.add(linkId);
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _moveSelectedToTrash() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Move to Trash'),
        content: Text('Move ${_selectedLinks.length} items to trash?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Move'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (final id in _selectedLinks) {
        await DatabaseHelper.instance.softDelete(id);
      }
      setState(() {
        _selectedLinks.clear();
        _isSelectionMode = false;
      });
      _loadLinks();
    }
  }

  void _showLinkActions(BuildContext context, Link link) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.select_all, color: colorScheme.primary),
            title: Text('Select All', style: TextStyle(color: colorScheme.onSurface)),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _isSelectionMode = true;
                _selectedLinks = _links.map((link) => link.id!).toSet();
              });
            },
          ),
          ListTile(
            leading: Icon(
              link.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: link.isPinned ? colorScheme.primary : colorScheme.primary,
            ),
            title: Text(
              link.isPinned ? 'Unpin' : 'Pin to Top',
              style: TextStyle(color: colorScheme.onSurface),
            ),
            onTap: () async {
              Navigator.pop(context);
              await DatabaseHelper.instance.updatePinStatus(link.id!, !link.isPinned);
              _loadLinks();
            },
          ),
          ListTile(
            leading: Icon(
              link.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: link.isFavorite ? colorScheme.error : colorScheme.primary,
            ),
            title: Text(
              link.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
              style: TextStyle(color: colorScheme.onSurface),
            ),
            onTap: () async {
              Navigator.pop(context);
              await DatabaseHelper.instance.updateFavoriteStatus(link.id!, !link.isFavorite);
              _loadLinks();
            },
          ),
          ListTile(
            leading: Icon(Icons.share, color: colorScheme.primary),
            title: Text('Share', style: TextStyle(color: colorScheme.onSurface)),
            onTap: () {
              Navigator.pop(context);
              Share.share('${link.title}\n${link.url}');
            },
          ),
          ListTile(
            leading: Icon(Icons.archive, color: colorScheme.primary),
            title: Text('Archive', style: TextStyle(color: colorScheme.onSurface)),
            onTap: () async {
              Navigator.pop(context);
              await DatabaseHelper.instance.updateArchiveStatus(link.id!, true);
              _loadLinks();
            },
          ),
          ListTile(
            leading: Icon(Icons.delete, color: colorScheme.error),
            title: Text('Move to Trash', style: TextStyle(color: colorScheme.onSurface)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Move to Trash', style: TextStyle(color: colorScheme.onSurface)),
                  content: Text(
                    'Are you sure you want to move this link to trash?',
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                  backgroundColor: colorScheme.surface,
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('Cancel', style: TextStyle(color: colorScheme.primary)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('Move', style: TextStyle(color: colorScheme.error)),
                    ),
                  ],
                ),
              );
              
              if (confirm == true && mounted) {
                Navigator.pop(context);
                await DatabaseHelper.instance.softDelete(link.id!);
                _loadLinks();
              }
            },
          ),
        ],
      ),
    );
  }

  Color _getCardColor(int index, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = [
      colorScheme.primaryContainer,
      colorScheme.secondaryContainer,
      colorScheme.tertiaryContainer,
      colorScheme.surfaceContainerHighest,
      colorScheme.inversePrimary,
    ];
    return colors[index % colors.length];
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _links.removeAt(oldIndex);
      _links.insert(newIndex, item);
    });
  }

  void _toggleViewMode() async {
    final newValue = !_isGridView;
    await ViewModeService.instance.setIsGridView(newValue);
    setState(() {
      _isGridView = newValue;
    });
  }

  Widget _buildViewToggle() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = _themeMode == AppThemeMode.staticDark || 
        (_themeMode == AppThemeMode.system && 
         MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: IconButton(
        icon: Icon(_isGridView ? Icons.grid_view : Icons.view_list),
        tooltip: _isGridView ? 'Grid View' : 'List View',
        style: IconButton.styleFrom(
          backgroundColor: _currentSortOption != SortOption.none
              ? isDarkMode
                  ? colorScheme.primaryContainer.withOpacity(0.7)
                  : colorScheme.primaryContainer.withOpacity(0.7) 
              : Colors.transparent,
          foregroundColor: colorScheme.primary.withOpacity(0.87),
        ),
        onPressed: _toggleViewMode,
      ),
    );
  }

  Future<void> _loadViewMode() async {
    final isGridView = await ViewModeService.instance.getIsGridView();
    setState(() => _isGridView = isGridView);
  }

  void _showComingSoonDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon'),
        content: const Text('We are working on backup functionality. Stay tuned!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = _themeMode == AppThemeMode.staticDark || 
        (_themeMode == AppThemeMode.system && 
        MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Drawer(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
            ),
            child: Column(
              children: [
                // Full-width toggle button at the top
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorScheme.primary.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Grid view button
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _isGridView = true),
                                child: Container(
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _isGridView ? colorScheme.primary : Colors.transparent,
                                    borderRadius: BorderRadius.horizontal(left: Radius.circular(7)),
                                  ),
                                  child: Icon(
                                    Icons.grid_view,
                                    size: 18,
                                    color: _isGridView 
                                        ? colorScheme.onPrimary 
                                        : colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ),
                            // List view button
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _isGridView = false),
                                child: Container(
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: !_isGridView ? colorScheme.primary : Colors.transparent,
                                    borderRadius: BorderRadius.horizontal(right: Radius.circular(7)),
                                  ),
                                  child: Icon(
                                    Icons.view_list,
                                    size: 18,
                                    color: !_isGridView 
                                        ? colorScheme.onPrimary 
                                        : colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Spacer to push text to bottom
                const Spacer(),
                // App title text at bottom in drawer
                Text(
                  'Clik',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900, // Use w900 for extra bold
                    color: colorScheme.onPrimaryContainer.withOpacity(0.95), // Increased from default
                    fontFamily: 'fnt', // Changed from Jersey to fnt
                  ),
                ),
                const SizedBox(height: 16), // Bottom padding
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: Icon(Icons.favorite, color: colorScheme.error),
                  title: const Text('Favorites'),
                  textColor: colorScheme.onSurface,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FavoritesPage(),
                      ),
                    ).then((_) => _loadLinks());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.archive_outlined),
                  title: const Text('Archive'),
                  iconColor: colorScheme.primary,
                  textColor: colorScheme.onSurface,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ArchivePage()),
                    ).then((_) => _loadLinks());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.restore_from_trash),
                  title: const Text('Trash'),
                  iconColor: colorScheme.primary,
                  textColor: colorScheme.onSurface,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DeletedPage()),
                    ).then((_) => _loadLinks());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Backup'),
                  iconColor: colorScheme.primary,
                  textColor: colorScheme.onSurface,
                  onTap: () {
                    Navigator.pop(context);
                    _showComingSoonDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.palette_outlined), // Changed from settings to palette_outlined
                  title: Text(
                    'Themes',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                    ),
                  ),
                  iconColor: colorScheme.primary,
                  textColor: colorScheme.onSurface,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SettingsPage(
                          onThemeChanged: () => _loadThemePreference(),
                        ),
                      ),
                    );
                  },
                ),
                // Add View Licenses button
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('View Licenses'),
                  iconColor: colorScheme.primary,
                  textColor: colorScheme.onSurface,
                  onTap: () {
                    Navigator.pop(context);
                    showLicensePage(
                      context: context,
                      applicationName: 'Clik',
                      applicationVersion: '1.0.0',
                      applicationIcon: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          FontAwesomeIcons.link,
                          size: 36,
                          color: colorScheme.primary,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = _themeMode == AppThemeMode.staticDark || 
        (_themeMode == AppThemeMode.system && 
         MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        // More sensitive swipe detection
        if (details.delta.dx > 8) { // Reduced threshold
          _scaffoldKey.currentState?.openDrawer(); // Use GlobalKey instead
          // Add haptic feedback
          HapticFeedback.lightImpact();
        }
      },
      child: Scaffold(
        key: _scaffoldKey, // Add the key here
        drawerEdgeDragWidth: MediaQuery.of(context).size.width * 0.2, // 20% of screen width
        drawerEnableOpenDragGesture: true,
        drawer: _buildDrawer(),
        appBar: _isSearchMode 
            ? _buildSearchAppBar(colorScheme, isDarkMode)
            : _buildNormalAppBar(colorScheme, isDarkMode),
        // Add gesture indicator
        body: Stack(
          children: [
            // Your existing body content
            if (!_isSearchMode) ...[
              Positioned(
                left: 0,
                top: MediaQuery.of(context).size.height * 0.4, // 40% from top
                child: Container(
                  width: 3,
                  height: 80,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.3),
                    borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                  ),
                ),
              ),
            ],
            // Wrap your existing body with positioned
            Positioned.fill(
              child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: colorScheme.primary,
                      strokeWidth: 3,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: colorScheme.primary,
                    backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
                    strokeWidth: 3,
                    child: NotificationListener<ScrollUpdateNotification>(
                      onNotification: (notification) {
                        if (notification.dragDetails != null) {
                          _rotationController.value = 
                              (notification.metrics.pixels / 100).clamp(0.0, 1.0);
                        }
                        return false;
                      },
                      child: Stack(
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
                                        colorScheme.primary.withOpacity(0.05),
                                        colorScheme.surface,
                                        colorScheme.surface,
                                      ],
                              ),
                            ),
                          ),
                          
                          // Main content
                          (_isSearchMode ? _filteredLinks : _links).isEmpty
                              ? _buildEmptyState(isDarkMode, colorScheme, isSearchResults: _isSearchMode)
                              : _isGridView
                                  ? _buildGridView(isDarkMode, colorScheme)
                                  : _buildListView(isDarkMode, colorScheme),
                                  
                          // Refresh animation overlay
                          if (_isRefreshing)
                            _buildRefreshOverlay(colorScheme),
                        ],
                      ),
                    ),
                  ),
            ),
          ],
        ),
        // Only show FAB when NOT in search mode
        floatingActionButton: _isSearchMode 
            ? null 
            : AnimatedSlide(
                duration: const Duration(milliseconds: 300),
                offset: _isFabVisible ? Offset.zero : const Offset(0, 2),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _isFabVisible ? 1.0 : 0.0,
                  child: _buildFAB(colorScheme),
                ),
              ),
      ),
    );
  }

  PreferredSize _buildSearchAppBar(ColorScheme colorScheme, bool isDarkMode) {
    final resultCount = _filteredLinks.length;
    final hasResults = _searchController.text.isNotEmpty;
    
    // Create filter chips
    List<Widget> filterChips = [];
    
    // Add tag chips
    for (String tag in _selectedTags) {
      filterChips.add(
        Container(
          margin: const EdgeInsets.only(right: 6, bottom: 4),
          padding: const EdgeInsets.symmetric(
            horizontal: 8, 
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: isDarkMode
                ? colorScheme.primary.withOpacity(0.15)
                : colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tag,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode
                      ? colorScheme.primary
                      : colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTags.remove(tag);
                    _isFilterActive = _selectedTags.isNotEmpty || _startDate != null || _endDate != null;
                    _filterLinks();
                  });
                },
                child: Icon(
                  Icons.close,
                  size: 12,
                  color: isDarkMode
                      ? colorScheme.primary
                      : colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Add date range chip if needed
    if (_startDate != null || _endDate != null) {
      filterChips.add(
        Container(
          margin: const EdgeInsets.only(right: 6, bottom: 4),
          padding: const EdgeInsets.symmetric(
            horizontal: 8, 
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: isDarkMode
                ? colorScheme.primary.withOpacity(0.15)
                : colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _startDate != null && _endDate != null
                    ? "${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}"
                    : _startDate != null
                        ? "From ${_formatDate(_startDate!)}"
                        : "Until ${_formatDate(_endDate!)}",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode
                      ? colorScheme.primary
                      : colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                    _isFilterActive = _selectedTags.isNotEmpty;
                    _filterLinks();
                  });
                },
                child: Icon(
                  Icons.close,
                  size: 12,
                  color: isDarkMode
                      ? colorScheme.primary
                      : colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Calculate the height of the AppBar based on whether filters are active
    final double appBarHeight = 80 + (_isFilterActive ? 40.0 : 0.0);
    
    return PreferredSize(
      preferredSize: Size.fromHeight(appBarHeight),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [Colors.grey.shade900, Colors.grey.shade900.withOpacity(0.95)]
                : [colorScheme.primaryContainer, colorScheme.primaryContainer.withOpacity(0.95)],
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Row(
                  children: [
                    // Back button
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      style: IconButton.styleFrom(
                        backgroundColor: isDarkMode
                            ? Colors.grey.shade800.withOpacity(0.5)
                            : colorScheme.surface.withOpacity(0.7),
                        foregroundColor: colorScheme.primary,
                      ),
                      onPressed: () {
                        setState(() {
                          _isSearchMode = false;
                          _searchController.clear();
                          // Clear any filters when exiting search
                          _selectedTags = {};
                          _startDate = null;
                          _endDate = null;
                          _isFilterActive = false;
                        });
                      },
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Search field expanded
                    Expanded(
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.grey.shade800
                              : colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 8),
                            Icon(
                              Icons.search,
                              size: 20,
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.6)
                                  : colorScheme.primary.withOpacity(0.6),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                autofocus: true,
                                decoration: InputDecoration(
                                  hintText: 'Search links...',
                                  hintStyle: TextStyle(
                                    color: isDarkMode 
                                        ? Colors.white.withOpacity(0.6) 
                                        : colorScheme.onPrimaryContainer.withOpacity(0.6),
                                    fontSize: 16,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white : colorScheme.onPrimaryContainer,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Colors.grey.shade700.withOpacity(0.5)
                                        : colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: isDarkMode
                                        ? Colors.white.withOpacity(0.8)
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Filter button with background when active
                    IconButton(
                      icon: const Icon(Icons.filter_list),
                      tooltip: 'Filter',
                      style: IconButton.styleFrom(
                        backgroundColor: _isFilterActive
                            ? colorScheme.primaryContainer
                            : isDarkMode
                                ? Colors.grey.shade800.withOpacity(0.5)
                                : colorScheme.surface.withOpacity(0.7),
                        foregroundColor: _isFilterActive
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      onPressed: _showFilterDialog,
                    ),
                  ],
                ),
              ),
              
              // Results count and filter chips
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  children: [
                    if (hasResults)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$resultCount result${resultCount != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Filter chips row
              if (_isFilterActive)
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
                    child: Row(
                      children: filterChips,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildNormalAppBar(ColorScheme colorScheme, bool isDarkMode) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [Colors.grey.shade900, Colors.grey.shade900.withOpacity(0.95)]
                : [colorScheme.primaryContainer, colorScheme.primaryContainer.withOpacity(0.95)],
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        margin: const EdgeInsets.only(bottom: 2),
      ),
      foregroundColor: isDarkMode
          ? Colors.white.withOpacity(0.87) // Darkened white
          : colorScheme.onPrimaryContainer.withOpacity(0.87), // Darkened text
      leading: _isSelectionMode
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSelectionMode = false;
                  _selectedLinks.clear();
                });
              },
            )
          : null,
      title: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: isDarkMode 
              ? Colors.white.withOpacity(0.95) // Increased from 0.87
              : colorScheme.primary.withOpacity(0.95), // Increased from 0.87
          fontFamily: 'fnt', // Changed from Jersey to fnt
        ),
        child: _isSelectionMode
            ? Text('${_selectedLinks.length} selected')
            : const Text('Clik'),
      ),
      actions: [
        if (_isSelectionMode) ...[
          IconButton(
            icon: const Icon(Icons.delete),
            style: IconButton.styleFrom(
              foregroundColor: colorScheme.error.withOpacity(0.87), // Darkened error
            ),
            onPressed: _moveSelectedToTrash,
          ),
        ] else ...[
          // Search button first
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            style: IconButton.styleFrom(
              foregroundColor: colorScheme.primary.withOpacity(0.87), // Darkened primary
            ),
            onPressed: () {
              setState(() {
                _isSearchMode = true;
              });
            },
          ),
          const SizedBox(width: 4),
          // Sort button with background if active
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            style: IconButton.styleFrom(
              backgroundColor: _currentSortOption != SortOption.none
                  ? isDarkMode
                      ? colorScheme.primaryContainer.withOpacity(0.7)
                      : colorScheme.primaryContainer.withOpacity(0.7) 
                  : Colors.transparent,
              foregroundColor: colorScheme.primary.withOpacity(0.87), // Darkened primary
            ),
            onPressed: _showSortOptions,
          ),
          const SizedBox(width: 8),
        ],
      ],
      centerTitle: false,
      titleSpacing: 4,
      toolbarHeight: 64,
    );
  }

  Widget _buildEmptyState(bool isDarkMode, ColorScheme colorScheme, {bool isSearchResults = false}) {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDarkMode 
              ? Colors.grey[850]?.withOpacity(0.5) 
              : colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSearchResults ? Icons.search_off : FontAwesomeIcons.link,
              size: 64,
              color: colorScheme.primary.withOpacity(0.7),
            ),
            const SizedBox(height: 24),
            Text(
              isSearchResults ? 'No matches found' : 'No links yet!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            if (!isSearchResults)
              Text(
                'Tap + to add your first link',
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            if (isSearchResults)
              Text(
                'Try different keywords or filters',
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridView(bool isDarkMode, ColorScheme colorScheme) {
    final displayLinks = _isSearchMode ? _filteredLinks : _links;
    
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16), // Remove top padding since app bar is solid now
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: displayLinks.length,
      itemBuilder: (context, index) {
        final link = displayLinks[index];
        return _buildGridCard(link, isDarkMode, colorScheme);
      },
    );
  }

  Widget _buildGridCard(Link link, bool isDarkMode, ColorScheme colorScheme) {
    final isSelected = _selectedLinks.contains(link.id);
    
    return OpenContainer(
      transitionDuration: const Duration(milliseconds: 250), // Speed up animation
      openBuilder: (context, _) => LinkDetailPage(link: link),
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      closedColor: Colors.transparent,
      closedElevation: 0, // Add this to remove shadow
      closedBuilder: (context, openContainer) => InkWell(
        onLongPress: () => _isSelectionMode 
            ? _toggleSelection(link.id)
            : _showLinkActions(context, link),
        onTap: _isSelectionMode
            ? () => _toggleSelection(link.id)
            : openContainer,
        child: Stack(
          children: [
            // Card content
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
                // Remove shadow
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with icon and status indicators
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
                                _getDomainFromUrl(link.url),
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
                                _formatDate(link.createdAt),
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
                        if (link.isPinned || link.isFavorite) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (link.isPinned)
                                Icon(
                                  Icons.push_pin,
                                  size: 16,
                                  color: colorScheme.primary,
                                ),
                              if (link.isPinned && link.isFavorite)
                                const SizedBox(width: 4),
                              if (link.isFavorite)
                                Icon(
                                  Icons.favorite,
                                  size: 16,
                                  color: colorScheme.error,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Content area
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
                            Expanded(
                              child: Text(
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
                                        ),
                                        child: Text(
                                          tag.trim(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: isDarkMode
                                                ? colorScheme.primary
                                                : colorScheme.onPrimaryContainer,
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
            
            // Selection overlay
            if (_isSelectionMode)
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
  }

  Widget _buildListView(bool isDarkMode, ColorScheme colorScheme) {
    final displayLinks = _isSearchMode ? _filteredLinks : _links;
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: displayLinks.length,
      itemBuilder: (context, index) {
        final link = displayLinks[index];
        return OpenContainer(
          transitionDuration: const Duration(milliseconds: 250), // Speed up animation
          openBuilder: (context, _) => LinkDetailPage(link: link),
          closedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          closedColor: Colors.transparent,
          closedElevation: 0, // Add this to remove shadow
          closedBuilder: (context, openContainer) => Dismissible(
            key: ValueKey(link.id),
            background: Container(
              color: colorScheme.error,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            direction: DismissDirection.endToStart,
            onDismissed: (_) async {
              await DatabaseHelper.instance.softDelete(link.id!);
              _loadLinks();
            },
            child: _buildListCard(link, isDarkMode, colorScheme, openContainer),
          ),
        );
      },
    );
  }

  Widget _buildListCard(Link link, bool isDarkMode, ColorScheme colorScheme, VoidCallback openContainer) {
    final isSelected = _selectedLinks.contains(link.id);
    
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
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
          // Remove shadow
        ),
        child: Stack(
          children: [
            InkWell(
              onLongPress: () => _isSelectionMode 
                  ? _toggleSelection(link.id)
                  : _showLinkActions(context, link),
              onTap: _isSelectionMode
                  ? () => _toggleSelection(link.id)
                  : openContainer,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with icon and status indicators
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
                                _getDomainFromUrl(link.url),
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
                                _formatDate(link.createdAt),
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
                        if (link.isPinned || link.isFavorite) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (link.isPinned)
                                Icon(
                                  Icons.push_pin,
                                  size: 16,
                                  color: colorScheme.primary,
                                ),
                              if (link.isPinned && link.isFavorite)
                                const SizedBox(width: 4),
                              if (link.isFavorite)
                                Icon(
                                  Icons.favorite,
                                  size: 16,
                                  color: colorScheme.error,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Content area
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        if (link.description.isNotEmpty) ...[
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
                          const SizedBox(height: 8),
                        ],
                        Container(
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
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDarkMode
                                            ? colorScheme.primary.withOpacity(0.15)
                                            : colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        tag.trim(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isDarkMode
                                              ? colorScheme.primary
                                              : colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Selection checkbox
            if (_isSelectionMode)
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
  }

  Widget _buildRefreshOverlay(ColorScheme colorScheme) {
    return Positioned(
      top: 20,
      left: 0,
      right: 0,
      child: Center(
        child: RotationTransition(
          turns: _rotationController,
          child: Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            child: FaIcon(
              FontAwesomeIcons.link,
              size: 30,
              color: colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFAB(ColorScheme colorScheme) {
    return OpenContainer<bool>(
      transitionType: ContainerTransitionType.fade,
      openBuilder: (context, _) => const AddLinkPage(sharedUrl: '',),
      onClosed: (result) {
        if (result == true) {
          _loadLinks();
        }
      },
      closedElevation: 6.0,
      openElevation: 0,
      transitionDuration: const Duration(milliseconds: 250), // Speed up animation
      middleColor: colorScheme.primary,
      closedColor: colorScheme.primary,
      closedShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(56.0)),
      ),
      openShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.zero),
      ),
      closedBuilder: (context, openContainer) => RotationTransition(
        turns: Tween(begin: 0.0, end: 1.0).animate(_rotationController),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
                spreadRadius: -2,
              ),
            ],
          ),
          child: FloatingActionButton(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            elevation: 0, // Remove default elevation since we're using custom shadows
            onPressed: () {
              _onFabPressed();
              openContainer(); // Trigger navigation without awaiting a value.
            },
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }

  IconData _getIconForLink(String url) {
    return UrlUtils.getIconForUrl(url);
  }

  String _getTruncatedTitle(String title) {
    if (title.length <= 40) return title;
    return '${title.substring(0, 37)}...';
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  String _getDomainFromUrl(String url) {
    return Uri.parse(url).host.replaceAll('www.', '');
  }

  // Show filter dialog
  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Makes bottom sheet full height
      backgroundColor: Colors.transparent,
      builder: (context) => _buildFilterBottomSheet(context),
    );
  }
  
  // Build filter bottom sheet
  Widget _buildFilterBottomSheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = _themeMode == AppThemeMode.staticDark || 
        (_themeMode == AppThemeMode.system && 
         MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    
    // Temporary state variables for the bottom sheet
    Set<String> tempSelectedTags = Set.from(_selectedTags);
    DateTime? tempStartDate = _startDate;
    DateTime? tempEndDate = _endDate;
    
    // Get custom tags from links that aren't in the predefined categories
    Set<String> customTags = {};
    for (final tag in _availableTags) {
      if (!TagCategories.common.contains(tag) && 
          !TagCategories.types.contains(tag) && 
          !TagCategories.categories.contains(tag) && 
          !TagCategories.platforms.contains(tag)) {
        customTags.add(tag);
      }
    }
    
    return StatefulBuilder(
      builder: (context, setState) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (_, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[900] : colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : colorScheme.onSurface,
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                tempSelectedTags = {};
                                tempStartDate = null;
                                tempEndDate = null;
                              });
                            },
                            child: Text(
                              'Reset',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        // Date Range Picker
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final date = await showDatePicker(
                                          context: context,
                                          initialDate: tempStartDate ?? DateTime.now(),
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100),
                                        );
                                        if (date != null) {
                                          setState(() {
                                            tempStartDate = date;
                                          });
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: colorScheme.primary.withOpacity(0.3),
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              tempStartDate != null 
                                                  ? '${tempStartDate!.day}/${tempStartDate!.month}/${tempStartDate!.year}'
                                                  : 'Start Date',
                                              style: TextStyle(
                                                color: isDarkMode ? Colors.white : colorScheme.onSurface,
                                              ),
                                            ),
                                            Icon(
                                              Icons.calendar_today,
                                              size: 16,
                                              color: colorScheme.primary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final date = await showDatePicker(
                                          context: context,
                                          initialDate: tempEndDate ?? DateTime.now(),
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100),
                                        );
                                        if (date != null) {
                                          setState(() {
                                            tempEndDate = date;
                                          });
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: colorScheme.primary.withOpacity(0.3),
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              tempEndDate != null 
                                                  ? '${tempEndDate!.day}/${tempEndDate!.month}/${tempEndDate!.year}'
                                                  : 'End Date',
                                              style: TextStyle(
                                                color: isDarkMode ? Colors.white : colorScheme.onSurface,
                                              ),
                                            ),
                                            Icon(
                                              Icons.calendar_today,
                                              size: 16,
                                              color: colorScheme.primary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        // Common Tags Section
                        if (TagCategories.common.isNotEmpty) ...[
                          _buildTagCategorySection(
                            'Common Tags', 
                            TagCategories.common, 
                            tempSelectedTags, 
                            (tag, selected) {
                              setState(() {
                                if (selected) {
                                  tempSelectedTags.add(tag);
                                } else {
                                  tempSelectedTags.remove(tag);
                                }
                              });
                            },
                            isDarkMode,
                            colorScheme,
                          ),
                        ],
                        
                        // Content Types Section
                        if (TagCategories.types.isNotEmpty) ...[
                          _buildTagCategorySection(
                            'Content Types', 
                            TagCategories.types, 
                            tempSelectedTags, 
                            (tag, selected) {
                              setState(() {
                                if (selected) {
                                  tempSelectedTags.add(tag);
                                } else {
                                  tempSelectedTags.remove(tag);
                                }
                              });
                            },
                            isDarkMode,
                            colorScheme,
                          ),
                        ],
                        
                        // Categories Section
                        if (TagCategories.categories.isNotEmpty) ...[
                          _buildTagCategorySection(
                            'Categories', 
                            TagCategories.categories, 
                            tempSelectedTags, 
                            (tag, selected) {
                              setState(() {
                                if (selected) {
                                  tempSelectedTags.add(tag);
                                } else {
                                  tempSelectedTags.remove(tag);
                                }
                              });
                            },
                            isDarkMode,
                            colorScheme,
                          ),
                        ],
                        
                        // Platforms Section
                        if (TagCategories.platforms.isNotEmpty) ...[
                          _buildTagCategorySection(
                            'Platforms', 
                            TagCategories.platforms, 
                            tempSelectedTags, 
                            (tag, selected) {
                              setState(() {
                                if (selected) {
                                  tempSelectedTags.add(tag);
                                } else {
                                  tempSelectedTags.remove(tag);
                                }
                              });
                            },
                            isDarkMode,
                            colorScheme,
                          ),
                        ],
                        
                        // Custom tags from links
                        if (customTags.isNotEmpty) ...[
                          _buildTagCategorySection(
                            'Other Tags', 
                            customTags.toList(), 
                            tempSelectedTags, 
                            (tag, selected) {
                              setState(() {
                                if (selected) {
                                  tempSelectedTags.add(tag);
                                } else {
                                  tempSelectedTags.remove(tag);
                                }
                              });
                            },
                            isDarkMode,
                            colorScheme,
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Apply button
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: ElevatedButton(
                      onPressed: () {
                        // Apply filters
                        this.setState(() {
                          _selectedTags = tempSelectedTags;
                          _startDate = tempStartDate;
                          _endDate = tempEndDate;
                          _isFilterActive = _selectedTags.isNotEmpty || _startDate != null || _endDate != null;
                        });
                        _filterLinks();
                        
                        // Close keyboard when filters are applied
                        FocusManager.instance.primaryFocus?.unfocus();
                        
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    );
  }
  
  // Helper method to build a tag category section
  Widget _buildTagCategorySection(
    String title, 
    List<String> tags, 
    Set<String> selectedTags, 
    Function(String, bool) onTagSelected,
    bool isDarkMode,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tag) {
              final isSelected = selectedTags.contains(tag);
              return FilterChip(
                label: Text(tag),
                selected: isSelected,
                onSelected: (selected) => onTagSelected(tag, selected),
                backgroundColor: isDarkMode 
                    ? Colors.grey[800] 
                    : colorScheme.surfaceContainerHighest,
                selectedColor: colorScheme.primaryContainer,
                checkmarkColor: colorScheme.primary,
                labelStyle: TextStyle(
                  color: isSelected
                      ? colorScheme.primary
                      : (isDarkMode ? Colors.white : colorScheme.onSurface),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Handle scroll events to show/hide FAB
  void _onScroll() {
    if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
      if (_isFabVisible) setState(() => _isFabVisible = false);
    } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
      if (!_isFabVisible) setState(() => _isFabVisible = true);
    }
  }

  // Add method to show sort options
  void _showSortOptions() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = _themeMode == AppThemeMode.staticDark || 
        (_themeMode == AppThemeMode.system && 
        MediaQuery.platformBrightnessOf(context) == Brightness.dark);
        
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey[900] : colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Sort by',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : colorScheme.onSurface,
              ),
            ),
          ),
          // Add None option
          ListTile(
            leading: Icon(
              Icons.clear_all, 
              color: _currentSortOption == SortOption.none 
                ? colorScheme.primary 
                : null
            ),
            title: Text(
              'None',
              style: TextStyle(
                color: isDarkMode ? Colors.white : colorScheme.onSurface,
                fontWeight: _currentSortOption == SortOption.none 
                  ? FontWeight.bold 
                  : FontWeight.normal,
              ),
            ),
            trailing: _currentSortOption == SortOption.none 
              ? Icon(Icons.check, color: colorScheme.primary) 
              : null,
            onTap: () {
              _applySorting(SortOption.none);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.calendar_today, 
              color: _currentSortOption == SortOption.dateNewest 
                ? colorScheme.primary 
                : null
            ),
            title: Text(
              'Date (Newest first)',
              style: TextStyle(
                color: isDarkMode ? Colors.white : colorScheme.onSurface,
                fontWeight: _currentSortOption == SortOption.dateNewest 
                  ? FontWeight.bold 
                  : FontWeight.normal,
              ),
            ),
            trailing: _currentSortOption == SortOption.dateNewest 
              ? Icon(Icons.check, color: colorScheme.primary) 
              : null,
            onTap: () {
              _applySorting(SortOption.dateNewest);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.calendar_today,
              color: _currentSortOption == SortOption.dateOldest 
                ? colorScheme.primary 
                : null
            ),
            title: Text(
              'Date (Oldest first)',
              style: TextStyle(
                color: isDarkMode ? Colors.white : colorScheme.onSurface,
                fontWeight: _currentSortOption == SortOption.dateOldest 
                  ? FontWeight.bold 
                  : FontWeight.normal,
              ),
            ),
            trailing: _currentSortOption == SortOption.dateOldest 
              ? Icon(Icons.check, color: colorScheme.primary) 
              : null,
            onTap: () {
              _applySorting(SortOption.dateOldest);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.sort_by_alpha, 
              color: _currentSortOption == SortOption.titleAZ 
                ? colorScheme.primary 
                : null
            ),
            title: Text(
              'Title (A-Z)',
              style: TextStyle(
                color: isDarkMode ? Colors.white : colorScheme.onSurface,
                fontWeight: _currentSortOption == SortOption.titleAZ 
                  ? FontWeight.bold 
                  : FontWeight.normal,
              ),
            ),
            trailing: _currentSortOption == SortOption.titleAZ 
              ? Icon(Icons.check, color: colorScheme.primary) 
              : null,
            onTap: () {
              _applySorting(SortOption.titleAZ);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.sort_by_alpha, 
              color: _currentSortOption == SortOption.titleZA 
                ? colorScheme.primary 
                : null
            ),
            title: Text(
              'Title (Z-A)',
              style: TextStyle(
                color: isDarkMode ? Colors.white : colorScheme.onSurface,
                fontWeight: _currentSortOption == SortOption.titleZA 
                  ? FontWeight.bold 
                  : FontWeight.normal,
              ),
            ),
            trailing: _currentSortOption == SortOption.titleZA 
              ? Icon(Icons.check, color: colorScheme.primary) 
              : null,
            onTap: () {
              _applySorting(SortOption.titleZA);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.language, 
              color: _currentSortOption == SortOption.domainAZ 
                ? colorScheme.primary 
                : null
            ),
            title: Text(
              'Domain name',
              style: TextStyle(
                color: isDarkMode ? Colors.white : colorScheme.onSurface,
                fontWeight: _currentSortOption == SortOption.domainAZ 
                  ? FontWeight.bold 
                  : FontWeight.normal,
              ),
            ),
            trailing: _currentSortOption == SortOption.domainAZ 
              ? Icon(Icons.check, color: colorScheme.primary) 
              : null,
            onTap: () {
              _applySorting(SortOption.domainAZ);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  // Add method to apply sorting
  void _applySorting(SortOption sortOption) {
    setState(() {
      _currentSortOption = sortOption;
      _sortLinks();
    });
  }

  // Add method to sort links
  void _sortLinks() {
    switch (_currentSortOption) {
      case SortOption.none:
        // Just reload the links from database without sorting
        _loadLinks();
        break;
      case SortOption.dateNewest:
        _links.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.dateOldest:
        _links.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortOption.titleAZ:
        _links.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SortOption.titleZA:
        _links.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case SortOption.domainAZ:
        _links.sort((a, b) {
          final aDomain = _getDomainFromUrl(a.url).toLowerCase();
          final bDomain = _getDomainFromUrl(b.url).toLowerCase();
          return aDomain.compareTo(bDomain);
        });
        break;
    }
    
    // Also sort filtered links if search is active
    if (_isSearchMode) {
      _filterLinks();
    }
  }
}
