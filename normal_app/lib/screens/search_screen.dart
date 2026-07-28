import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../widgets/media_card.dart';
import 'details_screen.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('جست‌وجوی فیلم و سریال')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchBar(
              hintText: 'نام فیلم یا سریال',
              leading: const Icon(Icons.search),
              onChanged: state.debouncedSearch,
            ),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (state.busy) const LinearProgressIndicator(),
          Expanded(
            child: state.searchResults.isEmpty && !state.busy
                ? const Center(child: Text('برای شروع حداقل دو حرف بنویسید.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: state.searchResults.length,
                    itemBuilder: (context, index) {
                      final media = state.searchResults[index];
                      return MediaCard(
                        media: media,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetailsScreen(mediaId: media.id),
                          ),
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
