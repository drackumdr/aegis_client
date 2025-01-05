import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../websocket_client.dart';
import 'dart:async';
import 'alarm_monitoring_ui.dart';
import 'config_page.dart';

class LoginPage extends StatefulWidget {
  final WebSocketClient? webSocketClient;

  const LoginPage({super.key, this.webSocketClient});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late WebSocketClient _webSocketClient;
  final _formKey = GlobalKey<FormState>();
  bool _rememberMe = false;
  bool _isLoading = false;
  StreamSubscription? _authSubscription;

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeWebSocket();
    _loadSavedCredentials();
  }

  Future<void> _initializeWebSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString('serverUrl');
    final port = prefs.getString('port');

    if (serverUrl == null || port == null) {
      // Manejar error de configuración
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Configuración incompleta')),
        );
      }
      return;
    }

    final wsUrl = 'ws://$serverUrl:$port';
    _webSocketClient = widget.webSocketClient ?? WebSocketClient(wsUrl);

    try {
      await _webSocketClient.connect();
      _setupAuthListener();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de conexión: $e')),
        );
      }
    }
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('savedUsername');
    final savedPassword = prefs.getString('savedPassword');
    final rememberMe = prefs.getBool('rememberMe') ?? false;

    if (savedUsername != null && savedPassword != null && rememberMe) {
      setState(() {
        _usernameController.text = savedUsername;
        _passwordController.text = savedPassword;
        _rememberMe = true;
      });

      // Auto login
      if (mounted) {
        _handleSubmit();
      }
    }
  }

  void _setupAuthListener() {
    _authSubscription = _webSocketClient.authStream.listen(
      (data) {
        if (!mounted) return;

        setState(() => _isLoading = false);

        switch (data['type']) {
          case 'login_success':
            final user = data['user'];
            _handleLoginSuccess(user);
            break;
          case 'login_failed':
            _handleLoginError(data['message'] ?? 'Login failed');
            break;
          case 'error':
            _handleLoginError(data['message'] ?? 'Unknown error');
            break;
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isLoading = false);
          _handleLoginError('Connection error: $error');
        }
      },
    );
  }

  void _handleLoginSuccess(Map<String, dynamic> user) {
    if (_rememberMe) {
      _saveCredentials();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => AlarmMonitoringUI(
          webSocketClient: _webSocketClient,
          currentUser: user,
        ),
      ),
    );
  }

  void _handleLoginError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('savedUsername', _usernameController.text);
      await prefs.setString('savedPassword', _passwordController.text);
      await prefs.setBool('rememberMe', true);
    } else {
      // Clear saved credentials if remember me is disabled
      await prefs.remove('savedUsername');
      await prefs.remove('savedPassword');
      await prefs.remove('rememberMe');
    }
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    _webSocketClient.login(
      _usernameController.text,
      _passwordController.text,
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: Theme.of(context).brightness == Brightness.dark
                ? [
                    const Color(0xFF1F2937), // dark gray
                    const Color(0xFF111827), // darker gray
                  ]
                : [
                    const Color(0xFFF8F6FF), // light purple
                    const Color(0xFFF0F7FF), // light blue
                  ],
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Bienvenido',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937), // text-gray-800
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ingresa tus credenciales para continuar',
                        style: TextStyle(
                          color: Color(0xFF4B5563), // text-gray-600
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Username field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nombre de usuario',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.person_outline),
                              hintText: 'Ingresa tu usuario',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor ingresa tu usuario';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Password field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Contraseña',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.lock_outline),
                              hintText: 'Ingresa tu contraseña',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor ingresa tu contraseña';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Remember me and Forgot password row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value!;
                                  });
                                },
                              ),
                              const Text(
                                'Recordarme',
                                style: TextStyle(
                                  color: Color(0xFF4B5563), // text-gray-600
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () {
                              // Handle forgot password
                            },
                            child: const Text('¿Olvidaste tu contraseña?'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Submit button
                      _buildLoginButton(),
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

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Iniciar sesión',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }
}
