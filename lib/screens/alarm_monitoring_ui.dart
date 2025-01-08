import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../theme/app_colors.dart';
import '../websocket_client.dart';
import 'audio.dart';
import 'clients_list_screen.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'login_page.dart'; // Add this import
import 'client_details_screen.dart'; // Add this import

class AlarmMonitoringUI extends StatefulWidget {
  final WebSocketClient webSocketClient;
  final Map<String, dynamic>? currentUser;

  const AlarmMonitoringUI({
    super.key,
    required this.webSocketClient,
    this.currentUser,
  });

  @override
  State<AlarmMonitoringUI> createState() => _AlarmMonitoringUIState();
}

class _AlarmMonitoringUIState extends State<AlarmMonitoringUI> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _events = [];
  StreamSubscription? _subscription;
// Add this property
  Timer? _periodicTimer;
  final ScrollController _scrollController = ScrollController();
  static const int _maxEvents = 200;

  // Add new state variables
  String _searchTerm = '';
  final String _statusFilter = 'todos';
  bool _showEventList = true;
  final bool _isLoading = false;
  Map<String, dynamic>? _selectedEvent;
  Map<String, dynamic>? _clientData;

  // Add this property
  final AudioManager _audioManager = AudioManager();

  @override
  void initState() {
    super.initState();
    _setupWebSocket();
    _initialLoad();
    _setupPeriodicUpdate();
    _setupSearchListener(); // Add this line
  }

  void _initialLoad() {
    if (widget.webSocketClient.isConnected) {
      widget.webSocketClient
          .sendMessage({'type': 'get_events', 'page': 1, 'limit': _maxEvents});
    }
  }

  void _setupPeriodicUpdate() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (widget.webSocketClient.isConnected) {
        widget.webSocketClient.sendMessage(
            {'type': 'get_events', 'page': 1, 'limit': _maxEvents});
      }
    });
  }

  void _setupWebSocket() {
    _subscription = widget.webSocketClient.eventsStream.listen(
      (data) {
        if (!mounted) return;
        setState(() {
          if (data['type'] == 'events') {
            final newEvents = data['events'] as List;
            _events = newEvents.take(_maxEvents).toList();
            if (newEvents.isNotEmpty) {}
            _updateCounters();
          } else if (data['type'] == 'new_events') {
            final newEvents = data['events'] as List;
            if (newEvents.isNotEmpty) {
              // Merge new events with existing ones and keep only the latest 200
              _events = [...newEvents, ..._events].take(_maxEvents).toList();
              _updateCounters();
            }
          } else if (data['type'] == 'event_created') {
            final newEvent = data['event'];
            print('Event created data: $data');
            // Insertar el evento al inicio de la lista
            setState(() {
              _events.insert(0, newEvent);
            });
          } else if (data['type'] == 'event_updated') {
            final updatedEvent = data['event'];
            print('Event updated data: $data');
            final index =
                _events.indexWhere((e) => e['id'] == updatedEvent['id']);
            if (index != -1) {
              _events[index] = updatedEvent;
            } else {
              _events.insert(0, updatedEvent);
            }
            _updateCounters();
          }
        });
      },
    );
  }

  void _setupSearchListener() {
    _searchController.addListener(() {
      setState(() {
        _searchTerm = _searchController.text;
      });
    });
  }

  void _updateCounters() {
    if (_events.isNotEmpty) {
      bool hasUnprocessedEvents = _events.any((e) => !e['isProcessed']);
      if (hasUnprocessedEvents && !_audioManager.isPaused) {
        _audioManager.playAlertSound();
      }
    }
  }

  Future<void> _processEvent(Map<String, dynamic> event) async {
    // Verify if event can be processed
    widget.webSocketClient
        .verifyEventTap(event['id'], widget.currentUser?['name'] ?? 'N/A');

    try {
      final response = await widget.webSocketClient.eventTapStream.first;

      if (response['type'] == 'event_tap_error') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'El evento está siendo procesado por ${response['operator']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Continue with comment dialog if event can be processed
      String? comment = await _showCommentDialog();

      if (comment == null) return; // User cancelled the dialog

      if (comment.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Debe ingresar un comentario para procesar el evento'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Send the comment and process the event
      widget.webSocketClient.sendMessage({
        'type': 'add_comment',
        'eventId': event['id'],
        'comment': comment,
        'commentUser': widget.currentUser?['name'] ?? 'Desconocido',
      });

      widget.webSocketClient
          .sendMessage({'type': 'process_event', 'eventId': event['id']});

      widget.webSocketClient
          .sendMessage({'type': 'get_events', 'page': 1, 'limit': _maxEvents});

      //libera el usuario del evento
      widget.webSocketClient.sendMessage({
        'type': 'release_event',
        'eventId': event['id'],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evento procesado correctamente'),
            backgroundColor: Colors.green,
          ),
        );

        // Check for remaining unprocessed events after processing
        if (_events.any((e) => !e['isProcessed'])) {
          _audioManager.isPaused = false;
          _audioManager.playAlertSound();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al procesar el evento'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _showCommentDialog() async {
    final TextEditingController commentController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false, // User must tap button to close dialog
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Agregar comentario'),
          content: TextField(
            controller: commentController,
            decoration: const InputDecoration(
              hintText: 'Ingrese un comentario...',
              errorText: null,
            ),
            autofocus: true,
            maxLines: 3,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final comment = commentController.text.trim();
                if (comment.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('El comentario no puede estar vacío'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop(comment);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  String _formatDateTime(int milliseconds) {
    final dt = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute}:${dt.second}';
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return Colors.red;
      case 5:
        return Colors.orange;
      case 10:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getEventBackgroundColor(Map<String, dynamic> event) {
    if (!event['isProcessed']) {
      return Theme.of(context).brightness == Brightness.dark
          ? AppColors.pendingDark
          : AppColors.pendingLight;
    }
    return Colors.transparent;
  }

  Future<void> _handleEventSelect(Map<String, dynamic> event) async {
    // First, verify if we can select this event
    widget.webSocketClient
        .verifyEventTap(event['id'], widget.currentUser?['name'] ?? 'N/A');

    try {
      final response = await widget.webSocketClient.eventTapStream.first;

      if (response['type'] == 'event_tap_success' &&
          response['isBeingProcessed'] == true &&
          response['currentOperator'] != null &&
          response['currentOperator'] != widget.currentUser?['name']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'El evento está siendo procesado por ${response['currentOperator']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!event['isProcessed']) {
        _audioManager.pauseSound(const Duration(minutes: 1));
      }

      setState(() {
        _selectedEvent = event;
        _clientData = null;
        if (MediaQuery.of(context).size.width <= 600) {
          _showEventList = false;
        }
      });

      // Continue with client data fetch...
      try {
        // Fetch client data by account number
        widget.webSocketClient.sendMessage({
          'type': 'get_client_by_account_number',
          'accountNumber': event['accountNumber'],
        });

        // Setup listener for client data
        await for (final data in widget.webSocketClient.clientsStream) {
          if (data['type'] == 'client') {
            final clientData = data['client'];
            // Fetch contacts and emails
            widget.webSocketClient.sendMessage({
              'type': 'get_clientcontacts',
              'clientId': clientData['id'],
            });
            widget.webSocketClient.sendMessage({
              'type': 'get_clientemails',
              'clientId': clientData['id'],
            });

            // Wait for contacts and emails
            Map<String, dynamic> fullClientData = Map.from(clientData);
            List<dynamic> contacts = [];
            List<dynamic> emails = [];

            await for (final details
                in widget.webSocketClient.clientDetailsStream) {
              if (details['type'] == 'client_contacts') {
                contacts = details['contacts'];
              } else if (details['type'] == 'client_emails') {
                emails = details['emails'];
                // Once we have all data, update the state
                if (mounted) {
                  setState(() {
                    fullClientData['contacts'] = contacts;
                    fullClientData['emails'] = emails;
                    _clientData = fullClientData;
                  });
                }
                break;
              }
            }
            break;
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading client data: $e')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al verificar el evento: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final signalCounts = {
      'total': _events.length,
      'pending': _events.where((e) => !e['isProcessed']).length,
      'critical':
          _events.where((e) => e['priority'] <= 2 && !e['isProcessed']).length,
    };

    final filteredEvents = _events.where((e) {
      final matchesSearch = e['accountName']
              .toString()
              .toLowerCase()
              .contains(_searchTerm.toLowerCase()) ||
          e['accountNumber']
              .toString()
              .toLowerCase()
              .contains(_searchTerm.toLowerCase()) ||
          e['eventType']
              .toString()
              .toLowerCase()
              .contains(_searchTerm.toLowerCase()) ||
          (e['signalInfo'] ?? '')
              .toString()
              .toLowerCase()
              .contains(_searchTerm.toLowerCase());

      final matchesStatus = _statusFilter == 'todos' ||
          (_statusFilter == 'pendientes' && !e['isProcessed']) ||
          (_statusFilter == 'críticos' &&
              e['priority'] <= 2 &&
              !e['isProcessed']);

      return matchesSearch && matchesStatus;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth <= 600;
        return Scaffold(
          appBar: _buildHeader(signalCounts, isMobile),
          body: SafeArea(
            child: Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: isMobile
                      ? _buildMobileLayout(filteredEvents, signalCounts)
                      : _buildDesktopLayout(filteredEvents, signalCounts),
                ),
              ],
            ),
          ),
          bottomNavigationBar: isMobile ? _buildMobileNavBar() : null,
        );
      },
    );
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      margin: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          hintText: 'Buscar por cuenta, nombre, tipo de evento...',
          prefixIcon: Icon(Icons.search),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildMobileNavBar() {
    return BottomNavigationBar(
      currentIndex: _showEventList ? 0 : 1,
      onTap: (index) {
        setState(() {
          _showEventList = index == 0;
        });
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(LucideIcons.list),
          label: 'Eventos',
        ),
        BottomNavigationBarItem(
          icon: Icon(LucideIcons.info),
          label: 'Detalles',
        ),
      ],
    );
  }

  // Add new methods for layout building
  PreferredSizeWidget _buildHeader(
      Map<String, int> signalCounts, bool isMobile) {
    return AppBar(
      title: Row(
        children: [
          Icon(LucideIcons.alertCircle, color: Colors.blue[500]),
          const SizedBox(width: 8),
          if (!isMobile) const Text('Sistema de Monitoreo de Alarmas'),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.business),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ClientsListScreen(
                  webSocketClient: widget.webSocketClient,
                  currentUser: widget.currentUser,
                ),
              ),
            );
          },
        ),
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
    );
  }

  Widget _buildMobileLayout(
      List<dynamic> filteredEvents, Map<String, int> signalCounts) {
    return _showEventList
        ? Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _buildSignalCounters(signalCounts),
                  ),
                ),
              ),
              Expanded(
                child: _buildEventsList(filteredEvents),
              ),
            ],
          )
        : _buildMainContent();
  }

  Widget _buildDesktopLayout(
      List<dynamic> filteredEvents, Map<String, int> signalCounts) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: _buildSidebar(filteredEvents, signalCounts),
        ),
        Expanded(
          flex: 1,
          child: _buildMainContent(),
        ),
      ],
    );
  }

  Widget _buildSidebar(
      List<dynamic> filteredEvents, Map<String, int> signalCounts) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _buildSignalCounters(signalCounts),
          ),
        ),
        Expanded(
          child: _buildEventsList(filteredEvents),
        ),
      ],
    );
  }

  List<Widget> _buildSignalCounters(Map<String, int> signalCounts) {
    return [
      _buildCounter('Total', signalCounts['total'] ?? 0, Colors.blue),
      _buildCounter('Pendientes', signalCounts['pending'] ?? 0, Colors.orange),
      _buildCounter('Críticas', signalCounts['critical'] ?? 0, Colors.red),
    ];
  }

  Widget _buildMainContent() {
    if (_selectedEvent == null) {
      return const Center(
        child: Text('Selecciona un evento para ver los detalles'),
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                (_selectedEvent!['isProcessed'] ? Colors.blue : Colors.orange)
                    .withAlpha((0.1 * 255).toInt()),
            border: Border(
              left: BorderSide(
                color: _selectedEvent!['isProcessed']
                    ? Colors.blue
                    : Colors.orange,
                width: 4,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedEvent!['signalInfo'],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text('Codigo de señal: ${_selectedEvent!['signalCode']}'),
                    Text(
                        'Recibido: ${_formatDateTime(_selectedEvent!['eventDateTime'])}'),
                  ],
                ),
              ),
              if (!_selectedEvent!['isProcessed'])
                ElevatedButton.icon(
                  onPressed: () => _processEvent(_selectedEvent!),
                  icon: const Icon(LucideIcons.checkCircle),
                  label: const Text('Procesar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),

        // Client Details
        if (_clientData != null)
          Expanded(
            child: ClientDetailsScreen(
              client: _clientData!,
              webSocketClient: widget.webSocketClient,
            ),
          ),
      ],
    );
  }

  Widget _buildCounter(String label, int count, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 40 : 25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList(List<dynamic> filteredEvents) {
    return ListView.builder(
      itemCount: filteredEvents.length,
      itemBuilder: (context, index) {
        // Convert the dynamic Map to Map<String, dynamic>
        final Map<String, dynamic> event =
            Map<String, dynamic>.from(filteredEvents[index]);
        return _buildEventCard(event);
      },
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    // Add null checks for the event properties
    final int priority = event['priority'] as int? ?? 0;
    final bool isProcessed = event['isProcessed'] as bool? ?? false;
    final String accountNumber = event['accountNumber']?.toString() ?? '';
    final String accountName = event['accountName']?.toString() ?? 'Sin nombre';
    final String signalInfo = event['signalInfo']?.toString() ?? 'N/A';
    final int eventDateTime = event['eventDateTime'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 1,
      child: InkWell(
        onTap: () => _handleEventSelect(event),
        child: Container(
          decoration: BoxDecoration(
            color: _getEventBackgroundColor({'isProcessed': isProcessed}),
            border: Border(
              left: BorderSide(
                color: _getPriorityColor(priority),
                width: 4,
              ),
            ),
          ),
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
                        'Cuenta: $accountNumber',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildStatusChip(isProcessed),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  accountName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  signalInfo,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(LucideIcons.clock, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      _formatDateTime(eventDateTime),
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
      ),
    );
  }

  Widget _buildStatusChip(bool isProcessed) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isProcessed ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isProcessed ? 'PROCESADA' : 'PENDIENTE',
        style: TextStyle(
          color:
              isProcessed ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioManager.dispose();
    _scrollController.dispose();
    _periodicTimer?.cancel();
    _subscription?.cancel();
    _searchController.dispose(); // Update this line
    super.dispose();
  }
}
