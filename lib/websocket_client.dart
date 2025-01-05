import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketClient {
  WebSocketChannel? _channel;
  final String url;
  final _responseController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _eventsController = StreamController<Map<String, dynamic>>.broadcast();
  bool isConnected = false;

  WebSocketClient(this.url) {
    assert(url.startsWith('ws://') || url.startsWith('wss://'),
        'WebSocket URL must start with ws:// or wss://');
  }

  Stream<Map<String, dynamic>> get responses => _responseController.stream;
  Stream<Map<String, dynamic>> get eventsStream => _eventsController.stream;

  Future<void> connect() async {
    if (isConnected) {
      return;
    }

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      isConnected = true;

      _channel!.stream.listen(
        (message) {
          final truncatedMessage = message.toString().length > 500
              ? '${message.toString().substring(0, 500)}...'
              : message.toString();
          print('WebSocketClient: Received message: $truncatedMessage');
          _handleMessage(message);
        },
        onDone: () {
          isConnected = false;
          _channel = null;
        },
        onError: (error) {
          isConnected = false;
          _channel = null;
        },
      );
    } catch (e) {
      isConnected = false;
      rethrow;
    }
  }

  void disconnect() {
    _channel?.sink.close();
    isConnected = false;
  }

  void sendMessage(Map<String, dynamic> message) async {
    if (!isConnected) {
      try {
        await connect();
      } catch (e) {
        return;
      }
    }

    if (_channel != null) {
      print('WebSocketClient: Sending message: $message');
      _channel!.sink.add(json.encode(message));
    } else {}
  }

  // Client related methods
  void getAllClients() {
    print('WebSocketClient: Requesting all clients');
    sendMessage({
      'type': 'get_clients',
    });
  }

  void getClientByAccountNumber(String accountNumber) {
    print(
        'WebSocketClient: Requesting client with account number: $accountNumber');
    sendMessage({
      'type': 'get_client_by_account_number',
      'accountNumber': accountNumber,
    });
  }

  void getClientContacts(int clientId) {
    print('WebSocketClient: Requesting contacts for client ID: $clientId');
    sendMessage({
      'type': 'get_clientcontacts',
      'clientId': clientId,
    });
  }

  void getClientEmails(int clientId) {
    print('WebSocketClient: Requesting emails for client ID: $clientId');
    sendMessage({
      'type': 'get_clientemails',
      'clientId': clientId,
    });
  }

  void login(String username, String password) {
    print('WebSocketClient: Attempting login for user: $username');
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    sendMessage({
      'type': 'login',
      'username': username,
      'password': password,
      'requestId': requestId,
    });
  }

  // Add a method to create a filtered stream for specific message types
  Stream<Map<String, dynamic>> getFilteredStream(List<String> messageTypes) {
    return responses.where((data) => messageTypes.contains(data['type']));
  }

  // Method to handle authentication responses only
  Stream<Map<String, dynamic>> get authStream {
    return responses.where((data) =>
        data['type'] == 'login_success' ||
        data['type'] == 'login_failed' ||
        data['type'] == 'error');
  }

  // Method to handle client list responses only
  Stream<Map<String, dynamic>> get clientsStream {
    return responses
        .where((data) => data['type'] == 'clients' || data['type'] == 'client');
  }

  // Method to handle client details responses only
  Stream<Map<String, dynamic>> get clientDetailsStream {
    return responses.where((data) =>
        data['type'] == 'client_contacts' || data['type'] == 'client_emails');
  }

  // Modify the _handleMessage method to handle events
  void _handleMessage(dynamic message) {
    final data = json.decode(message);

    // Handle different event types
    switch (data['type']) {
      case 'events':
      case 'new_events':
      case 'last_x_events':
      case 'event':
      case 'unprocessed_events':
      case 'event_created':
      case 'event_updated':
        _eventsController.add(data);
        break;
      default:
        _responseController.add(data);
        break;
    }
  }

  // Add methods to request events
  void getAllEvents({int limit = 200}) {
    print('WebSocketClient: Requesting all events with limit: $limit');
    sendMessage({
      'type': 'get_events',
      'limit': limit,
    });
  }

  void getEventsByAccount(String accountNumber,
      {int page = 1, int limit = 50}) {
    if (_channel != null) {
      sendMessage({
        'type': 'get_events',
        'accountNumber': accountNumber,
        'page': page,
        'limit': limit
      });
    }
  }

  getEventsByClient(String accountNumber, {int page = 1, int limit = 50}) {
    sendMessage({
      'type': 'get_events_by_client',
      'accountNumber': accountNumber,
      'page': page,
      'limit': limit,
    });
  }

  void getComments(int eventId) {
    sendMessage({
      'type': 'get_comments',
      'eventId': eventId,
    });
  }

  void addComment(int eventId, String comment) {
    sendMessage({
      'type': 'add_event_comment',
      'eventId': eventId,
      'comment': comment,
    });
  }

  // Optional: Add convenience methods
  void getNewEventsSince(int lastEventId, {int limit = 300}) {
    print('WebSocketClient: Requesting new events since ID: $lastEventId');
    sendMessage({
      'type': 'get_new_events',
      'lastEventId': lastEventId,
      'limit': limit,
    });
  }

  // Add the event tap verification method
  void verifyEventTap(int eventId, String operator) {
    sendMessage({
      'type': 'event_tap',
      'eventId': eventId,
      'operator': operator,
    });
  }

  // Add this getter for event tap responses
  Stream<Map<String, dynamic>> get eventTapStream {
    return responses.where((data) =>
        data['type'] == 'event_tap_success' ||
        data['type'] == 'event_tap_error');
  }

  // Don't forget to close the controller in dispose
  void dispose() {
    _eventsController.close();
    _responseController.close();
  }
}
