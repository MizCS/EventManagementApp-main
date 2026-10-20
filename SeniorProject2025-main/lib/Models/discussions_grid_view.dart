import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:icebreaker/assets/database/discussion_queries.dart';
import 'package:icebreaker/discussion_pop_up.dart';


class DiscussionsGridView extends StatefulWidget {
  final SupabaseClient supabase;

  DiscussionsGridView({super.key, required this.supabase});

  @override
  State<DiscussionsGridView> createState() => _DiscussionsGridViewState();
}

class _DiscussionsGridViewState extends State<DiscussionsGridView> {
  final _logger = Logger();
  List<dynamic> discussions = [];
  List<dynamic> filteredDiscussions = [];
  Set<String> selectedCategories = {};
  bool isLoading = false;
  String? errorMessage;
  int retryCount = 0;
  static const int maxRetries = 3;

  final List<String> availableCategories = [
    'General',
    'Questions',
    'Ideas',
    'Feedback',
    'Announcements',
    'Help',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _fetchDiscussions();
  }

  Future<void> _fetchDiscussions() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await DiscussionQueries().fetchDiscussionsByCategories(selectedCategories.toList()).first;
      if (!mounted) return;
      
      setState(() {
        discussions = response;
        filteredDiscussions = discussions;
        isLoading = false;
        retryCount = 0; // Reset retry count on success
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load discussions: ${e.toString()}';
      });
      _logger.e('Error fetching discussions: $e');
      
      if (retryCount < maxRetries) {
        retryCount++;
        _logger.i('Retrying fetch (attempt $retryCount of $maxRetries)');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          _fetchDiscussions();
        }
      }
    }
  }

  void _filterDiscussions() {
    if (!mounted) return;
    
    if (selectedCategories.isEmpty) {
      setState(() {
        filteredDiscussions = discussions;
      });
      return;
    }
    setState(() {
      filteredDiscussions = discussions.where((discussion) {
        final discussionCategories = (discussion['categories'] as List<dynamic>?)?.cast<String>() ?? [];
        return selectedCategories.every((category) => discussionCategories.contains(category));
      }).toList();
    });
  }

  void _showFilterDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Filter Discussions'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8.0,
                  children: availableCategories.map((category) {
                    final isSelected = selectedCategories.contains(category);
                    return FilterChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedCategories.add(category);
                          } else {
                            selectedCategories.remove(category);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (!mounted) return;
                setState(() {
                  selectedCategories.clear();
                });
                _filterDiscussions();
                Navigator.pop(context);
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () {
                if (!mounted) return;
                _filterDiscussions();
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDiscussionPopup(dynamic discussion) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DiscussionPopUp(
          discussion: discussion,
          onDiscussionDeleted: () {
            if (!mounted) return;
            _fetchDiscussions();
          },
        );
      },
    ).then((_) {
      if (!mounted) return;
      _fetchDiscussions();
    });
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            errorMessage ?? 'An error occurred',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          if (retryCount < maxRetries)
            ElevatedButton(
              onPressed: _fetchDiscussions,
              child: const Text('Retry'),
            )
          else
            ElevatedButton(
              onPressed: () {
                setState(() {
                  retryCount = 0;
                });
                _fetchDiscussions();
              },
              child: const Text('Reset and Retry'),
            ),
        ],
      ),
    );
  }

  String _formatDurationFromMinutes(int? minutes) {
    if (minutes == null || minutes == 0) {
      return 'No limit';
    } else if (minutes >= 1440) { // 24 hours or more
      final days = (minutes / 1440).round();
      return '$days ${days == 1 ? 'day' : 'days'}';
    } else if (minutes >= 60) {
      final hours = (minutes / 60).round();
      return '$hours ${hours == 1 ? 'hr' : 'hrs'}';
    } else {
      return '$minutes min';
    }
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Discussions'),
        actions: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterDialog,
              tooltip: 'Filter Discussions',
            ),
        ],
      ),
      body: Column(
        children: [
          if (selectedCategories.isNotEmpty) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Wrap(
                        spacing: 8,
                        children: selectedCategories.map((category) => Chip(
                          label: Text(category),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () {
                            if (!mounted) return;
                            setState(() {
                              selectedCategories.remove(category);
                              _filterDiscussions();
                            });
                          },
                        )).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (isLoading && discussions.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (errorMessage != null) {
                  return _buildErrorWidget();
                }

                if (filteredDiscussions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          selectedCategories.isEmpty
                              ? 'No discussions found'
                              : 'No discussions match the selected filters',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        if (selectedCategories.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                selectedCategories.clear();
                                _filterDiscussions();
                              });
                            },
                            child: const Text('Clear Filters'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return SizedBox(
                  width: double.maxFinite,
                  height: double.maxFinite,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: filteredDiscussions.length,
                    itemBuilder: (context, index) {
                      final discussion = filteredDiscussions[index];
                      return GestureDetector(
                        onTap: () => _showDiscussionPopup(discussion),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Discussion Image
                              if (discussion['image_url'] != null)
                                Image.network(
                                  discussion['image_url'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    _logger.e('Error loading image: $error');
                                    return Container(
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.chat_bubble_outline, size: 50),
                                    );
                                  },
                                )
                              else
                                Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.chat_bubble_outline, size: 50),
                                ),
                              // Gradient overlay
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha:0.7),
                                    ],
                                  ),
                                ),
                              ),
                              // Discussion Title and Info
                              Positioned(
                                bottom: 10,
                                left: 10,
                                right: 10,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      discussion['title'] ?? 'Untitled Discussion',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.people, color: Colors.white, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${(discussion['participants'] as List?)?.length ?? 0}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(Icons.access_time, color: Colors.white, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatDurationFromMinutes(discussion['duration']),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
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
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 