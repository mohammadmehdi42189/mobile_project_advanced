import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/media.dart';
import '../state/app_state.dart';
import 'details_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final sections = const [
    ('فیلم‌های محبوب', 'Avengers', 'movie', null),
    ('سریال‌های محبوب', 'Breaking Bad', 'series', null),
    ('آثار جدید', 'The', null, 2025),
    ('آثار با امتیاز بالا', 'Godfather', 'movie', null),
    ('پیشنهاد برای شما', 'Batman', null, null),
  ];
  final Map<String, Future<List<MediaSummary>>> requests = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final api = context.read<AppState>().api;
    for (final section in sections) {
      requests.putIfAbsent(
        section.$1,
        () => api
            .search(section.$2, type: section.$3, year: section.$4)
            .then((result) => result.items),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('آثار محبوب')),
    body: RefreshIndicator(
      onRefresh: () async {
        setState(requests.clear);
        didChangeDependencies();
        await Future.wait(requests.values);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: sections
            .map((section) => _section(section.$1, requests[section.$1]!))
            .toList(),
      ),
    ),
  );

  Widget _section(String title, Future<List<MediaSummary>> request) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 245,
          child: FutureBuilder<List<MediaSummary>>(
            future: request,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || snapshot.data?.isEmpty != false) {
                return const Center(
                  child: Text('اطلاعات این بخش در دسترس نیست.'),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: snapshot.data!.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final media = snapshot.data![index];
                  return SizedBox(
                    width: 130,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailsScreen(mediaId: media.id),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              width: 130,
                              height: 185,
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
                          const SizedBox(height: 6),
                          Text(
                            media.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
