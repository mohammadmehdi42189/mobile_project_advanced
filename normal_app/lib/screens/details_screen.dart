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
      await context.read<AppState>().loadReviews(widget.mediaId);
      if (details!.type == 'series') await loadSeason();
    } catch (exception) {
      error = exception is Exception
          ? exception.toString().replaceAll('MovieServiceException: ', '')
          : '$exception';
    }
    if (mounted) setState(() {});
  }

  Future<void> loadSeason() async {
    episodes = await context.read<AppState>().api.season(
      widget.mediaId,
      selectedSeason,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(error!)),
      );
    }
    if (details == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
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
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 130,
                      height: 190,
                      child: media.poster == null
                          ? const ColoredBox(
                              color: Colors.black12,
                              child: Icon(Icons.movie),
                            )
                          : CachedNetworkImage(
                              imageUrl: media.poster!,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  if (media.type == 'series')
                    Positioned(
                      right: 0,
                      left: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: episodes.isEmpty
                            ? 0
                            : state.seasonWatchedCount(
                                    media.id,
                                    selectedSeason,
                                  ) /
                                  episodes.length,
                        color: _progressColor(state, media.id),
                        backgroundColor: Colors.grey.shade400,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      media.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text('${media.year ?? '-'} · ${media.runtime ?? '-'}'),
                    Text(media.genre ?? ''),
                    Text('IMDb: ${media.imdbRating ?? '-'}'),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<WatchState>(
                      value: state.watchStates[media.id],
                      hint: const Text('وضعیت تماشا'),
                      items: WatchState.values
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                      onChanged: state.user == null
                          ? null
                          : (value) {
                              if (value != null)
                                state.setWatchState(media, value);
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
            onChanged: state.user == null
                ? null
                : (value) => state.rate(media, value),
          ),
          FutureBuilder<Map<int, double>>(
            future: state.ratingDistribution(media.id),
            builder: (context, snapshot) {
              final values = snapshot.data;
              if (values == null) return const SizedBox.shrink();
              return ExpansionTile(
                title: const Text('توزیع امتیاز کاربران'),
                children: values.entries
                    .map(
                      (entry) => ListTile(
                        dense: true,
                        title: Text('${entry.key / 2} از ۵'),
                        trailing: Text('${entry.value.toStringAsFixed(1)}٪'),
                      ),
                    )
                    .toList(),
              );
            },
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
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text('${index + 1}'),
                    ),
                  ),
                  onChanged: (value) async {
                    if (value == null) return;
                    selectedSeason = value;
                    await loadSeason();
                  },
                ),
              ],
            ),
            ...episodes.map(
              (episode) => CheckboxListTile(
                value: state.isEpisodeWatched(
                  media.id,
                  selectedSeason,
                  episode.episode,
                ),
                title: Text('${episode.episode}. ${episode.title}'),
                subtitle: Text(
                  '${episode.released ?? '-'} · IMDb ${episode.rating ?? '-'}',
                ),
                onChanged: state.user == null
                    ? null
                    : (_) => state.toggleEpisode(
                        media,
                        selectedSeason,
                        episode.episode,
                      ),
              ),
            ),
            if (episodes.isNotEmpty)
              LinearProgressIndicator(
                value:
                    state.seasonWatchedCount(media.id, selectedSeason) /
                    episodes.length,
                color: _progressColor(state, media.id),
              ),
          ],
          const Divider(height: 32),
          FilledButton.tonalIcon(
            onPressed: state.user == null
                ? null
                : () => _showReview(context, state, media),
            icon: const Icon(Icons.rate_review_outlined),
            label: const Text('ثبت نظر'),
          ),
          FilledButton.tonalIcon(
            onPressed: state.user == null
                ? null
                : () => _showLists(context, state, media),
            icon: const Icon(Icons.playlist_add),
            label: const Text('افزودن به فهرست شخصی'),
          ),
          ...state
              .reviewsFor(media.id)
              .map(
                (review) => ListTile(
                  leading: CircleAvatar(
                    backgroundImage: review.userAvatar == null
                        ? null
                        : CachedNetworkImageProvider(review.userAvatar!),
                    child: review.userAvatar == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(review.userName ?? 'کاربر'),
                  subtitle: Text(
                    '${review.spoiler ? 'نظر دارای اسپویل - برای نمایش لمس کنید' : review.text}\n'
                    '${review.createdAt.toLocal().toString().substring(0, 16)}',
                  ),
                  trailing:
                      state.user == null ||
                          !state.reviews.any((item) => item.id == review.id)
                      ? null
                      : IconButton(
                          onPressed: () => state.deleteReview(review.id),
                          icon: const Icon(Icons.delete_outline),
                        ),
                  onTap: review.spoiler
                      ? () => showDialog<void>(
                          context: context,
                          builder: (_) =>
                              AlertDialog(content: Text(review.text)),
                        )
                      : null,
                ),
              ),
        ],
      ),
    );
  }

  Color _progressColor(AppState state, String mediaId) {
    final watched = state.seasonWatchedCount(mediaId, selectedSeason);
    if (state.watchStates[mediaId] == WatchState.dropped ||
        state.watchStates[mediaId] == WatchState.paused) {
      return Colors.red;
    }
    if (episodes.isNotEmpty && watched == episodes.length) {
      return state.watchStates[mediaId] == WatchState.completed
          ? Colors.green
          : Colors.purple;
    }
    return watched == 0 ? Colors.grey : Colors.orange;
  }

  Future<void> _showReview(
    BuildContext context,
    AppState state,
    MediaSummary media,
  ) async {
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
                onChanged: (value) =>
                    setDialogState(() => spoiler = value ?? false),
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

  Future<void> _showLists(
    BuildContext context,
    AppState state,
    MediaSummary media,
  ) async {
    if (state.customLists.isEmpty) await state.createList('فهرست من');
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: state.customLists.keys
              .map(
                (name) => ListTile(
                  leading: const Icon(Icons.playlist_add_check),
                  title: Text(name),
                  onTap: () {
                    state.addToList(name, media);
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
