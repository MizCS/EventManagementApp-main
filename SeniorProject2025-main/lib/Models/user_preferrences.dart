import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

class UserPreferences extends StatefulWidget {
  const UserPreferences({super.key});

  @override
  State<UserPreferences> createState() => _UserPreferencesState();
}

class _UserPreferencesState extends State<UserPreferences> {
  final _logger = Logger();
  //final SupabaseClient _supabase = Supabase.instance.client;
  String? userId;
  
  List<String> _allTags = [];
  List<String> _allCategories = [];
  Set<String> _selectedTags = {};
  Set<String> _preferedTags = {};
  Set<String> _selectedCategories = {};
  Set<String> _preferedCategories = {};

  @override
  void initState() {
    super.initState();
    _loadTagsAndCategories();
    _loadPreferredTagsAndCategories();
  }

  //fetch tags from supabase
  Future<Map<String, Set<String>>> _getAllTags() async {
    try {
      // Fetch tags from Events table
      final eventsResponse = await Supabase.instance.client
          .from('Events')
          .select('tags');
      
      // Fetch categories from Discussions table
      final discussionsResponse = await Supabase.instance.client
          .from('Discussions')
          .select('categories');
      
      final Set<String> allTags = {};
      final Set<String> allCategories = {};

      // Process Events - only get tags
      for (final event in eventsResponse) {
        if (event['tags'] != null && event['tags'] is List) {
          final tags = (event['tags'] as List).whereType<String>().toList();
          allTags.addAll(tags);
        }
      }

      // Process Discussions - only get categories
      for (final discussion in discussionsResponse) {
        if (discussion['categories'] != null && discussion['categories'] is List) {
          final categories = (discussion['categories'] as List).whereType<String>().toList();
          allCategories.addAll(categories);
        }
      }

      return {
        'allTags': allTags,
        'allCategories': allCategories,
      };
    } catch (e) {
      _logger.e('Error fetching tags and categories: $e');
      return {
        'allTags': {},
        'allCategories': {},
      };
    }
  }

  Future<void> _loadTagsAndCategories() async {
    final tags = await _getAllTags();
    setState(() {
      _allTags = tags['allTags']?.toList() ?? [];
      _allCategories = tags['allCategories']?.toList() ?? []; 
      // For now, we'll use some default categories
      //_categories = ['Sports', 'Music', 'Food', 'Art', 'Technology'];
    });
  }
  Future<void> selectPreferredTags() async {
    // First fetch all tags from the database
    final tags = await _getAllTags();
    if (!mounted) return;
    setState(() {
      _allTags = tags['allTags']?.toList() ?? [];
      // Initialize _selectedTags with current _PreferedTags for the dialog
      _selectedTags = Set<String>.from(_preferedTags);
    });

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text('Select Preferred Tags'),
              content: SizedBox(
                width: double.maxFinite,
                child: _allTags.isEmpty
                    ? Center(child: Text('No tags available'))
                    : SingleChildScrollView(
                        child: Wrap(
                          spacing: 2.0,
                          runSpacing: 2.0,
                          children: _allTags.map((tag) {
                            final isSelected = _selectedTags.contains(tag);
                            return FilterChip(
                              label: Text(
                                tag,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (bool selected) {
                                setDialogState(() {
                                  if (selected) {
                                    _selectedTags.add(tag);
                                  } else {
                                    _selectedTags.remove(tag);
                                  }
                                });
                              },
                              backgroundColor: theme.colorScheme.surface,
                              selectedColor: theme.colorScheme.primary.withValues(alpha:0.2),
                              checkmarkColor: theme.colorScheme.primary,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.textTheme.bodyLarge?.color,
                              ),
                              elevation: isSelected ? 2 : 0,
                              shadowColor: theme.colorScheme.shadow,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected 
                                      ? theme.colorScheme.primary 
                                      : theme.dividerColor,
                                  width: 1,
                                ),
                              ),
                              showCheckmark: true,
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            );
                          }).toList(),
                        ),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _savePreferredTags();
                  },
                  child: Text('Update'),
                ),
              ],
            );
          }
        );
      },
    ); 
  }
  Future<void> _savePreferredTags() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        _logger.e('No user logged in');
        return;
      }

      await Supabase.instance.client
          .from('Users')
          .update({
            'pref_tags': _selectedTags.toList(),
          })
          .eq('user_id', currentUser.id);
      
      // Only update _PreferedTags after successful database update
      if (!mounted) return;
      setState(() {
        _preferedTags = Set<String>.from(_selectedTags);
      });
    } catch (e) {
      _logger.e('Error saving preferred tags: $e');
    }
  }
  Future<void> selectPreferredCategories() async {
    // First fetch all tags from the database
    final tags = await _getAllTags();
    if (!mounted) return;
    setState(() {
      _allCategories = tags['allCategories']?.toList() ?? [];
      // Initialize _selectedCategories with current _PreferedCategories for the dialog
      _selectedCategories = Set<String>.from(_preferedCategories);
    });

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text('Select Preferred Categories'),
              content: SizedBox(
                width: double.maxFinite,
                child: _allCategories.isEmpty
                    ? Center(child: Text('No categories available'))
                    : SingleChildScrollView(
                        child: Wrap(
                          spacing: 2.0,
                          runSpacing: 2.0,
                          children: _allCategories.map((category) {
                            final isSelected = _selectedCategories.contains(category);
                            return ChoiceChip(
                              label: Text(
                                category,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (bool selected) {
                                setDialogState(() {
                                  if (selected) {
                                    _selectedCategories.add(category);
                                  } else {
                                    _selectedCategories.remove(category);
                                  }
                                });
                              },
                              backgroundColor: theme.colorScheme.surface,
                              selectedColor: theme.colorScheme.primary.withValues(alpha:0.2),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.textTheme.bodyLarge?.color,
                              ),
                              elevation: isSelected ? 2 : 0,
                              shadowColor: theme.colorScheme.shadow,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected 
                                      ? theme.colorScheme.primary 
                                      : theme.dividerColor,
                                  width: 1,
                                ),
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            );
                          }).toList(),
                        ),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _savePreferredCategories();
                  },
                  child: Text('Update'),
                ),
              ],
            );
          }
        );
      },
    );  
  }
  Future<void> _savePreferredCategories() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        _logger.e('No user logged in');
        return;
      }
      await Supabase.instance.client
          .from('Users')
          .update({
            'pref_cat': _selectedCategories.toList(),
          })
          .eq('user_id', currentUser.id);      
      // Only update _PreferedCategories after successful database update
      if (!mounted) return;
      setState(() {
        _preferedCategories = Set<String>.from(_selectedCategories);
      });
    } catch (e) {
      _logger.e('Error saving preferred categories: $e');
    }
  }
  Future<void> _loadPreferredTagsAndCategories() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      final response = await Supabase.instance.client
          .from('Users')
          .select('pref_tags, pref_cat')
          .eq('user_id', currentUser.id)
          .single();

      setState(() {
        _preferedTags = (response['pref_tags'] as List<dynamic>?)?.cast<String>().toSet() ?? {};
        _preferedCategories = (response['pref_cat'] as List<dynamic>?)?.cast<String>().toSet() ?? {};
      });
    } catch (e) {
      _logger.e('Error loading preferred tags and categories: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    //final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final iconColor = theme.iconTheme.color ?? Colors.black;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(child: Icon(Icons.tag, color: iconColor, size: 16, semanticLabel: 'Preferred Events')),
                  TextSpan(text: 'Events', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            trailing: IconButton(
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
              onPressed: () {
                selectPreferredTags();
              }, 
              icon: Icon(Icons.edit, color: iconColor, size: 18,)
            ),
          ),
          if (_preferedTags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Wrap(
                alignment: WrapAlignment.start,

                spacing: 2,
                runSpacing: 2,
                children: _preferedTags.map((tag) => Chip(
                  label: Text(tag, style: TextStyle(color: theme.colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black)),
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: Colors.white,
                      width: 1,
                    ),
                  ),
                )).toList(),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Text('No preferred tags', style: TextStyle(color: Colors.grey)),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(child: Icon(Icons.tag, color: iconColor, size: 16, semanticLabel: 'Preferred Discussions')),
                  TextSpan(text: 'Discussions', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            trailing: IconButton(
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
              onPressed: () {
                selectPreferredCategories();
              }, 
              icon: Icon(Icons.edit, color: iconColor, size: 18,)
            ),
          ),
          if (_preferedCategories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Wrap(
                alignment: WrapAlignment.start,
                spacing: 2,
                runSpacing: 2,
                children: _preferedCategories.map((category) => Chip(
                  label: Text(category, style: TextStyle(color: theme.colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black)),
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: Colors.white,
                      width: 1,
                    ),
                  ),
                )).toList(),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Text('No preferred categories', style: TextStyle(color: Colors.grey)),
            ),
        ],
      ),
    );
  }
}