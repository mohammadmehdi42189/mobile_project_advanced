import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_data.dart';
import '../state/app_state.dart';
import '../widgets/media_card.dart';
import 'details_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('فهرست تماشا'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'در حال تماشا'),
              Tab(text: 'مشاهده‌شده'),
              Tab(text: 'بعداً'),
              Tab(text: 'موردعلاقه'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _items(context, state, WatchState.watching),
            _items(context, state, WatchState.completed),
            _items(context, state, WatchState.planned),
            _items(context, state, WatchState.favorite),
          ],
        ),
      ),
    );
  }

  Widget _items(BuildContext context, AppState state, WatchState status) {
    final items = state.watchStates.entries
        .where((entry) => entry.value == status)
        .map((entry) => state.savedMedia[entry.key])
        .whereType<dynamic>()
        .toList();
    if (items.isEmpty) return const Center(child: Text('این فهرست خالی است.'));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) => MediaCard(
        media: items[index],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailsScreen(mediaId: items[index].id),
          ),
        ),
      ),
    );
  }
}
