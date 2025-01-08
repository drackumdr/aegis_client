import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = true; // Add this line

  // Settings state
  Map<String, dynamic> settings = {
    'serverUrl': '',
    'port': '',
    'isDarkMode': false,
    'maxRetries': 3,
    'retryDelay': 1000,
    'playAlerts': false,
    'usesSip': false,
    'sipServer': '',
    'sipPort': '',
    'sipUser': '',
    'sipPassword': ''
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

      setState(() {
        settings['serverUrl'] = prefs.getString('serverUrl') ?? '';
        settings['port'] = prefs.getString('port') ?? '';
        settings['isDarkMode'] = themeProvider.themeMode == ThemeMode.dark;
        settings['maxRetries'] = prefs.getInt('maxRetries') ?? 3;
        settings['retryDelay'] = prefs.getInt('retryDelay') ?? 1000;
        settings['playAlerts'] = prefs.getBool('playAlerts') ?? false;
        settings['usesSip'] = prefs.getString('usesSip') ?? false;
        settings['sipServer'] = prefs.getString('sipServer') ?? '';
        settings['sipPort'] = prefs.getString('sipPort') ?? '';
        settings['sipUser'] = prefs.getString('sipUser') ?? '';
        settings['sipPassword'] = prefs.getString('sipPassword') ?? '';
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('serverUrl', settings['serverUrl']);
      await prefs.setString('port', settings['port']);

      // Update theme
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      if (settings['isDarkMode']) {
        if (themeProvider.themeMode == ThemeMode.light) {
          await themeProvider.toggleTheme();
        }
      } else {
        if (themeProvider.themeMode == ThemeMode.dark) {
          await themeProvider.toggleTheme();
        }
      }

      await prefs.setInt('maxRetries', settings['maxRetries']);
      await prefs.setInt('retryDelay', settings['retryDelay']);
      await prefs.setBool('playAlerts', settings['playAlerts']);
      await prefs.setString('usesSip', settings['usesSip']);
      await prefs.setString('sipServer', settings['sipServer'] ?? '');
      await prefs.setString('sipPort', settings['sipPort'] ?? '');
      await prefs.setString('sipUser', settings['sipUser'] ?? '');
      await prefs.setString('sipPassword', settings['sipPassword'] ?? '');
      // Aquí iría la lógica para guardar la configuración

      // Restart the application
      _restartApp();
    }
  }

  void _restartApp() {
    // This method restarts the application
    if (Platform.isAndroid || Platform.isIOS) {
      SystemNavigator.pop();
    } else {
      exit(0);
    }
  }

  void _resetSettings() async {
    setState(() {
      settings = {
        'serverUrl': '',
        'port': '',
        'isDarkMode': false,
        'maxRetries': 3,
        'retryDelay': 1000,
        'playAlerts': false,
        'usesSip': false,
        'sipServer': '',
        'sipPort': '',
        'sipUser': '',
        'sipPassword': ''
      };
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('serverUrl');
    await prefs.remove('port');
    await prefs.remove('isDarkMode');
    await prefs.remove('maxRetries');
    await prefs.remove('retryDelay');
    await prefs.remove('playAlerts');
    await prefs.remove('usesSip');
    await prefs.remove('sipServer');
    await prefs.remove('sipPort');
    await prefs.remove('sipUser');
    await prefs.remove('sipPassword');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFFF8F6FF), Color(0xFFF0F7FF)],
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Server Configuration
                            _buildSection(
                              'Configuración del Servidor',
                              Column(
                                children: [
                                  _buildTextField(
                                    'Dirección del Servidor',
                                    'ej: https://miservidor.com',
                                    Icons.dns,
                                    (value) {
                                      setState(
                                          () => settings['serverUrl'] = value);
                                    },
                                    settings['serverUrl'],
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    'Puerto',
                                    'ej: 3000',
                                    null,
                                    (value) {
                                      setState(() => settings['port'] = value);
                                    },
                                    settings['port'],
                                  ),
                                ],
                              ),
                            ),

                            // Reconnection Configuration
                            _buildSection(
                              'Configuración de Reconexión',
                              Column(
                                children: [
                                  _buildTextField(
                                    'Máximos Intentos de Reconexión',
                                    'ej: 3',
                                    null,
                                    (value) {
                                      setState(() => settings['maxRetries'] =
                                          int.tryParse(value) ?? 3);
                                    },
                                    settings['maxRetries'].toString(),
                                    isNumber: true,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    'Retraso entre Intentos (ms)',
                                    'ej: 1000',
                                    null,
                                    (value) {
                                      setState(() => settings['retryDelay'] =
                                          int.tryParse(value) ?? 1000);
                                    },
                                    settings['retryDelay'].toString(),
                                    isNumber: true,
                                  ),
                                ],
                              ),
                            ),

                            // Alerts Switch
                            _buildSection(
                              'Reproducir Alertas',
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                subtitle: const Text(
                                    'Activa o desactiva las alertas de sonido'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.notifications,
                                        color: Colors.grey),
                                    Switch(
                                      value: settings['playAlerts'],
                                      onChanged: (value) {
                                        setState(() =>
                                            settings['playAlerts'] = value);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Theme Switch
                            _buildSection(
                              'Tema de la Aplicación',
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                subtitle: const Text(
                                    'Cambia entre modo claro y oscuro'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.light_mode,
                                        color: Colors.grey),
                                    Switch(
                                      value: settings['isDarkMode'],
                                      onChanged: (value) {
                                        setState(() =>
                                            settings['isDarkMode'] = value);
                                      },
                                    ),
                                    const Icon(Icons.dark_mode,
                                        color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),

                            // SIP Switch and Configuration
                            _buildSection(
                              'Usar SIP',
                              Column(
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    subtitle: const Text(
                                        'Activa o desactiva el uso de SIP'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.phone,
                                            color: Colors.grey),
                                        Switch(
                                          value: settings['usesSip'],
                                          onChanged: (value) {
                                            setState(() =>
                                                settings['usesSip'] = value);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (settings['usesSip']) ...[
                                    const SizedBox(height: 16),
                                    _buildTextField(
                                      'Servidor SIP',
                                      'ej: sip.ejemplo.com',
                                      Icons.dns,
                                      (value) {
                                        setState(() =>
                                            settings['sipServer'] = value);
                                      },
                                      settings['sipServer'] ?? '',
                                    ),
                                    const SizedBox(height: 16),
                                    _buildTextField(
                                      'Puerto SIP',
                                      'ej: 5060',
                                      null,
                                      (value) {
                                        setState(
                                            () => settings['sipPort'] = value);
                                      },
                                      settings['sipPort'] ?? '',
                                      isNumber: true,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildTextField(
                                      'Usuario SIP',
                                      'ej: usuario@dominio.com',
                                      Icons.person,
                                      (value) {
                                        setState(
                                            () => settings['sipUser'] = value);
                                      },
                                      settings['sipUser'] ?? '',
                                    ),
                                    const SizedBox(height: 16),
                                    _buildTextField(
                                      'Contraseña SIP',
                                      'Contraseña',
                                      Icons.lock,
                                      (value) {
                                        setState(() =>
                                            settings['sipPassword'] = value);
                                      },
                                      settings['sipPassword'] ?? '',
                                      isPassword: true,
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Action Buttons
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _handleSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: const Text('Guardar Configuración'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _resetSettings,
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: const Text('Restablecer Valores'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _testConnection,
                                child: const Text('Probar Conexión'),
                              ),
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
  }

  Future<void> _testConnection() async {
    final url = '${settings['serverUrl']}:${settings['port']}';
    try {
      // Simple check (example):
      final socket = await Socket.connect(
          settings['serverUrl'], int.parse(settings['port']),
          timeout: const Duration(seconds: 3));
      socket.destroy();
      _showConnectionResult('Conexión exitosa a $url');
    } catch (_) {
      _showConnectionResult('No se pudo conectar a $url');
    }
  }

  void _showConnectionResult(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        content,
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    IconData? icon,
    Function(String) onChanged,
    String value, {
    bool isNumber = false,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: value,
          obscureText: isPassword,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon) : null,
            border: const OutlineInputBorder(),
          ),
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          onChanged: onChanged,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor ingrese un valor';
            }
            if (isNumber && int.tryParse(value) == null) {
              return 'Por favor ingrese un número válido';
            }
            return null;
          },
        ),
      ],
    );
  }
}
