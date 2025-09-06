// lib/widgets/code_editor/search_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SearchPanel extends StatefulWidget {
  final Function(String, bool, bool, bool)
  onSearch; // query, caseSensitive, wholeWord, regex
  final Function(String, String, bool, bool, bool)
  onReplace; // find, replace, caseSensitive, wholeWord, regex
  final VoidCallback onClose;
  final bool showReplace;

  const SearchPanel({
    super.key,
    required this.onSearch,
    required this.onReplace,
    required this.onClose,
    this.showReplace = false,
  });

  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _replaceFocusNode = FocusNode();

  bool _caseSensitive = false;
  bool _wholeWord = false;
  bool _useRegex = false;
  bool _showReplace = false;

  @override
  void initState() {
    super.initState();
    _showReplace = widget.showReplace;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _replaceController.dispose();
    _searchFocusNode.dispose();
    _replaceFocusNode.dispose();
    super.dispose();
  }

  void _performSearch() {
    widget.onSearch(
      _searchController.text,
      _caseSensitive,
      _wholeWord,
      _useRegex,
    );
  }

  void _performReplace() {
    widget.onReplace(
      _searchController.text,
      _replaceController.text,
      _caseSensitive,
      _wholeWord,
      _useRegex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search row
          Row(
            children: [
              // Search icon
              Icon(
                Icons.search,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(width: 8),

              // Search input
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: const InputDecoration(
                    hintText: 'Search',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (_) => _performSearch(),
                  onSubmitted: (_) => _performSearch(),
                ),
              ),

              const SizedBox(width: 8),

              // Search options
              _buildToggleButton(
                icon: Icons.text_fields,
                tooltip: 'Match Case',
                isActive: _caseSensitive,
                onPressed: () {
                  setState(() => _caseSensitive = !_caseSensitive);
                  _performSearch();
                },
              ),

              _buildToggleButton(
                icon: Icons.crop_free,
                tooltip: 'Whole Word',
                isActive: _wholeWord,
                onPressed: () {
                  setState(() => _wholeWord = !_wholeWord);
                  _performSearch();
                },
              ),

              _buildToggleButton(
                icon: Icons.data_object,
                tooltip: 'Use Regular Expression',
                isActive: _useRegex,
                onPressed: () {
                  setState(() => _useRegex = !_useRegex);
                  _performSearch();
                },
              ),

              const SizedBox(width: 8),

              // Toggle replace
              IconButton(
                icon: Icon(
                  _showReplace
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _showReplace = !_showReplace);
                },
                tooltip: 'Toggle Replace',
              ),

              // Close button
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: widget.onClose,
                tooltip: 'Close',
              ),
            ],
          ),

          // Replace row (if shown)
          if (_showReplace) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                // Replace icon
                Icon(
                  Icons.find_replace,
                  size: 20,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 8),

                // Replace input
                Expanded(
                  child: TextField(
                    controller: _replaceController,
                    focusNode: _replaceFocusNode,
                    decoration: const InputDecoration(
                      hintText: 'Replace',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => _performReplace(),
                  ),
                ),

                const SizedBox(width: 8),

                // Replace buttons
                ElevatedButton.icon(
                  onPressed: _performReplace,
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text('Replace'),
                ),

                const SizedBox(width: 8),

                ElevatedButton.icon(
                  onPressed: () {
                    // Replace all logic
                    _performReplace();
                  },
                  icon: const Icon(Icons.swap_horizontal_circle, size: 16),
                  label: const Text('Replace All'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                : null,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).dividerColor,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ),
    );
  }
}

class SearchResultIndicator extends StatelessWidget {
  final int currentMatch;
  final int totalMatches;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const SearchResultIndicator({
    super.key,
    required this.currentMatch,
    required this.totalMatches,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            totalMatches > 0 ? '$currentMatch of $totalMatches' : 'No results',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          if (totalMatches > 0) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up, size: 16),
              onPressed: onPrevious,
              tooltip: 'Previous match',
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, size: 16),
              onPressed: onNext,
              tooltip: 'Next match',
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
          ],
        ],
      ),
    );
  }
}
