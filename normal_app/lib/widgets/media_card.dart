import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/media.dart';

class MediaCard extends StatelessWidget {
  const MediaCard({super.key, required this.media, required this.onTap});
  final MediaSummary media;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 88,
            height: 124,
            child: media.poster == null
                ? const ColoredBox(
                    color: Color(0xFFE0E0E0),
                    child: Icon(Icons.movie_outlined, size: 36),
                  )
                : CachedNetworkImage(
                    imageUrl: media.poster!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${media.year ?? 'نامشخص'} · '
                    '${media.type == 'series' ? 'سریال' : 'فیلم'}',
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.chevron_left),
          ),
        ],
      ),
    ),
  );
}
