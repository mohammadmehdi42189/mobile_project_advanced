import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false;
  bool busy = false;
  String? error;

  Future<void> submit() async {
    if (email.text.trim().isEmpty || password.text.length < 8 ||
        (register && name.text.trim().length < 2)) {
      setState(() => error = 'اطلاعات فرم را کامل و معتبر وارد کنید.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final state = context.read<AppState>();
      if (register) {
        await state.register(name.text, email.text, password.text);
      } else {
        await state.login(email.text, password.text);
      }
    } catch (exception) {
      setState(() => error = exception.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.movie_filter_rounded, size: 64),
                        const SizedBox(height: 12),
                        Text(
                          register ? 'ساخت حساب کاربری' : 'ورود به فیلم‌یار',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 24),
                        if (register)
                          TextField(
                            controller: name,
                            decoration: const InputDecoration(labelText: 'نام کاربری'),
                          ),
                        if (register) const SizedBox(height: 12),
                        TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'ایمیل'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: password,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'رمز عبور'),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: busy ? null : submit,
                          child: busy
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(register ? 'ثبت‌نام' : 'ورود'),
                        ),
                        TextButton(
                          onPressed: () => setState(() => register = !register),
                          child: Text(register ? 'حساب دارم' : 'ساخت حساب جدید'),
                        ),
                        if (!register)
                          TextButton(
                            onPressed: () => _resetPassword(context),
                            child: const Text('بازیابی رمز عبور'),
                          ),
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : context.read<AppState>().continueAsGuest,
                          child: const Text('ادامه به‌عنوان مهمان'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> _resetPassword(BuildContext context) async {
    final resetEmail = TextEditingController(text: email.text);
    final newPassword = TextEditingController();
    String? dialogError;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('بازیابی رمز عبور'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: resetEmail,
                decoration: const InputDecoration(labelText: 'ایمیل'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPassword,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'رمز عبور جدید'),
              ),
              if (dialogError != null) Text(dialogError!),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                if (newPassword.text.length < 8) {
                  setDialogState(() => dialogError = 'رمز عبور باید حداقل ۸ نویسه باشد.');
                  return;
                }
                try {
                  await this.context
                      .read<AppState>()
                      .resetPassword(resetEmail.text, newPassword.text);
                  if (context.mounted) Navigator.pop(context);
                } catch (exception) {
                  setDialogState(() =>
                      dialogError = exception.toString().replaceFirst('Bad state: ', ''));
                }
              },
              child: const Text('تغییر رمز'),
            ),
          ],
        ),
      ),
    );
  }
}
