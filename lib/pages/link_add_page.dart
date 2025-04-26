import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this for Clipboard
import '../models/link.dart';
import '../services/database_helper.dart';
import 'package:metadata_fetch/metadata_fetch.dart'; // Add this for metadata fetching

class LinkAddPage extends StatefulWidget {
  final String sharedUrl;
  const LinkAddPage({super.key, required this.sharedUrl});

  @override
  State<LinkAddPage> createState() => _LinkAddPageState();
}

class _LinkAddPageState extends State<LinkAddPage> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = false;
  final List<String> _predefinedTags = [
    'Work',
    'Personal',
    'Read Later',
    'Important',
    'Project',
    'Research',
    'Tutorial',
    'Reference',
  ];
  final Set<String> _selectedTags = {};

  @override
  void initState() {
    super.initState();
    // Initialize URL field with shared URL if provided
    if (widget.sharedUrl.isNotEmpty) {
      _urlController.text = widget.sharedUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Link'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Save'),
            onPressed: _saveLink,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // URL Input with Paste Button
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[850] : colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    child: TextFormField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        hintText: 'Enter URL',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        prefixIcon: Icon(
                          Icons.link,
                          color: colorScheme.primary,
                        ),
                      ),
                      keyboardType: TextInputType.url,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) {
                      setState(() {
                        _urlController.text = data!.text!;
                      });
                    }
                  },
                  icon: const Icon(Icons.content_paste, size: 16),
                  label: const Text('Paste'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title Input
            Container(
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[850] : colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.3),
                ),
              ),
              child: TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Title',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  prefixIcon: Icon(
                    Icons.title,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description Input
            Container(
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[850] : colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.3),
                ),
              ),
              child: TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  hintText: 'Notes (optional)',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  prefixIcon: Icon(
                    Icons.note,
                    color: colorScheme.primary,
                  ),
                ),
                maxLines: 3,
              ),
            ),
            const SizedBox(height: 24),

            // Tags Section
            Text(
              'Tags',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _predefinedTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                  backgroundColor: isSelected
                      ? colorScheme.primary.withOpacity(0.1)
                      : colorScheme.surfaceVariant,
                  selectedColor: colorScheme.primaryContainer,
                  checkmarkColor: colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveLink() async {
    if (_urlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a URL')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Fetch metadata if title is empty
      if (_titleController.text.isEmpty) {
        final metadata = await MetadataFetch.extract(_urlController.text);
        if (metadata != null && metadata.title != null) {
          _titleController.text = metadata.title!;
        }
      }

      // Create new link
      final link = Link(
        url: _urlController.text,
        title: _titleController.text.isEmpty
            ? _urlController.text // Use URL as fallback title
            : _titleController.text,
        description: _descriptionController.text,
        tags: _selectedTags.join(','),
        // Removed dateAdded as it is not defined in the Link model
      );

      // Save to database
      DatabaseHelper().insertLink(link);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving link: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
