import 'package:flutter/material.dart';
import '../assets/database/disc_message.dart';

/// Constants for the reaction system
class ReactionConstants {
  static const double pickerWidth = 200.0;
  static const double emojiButtonSize = 36.0;
  static const double messageBorderRadius = 20.0;
  static const double reactionBorderRadius = 12.0;
  static const List<String> defaultReactions = ['👍', '❤️', '😂', '😮', '😢', '😡', '🎉', '🙏'];
  
  // Comprehensive emoji list organized by categories
  static const Map<String, List<String>> categories = {
    'Frequently Used': ['👍', '❤️', '😂', '😮', '😢', '😡', '🎉', '🙏'],
    'Smileys': ['😀', '😃', '😄', '😁', '😅', '😂', '🤣', '😊', '😇', '🙂', '😉', '😌', '😍', '🥰', '😘', '😗', '😙', '😚', '😋', '😛', '😝', '😜', '🤪', '🤨', '🧐', '🤓', '😎', '🤩', '🥳'],
    'Gestures': ['👍', '👎', '👌', '✌️', '🤞', '🤟', '🤘', '🤙', '👈', '👉', '👆', '👇', '☝️', '✋', '🤚', '🖐️', '🖖', '👋', '🤏', '✍️'],
    'Hearts': ['❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔', '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝'],
    'Activities': ['🎉', '🎊', '🎈', '🎂', '🎯', '🎲', '🎮', '🎨', '🎭', '🎪', '🎫', '🎟️', '🎠', '🎡', '🎢', '🎬', '🎤', '🎧', '🎼', '🎹', '🥁', '🎷', '🎺', '🎸', '🎻'],
  };
}

/// Represents a single reaction with user information
class ReactionInfo {
  final String userId;
  final String emoji;

  ReactionInfo(this.userId, this.emoji);

  factory ReactionInfo.fromString(String reaction) {
    final parts = reaction.split(':');
    return ReactionInfo(parts[0], parts[1]);
  }

  String format() => "$userId:$emoji";
}

/// Manages all reaction-related functionality
class ReactionManager {
  final BuildContext context;
  final String currentUserId;
  final Function(DiscMessage, String) onUpdateReaction;

  ReactionManager({
    required this.context,
    required this.currentUserId,
    required this.onUpdateReaction,
  });

  /// Shows the full emoji picker in a bottom sheet
  void showFullEmojiPicker(DiscMessage message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: 400,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[900]
                : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _buildPickerHeader(context),
              Expanded(
                child: _buildCategoryTabs(context, message),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Shows the quick reaction picker
  void showQuickReactionPicker(DiscMessage message, Offset tapPosition) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        tapPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ReactionConstants.messageBorderRadius)
      ),
      color: Theme.of(context).brightness == Brightness.dark 
          ? Colors.grey[800]!.withValues(alpha: 0.8)
          : Colors.white.withValues(alpha: 0.8),
      items: [
        PopupMenuItem(
          padding: EdgeInsets.symmetric(horizontal: 8),
          height: 44,
          child: SizedBox(
            width: ReactionConstants.pickerWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...ReactionConstants.defaultReactions.map((emoji) => 
                        _buildEmojiButton(emoji: emoji, message: message)
                      ).toList(),
                      _buildEmojiButton(
                        emoji: '⋯',
                        message: message,
                        onTap: () {
                          Navigator.pop(context);
                          showFullEmojiPicker(message);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the header for the emoji picker
  Widget _buildPickerHeader(BuildContext context) {
    return Container(
      height: 40,
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]
            : Colors.grey[100],
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Choose a reaction',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
        ],
      ),
    );
  }

  /// Builds the category tabs for the full emoji picker
  Widget _buildCategoryTabs(BuildContext context, DiscMessage message) {
    return DefaultTabController(
      length: ReactionConstants.categories.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabs: ReactionConstants.categories.keys.map((category) => Tab(
              child: Text(
                category,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                ),
              ),
            )).toList(),
          ),
          Expanded(
            child: TabBarView(
              children: ReactionConstants.categories.values.map((emojiList) {
                return _buildEmojiGrid(emojiList, message);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the emoji grid for a category
  Widget _buildEmojiGrid(List<String> emojiList, DiscMessage message) {
    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        childAspectRatio: 1,
      ),
      itemCount: emojiList.length,
      itemBuilder: (context, index) {
        return _buildEmojiButton(
          emoji: emojiList[index],
          message: message,
        );
      },
    );
  }

  /// Builds a single emoji button
  Widget _buildEmojiButton({
    required String emoji,
    required DiscMessage message,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap ?? () {
          onUpdateReaction(message, emoji);
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(ReactionConstants.messageBorderRadius),
        child: Container(
          width: ReactionConstants.emojiButtonSize,
          height: ReactionConstants.emojiButtonSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ReactionConstants.emojiButtonSize / 2),
          ),
          child: Center(
            child: Text(
              emoji,
              style: TextStyle(fontSize: 22),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the reactions display for a message
  Widget buildReactions(List<String> reactions) {
    // Group reactions by emoji type
    Map<String, int> reactionCounts = {};
    Map<String, bool> userReactions = {};
    
    for (var reaction in reactions) {
      final info = ReactionInfo.fromString(reaction);
      reactionCounts[info.emoji] = (reactionCounts[info.emoji] ?? 0) + 1;
      if (info.userId == currentUserId) {
        userReactions[info.emoji] = true;
      }
    }

    return Wrap(
      spacing: 4,
      children: reactionCounts.entries.map((entry) {
        final hasUserReaction = userReactions[entry.key] ?? false;
        return _buildReactionBubble(
          emoji: entry.key,
          count: entry.value,
          isUserReaction: hasUserReaction,
        );
      }).toList(),
    );
  }

  /// Builds a single reaction bubble with count
  Widget _buildReactionBubble({
    required String emoji,
    required int count,
    required bool isUserReaction,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isUserReaction 
          ? Colors.blue.withValues(alpha: 0.2) 
          : Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ReactionConstants.reactionBorderRadius),
        border: isUserReaction
          ? Border.all(color: Colors.blue.withValues(alpha: 0.3))
          : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: 12)),
          if (count > 1) ...[
            SizedBox(width: 4),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
} 