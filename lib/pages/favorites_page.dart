import 'package:flutter/material.dart';
import '../models/link.dart';
import '../services/database_helper.dart';
import 'link_detail_page.dart';
import 'package:animations/animations.dart';
import '../utils/url_utils.dart';
import 'dart:ui';
import '../services/view_mode_service.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<Link> _favoriteLinks = [];
  bool _isLoading = true;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _loadViewMode();
    _loadFavoriteLinks();
  }

  Future<void> _loadFavoriteLinks() async {
    setState(() => _isLoading = true);
    try {
      final links = await DatabaseHelper.instance.getFavoriteLinks();
      setState(() => _favoriteLinks = links);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadViewMode() async {
    final isGridView = await ViewModeService.instance.getIsGridView();
    setState(() => _isGridView = isGridView);
  }

  Widget _buildGridView(bool isDarkMode, ColorScheme colorScheme) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85, // Match home page ratio
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _favoriteLinks.length,
      itemBuilder: (context, index) {
        final link = _favoriteLinks[index];
        return OpenContainer(
          transitionDuration: const Duration(milliseconds: 250),
          openBuilder: (context, _) => LinkDetailPage(link: link),
          closedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          closedColor: Colors.transparent,
          closedElevation: 0,
          closedBuilder: (context, openContainer) => Container(
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
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: openContainer,
                borderRadius: BorderRadius.circular(20),
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
                              UrlUtils.getIconForUrl(link.url),
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
                          Icon(
                            Icons.favorite,
                            size: 16,
                            color: colorScheme.error,
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
            ),
          ),
        );
      },
    );
  }

  // Update list view card style
  Widget _buildListView(bool isDarkMode, ColorScheme colorScheme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _favoriteLinks.length,
      itemBuilder: (context, index) {
        final link = _favoriteLinks[index];
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
            ),
            child: OpenContainer(
              transitionDuration: const Duration(milliseconds: 250),
              openBuilder: (context, _) => LinkDetailPage(link: link),
              closedColor: Colors.transparent,
              closedElevation: 0,
              closedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              closedBuilder: (context, openContainer) => InkWell(
                onTap: openContainer,
                borderRadius: BorderRadius.circular(12),
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
                              UrlUtils.getIconForUrl(link.url),
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
                                const SizedBox(height: 4),
                                Text(
                                  Uri.parse(link.url).host.replaceAll('www.', ''),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDarkMode
                                        ? colorScheme.primary
                                        : colorScheme.primary.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.favorite,
                            size: 20,
                            color: colorScheme.error,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                            const SizedBox(height: 12),
                          ],
                          if (link.tags.isNotEmpty) ...[
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
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : colorScheme.surface,
      appBar: AppBar(
        title: const Text('Favorites'),
        backgroundColor: isDarkMode ? Colors.grey[900] : colorScheme.primaryContainer,
        foregroundColor: isDarkMode ? Colors.white : colorScheme.onPrimaryContainer,
        actions: [],
      ),
      body: Stack(
        children: [
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
          _isLoading
              ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
              : _favoriteLinks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_outline,
                            size: 64,
                            color: colorScheme.primary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No favorites yet',
                            style: TextStyle(
                              fontSize: 20,
                              color: colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _isGridView
                      ? _buildGridView(isDarkMode, colorScheme)
                      : _buildListView(isDarkMode, colorScheme),
        ],
      ),
    );
  }
}
