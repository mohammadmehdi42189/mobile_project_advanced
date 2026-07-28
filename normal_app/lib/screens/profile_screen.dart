import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('پروفایل')),
        body: Center(
          child: FilledButton.icon(
            onPressed: state.exitGuest,
            icon: const Icon(Icons.login),
            label: const Text('برای ثبت فعالیت وارد شوید'),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('پروفایل'),
        actions: [
          IconButton(onPressed: state.logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const CircleAvatar(radius: 46, child: Icon(Icons.person, size: 50)),
          const SizedBox(height: 12),
          Text(user.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
          Text(user.email, textAlign: TextAlign.center),
          if (user.bio.isNotEmpty) Text(user.bio, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _stat(context, 'فیلم مشاهده‌شده', '${state.completedMovies}'),
              _stat(context, 'سریال مشاهده‌شده', '${state.completedSeries}'),
              _stat(
                context,
                'قسمت مشاهده‌شده',
                '${state.watchedEpisodes.values.fold<int>(0, (sum, item) => sum + item)}',
              ),
              _stat(context, 'میانگین امتیاز', state.averageRating.toStringAsFixed(1)),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _edit(context, state),
            icon: const Icon(Icons.edit),
            label: const Text('ویرایش پروفایل'),
          ),
          const SizedBox(height: 16),
          Text('فهرست‌های شخصی', style: Theme.of(context).textTheme.titleLarge),
          ...state.customLists.entries.map(
            (entry) => ListTile(
              leading: const Icon(Icons.playlist_play),
              title: Text(entry.key),
              trailing: Text('${entry.value.length} اثر'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('ساخت فهرست جدید'),
            onTap: () => _createList(context, state),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String title, String value) => Card(
        child: SizedBox(
          width: 150,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(value, style: Theme.of(context).textTheme.headlineMedium),
                Text(title, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );

  Future<void> _edit(BuildContext context, AppState state) async {
    final name = TextEditingController(text: state.user!.name);
    final bio = TextEditingController(text: state.user!.bio);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ویرایش پروفایل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'نام')),
            TextField(controller: bio, decoration: const InputDecoration(labelText: 'درباره من')),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              state.updateProfile(name.text, bio.text);
              Navigator.pop(context);
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  Future<void> _createList(BuildContext context, AppState state) async {
    final name = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فهرست جدید'),
        content: TextField(controller: name, decoration: const InputDecoration(labelText: 'نام')),
        actions: [
          FilledButton(
            onPressed: () {
              if (name.text.trim().isNotEmpty) state.createList(name.text);
              Navigator.pop(context);
            },
            child: const Text('ساخت'),
          ),
        ],
      ),
    );
  }
}
