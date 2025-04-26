import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/link.dart';
import '../services/database_helper.dart';
import '../data/tags.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddLinkPage extends StatefulWidget {
  const AddLinkPage({super.key, required String sharedUrl});

  @override
  State<AddLinkPage> createState() => _AddLinkPageState();
}

class _AddLinkPageState extends State<AddLinkPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  final Set<String> _selectedTags = {};
  
  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _pasteAnimationController;
  bool _hasClipboardContent = false;

  // UI state variables
  ThemeMode _themeMode = ThemeMode.system;
  bool _isLoading = false;
  static const String _themeModeKey = 'themeMode';

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    
    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    // Start animation after first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });

    // Initialize paste animation controller
    _pasteAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // Check clipboard on start
    _checkClipboard();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pasteAnimationController.dispose();
    _urlController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = ThemeMode.values[prefs.getInt(_themeModeKey) ?? 0];
    });
  }

  Future<void> _checkClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    setState(() {
      _hasClipboardContent = clipboardData?.text?.isNotEmpty ?? false;
    });
  }

  // Optimized tag section for minimal space
  Widget _buildTagSection(String title, List<String> tags, int sectionIndex) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final delay = 0.1 + (sectionIndex * 0.1);
        final Animation<double> delayedAnimation = CurvedAnimation(
          parent: _animationController,
          curve: Interval(delay, 1.0, curve: Curves.easeOut),
        );
        
        return FadeTransition(
          opacity: delayedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.2),
              end: Offset.zero,
            ).animate(delayedAnimation),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with icon
                  Row(
                    children: [
                      Icon(
                        _getIconForSection(title),
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Tag chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tags.map((tag) {
                      final isSelected = _selectedTags.contains(tag);
                      return _buildCompactChip(tag, isSelected);
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  // Get icon for each tag section
  IconData _getIconForSection(String title) {
    switch (title) {
      case 'Common':
        return Icons.star_outline;
      case 'Content Type':
        return Icons.category_outlined;
      case 'Categories':
        return Icons.folder_outlined;
      case 'Platforms':
        return Icons.devices_outlined;
      default:
        return Icons.tag;
    }
  }
  
  // More compact chip design
  Widget _buildCompactChip(String tag, bool isSelected) {
    return AnimatedScale(
      scale: isSelected ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: FilterChip(
          label: Text(
            tag,
            style: TextStyle(
              fontSize: 12, // Smaller font
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          selected: isSelected,
          onSelected: (selected) {
            HapticFeedback.selectionClick();
            setState(() {
              if (selected) {
                _selectedTags.add(tag);
              } else {
                _selectedTags.remove(tag);
              }
              _tagsController.text = _selectedTags.join(', ');
            });
          },
          backgroundColor: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Theme.of(context).colorScheme.surfaceVariant,
          selectedColor: Theme.of(context).colorScheme.primaryContainer,
          checkmarkColor: Theme.of(context).colorScheme.primary,
          visualDensity: VisualDensity.compact, // More compact size
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Smaller tap target
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced padding
          elevation: isSelected ? 1 : 0, // Reduced elevation
          shadowColor: isSelected 
              ? Theme.of(context).colorScheme.primary.withOpacity(0.2) 
              : Colors.transparent,
        ),
      ),
    );
  }

  // Animated form field
  Widget _buildAnimatedFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required int index,
    bool multiline = false,
    String? Function(String?)? validator,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = _themeMode == ThemeMode.dark || 
        (_themeMode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final delay = 0.1 * index;
        final Animation<double> delayedAnimation = CurvedAnimation(
          parent: _animationController,
          curve: Interval(delay, 1.0, curve: Curves.easeOut),
        );
        
        return FadeTransition(
          opacity: delayedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(delayedAnimation),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextFormField(
                controller: controller,
                maxLines: multiline ? 3 : 1,
                decoration: InputDecoration(
                  labelText: label,
                  prefixIcon: Icon(icon, 
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  floatingLabelStyle: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colorScheme.outline.withOpacity(0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colorScheme.error,
                      width: 1,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colorScheme.error,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: isDarkMode
                      ? Colors.grey[800]!.withOpacity(0.6)
                      : colorScheme.surface.withOpacity(0.8),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  errorStyle: TextStyle(
                    color: colorScheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: TextStyle(
                  fontSize: 15,
                  color: isDarkMode ? Colors.white : colorScheme.onSurface,
                ),
                validator: validator,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPasteButton() {
    return GestureDetector(
      onTapDown: (_) => _pasteAnimationController.forward(),
      onTapUp: (_) => _pasteAnimationController.reverse(),
      onTapCancel: () => _pasteAnimationController.reverse(),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.95).animate(
          CurvedAnimation(
            parent: _pasteAnimationController,
            curve: Curves.easeInOut,
          ),
        ),
        child: IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              _hasClipboardContent ? Icons.content_paste : Icons.content_paste_off,
              key: ValueKey(_hasClipboardContent),
              color: _hasClipboardContent 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
          onPressed: _hasClipboardContent
              ? () async {
                  final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
                  if (clipboardData?.text != null) {
                    _urlController.text = clipboardData!.text!;
                    // Add haptic feedback
                    HapticFeedback.lightImpact();
                  }
                  _checkClipboard();
                }
              : null,
          tooltip: _hasClipboardContent ? 'Paste URL' : 'No content to paste',
        ),
      ),
    );
  }

  Widget _buildUrlField() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = _themeMode == ThemeMode.dark || 
        (_themeMode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final Animation<double> delayedAnimation = CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
        );
        
        return FadeTransition(
          opacity: delayedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(delayedAnimation),
            child: TextFormField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'URL',
                hintText: 'Enter or paste a URL',
                prefixIcon: Icon(
                  Icons.link_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
                suffixIcon: _buildPasteButton(),
                floatingLabelStyle: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colorScheme.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: colorScheme.outline.withOpacity(0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: colorScheme.error,
                    width: 1,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: colorScheme.error,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: isDarkMode
                    ? Colors.grey[800]!.withOpacity(0.6)
                    : colorScheme.surface.withOpacity(0.8),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                errorStyle: TextStyle(
                  color: colorScheme.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextStyle(
                fontSize: 15,
                color: isDarkMode ? Colors.white : colorScheme.onSurface,
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter URL' : null,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;
    
    final isDarkMode = _themeMode == ThemeMode.dark || 
        (_themeMode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : colorScheme.surface,
      extendBodyBehindAppBar: true, // Makes content flow under app bar
      appBar: AppBar(
        title: Text(
          'Add Link',
          style: TextStyle(
            fontFamily: 'AppFont',
            color: isDarkMode ? Colors.white : colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
        scrolledUnderElevation: 0, // No elevation when scrolled under
        backgroundColor: isDarkMode 
            ? Colors.grey[900]!.withOpacity(0.9) 
            : colorScheme.surface.withOpacity(0.9),
        foregroundColor: isDarkMode 
            ? Colors.white 
            : colorScheme.onSurface,
        systemOverlayStyle: isDarkMode 
            ? SystemUiOverlayStyle.light 
            : SystemUiOverlayStyle.dark,
        elevation: 0,
        centerTitle: false,
        // Add save button to app bar
        actions: [
          _isLoading
              ? Container(
                  margin: const EdgeInsets.all(10.0),
                  padding: const EdgeInsets.all(6.0),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
                  ),
                )
              : Container(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: IconButton.filled(
                    onPressed: _saveLink,
                    icon: const Icon(Icons.check_rounded),
                    tooltip: 'Save Link',
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      minimumSize: const Size(42, 42),
                    ),
                  ),
                ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            decoration: BoxDecoration(
              gradient: isDarkMode
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.grey[900]!,
                        Colors.grey[850]!,
                        Colors.grey[850]!.withBlue(Colors.grey[850]!.blue + 5),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.surface,
                        colorScheme.surface,
                        colorScheme.surfaceVariant.withOpacity(0.5),
                      ],
                    ),
            ),
            child: SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    // Page description
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Add a new link to your collection',
                        style: TextStyle(
                          fontSize: 15,
                          color: isDarkMode 
                              ? Colors.grey[400] 
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    
                    // URL Input with Paste Button with adjusted position
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildUrlField(),
                    ),

                    // Title Input
                    _buildAnimatedFormField(
                      controller: _titleController,
                      label: 'Title',
                      icon: Icons.title_rounded,
                      index: 1,
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Please enter title' : null,
                    ),

                    // Description Input
                    _buildAnimatedFormField(
                      controller: _descriptionController,
                      label: 'Description (optional)',
                      icon: Icons.description_rounded,
                      index: 2,
                      multiline: true,
                    ),

                    // Tags Section Divider
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: colorScheme.outline.withOpacity(0.3),
                              thickness: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Tags',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: colorScheme.outline.withOpacity(0.3),
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tags Section Header with count
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        final Animation<double> headerAnimation = CurvedAnimation(
                          parent: _animationController,
                          curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
                        );
                        
                        return FadeTransition(
                          opacity: headerAnimation,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.tag_rounded,
                                  color: colorScheme.primary,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Tag your link for easy finding',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode 
                                        ? Colors.grey[400] 
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const Spacer(),
                                // Show selected tag count in a modern badge
                                if (_selectedTags.isNotEmpty)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      '${_selectedTags.length}',
                                      style: TextStyle(
                                        color: colorScheme.onPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // Tags in Cards with better spacing
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Card(
                        elevation: 0,
                        color: isDarkMode 
                            ? Colors.grey[850] 
                            : colorScheme.surfaceVariant.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: colorScheme.outline.withOpacity(0.1),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              _buildTagSection('Common', TagCategories.common, 0),
                              _buildTagSection('Content Type', TagCategories.types, 1),
                              _buildTagSection('Categories', TagCategories.categories, 2),
                              _buildTagSection('Platforms', TagCategories.platforms, 3),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Extra space at the bottom for scrolling
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveLink() async {
    if (_formKey.currentState?.validate() ?? false) {
      // Show loading state
      setState(() => _isLoading = true);
      
      try {
        // Haptic feedback for save action
        HapticFeedback.mediumImpact();
        
        await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay
        
        final link = Link(
          url: _urlController.text,
          title: _titleController.text,
          description: _descriptionController.text,
          tags: _tagsController.text,
        );

        final dbHelper = DatabaseHelper.instance;
        await dbHelper.create(link);
        
        if (mounted) {
          // Show success animation before popping
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Link saved successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          
          // Wait for snackbar to show before popping
          await Future.delayed(const Duration(milliseconds: 300));
          Navigator.pop(context, true); // Return true on success
        }
      } catch (e) {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }
}
