import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../state/app_state.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final name = TextEditingController();
  final username = TextEditingController();
  final bio = TextEditingController();
  final avatarUrl = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false;
  bool busy = false;
  int sessionDays = 30;
  String? error;

  @override
  void dispose() {
    name.dispose();
    username.dispose();
    bio.dispose();
    avatarUrl.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (email.text.trim().isEmpty ||
        password.text.length < 8 ||
        (register && name.text.trim().length < 2) ||
        (register &&
            !RegExp(r'^[a-zA-Z0-9_.]{3,30}$').hasMatch(username.text.trim()))) {
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
        await state.register(
          name: name.text,
          username: username.text,
          email: email.text,
          password: password.text,
          bio: bio.text,
          avatarPath: avatarUrl.text,
          sessionDays: sessionDays,
        );
      } else {
        await state.login(
          email.text,
          password.text,
          sessionDays: sessionDays,
        );
      }
    } catch (exception) {
      setState(
        () => error = exception.toString().replaceFirst('Bad state: ', ''),
      );
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
                        decoration: const InputDecoration(
                          labelText: 'نام و نام خانوادگی',
                        ),
                      ),
                    if (register) const SizedBox(height: 12),
                    if (register)
                      TextField(
                        controller: username,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'نام کاربری',
                          helperText: '۳ تا ۳۰ نویسه: حروف انگلیسی، عدد، . و _',
                        ),
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
                    if (register) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: bio,
                        maxLength: 300,
                        decoration: const InputDecoration(
                          labelText: 'درباره من (اختیاری)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: avatarUrl,
                        keyboardType: TextInputType.url,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'آدرس تصویر پروفایل (اختیاری)',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: sessionDays,
                      decoration: const InputDecoration(
                        labelText: 'مدت فعال ماندن ورود',
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('۱ روز')),
                        DropdownMenuItem(value: 7, child: Text('۷ روز')),
                        DropdownMenuItem(value: 30, child: Text('۳۰ روز')),
                      ],
                      onChanged: busy
                          ? null
                          : (value) => setState(() => sessionDays = value ?? 30),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
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
                    if (!register && AppConfig.advancedMode)
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
    final resetToken = TextEditingController();
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
              if (AppConfig.advancedMode) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: resetToken,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'کد بازیابی'),
                ),
              ],
              if (dialogError != null) Text(dialogError!),
            ],
          ),
          actions: [
            if (AppConfig.advancedMode)
              TextButton(
                onPressed: () async {
                  try {
                    await this.context.read<AppState>().requestPasswordReset(
                      resetEmail.text,
                    );
                    setDialogState(
                      () => dialogError = 'کد بازیابی به ایمیل شما ارسال شد.',
                    );
                  } catch (exception) {
                    setDialogState(() => dialogError = exception.toString());
                  }
                },
                child: const Text('ارسال کد'),
              ),
            FilledButton(
              onPressed: () async {
                if (newPassword.text.length < 8) {
                  setDialogState(
                    () => dialogError = 'رمز عبور باید حداقل ۸ نویسه باشد.',
                  );
                  return;
                }
                try {
                  await this.context.read<AppState>().resetPassword(
                    resetEmail.text,
                    newPassword.text,
                    token: resetToken.text.trim(),
                  );
                  if (context.mounted) Navigator.pop(context);
                } catch (exception) {
                  setDialogState(
                    () => dialogError = exception.toString().replaceFirst(
                      'Bad state: ',
                      '',
                    ),
                  );
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
