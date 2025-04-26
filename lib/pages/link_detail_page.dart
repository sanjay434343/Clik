// ignore_for_file: unused_element

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/link.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../utils/url_utils.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import '../services/url_launcher_service.dart';
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
import '../services/database_service.dart';
import '../services/database_helper.dart';
import 'package:nlp/nlp.dart' as nlp; // updated import with alias
import 'package:flutter/gestures.dart'; // new import for tap recognizers
import '../main.dart'; // Import to access routeObserver
import 'package:flutter_tts/flutter_tts.dart'; // new import for TTS
import 'dart:ui';  // Add this for ImageFilter
import 'package:audioplayers/audioplayers.dart';  // Re-add this import
import '../services/theme_service.dart'; // Add this import
import 'package:share_plus/share_plus.dart'; // new import for sharing

class LinkDetailPage extends StatefulWidget {
  final Link link;

  const LinkDetailPage({super.key, required this.link});

  @override
  State<LinkDetailPage> createState() => _LinkDetailPageState();
}

class _LinkDetailPageState extends State<LinkDetailPage> with SingleTickerProviderStateMixin, RouteAware {
  AppThemeMode _themeMode = AppThemeMode.system;
  bool _useDynamicColors = true;
  
  Metadata? _metadata;
  bool _isLoading = true;
  String? _errorMessage;
  String? _fullContent;
  String? _summary;
  List<String>? _categories; // new variable for dynamic categories

  // Add static memory cache
  static final Map<String, Metadata> _memoryCache = {};

  final FlutterTts _flutterTts = FlutterTts(); // new TTS instance
  int _currentWordIndex = -1; // index for highlighting
  List<String> _summaryWords = []; // split summary words
  Timer? _highlightTimer; // timer to update word highlight
  bool _isSpeaking = false;
  double _speechRate = 0.5; // Default speech rate
  double _readingProgress = 0.0; // Add this variable near other state variables

  // Re-add AudioPlayer
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Add these new state variables
  final ScrollController _scrollController = ScrollController();
  double _textScaleFactor = 1.0;
  double _baseScaleFactor = 1.0;
  static const double _minScale = 0.5;
  static const double _maxScale = 3.0;
  final int _currentParagraphIndex = -1;
  final List<String> _paragraphs = []; // Add this variable to store the initial scale

  // Add this getter method near the top with other variables
  bool get isDarkMode {
    return _themeMode == AppThemeMode.staticDark || 
           (_themeMode == AppThemeMode.system && 
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
  }

  // Add these new variables for text size control
  bool _showTextSizeSlider = false;
  final double _minTextSize = 12.0;
  final double _maxTextSize = 24.0;
  double _currentTextSize = 16.0;  // Changed default size
  final bool _isAutoSummarizing = false;

  // Add this new state variable
  bool _showControls = false;

  // Define missing variables
  final List<double> _presetSpeeds = [0.5, 1.0, 1.5, 2.0]; // Preset speech rates
  double _knobRotation = 0.0; // Initial knob rotation
  bool _isGenerating = false; // Flag for summary generation
  bool _isSummaryGenerated = false; // Flag for summary completion

  // Add these state variables near other state variables
  final bool _isPlaying = false;
  String? _audioPath;

  // Add a flag to track if AudioPlayer has been disposed
  bool _audioPlayerDisposed = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    // Load from cache first, then refresh if needed
    _loadCachedContent();
    _loadMetadata();
    _initTts();
    _summary = widget.link.cachedSummary;  // Move this here
    
    // Add a listener for theme changes
    ThemeService.addListener(_loadThemePreference);
  }

  // Add the missing _initTts method
  Future<void> _initTts() async {
    // Pre-configure TTS settings once during initialization
    await Future.wait([
      _flutterTts.setLanguage("en-US"),
      _flutterTts.setSpeechRate(_speechRate),
      _flutterTts.setVolume(1.0),
      _flutterTts.setPitch(1.1),
    ]);
    
    _flutterTts.setProgressHandler(
      (String text, int startOffset, int endOffset, String word) {
        if (mounted && _isSpeaking) {
          setState(() {
            // Calculate progress based on character position
            _readingProgress = startOffset / text.length;
          });
        }
      }
    );

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _readingProgress = 0.0;
        });
        _highlightTimer?.cancel();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    // Called when returning to this page (e.g. after back navigation)
    _loadCachedContent();
    // Optionally also refresh metadata if needed:
    _loadMetadata();
  }

  @override
  void didPushNext() {
    // Called when navigating away from this page
    _stopReading();
    super.didPushNext();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    
    // Safe disposal of audio player
    if (!_audioPlayerDisposed) {
      try {
        _audioPlayer.stop().then((_) {
          _audioPlayer.dispose();
          _audioPlayerDisposed = true;
        });
      } catch (e) {
        debugPrint('Error disposing AudioPlayer: $e');
      }
    }
    
    // Stop TTS and timer without setState
    _flutterTts.stop();
    _highlightTimer?.cancel();
    _isSpeaking = false;  // Directly update the variable
    
    // Remove the theme listener
    ThemeService.removeListener(_loadThemePreference);
    routeObserver.unsubscribe(this);
    if (_audioPath != null) {
      File(_audioPath!).delete().catchError((e) => debugPrint('Error deleting temp audio: $e'));
    }
    
    // Remove this line as we're disposing the audio player above with safety checks
    // _audioPlayer.dispose();
    
    super.dispose();
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
  
  Future<String> _getCachePath() async {
    final directory = await getApplicationCacheDirectory();
    final cachePath = path.join(directory.path, 'metadata_cache');
    
    // Create directory if it doesn't exist
    final dir = Directory(cachePath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    return cachePath;
  }
  
  Future<File> _getCacheFile() async {
    final cachePath = await _getCachePath();
    final cacheFile = File(path.join(cachePath, '${widget.link.id}.json'));
    return cacheFile;
  }
  
  Future<void> _saveMetadataToCache(Metadata metadata) async {
    try {
      final cacheFile = await _getCacheFile();
      
      // Convert metadata to JSON with expiration time (7 days)
      final Map<String, dynamic> metadataMap = {
        'title': metadata.title,
        'description': metadata.description,
        'image': metadata.image,
        'url': metadata.url,
        'fullContent': _fullContent, // Add full content to cache
        'summary': _summary, // Add summary to cache
        'categories': _categories?.join(','), // new: store dynamic categories
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'expiresAt': DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch,
      };
      
      await cacheFile.writeAsString(jsonEncode(metadataMap));
      // Persist the cached content and summary in the database
      await _saveContentToCache(_fullContent, _summary);
    } catch (e) {
      debugPrint('Failed to cache metadata: $e');
    }
  }
  
  Future<Metadata?> _getMetadataFromCache() async {
    try {
      final cacheFile = await _getCacheFile();
      
      if (!await cacheFile.exists()) {
        return null;
      }
      
      final jsonStr = await cacheFile.readAsString();
      final Map<String, dynamic> metadataMap = jsonDecode(jsonStr);
      
      // Check if cache has expired
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(metadataMap['expiresAt'] ?? 0);
      if (DateTime.now().isAfter(expiresAt)) {
        await cacheFile.delete();
        return null;
      }

      // Load full content and summary from cache
      _fullContent = metadataMap['fullContent'];
      _summary = metadataMap['summary'];
      // New: Load dynamic categories from cache
      final cats = metadataMap['categories'];
      if (cats != null && cats is String && cats.isNotEmpty) {
        _categories = cats.split(',');
      }

      // NEW: Update the link model with the cached summary and content
      widget.link.cachedSummary = _summary;
      widget.link.cachedContent = _fullContent;

      // Create Metadata object with proper constructor
      return Metadata()
        ..title = metadataMap['title']
        ..description = metadataMap['description']
        ..image = metadataMap['image']
        ..url = metadataMap['url'];
    } catch (e) {
      debugPrint('Failed to read cached metadata: $e');
      return null;
    }
  }
  
  String? _extractTitle(dom.Document document) {
    // Try article title first
    final articleTitle = document.querySelector('article h1');
    if (articleTitle != null) return articleTitle.text.trim();
    
    // Try main heading
    final mainHeading = document.querySelector('h1');
    if (mainHeading != null) return mainHeading.text.trim();
    
    // Try page title
    return document.querySelector('title')?.text.trim();
  }
  
  String? _extractImage(dom.Document document) {
    // Try meta image first (usually the best quality)
    final ogImage = document.querySelector('meta[property="og:image"]');
    if (ogImage != null && ogImage.attributes['content'] != null) {
      return ogImage.attributes['content'];
    }
    
    final twitterImage = document.querySelector('meta[name="twitter:image"]');
    if (twitterImage != null && twitterImage.attributes['content'] != null) {
      return twitterImage.attributes['content'];
    }
    
    // Try article image
    final articleImage = document.querySelector('article img');
    if (articleImage != null && articleImage.attributes['src'] != null) {
      return articleImage.attributes['src'];
    }
    
    // Try first large image (filter out small icons)
    final images = document.querySelectorAll('img');
    for (var img in images) {
      final src = img.attributes['src'];
      if (src != null && 
          !src.contains('icon') && 
          !src.contains('logo') && 
          !src.contains('avatar')) {
        // Check for width/height attributes to find larger images
        final width = img.attributes['width'];
        final height = img.attributes['height'];
        if (width != null && height != null) {
          try {
            final w = int.parse(width);
            final h = int.parse(height);
            if (w > 200 && h > 100) {
              return src;
            }
          } catch (_) {}
        }
        // If no size attributes, just use the first one
        return src;
      }
    }
    
    // Try any image as a last resort
    final anyImage = document.querySelector('img');
    return anyImage?.attributes['src'];
  }
  
  String? _extractArticleContent(dom.Document document) {
    // Remove unwanted elements first
    document.querySelectorAll('script, style, nav, header, footer, .ads, iframe').forEach((e) => e.remove());
    
    // Try different content areas in order of priority
    final List<String> contents = [];
    
    // Try article content
    final article = document.querySelector('article');
    if (article != null) contents.add(article.text);
    
    // Try main content
    final main = document.querySelector('main');
    if (main != null) contents.add(main.text);
    
    // Try content div
    final content = document.querySelector('#content, .content, .post-content, .entry-content');
    if (content != null) contents.add(content.text);
    
    // Try paragraphs if no structured content found
    if (contents.isEmpty) {
      final paragraphs = document.querySelectorAll('p');
      contents.addAll(paragraphs.map((p) => p.text));
    }
    
    return contents.isNotEmpty 
      ? contents.join('\n\n').replaceAll(RegExp(r'\s+'), ' ').trim()
      : null;
  }

  // Update _generateSummary to use a fallback summarization method instead of nlp.summarize:
  // Updated _generateSummary to use up to 20 sentences and prepend categories as a label:
  String _generateSummary(String content) {
    // Split content into sentences
    final sentences = content.split(RegExp(r'(?<=[.!?])\s+'));
    
    // Take first sentence as potential title/intro
    String summary = sentences.first;
    
    // Calculate target length (about 40 lines with ~60 chars per line)
    const targetLength = 2400; // 40 lines × 60 chars
    
    // Add key sentences until we reach target length
    for (var i = 1; i < sentences.length && summary.length < targetLength; i++) {
      if (sentences[i].length > 20) { // Skip very short sentences
        summary += ' ${sentences[i]}';
      }
    }
    
    return summary;
  }

  // New: Extract dynamic categories based on content keywords.
  List<String> _extractCategories(String content) {
    final lower = content.toLowerCase();
    final categories = <String>[];
    if (lower.contains("personal")) categories.add("Personal");
    if (lower.contains("work") || lower.contains("office")) categories.add("Work");
    if (lower.contains("finance") || lower.contains("money")) categories.add("Finance");
    if (lower.contains("social") || lower.contains("friend")) categories.add("Social");
    if (categories.isEmpty) categories.add("General");
    return categories;
  }

  Future<Metadata?> _fetchMetadataFromNetwork(String url) async {
    try {
      final sanitizedUrl = UrlUtils.sanitizeUrl(url);
      final client = http.Client();
      
      // Fetch page content
      final response = await http.get(Uri.parse(sanitizedUrl));
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        
        // Extract and store full content (no truncation now)
        _fullContent = _extractArticleContent(document);
        // Generate summary using local model (helper function)
        _summary = _generateSummary(_fullContent ?? '');
        // Generate summary and extract categories
        _categories = _extractCategories(_fullContent ?? '');
        
        // Try direct metadata extraction first
        Metadata? metadata;
        try {
          metadata = await MetadataFetch.extract(sanitizedUrl);
          debugPrint('MetadataFetch result: ${metadata?.title}, ${metadata?.image}');
        } catch (e) {
          debugPrint('Metadata fetch failed: $e');
        }
        
        // If metadata fetching failed or returned incomplete data, build it manually
        if (metadata == null || metadata.title == null || metadata.image == null) {
          final title = _extractTitle(document);
          String? imageUrl = _extractImage(document);
          
          // Fix relative image URLs
          if (imageUrl != null && !imageUrl.startsWith('http')) {
            final uri = Uri.parse(sanitizedUrl);
            if (imageUrl.startsWith('/')) {
              imageUrl = '${uri.scheme}://${uri.host}$imageUrl';
            } else {
              final basePath = sanitizedUrl.substring(0, sanitizedUrl.lastIndexOf('/') + 1);
              imageUrl = '$basePath$imageUrl';
            }
          }
          
          // Create metadata manually using full extracted content and local summary
          metadata = Metadata()
            ..title = title ?? widget.link.title
            ..description = _fullContent ?? ''
            ..image = imageUrl
            ..url = sanitizedUrl;
        }
        
        return metadata;
      }
      
      client.close();
      return null;
    } catch (e) {
      debugPrint('Network fetch error: $e');
      return null;
    }
  }

  Future<void> _loadMetadata() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    
    try {
      // Check memory cache first
      if (_memoryCache.containsKey(widget.link.url)) {
        setState(() {
          _metadata = _memoryCache[widget.link.url];
          _isLoading = false;
        });
        return;
      }

      // Try disk cache
      final cachedMetadata = await _getMetadataFromCache();
      if (cachedMetadata != null) {
        _memoryCache[widget.link.url] = cachedMetadata;
        if (mounted) {
          setState(() {
            _metadata = cachedMetadata;
            _isLoading = false;
          });
        }
        
        // Refresh cache in background
        _fetchMetadataFromNetwork(widget.link.url).then((freshMetadata) {
          if (freshMetadata != null) {
            _memoryCache[widget.link.url] = freshMetadata;
            _saveMetadataToCache(freshMetadata);
            if (mounted) {
              setState(() => _metadata = freshMetadata);
            }
          }
        });
        return;
      }
      
      // If no cache, fetch from network
      final metadata = await _fetchMetadataFromNetwork(widget.link.url);
      
      if (mounted) {
        setState(() {
          _metadata = metadata;
          _isLoading = false;
        });
      }
      
      // Cache the fetched metadata
      if (metadata != null && widget.link.id != null) {
        _memoryCache[widget.link.url] = metadata;
        await _saveMetadataToCache(metadata);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load preview: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchAndUpdateMetadata() async {
    try {
      // Force update from network regardless of cache
      final freshMetadata = await _fetchMetadataFromNetwork(widget.link.url);
      
      if (mounted) {
        setState(() {
          _metadata = freshMetadata;
          _isLoading = false;
          _errorMessage = null;
        });
      }
      
      if (freshMetadata != null && widget.link.id != null) {
        _memoryCache[widget.link.url] = freshMetadata;
        await _saveMetadataToCache(freshMetadata);
      }
    } catch (e) {
      debugPrint('Fetch metadata error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshMetadata() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    await _fetchAndUpdateMetadata();
  }

  Future<void> _launchURL(String urlString) async {
    final sanitizedUrl = UrlUtils.sanitizeUrl(urlString);
    final launched = await UrlLauncherService.launchURL(sanitizedUrl, context: context);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open link'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadCachedContent() async {
    if (widget.link.cachedContent != null) {
      setState(() {
        _fullContent = widget.link.cachedContent;
        _summary = widget.link.cachedSummary;
      });
    }
  }

  Future<void> _saveContentToCache(String? content, String? summary) async {
    if (widget.link.id != null) {
      await DatabaseHelper().updateLinkCache(
        widget.link.id!,
        content,
        summary,
      );
      // Update the local widget.link cache fields
      widget.link.cachedContent = content;
      widget.link.cachedSummary = summary;
      
      // Also store a timestamp to track when the cache was updated
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('cache_timestamp_${widget.link.id}', DateTime.now().millisecondsSinceEpoch);
    }
  }

  // Add this new method to clear cache for a specific URL
  static Future<void> clearCacheForUrl(String url) async {
    try {
      // Remove from memory cache
      _memoryCache.remove(url);
      
      // Clear from disk cache - we'll need to find the cache file for this URL
      final directory = await getApplicationCacheDirectory();
      final cachePath = path.join(directory.path, 'metadata_cache');
      
      final dir = Directory(cachePath);
      if (await dir.exists()) {
        // Find cache files that might contain this URL
        final files = await dir.list().toList();
        for (var file in files) {
          if (file is File) {
            try {
              final content = await file.readAsString();
              // If this file contains our URL, delete it
              if (content.contains(url)) {
                await file.delete();
              }
            } catch (e) {
              debugPrint('Error reading cache file: $e');
            }
          }
        }
      }
      
      // Also purge from database
      await DatabaseHelper().purgeCacheForUrl(url);
      
    } catch (e) {
      debugPrint('Failed to clear cache for URL: $e');
    }
  }

  // Helper method to truncate content with line count limit
  String _getTruncatedContent(String content, int maxLines) {
    if (content.isEmpty) return content;
    
    final lines = content.split('\n');
    if (lines.length <= maxLines) return content;
    
    return '${lines.take(maxLines).join('\n')}\n...';
  }
  
  // Check if content has more than specified lines
  bool _hasMoreLines(String content, int lineCount) {
    if (content.isEmpty) return false;
    return content.split('\n').length > lineCount;
  }

  // NEW: Helper method to build a RichText summary that highlights URLs as hyperlinks.
  Widget _buildSummaryRichText(String summary) {
    final urlRegex = RegExp(r"(https?:\/\/[^\s]+)");
    final List<TextSpan> spans = [];
    int start = 0;
    for (final match in urlRegex.allMatches(summary)) {
      if (match.start > start) {
        spans.add(TextSpan(text: summary.substring(start, match.start)));
      }
      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              UrlLauncherService.launchURL(url, context: context);
            },
        ),
      );
      start = match.end;
    }
    if (start < summary.length) {
      spans.add(TextSpan(text: summary.substring(start)));
    }
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: _themeMode == ThemeMode.dark
              ? Colors.white
              : Theme.of(context).colorScheme.onSurface,
          fontSize: 14,
          height: 1.5,
        ),
        children: spans,
      ),
    );
  }

  // NEW: Start reading TTS and word highlighting
  void _startReading() async {
    if (_summary == null || _summary!.trim().isEmpty) {
      _showTtsError('No content available to read');
      return;
    }
    
    try {
      setState(() {
        _readingProgress = 0.0;
        _isSpeaking = true;
      });

      // Pre-split words for faster processing
      _summaryWords = _summary!.trim().split(RegExp(r'\s+'));
      if (_summaryWords.isEmpty) {
        _showTtsError('No words to read');
        return;
      }

      // Optimize text preprocessing
      final cleanText = _summary!
        .replaceAll(RegExp(r'[^\w\s.,!?-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

      // Start speaking immediately without waiting for additional processing
      final result = await _flutterTts.speak(cleanText);
      
      if (result == null || result == 0) {
        _showTtsError('Failed to start speech');
        return;
      }

      // Setup word highlighting after speech starts
      _highlightTimer?.cancel();
      _highlightTimer = Timer.periodic(
        Duration(milliseconds: 500), 
        (_) {
          if (_currentWordIndex < _summaryWords.length - 1 && _isSpeaking) {
            setState(() => _currentWordIndex++);
          }
        }
      );

    } catch (e) {
      debugPrint('TTS Error: $e');
      _showTtsError('Error starting speech');
      _stopReading();
    }
  }
  
  // NEW: Stop reading and clear highlighting with pause for Android TTS workaround
  void _stopReading() async {
    if (!mounted) return;  // Add mounted check
    
    setState(() {
      _isSpeaking = false;
    });
    
    await _flutterTts.stop();
    _highlightTimer?.cancel();
  }

  // Add helper methods for social icon and domain retrieval.
  IconData _getSocialIcon(String url) {
    return UrlUtils.getIconForUrl(url);
  }
  
  String _getDomainFromUrl(String url) {
    return UrlUtils.getDomainFromUrl(url);
  }

  Widget _buildLinkPreview() {
    // If metadata exists from cache, skip loading indicator.
    if (_isLoading && _summary == null) {
      return const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      debugPrint('Preview error: $_errorMessage'); // Add debug logging
      return GestureDetector(
        onTap: _refreshMetadata,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap to retry',
                  style: TextStyle(color: Colors.blue, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Log metadata for debugging
    debugPrint('Metadata: image=${_metadata?.image}, title=${_metadata?.title}');

    // Completely rebuilt preview UI with better fallbacks
    final String title = (_metadata?.title?.isNotEmpty == true) 
        ? _metadata!.title!
        : widget.link.title;
    
    final String description = (_metadata?.description?.isNotEmpty == true)
        ? _metadata!.description!
        : _fullContent != null && _fullContent!.isNotEmpty
            ? _fullContent!.substring(0, _fullContent!.length.clamp(0, 150))
            : '';
    
    final String? imageUrl = _metadata?.image;
    final bool isDarkMode = _themeMode == ThemeMode.dark || 
        (_themeMode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    
    // Build the preview container even if some content is missing
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.grey[850]
            : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? Colors.grey[700]!
              : Theme.of(context).colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
            CachedNetworkImage(
              imageUrl: imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 200,
                color: Colors.grey.withOpacity(0.3),
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) {
                debugPrint('Error loading image: $error for URL: $url');
                return Container(
                  height: 100,
                  color: Colors.grey.withOpacity(0.3),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image, size: 30),
                        const SizedBox(height: 4),
                        Text('Image load failed', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode
                          ? Colors.grey[300]
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      _getSocialIcon(widget.link.url),
                      size: 16,
                      color: isDarkMode
                          ? Colors.lightBlue[300]
                          : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getDomainFromUrl(widget.link.url),
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode
                              ? Colors.lightBlue[300]
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                // Removed summary display and TTS controls from meta card.
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Update the _buildTtsSummaryRichText method to remove highlighting
  Widget _buildTtsSummaryRichText(String content) {
    return Column(
      children: [
        if (_isSpeaking)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LinearProgressIndicator(
              value: _readingProgress,
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary.withOpacity(0.7),
              ),
            ),
          ),
        Container(
          height: 400, // Fixed height
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            child: Text(
              content,
              style: TextStyle(
                fontSize: _currentTextSize,
                height: 1.5,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Add a method to reset text scale
  void _resetTextScale() {
    setState(() {
      _textScaleFactor = 1.0;
      _baseScaleFactor = 1.0;
    });
    HapticFeedback.mediumImpact();
  }

  // Add a method to clean text for TTS
  String _cleanTextForTts(String text) {
    // Remove special characters but keep basic punctuation
    return text.replaceAll(RegExp(r'[^\w\s.,!?-]'), ' ')
               .replaceAll(RegExp(r'\s+'), ' ')
               .trim();
  }

  void _playKnobSound(double rotationSpeed) {
    try {
      // Use vibration only instead of sound to avoid media player errors
      // Different vibration patterns based on rotation speed
      if (rotationSpeed > 0.7) {
        HapticFeedback.heavyImpact();
      } else if (rotationSpeed > 0.3) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.selectionClick();
      }
      
      // Don't try to play audio - this is causing crashes
      // _audioPlayer.stop();
      // _audioPlayer.setPlaybackRate(playbackRate);
      // _audioPlayer.play(AssetSource('efx/knob.mp3'));
      
    } catch (e) {
      debugPrint('Failed to provide feedback: $e');
      // Fallback to basic haptic feedback if anything goes wrong
      HapticFeedback.selectionClick();
    }
  }

  void _showSpeedDialog() {
    double startAngle = 0.0;
    double startRate = _speechRate;
    double lastRate = _speechRate;
    double lastAngle = 0.0;
    double rotationSpeed = 0.0;
    DateTime lastUpdateTime = DateTime.now();
    
    // Set initial knob rotation based on current speech rate
    // This ensures the knob position matches the speech rate when dialog opens
    double initialKnobRotation = _speechRate * pi;
    
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Dialog(
            backgroundColor: isDarkMode 
                ? Colors.grey[900]?.withOpacity(0.7)
                : Colors.white.withOpacity(0.7),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Adjust Speech Rate',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Add preset speed buttons
                  Wrap(
                    spacing: 8,
                    children: _presetSpeeds.map((speed) => 
                      AnimatedScale(
                        scale: _speechRate == speed ? 1.1 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setDialogState(() {
                              _speechRate = speed;
                              initialKnobRotation = speed * pi; // Update initial knob rotation
                              if (_isSpeaking) {
                                _flutterTts.stop();
                                _flutterTts.setSpeechRate(_speechRate);
                                _startReading();
                              } else {
                                _flutterTts.setSpeechRate(_speechRate);
                              }
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _speechRate == speed 
                                ? Theme.of(context).colorScheme.primary 
                                : Theme.of(context).colorScheme.surfaceVariant,
                            foregroundColor: _speechRate == speed 
                                ? Theme.of(context).colorScheme.onPrimary 
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            elevation: _speechRate == speed ? 4 : 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text('${speed}x'),
                        ),
                      )
                    ).toList(),
                  ),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      );
                    },
                    child: Text(
                      '${_speechRate.toStringAsFixed(2)}x',
                      key: ValueKey<double>(_speechRate),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Improved knob with persistent rotation
                  GestureDetector(
                    onPanStart: (details) {
                      final currentAngle = _getAngleFromPosition(details.localPosition);
                      startAngle = currentAngle;
                      startRate = _speechRate;
                      lastRate = _speechRate;
                      lastAngle = currentAngle;
                      lastUpdateTime = DateTime.now();
                    },
                    onPanUpdate: (details) {
                      final currentAngle = _getAngleFromPosition(details.localPosition);
                      final angleDelta = currentAngle - startAngle;
                      
                      // Calculate rotation speed
                      final now = DateTime.now();
                      final elapsedSeconds = now.difference(lastUpdateTime).inMilliseconds / 1000;
                      if (elapsedSeconds > 0) {
                        rotationSpeed = (currentAngle - lastAngle).abs() / elapsedSeconds;
                        rotationSpeed = rotationSpeed.clamp(0.0, 5.0) / 5.0; // Normalize to 0.0-1.0
                      }
                      
                      // Calculate new rate with higher sensitivity (0.7 multiplier)
                      final rawRate = startRate + (angleDelta / pi) * 0.7;
                      final newRate = rawRate.clamp(0.1, 2.0);
                      
                      // Only update if there's a meaningful change
                      if ((newRate - lastRate).abs() >= 0.01) {
                        _playKnobFeedback(rotationSpeed);
                        
                        setDialogState(() {
                          initialKnobRotation = currentAngle;
                          _speechRate = double.parse(newRate.toStringAsFixed(2));
                          
                          if (_isSpeaking) {
                            _flutterTts.stop();
                            _flutterTts.setSpeechRate(_speechRate);
                            _startReading();
                          } else {
                            _flutterTts.setSpeechRate(_speechRate);
                          }
                        });
                        
                        // Update tracking variables
                        lastRate = newRate;
                        lastAngle = currentAngle;
                        lastUpdateTime = now;
                      }
                    },
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: isDarkMode
                              ? [Colors.grey[800]!, Colors.grey[900]!]
                              : [Colors.grey[200]!, Colors.grey[300]!],
                          stops: const [0.7, 1.0],
                        ),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Circular markers around the knob
                          ...List.generate(12, (index) {
                            final angle = index * (pi / 6);
                            return Positioned(
                              left: 100 + 80 * cos(angle) - 2,
                              top: 100 + 80 * sin(angle) - 2,
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                ),
                              ),
                            );
                          }),
                          // Knob hand that rotates - using initialKnobRotation instead
                          Transform.rotate(
                            angle: initialKnobRotation,
                            child: Center(
                              child: Container(
                                width: 160,
                                height: 160,
                                alignment: Alignment.topCenter,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 100),
                                  width: 4,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                                        blurRadius: 4,
                                        spreadRadius: 0.5,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Center dot
                          Center(
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.primary,
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                                    blurRadius: 4,
                                    spreadRadius: 0.5,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      // Store the final knob rotation value
                      _knobRotation = initialKnobRotation;
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Done',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 16,
                      ),
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

  // Renamed this method to clarify its purpose and separate it from the audio-related code
  void _playKnobFeedback(double rotationSpeed) {
    try {
      // Use only haptic feedback, more reliable than audio
      if (rotationSpeed > 0.7) {
        HapticFeedback.heavyImpact();
      } else if (rotationSpeed > 0.3) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    } catch (e) {
      debugPrint('Failed to provide feedback: $e');
      // Fallback to basic haptic feedback if anything goes wrong
      HapticFeedback.selectionClick();
    }
  }

  double _getAngleFromPosition(Offset position) {
    // Calculate the center of the knob (assumes a 200x200 container with center at 100,100)
    final center = const Offset(100, 100);
    
    // Calculate the angle between the center and the touch position
    final angle = atan2(
      position.dy - center.dy,
      position.dx - center.dx,
    );
    
    return angle;
  }

  // Add this method to handle summary generation
  Future<void> _handleGenerateSummary() async { // formerly _generateSummary
    if (_isGenerating) return;
    setState(() {
      _isGenerating = true;
    });
    // Simulate 5sec delay before generating summary
    await Future.delayed(const Duration(seconds: 5));
    
    try {
      if (_fullContent != null && _fullContent!.isNotEmpty) {
        final summary = _generateSummaryText(_fullContent!);
        // Commented out to avoid database error
        // await DatabaseHelper.instance.updateLinkCache(widget.link.id!, _fullContent, summary);
        setState(() {
          _summary = summary;
          _isSummaryGenerated = true;
          _summaryWords = summary.split(RegExp(r'\s+'));
        });
      }
    } catch (e) {
      debugPrint('Error generating summary: $e');
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  // Helper method for summary generation
  String _generateSummaryText(String content) {
    final sentences = content.split(RegExp(r'(?<=[.!?])\s+'));
    final count = sentences.length >= 20 ? 20 : sentences.length;
    return sentences.take(count).join(" ");
  }

  // Add new helper method for AI-style loading indicator:
  Widget _buildAiLoadingIndicator() {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Blurred RGB background
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.red, Colors.green, Colors.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          // Star icon with animated effect (for simplicity, static text here)
          Text(
            "★",
            style: TextStyle(
              fontSize: 40,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  // Add below the existing _buildAiLoadingIndicator (or at a similar location)
  Widget _buildSparkLoader() {
    return Container(
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Blurred RGB glow background
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.pink, Colors.blue, Colors.green],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          // Spark animation (using a star emoji with glowing shadow)
          Text(
            "✨",
            style: TextStyle(
              fontSize: 50,
              color: Colors.white,
              shadows: [
                Shadow(blurRadius: 12, color: Colors.white, offset: Offset(0, 0)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Update the _buildTextSizeControl method
  Widget _buildTextSizeControl() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _showTextSizeSlider ? 60 : 0, // Fixed height
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Keep vertical margin
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDarkMode 
              ? Colors.grey[850]
              : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withAlpha(51),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.text_fields, 
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            Expanded(
              child: Slider(
                value: _currentTextSize,
                min: _minTextSize,
                max: _maxTextSize,
                divisions: 12,
                label: '${_currentTextSize.round()}',
                onChanged: (value) {
                  // Add haptic feedback when slider value changes
                  if ((value - _currentTextSize).abs() >= 1.0) {
                    HapticFeedback.selectionClick();
                  }
                  setState(() {
                    _currentTextSize = value;
                    _textScaleFactor = value / 14.0;
                  });
                },
              ),
            ),
            Icon(Icons.text_fields,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            // Add text size indicator
            SizedBox(width: 8),
            Text(
              '${_currentTextSize.round()}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Update the controls section in the build method
  Widget _buildControls(ColorScheme colorScheme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _showControls ? null : 0, // Dynamic height
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: isDarkMode 
            ? Colors.grey[850]
            : colorScheme.surfaceVariant.withOpacity(0.7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outline.withAlpha(51),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                    icon: _isSpeaking ? Icons.stop : Icons.play_arrow,
                    label: _isSpeaking ? 'Stop' : 'Play',
                    onPressed: _isSpeaking ? _stopReading : _startReading,
                    colorScheme: colorScheme,
                    isActive: _isSpeaking,
                  ),
                  _buildControlButton(
                    icon: Icons.speed,
                    label: '${_speechRate}x',
                    onPressed: _showSpeedDialog,
                    colorScheme: colorScheme,
                  ),
                  _buildControlButton(
                    icon: Icons.text_fields,
                    label: 'Size',
                    onPressed: () {
                      setState(() {
                        _showTextSizeSlider = !_showTextSizeSlider;
                      });
                      HapticFeedback.selectionClick();
                    },
                    colorScheme: colorScheme,
                    isActive: _showTextSizeSlider,
                  ),
                ],
              ),
              if (_showTextSizeSlider) ...[
                const SizedBox(height: 16),
                _buildTextSizeControl(),
                const SizedBox(height: 8), // Add bottom spacing here
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentTabs(String rawContent, String summarizedContent) {
    final summarizedLines = summarizedContent.split('\n').length; // Count lines in summarized content

    return DefaultTabController(
      length: 2,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 400), // Limit card height to 400px
        decoration: BoxDecoration(
          color: isDarkMode 
              ? Colors.grey[850]
              : Theme.of(context).colorScheme.surfaceVariant.withAlpha(179),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withAlpha(51),
          ),
        ),
        child: Column(
          children: [
            // Tab bar with settings button
            Row(
              children: [
                Expanded(
                  child: TabBar(
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: isDarkMode 
                        ? Colors.grey[400]
                        : Colors.grey[600],
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    tabs: const [
                      Tab(text: "Raw Content"),
                      Tab(text: "Summarized"),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.settings,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () {
                    // Handle settings button press
                    setState(() {
                      _showControls = !_showControls;
                    });
                  },
                ),
              ],
            ),
            // Tab views
            Expanded(
              child: TabBarView(
                children: [
                  // Raw content tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      rawContent,
                      style: TextStyle(
                        fontSize: _currentTextSize,
                        height: 1.5,
                        color: isDarkMode 
                            ? Colors.grey[300]
                            : Colors.grey[800],
                      ),
                    ),
                  ),
                  // Summarized content tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summarizedContent,
                          style: TextStyle(
                            fontSize: _currentTextSize,
                            height: 1.5,
                            color: isDarkMode 
                                ? Colors.grey[300]
                                : Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Lines: $summarizedLines",
                          style: TextStyle(
                            fontSize: 12,
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : colorScheme.background,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.grey[850] : colorScheme.surfaceVariant,
        foregroundColor: isDarkMode ? Colors.white : colorScheme.onSurfaceVariant,
        elevation: 0,
        title: AnimatedOpacity(
          opacity: 0.9,
          duration: const Duration(milliseconds: 200),
          child: Text(
            widget.link.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshMetadata,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.link.url));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Text('URL copied to clipboard'),
                    ],
                  ),
                  backgroundColor: colorScheme.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: EdgeInsets.all(8),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Copy URL',
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _launchURL(widget.link.url),
            tooltip: 'Open in browser',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => Share.share('${widget.link.title}\n${widget.link.url}'),
          ),
        ],
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode 
                ? [Colors.grey[900]!, Colors.grey[850]!] 
                : [colorScheme.background, colorScheme.surface.withAlpha(128)],
          ),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Title
              Hero(
                tag: 'link_title_${widget.link.id}',
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDarkMode 
                            ? [Colors.purple.withOpacity(0.1), Colors.blue.withOpacity(0.1)]
                            : [colorScheme.primaryContainer.withAlpha(179), colorScheme.primary.withAlpha(51)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      widget.link.title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : colorScheme.primary,
                        height: 1.3,
                        shadows: [
                          if (isDarkMode) Shadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: Offset(1, 1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16), // Increased spacing
              
              // URL with ripple effect
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _launchURL(widget.link.url),
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    Clipboard.setData(ClipboardData(text: widget.link.url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('URL copied to clipboard'),
                        backgroundColor: colorScheme.primary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(
                          _getSocialIcon(widget.link.url),
                          size: 16,
                          color: isDarkMode ? Colors.lightBlue[300] : colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getDomainFromUrl(widget.link.url),
                            style: TextStyle(
                              color: isDarkMode ? Colors.lightBlue[300] : colorScheme.primary,
                              decoration: TextDecoration.underline,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Notes section - Moved here, right after the URL
              if (widget.link.description.isNotEmpty) ...[
                const SizedBox(height: 20), // Increased spacing
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode 
                        ? Colors.grey[850]
                        : colorScheme.surfaceVariant.withAlpha(179),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outline.withAlpha(51),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.note_outlined,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Notes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode
                                  ? Colors.white
                                  : colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.link.description,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: isDarkMode
                              ? Colors.grey[300]
                              : Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Add metadata preview right after notes
              _buildLinkPreview(),

              // TTS Controls and content section
              if (_summary != null && _summary!.isNotEmpty) ...[
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDarkMode 
                        ? Colors.grey[850]
                        : colorScheme.surfaceVariant.withAlpha(179),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outline.withAlpha(51),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with title, play and settings buttons
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Content Summary',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? Colors.white
                                    : colorScheme.onSurface,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _isSpeaking ? Icons.stop : Icons.play_arrow,
                                    size: 20,
                                    color: _isSpeaking 
                                        ? colorScheme.primary 
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                  onPressed: _isSpeaking ? _stopReading : _startReading,
                                ),
                                IconButton(
                                  icon: Icon(
                                    _showControls ? Icons.settings : Icons.settings_outlined,
                                    size: 20,
                                    color: _showControls 
                                        ? colorScheme.primary 
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                  onPressed: () {
                                    setState(() => _showControls = !_showControls);
                                    HapticFeedback.lightImpact();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Controls section appears directly under header when shown
                      if (_showControls) _buildControls(colorScheme),
                      
                      // Content section with no padding gap
                      _buildTtsSummaryRichText(_summary!),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Add this helper method to the class
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed, // Allow nullable callback
    required ColorScheme colorScheme,
    bool isActive = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isActive 
                ? colorScheme.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(icon),
            onPressed: onPressed ?? () {}, // Provide a default no-op callback
            color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
  
  void _showTtsError(String message) {
    _stopReading();
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String? _insertNaturalPauses(String text) {
    try {
      // Add pauses after punctuation
      text = text.replaceAll('. ', '.<break time="500ms"/>');
      text = text.replaceAll('? ', '?<break time="500ms"/>');
      text = text.replaceAll('! ', '!<break time="500ms"/>');
      text = text.replaceAll(', ', ',<break time="300ms"/>');
      
      // Add emphasis on important words
      final importantWords = ['important', 'significant', 'key', 'main'];
      for (final word in importantWords) {
        text = text.replaceAll(
          RegExp('\\b$word\\b', caseSensitive: false),
          ' $word '
        );
      }
      
      return text;
    } catch (e) {
      debugPrint('Error adding pauses: $e');
      return null;
    }
  }
}

extension on FlutterTts {
  setRate(double d) {}
}

extension on Clip {
  static String insertNaturalPauses(String text) {
    // Add commas for natural pauses
    text = text.replaceAll('. ', '.<break time="500ms"/>');
    text = text.replaceAll('? ', '?<break time="500ms"/>');
    text = text.replaceAll('! ', '!<break time="500ms"/>');
    
    // Add emphasis on important words
    final importantWords = ['important', 'significant', 'crucial', 'main'];
    for (final word in importantWords) {
      text = text.replaceAll(
        RegExp('\\b$word\\b', caseSensitive: false),
        '<emphasis>$word</emphasis>'
      );
    }
    
    return text;
  }
}