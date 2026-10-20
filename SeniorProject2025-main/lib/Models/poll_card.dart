import 'package:flutter/material.dart';
import 'package:icebreaker/assets/database/poll.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatePollDialog extends StatefulWidget {
  final String discussionId;

  const CreatePollDialog({required this.discussionId});

  @override
  State<CreatePollDialog> createState() => _CreatePollDialogState();
}

class _CreatePollDialogState extends State<CreatePollDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _pollQuestionController = TextEditingController();
  final List<TextEditingController> _pollOptionControllers = [];
  final TextEditingController _newOptionController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize with two empty options
    _pollOptionControllers.add(TextEditingController());
    _pollOptionControllers.add(TextEditingController());
  }

  @override
  void dispose() {
    _pollQuestionController.dispose();
    _newOptionController.dispose();
    for (var controller in _pollOptionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _removePollOption(int index) {
    setState(() {
      _pollOptionControllers.removeAt(index);
    });
  }

  void _addPollOption() {
    setState(() {
      _pollOptionControllers.add(TextEditingController(text: _newOptionController.text));
      _newOptionController.clear();
    });
  }

  Future<void> _createPoll() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      isLoading = true;
    });

    try {
      // Create poll
      final pollResponse = await Supabase.instance.client
          .from('Polls')
          .insert({
            'discussion_id': widget.discussionId,
            'poll_question': _pollQuestionController.text,
            'past': false,
            'auto_delete': false,
          })
          .select()
          .single();

      final pollId = pollResponse['poll_id'];

      // Create poll options
      for (var i = 0; i < _pollOptionControllers.length; i++) {
        await Supabase.instance.client
            .from('Poll_questions')
            .insert({
              'poll_id': pollId,
              'p_option': _pollOptionControllers[i].text,
              'vote_count': 0,
              'option_order': i + 1,
            });
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating poll: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final inputColor = isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5);
    final borderColor = isDark ? const Color(0xFF404040) : const Color(0xFFE0E0E0);
    final hintColor = isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575);
    final selectedColor = isDark ? const Color(0xFF64B5F6) : Colors.blue;

    return Dialog(
      child: Container(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _pollQuestionController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: selectedColor),
                  ),
                  labelText: "Poll Question",
                  labelStyle: TextStyle(fontSize: 16, color: hintColor),
                  filled: true,
                  fillColor: inputColor,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a poll question';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              Text(
                "Poll Options",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 10),
              ..._pollOptionControllers.asMap().entries.map((entry) {
                final index = entry.key;
                final controller = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(color: selectedColor),
                            ),
                            labelText: "Option ${index + 1}",
                            labelStyle: TextStyle(fontSize: 16, color: hintColor),
                            filled: true,
                            fillColor: inputColor,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Option cannot be empty';
                            }
                            return null;
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => _removePollOption(index),
                      ),
                    ],
                  ),
                );
              }),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Icons.add_circle, color: selectedColor),
                    onPressed: _addPollOption,
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isLoading ? null : () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: isLoading ? null : _createPoll,
                    child: isLoading 
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text('Create Poll'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

