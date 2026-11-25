import 'package:material_ui/material_ui.dart';

import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/history/history_screen.dart';
import 'features/tools/tools_screen.dart';
import 'features/voice/voice_screen.dart';
import 'theme/app_theme.dart';

abstract final class Routes {
  static const login = '/login';
  static const register = '/register';
  static const chat = '/chat';
  static const voice = '/voice';
  static const tools = '/tools';
  static const history = '/history';
}

class LumiApp extends StatelessWidget {
  const LumiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lumi',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      themeMode: ThemeMode.dark,
      initialRoute: Routes.login,
      routes: {
        Routes.login: (_) => const LoginScreen(),
        Routes.register: (_) => const RegisterScreen(),
        Routes.chat: (_) => const ChatScreen(),
        Routes.voice: (_) => const VoiceScreen(),
        Routes.tools: (_) => const ToolsScreen(),
        Routes.history: (_) => const HistoryScreen(),
      },
    );
  }
}
