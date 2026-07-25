import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/media.dart';
import '../models/user_data.dart';
import '../state/app_state.dart';

class DetailsScreen extends StatefulWidget {
  const DetailsScreen({super.key, required this.mediaId});
  final String mediaId;
  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  MediaDetails? details;
  String? error;
  int selectedSeason = 1;
  List<Episode> episodes = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      details = await context.read<AppState>().api.details(widget.mediaId);
      if (details!.type == 'series') await loadSeason();
    } catch (exception) {
      error = exception is Exception
          ? exception.toString().replaceAll('MovieServiceException: ', '')
          : '$exception';
    }
    if (mounted) setState(() {});
  }

  Future<void> loadSeason() async {
    episodes = await context.read<AppState>().api.season(widget.mediaId, selectedSeason);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(error!)));
    }
    if (details == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final media = details!;
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(media.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 130,
                  height: 190,
                  child: media.poster == null
                      ? const ColoredBox(color: Colors.black12, child: Icon(Icons.movie))
                      : CachedNetworkImage(imageUrl: media.poster!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(media.title, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text('${media.year ?? '-'} · ${media.runtime ?? '-'}'),
                    Text(media.genre ?? ''),
                    Text('IMDb: ${media.imdbRating ?? '-'}'),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<WatchState>(
                      value: state.watchStates[media.id],
                      hint: const Text('وضعیت تماشا'),
                      items: WatchState.values
                          .map((item) => DropdownMenuItem(value: item, child: Text(item.label)))
                          .toList(),
                      onChanged: state.user == null ? null : (value) {
                        if (value != null) state.setWatchState(media, value);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(media.plot ?? 'خلاصه‌ای ثبت نشده است.'),
          const SizedBox(height: 12),
          Text('کارگردان: ${media.director ?? '-'}'),
          Text('بازیگران: ${media.actors ?? '-'}'),
          Text('کشور سازنده: ${media.country ?? '-'}'),
          const Divider(height: 32),
          Text('امتیاز شما', style: Theme.of(context).textTheme.titleMedium),
          Slider(
            value: state.ratings[media.id] ?? 0,
            min: 0,
            max: 5,
            divisions: 10,
            label: '${state.ratings[media.id] ?? 0}',
            onChanged: state.user == null ? null : (value) => state.rate(media, value),
          ),
          if (media.type == 'series') ...[
            const Divider(height: 32),
            Row(
              children: [
                Text('فصل', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: selectedSeason,
                  items: List.generate(
                    media.totalSeasons ?? 1,
                    (index) => DropdownMenuItem(value: index + 1, child: Text('${index + 1}')),
                  ),
                  onChanged: (value) async {
                    if (value == null) return;
                    selectedSeason = value;
                    await loadSeason();
                  },
                ),
              ],
            ),
            ...episodes.map((episode) => CheckboxListTile(
                  value: (state.watchedEpisodes[media.id] ?? 0) >= episode.episode,
                  title: Text('${episode.episode}. ${episode.title}'),
                  subtitle: Text('${episode.released ?? '-'} · IMDb ${episode.rating ?? '-'}'),
                  onChanged: state.user == null
                      ? null
                      : (_) => state.toggleEpisode(media, episode.episode),
                )),
            if (episodes.isNotEmpty)
              LinearProgressIndicator(
                value: (state.watchedEpisodes[media.id] ?? 0) / episodes.length,
              ),
          ],
          const Divider(height: 32),
          FilledButton.tonalIcon(
            onPressed: state.user == null ? null : () => _showReview(context, state, media),
            icon: const Icon(Icons.rate_review_outlined),
            label: const Text('ثبت نظر'),
          ),
          FilledButton.tonalIcon(
            onPressed: state.user == null ? null : () => _showLists(context, state, media),
            icon: const Icon(Icons.playlist_add),
            label: const Text('افزودن به فهرست شخصی'),
          ),
          ...state.reviews
              .where((review) => review.mediaId == media.id)
              .map((review) => ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(state.user?.name ?? ''),
                    subtitle: Text(review.spoiler ? 'نظر دارای اسپویل - برای نمایش لمس کنید' : review.text),
                    onTap: review.spoiler
                        ? () => showDialog<void>(
                              context: context,
                              builder: (_) => AlertDialog(content: Text(review.text)),
                            )
                        : null,
                  )),
        ],
      ),
    );
  }

  Future<void> _showReview(BuildContext context, AppState state, MediaSummary media) async {
    final controller = TextEditingController();
    var spoiler = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('نظر جدید'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: controller, maxLines: 4),
              CheckboxListTile(
                value: spoiler,
                title: const Text('دارای اسپویل'),
                onChanged: (value) => setDialogState(() => spoiler = value ?? false),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  state.addReview(media.id, controller.text, spoiler);
                  Navigator.pop(context);
                }
              },
              child: const Text('ثبت'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLists(BuildContext context, AppState state, MediaSummary media) async {
    if (state.customLists.isEmpty) await state.createList('فهرست من');
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: state.customLists.keys
              .map((name) => ListTile(
                    leading: const Icon(Icons.playlist_add_check),
                    title: Text(name),
                    onTap: () {
                      state.addToList(name, media);
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }
}
