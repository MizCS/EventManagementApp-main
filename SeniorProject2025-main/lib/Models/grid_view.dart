import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:icebreaker/Models/events_model.dart';
import 'package:icebreaker/event_pop_up.dart';

class EventsGridView extends StatefulWidget {
  final SupabaseClient supabase;
  final eventsModel = EventsModel();

  EventsGridView({super.key, required this.supabase});

  @override
  State<EventsGridView> createState() => _EventsGridViewState();
}

class _EventsGridViewState extends State<EventsGridView> {
  final _logger = Logger();
  List<dynamic> events = [];
  List<dynamic> filteredEvents = [];
  Set<String> selectedTags = {};
  bool isLoading = false;
  String? errorMessage;
  int retryCount = 0;
  static const int maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await widget.eventsModel.fetchEvents();
      if (!mounted) return;
      
      setState(() {
        events = response;
        filteredEvents = events;
        isLoading = false;
        retryCount = 0; // Reset retry count on success
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load events: ${e.toString()}';
      });
      _logger.e('Error fetching events: $e');
      
      if (retryCount < maxRetries) {
        retryCount++;
        _logger.i('Retrying fetch (attempt $retryCount of $maxRetries)');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          _fetchEvents();
        }
      }
    }
  }

  void _filterEvents() {
    if (!mounted) return;
    
    if (selectedTags.isEmpty) {
      setState(() {
        filteredEvents = events;
      });
      return;
    }
    setState(() {
      filteredEvents = events.where((event) {
        final eventTags = (event['tags'] as List<dynamic>?)?.cast<String>() ?? [];
        return selectedTags.every((tag) => eventTags.contains(tag));
      }).toList();
    });
  }

  Set<String> _getAllTags() {
    final Set<String> allTags = {};
    for (final event in events) {
      final tags = (event['tags'] as List<dynamic>?)?.cast<String>() ?? [];
      allTags.addAll(tags);
    }
    return allTags;
  }

  void _showFilterDialog() {
    if (!mounted) return;
    
    final allTags = _getAllTags();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Filter Events'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8.0,
                  children: allTags.map((tag) {
                    final isSelected = selectedTags.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedTags.add(tag);
                          } else {
                            selectedTags.remove(tag);
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
                  selectedTags.clear();
                });
                _filterEvents();
                Navigator.pop(context);
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () {
                if (!mounted) return;
                _filterEvents();
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEventPopup(dynamic event) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return EventPopUp(
          event: event,
          onEventDeleted: () {
            if (!mounted) return;
            _fetchEvents();
          },
        );
      },
    ).then((_) {
      if (!mounted) return;
      _fetchEvents();
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
              onPressed: _fetchEvents,
              child: const Text('Retry'),
            )
          else
            ElevatedButton(
              onPressed: () {
                setState(() {
                  retryCount = 0;
                });
                _fetchEvents();
              },
              child: const Text('Reset and Retry'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Events'),
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
              tooltip: 'Filter Events',
            ),
        ],
      ),
      body: Column(
        children: [
          if (selectedTags.isNotEmpty) ...[
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
                        children: selectedTags.map((tag) => Chip(
                          label: Text(tag),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () {
                            if (!mounted) return;
                            setState(() {
                              selectedTags.remove(tag);
                              _filterEvents();
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
                if (isLoading && events.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (errorMessage != null) {
                  return _buildErrorWidget();
                }

                if (filteredEvents.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.event_busy, size: 48, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          selectedTags.isEmpty
                              ? 'No events found'
                              : 'No events match the selected filters',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        if (selectedTags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                selectedTags.clear();
                                _filterEvents();
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
                    itemCount: filteredEvents.length,
                    itemBuilder: (context, index) {
                      final event = filteredEvents[index];
                      return GestureDetector(
                        onTap: () => _showEventPopup(event),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Event Image
                              if (event['image_url'] != null)
                                Image.network(
                                  event['image_url'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    _logger.e('Error loading image: $error');
                                    return Container(
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.broken_image, size: 50),
                                    );
                                  },
                                )
                              else
                                Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.event, size: 50),
                                ),
                              // Gradient overlay
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.7),
                                    ],
                                  ),
                                ),
                              ),
                              // Event Title
                              Positioned(
                                bottom: 10,
                                left: 10,
                                right: 10,
                                child: Text(
                                  event['title'] ?? 'Untitled Event',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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