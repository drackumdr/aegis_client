import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async'; // Add this import
import '../websocket_client.dart';
import 'package:url_launcher/url_launcher.dart'; // Add this import
import 'package:permission_handler/permission_handler.dart';

import 'event_history_screen.dart'; // Add this import

class ClientDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> client;
  final WebSocketClient webSocketClient;

  const ClientDetailsScreen({
    super.key,
    required this.client,
    required this.webSocketClient,
  });

  @override
  State<ClientDetailsScreen> createState() => _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends State<ClientDetailsScreen> {
  List<dynamic> _clientContacts = [];
  List<dynamic> _clientEmails = [];
  StreamSubscription? _subscription; // Add this line

  @override
  void initState() {
    super.initState();
    _setupWebSocket();
    _loadClientData();
  }

  void _setupWebSocket() {
    _subscription = widget.webSocketClient.clientDetailsStream.listen(
      (data) {
        if (!mounted) return; // Add this check
        setState(() {
          switch (data['type']) {
            case 'client_contacts':
              _clientContacts = data['contacts'];
              break;
            case 'client_emails':
              _clientEmails = data['emails'];
              break;
          }
        });
      },
    );
  }

  void _loadClientData() {
    widget.webSocketClient.getClientContacts(widget.client['id']);
    widget.webSocketClient.getClientEmails(widget.client['id']);
  }

  @override
  void dispose() {
    _subscription?.cancel(); // Cancel subscription
    super.dispose();
  }

  void _launchDialer(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleanNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Número de teléfono inválido')),
      );
      return;
    }

    if (Platform.isLinux) {
      // Direct URL launch for Linux without permission check
      final Uri launchUri = Uri(
        scheme: 'tel',
        path: cleanNumber,
      );
      try {
        if (!await launchUrl(launchUri, mode: LaunchMode.externalApplication)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se puede llamar a $cleanNumber')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al intentar llamar: $e')),
        );
      }
      return;
    }

    // Permission check for other platforms
    if (await Permission.phone.isGranted || !Platform.isAndroid) {
      final Uri launchUri = Uri(
        scheme: 'tel',
        path: cleanNumber,
      );
      try {
        if (!await launchUrl(launchUri, mode: LaunchMode.externalApplication)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se puede llamar a $cleanNumber')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al intentar llamar: $e')),
        );
      }
    } else {
      // Request permission if not granted
      var status = await Permission.phone.request();
      if (status.isGranted) {
        _launchDialer(phoneNumber); // Retry launching after permission
      } else {
        // Handle the case when permission is denied
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso para hacer llamadas denegado')),
        );
      }
    }
  }

  Future<void> _launchMaps(String query, {bool isCoordinate = false}) async {
    String url;
    if (isCoordinate) {
      // For GPS coordinates
      url = 'https://www.google.com/maps/search/?api=1&query=$query';
    } else {
      // For addresses
      final encodedQuery = Uri.encodeComponent(query);
      url = 'https://www.google.com/maps/search/?api=1&query=$encodedQuery';
    }

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir Google Maps')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.client['businessName'] ?? 'Detalles del Cliente'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 4.0 : 8.0), // Reduced padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              margin: EdgeInsets.zero, // Remove margin
              elevation: 1, // Reduce elevation
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'No. Cuenta: ${widget.client['accountNumber']}',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.client['isOpenAtThisTime'] != null)
                          _buildStatusChip(widget.client['isOpenAtThisTime']),
                      ],
                    ),
                    if (widget.client['accountGroup']?.isNotEmpty ?? false)
                      Text(
                        'Grupo: ${widget.client['accountGroup']}',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    Text(
                      widget.client['managerName'] ?? 'N/A',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                    ),
                    // Add more info here as needed (address, city, state, etc.)
                    GestureDetector(
                      onTap: () {
                        final address = [
                          widget.client['address'],
                          widget.client['city'],
                          widget.client['state'],
                          widget.client['country'],
                        ].where((e) => e != null && e.isNotEmpty).join(', ');
                        _launchMaps(address);
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.client['address'] ?? 'N/A',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16,
                              ),
                            ),
                          ),
                          const Icon(Icons.map,
                              size: 20, color: Color(0xFF3498DB)),
                        ],
                      ),
                    ),
                    //reference
                    Text(
                      widget.client['references'] ?? 'N/A',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                    ),
                    Text(
                      widget.client['city'] ?? 'N/A',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                    ),
                    Text(
                      widget.client['state'] ?? 'N/A',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                    ),
                    Text(
                      widget.client['postalCode'] ?? 'N/A',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                    ),
                    Text(
                      widget.client['country'] ?? 'N/A',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          _launchDialer(widget.client['phoneNumber'] ?? ''),
                      child: Card(
                        margin: EdgeInsets.zero,
                        elevation: 1,
                        child: Padding(
                          padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                          child: Row(
                            children: [
                              const Icon(Icons.phone, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                widget.client['phoneNumber'] ?? 'N/A',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const Divider(height: 16),

                    if (widget.client['comments1']?.trim().isNotEmpty ?? false)
                      GestureDetector(
                        onTap: () => _launchMaps(
                          widget.client['comments1']?.trim() ?? '',
                          isCoordinate: true,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildSimpleCommentSection(
                                'Ubicación GPS',
                                widget.client['comments1'],
                              ),
                            ),
                            const Icon(Icons.location_on,
                                size: 20, color: Color(0xFF3498DB)),
                          ],
                        ),
                      ),
                    if (widget.client['comments2']?.trim().isNotEmpty ?? false)
                      _buildSimpleCommentSection(
                          'Comentarios', widget.client['comments2']),
                    if (widget.client['comments3']?.trim().isNotEmpty ?? false)
                      _buildSimpleCommentSection('Comentarios Adicionales',
                          widget.client['comments3']),
                    const SizedBox(height: 8),
                    _buildHistoryButton(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Contactos y Correos en tarjetas más compactas
            if (_clientContacts.isNotEmpty)
              _buildCompactSection('Contactos', _clientContacts),

            if (_clientEmails.isNotEmpty)
              _buildCompactSection('Correos', _clientEmails),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactSection(String title, List<dynamic> items) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              return title == 'Contactos'
                  ? _buildCompactContactTile(items[index])
                  : _buildCompactEmailTile(items[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompactContactTile(dynamic contact) {
    return ListTile(
      dense: true,
      onTap: () => _launchDialer(contact['phone'] ?? ''),
      leading: const Icon(Icons.person, color: Color(0xFF3498DB), size: 20),
      title: Text(contact['name'] ?? 'N/A',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      subtitle:
          Text(contact['phone'] ?? 'N/A', style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.phone, size: 18, color: Color(0xFF3498DB)),
    );
  }

  Widget _buildCompactEmailTile(dynamic email) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.email, color: Color(0xFF3498DB), size: 20),
      title: Text(email['email'] ?? 'N/A',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      subtitle: Wrap(
        spacing: 4,
        children: [
          if (email['emailOC'] == true) _buildMiniTag('OC'),
          if (email['emailAlarm'] == true) _buildMiniTag('Alarma'),
          if (email['emailFailure'] == true) _buildMiniTag('Falla'),
        ],
      ),
    );
  }

  Widget _buildMiniTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, color: Color(0xFF2E7D32)),
      ),
    );
  }

  Widget _buildSimpleCommentSection(String title, String comment) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF95A5A6),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            comment,
            style: const TextStyle(fontSize: 13),
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

  Widget _buildHistoryButton() {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => HistoryPage(
            accountNumber: widget.client['accountNumber'],
            webSocketClient: widget.webSocketClient,
            businessName: widget.client['businessName'],
          ),
        ));
      },
      icon: const Icon(Icons.history),
      label: const Text('Historial de Eventos'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF3498DB),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
