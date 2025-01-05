import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; // Add this import
import '../websocket_client.dart';
import 'client_details_screen.dart';
import 'login_page.dart';
import '../theme/app_colors.dart';

class ClientsListScreen extends StatefulWidget {
  final WebSocketClient webSocketClient;
  final Map<String, dynamic>? currentUser;

  const ClientsListScreen({
    super.key,
    required this.webSocketClient,
    this.currentUser,
  });

  @override
  State<ClientsListScreen> createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends State<ClientsListScreen> {
  final TextEditingController _searchText = TextEditingController();
  List<dynamic> _clients = [];
  List<dynamic> _filteredClients = []; // Add this line
  StreamSubscription? _subscription;
  String? _selectedGroup;
  List<String> _uniqueGroups = [];

  @override
  void initState() {
    super.initState();
    _ensureConnection();
    _searchText.addListener(_filterClients); // Add this line
  }

  Future<void> _ensureConnection() async {
    if (!widget.webSocketClient.isConnected) {
      try {
        await widget.webSocketClient.connect();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connection error: $e')),
          );
        }
      }
    }
    _setupWebSocket();
    widget.webSocketClient
        .getAllClients(); // Solicitar clientes una vez conectado
  }

  void _setupWebSocket() {
    _subscription = widget.webSocketClient.clientsStream.listen(
      (data) {
        if (!mounted) return;
        switch (data['type']) {
          case 'clients':
            setState(() {
              _clients = data['clients'];
              _updateUniqueGroups(); // Add this line
              _filterClients(); // Add this line
            });
            break;
          case 'client':
            if (mounted) {
              _navigateToClientDetails(data['client']);
            }
            break;
        }
      },
    );
  }

  void _updateUniqueGroups() {
    final groups = _clients
        .map((client) => client['accountGroup']?.toString() ?? '')
        .where((group) => group.isNotEmpty)
        .toSet()
        .toList();
    groups.sort();
    setState(() {
      _uniqueGroups = groups;
    });
  }

  void _filterClients() {
    final searchTerm = _searchText.text.toLowerCase();
    setState(() {
      _filteredClients = _clients.where((client) {
        final matchesSearch = client['accountNumber']
                    ?.toString()
                    .toLowerCase()
                    .contains(searchTerm) ==
                true ||
            client['businessName']
                    ?.toString()
                    .toLowerCase()
                    .contains(searchTerm) ==
                true ||
            client['address']?.toString().toLowerCase().contains(searchTerm) ==
                true ||
            client['managerName']
                    ?.toString()
                    .toLowerCase()
                    .contains(searchTerm) ==
                true ||
            client['phoneNumber']
                    ?.toString()
                    .toLowerCase()
                    .contains(searchTerm) ==
                true;

        final matchesGroup = _selectedGroup == null ||
            (client['accountGroup']?.toString() ?? '') == _selectedGroup;

        return matchesSearch && matchesGroup;
      }).toList();
    });
  }

  void _navigateToClientDetails(Map<String, dynamic> client) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClientDetailsScreen(
          client: client,
          webSocketClient: widget.webSocketClient,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [
          if (widget.currentUser != null)
            PopupMenuButton(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Chip(
                  label: Text(widget.currentUser!['name']),
                  avatar: const Icon(Icons.person),
                ),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: const Text('Cerrar Sesión'),
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('savedUsername');
                    await prefs.remove('savedPassword');
                    await prefs.remove('rememberMe');

                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (context) => const LoginPage()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Card(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            margin: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchText,
                  decoration: const InputDecoration(
                    hintText: 'Buscar por cuenta, nombre, dirección...',
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                if (_uniqueGroups.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: DropdownButtonFormField<String?>(
                      value: _selectedGroup,
                      decoration: const InputDecoration(
                        labelText: 'Filtrar por Grupo',
                        border: InputBorder.none,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Todos los grupos'),
                        ),
                        ..._uniqueGroups
                            .map((group) => DropdownMenuItem<String>(
                                  value: group,
                                  child: Text(group),
                                )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedGroup = value;
                          _filterClients();
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              '${_filteredClients.length} de ${_clients.length} clientes',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredClients.length,
              itemBuilder: (context, index) {
                final client = _filteredClients[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  elevation: 1,
                  child: InkWell(
                    onTap: () => _navigateToClientDetails(client),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'No. Cuenta: ${client['accountNumber'] ?? 'N/A'}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (client['isOpenAtThisTime'] != null)
                                _buildStatusChip(client['isOpenAtThisTime']),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            client['businessName'] ?? 'Sin nombre',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            client['managerName'] ?? 'N/A',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            client['address'] ?? 'N/A',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (client['references'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                client['references'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.phone,
                                  size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Text(
                                client['phoneNumber'] ?? 'N/A',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(bool? isOpen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isOpen ?? false)
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        (isOpen ?? false) ? 'ABIERTO' : 'CERRADO',
        style: TextStyle(
          color: (isOpen ?? false)
              ? const Color(0xFF2E7D32)
              : const Color(0xFFC62828),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchText.dispose();
    super.dispose();
  }
}
