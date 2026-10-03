import 'package:flutter/material.dart';

import '../services/ads_service.dart';
import '../services/faq_repository.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/fade_slide_in.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  List<FaqItem>? _items;
  List<String> _categories = const [];
  String? _selectedCategory;
  String _query = '';
  bool showSearchBar = false;

  @override
  void initState() {
    super.initState();
    AdsService.instance.init();
    FaqRepository.load().then((items) {
      if (!mounted) return;
      setState(() {
        _items = items;
        _categories = FaqRepository.categoriesOf(items);
      });
    });
  }

  List<FaqItem> get _filtered {
    final items = _items ?? const [];
    return items.where((i) {
      final matchesCategory =
          _selectedCategory == null || i.category == _selectedCategory;
      final matchesQuery =
          _query.isEmpty ||
          i.question.toLowerCase().contains(_query.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pine,
      appBar: AppBar(
        backgroundColor: AppColors.pine,
        elevation: 0,
        title: Text('Help & FAQ', style: AppText.h2),
        iconTheme: IconThemeData(color: AppColors.text),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                showSearchBar = !showSearchBar;
              });
            },
            icon: Icon(Icons.search_rounded, color: AppColors.text),
          ),
          SizedBox(width: 10),
        ],
      ),
      body:
          _items == null
              ? Center(child: CircularProgressIndicator(color: AppColors.ember))
              : SafeArea(
                top: false,
                child: ListView(
                  // Using a key tied to the filtered question list, not the
                  // page itself, keeps this ListView's own element alive
                  // across rebuilds (search toggling, category taps) so it
                  // doesn't get rebuilt from scratch — combined with the
                  // keep-alive mixin on each tile below, this is what stops
                  // an open answer from closing when you scroll.
                  key: const PageStorageKey('faq-list'),
                  physics: BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    Visibility(
                      visible: showSearchBar,
                      child: FadeSlideIn(
                        key: ValueKey('search'),
                        child: _SearchBar(
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    FadeSlideIn(
                      key: ValueKey('cats'),
                      delay: Duration(milliseconds: 60),
                      child: SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: BouncingScrollPhysics(),
                          children: [
                            _CategoryChip(
                              label: 'All',
                              selected: _selectedCategory == null,
                              onTap:
                                  () =>
                                      setState(() => _selectedCategory = null),
                            ),
                            SizedBox(width: 8),
                            for (final c in _categories) ...[
                              _CategoryChip(
                                label: c,
                                selected: _selectedCategory == c,
                                onTap:
                                    () => setState(() => _selectedCategory = c),
                              ),
                              SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    if (_filtered.isEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text(
                            'No matching questions.',
                            style: AppText.muted,
                          ),
                        ),
                      )
                    else
                      for (var i = 0; i < _filtered.length; i++)
                        Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: FadeSlideIn(
                            key: ValueKey(_filtered[i].question),
                            delay: Duration(milliseconds: 20 * (i % 12)),
                            child: _FaqTile(item: _filtered[i]),
                          ),
                        ),
                  ],
                ),
              ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline.alp(0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: AppColors.muted, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: AppText.body,
              decoration: InputDecoration(
                hintText: 'Search questions',
                hintStyle: AppText.muted,
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ember : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: selected ? AppColors.pine : AppColors.text,
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.item});
  final FaqItem item;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

// AutomaticKeepAliveClientMixin is the fix for "answer closes on scroll":
// without it, Flutter is free to tear down and rebuild this tile's State
// (losing _revealed) once it's scrolled far enough off-screen, even inside
// a plain (non-lazy) ListView. wantKeepAlive=true tells Flutter to keep
// this tile's state alive for as long as the FAQ page itself is alive — so
// it still resets the moment you actually leave the page, which is exactly
// the behaviour asked for.
class _FaqTileState extends State<_FaqTile> with AutomaticKeepAliveClientMixin {
  bool _revealed = false;
  bool _loadingAd = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _reveal() async {
    setState(() => _loadingAd = true);
    final earned = await AdsService.instance.requestReveal();
    if (!mounted) return;
    setState(() {
      _loadingAd = false;
      if (earned) _revealed = true;
    });
    if (!earned) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Couldn't load the ad just now — check your connection and try again.",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    return AppCard(
      radius: 20,
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.only(top: 2),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.mint.alp(0.16),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.help_outline_rounded,
                  size: 16,
                  color: AppColors.mint,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.item.question,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Align(
            alignment: Alignment.bottomRight,
            child: AnimatedSize(
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child:
                  _revealed
                      ? Padding(
                        padding: EdgeInsets.only(left: 38),
                        child: Text(widget.item.answer, style: AppText.muted),
                      )
                      : Padding(
                        padding: EdgeInsets.only(left: 38),
                        child: SizedBox(
                          height: 34,
                          child: OutlinedButton.icon(
                            onPressed: _loadingAd ? null : _reveal,
                            icon:
                                _loadingAd
                                    ? SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.sun,
                                      ),
                                    )
                                    : Icon(
                                      // Icons.play_circle_fill_rounded,
                                      Icons.psychology_outlined,
                                      size: 18,
                                      color: AppColors.sun,
                                    ),
                            label: Text(
                              "Reveal",
                              // _loadingAd ? 'Loading ad…' : 'Watch ad to reveal',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.sun,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.sun.alp(0.5)),
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
