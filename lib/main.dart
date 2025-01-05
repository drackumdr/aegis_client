import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'screens/config_page.dart';
import 'screens/login_page.dart';
import 'theme/theme_provider.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _handlePermissions();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

Future<void> _handlePermissions() async {
  try {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
      if (!status.isGranted) {}
    }
    // ignore: empty_catches
  } catch (e) {}
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Aegis Client',
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const InitialRoutePage(),
        );
      },
    );
  }
}

class InitialRoutePage extends StatefulWidget {
  const InitialRoutePage({super.key});

  @override
  _InitialRoutePageState createState() => _InitialRoutePageState();
}

class _InitialRoutePageState extends State<InitialRoutePage> {
  @override
  void initState() {
    super.initState();
    _handlePermissions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkConfiguration();
  }

  Future<void> _checkConfiguration() async {
    await _requestPermissions();

    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString('serverUrl');
    final port = prefs.getString('port');

    if (serverUrl == null ||
        serverUrl.isEmpty ||
        port == null ||
        port.isEmpty) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const SettingsPage()),
        );
      }
    } else {
      try {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Error de conexión. Verifique la configuración')),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const SettingsPage()),
          );
        }
      }
    }
  }

  Future<void> _requestPermissions() async {
    if (Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS) {
      var status = await Permission.phone.status;
      if (!status.isGranted) {
        status = await Permission.phone.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Permiso para hacer llamadas denegado')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
