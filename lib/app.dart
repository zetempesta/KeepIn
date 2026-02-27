import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/di/providers.dart';
import 'core/theme/app_theme.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/pages/notes_board_page.dart';

class KeepInApp extends ConsumerWidget {
  const KeepInApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authSession = ref.watch(authSessionProvider);

    return MaterialApp(
      title: 'KeepIn',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: authSession == null ? const LoginPage() : const NotesBoardPage(),
    );
  }
}
