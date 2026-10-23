import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'store.dart';
import 'ui/glass.dart';
import 'ui/shell.dart';

class EscapeBackIntent extends Intent {
  const EscapeBackIntent();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT');
  final state = AppState();
  await state.load();
  runApp(ChangeNotifierProvider.value(
    value: state,
    child: const MediaArchiveApp(),
  ));
}

class MediaArchiveApp extends StatelessWidget {
  const MediaArchiveApp({super.key});

  static final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final darkTheme = context.watch<AppState>().darkTheme;
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Media Archive',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(darkTheme: darkTheme),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): EscapeBackIntent(),
      },
      actions: <Type, Action<Intent>>{
        EscapeBackIntent: CallbackAction<EscapeBackIntent>(
          onInvoke: (_) {
            _navigatorKey.currentState?.maybePop();
            return null;
          },
        ),
      },
      builder: (context, child) =>
          GlassBackground(child: child ?? const SizedBox()),
      home: const Shell(),
    );
  }
}
