import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/comment.dart';
import '../models/event.dart';
import '../websocket_client.dart';
import '../theme/app_colors.dart';

class HistoryPage extends StatelessWidget {
  final String accountNumber;
  final String businessName;
  final WebSocketClient webSocketClient;

  const HistoryPage({
    super.key,
    required this.accountNumber,
    required this.businessName,
    required this.webSocketClient,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historial para la cuenta $accountNumber\n$businessName'),
      ),
      body: Column(
        children: [
          Expanded(
            child: EventList(
              accountNumber: accountNumber,
              webSocketClient: webSocketClient,
            ),
          ),
        ],
      ),
    );
  }
}

class EventList extends StatefulWidget {
  final String accountNumber;
  final WebSocketClient webSocketClient;

  const EventList({
    super.key,
    required this.accountNumber,
    required this.webSocketClient,
  });

  @override
  _EventListState createState() => _EventListState();
}

class _EventListState extends State<EventList> {
  List<Event> _events = [];
  List<Event> _filteredEvents = [];
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = DateTime.now().subtract(const Duration(days: 30));

    _eventSubscription = widget.webSocketClient.eventsStream.listen((data) {
      if (data['type'] == 'events' || data['type'] == 'events_by_client') {
        if (data['accountNumber'] == widget.accountNumber) {
          final events = (data['events'] as List)
              .map((e) => Event.fromJson(e))
              .toList()
            ..sort((a, b) => b.eventDateTime.compareTo(a.eventDateTime));

          setState(() {
            _events = events;
            _filterEvents();
          });
        }
      }
    });
    _fetchEvents();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchEvents() async {
    widget.webSocketClient.getEventsByClient(widget.accountNumber);
  }

  void _filterEvents() {
    setState(() {
      _filteredEvents = _events.where((event) {
        final matchesSearch = event.signalInfo
                ?.toLowerCase()
                .contains(_searchQuery.toLowerCase()) ??
            false;
        final matchesStartDate =
            _startDate == null || event.eventDateTime.isAfter(_startDate!);
        final matchesEndDate = _endDate == null ||
            event.eventDateTime
                .isBefore(_endDate!.add(const Duration(days: 1)));
        return matchesSearch && matchesStartDate && matchesEndDate;
      }).toList();
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _filterEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Card(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          margin: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar por información de señal...',
              prefixIcon: const Icon(Icons.search),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              hintStyle: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            style: TextStyle(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
              _filterEvents();
            },
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _selectDateRange(context),
                    icon: const Icon(Icons.calendar_today, size: 20),
                    label: Text(
                      _startDate == null && _endDate == null
                          ? 'Seleccionar fechas'
                          : '${DateFormat('dd/MM/yyyy').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                    });
                    _filterEvents();
                  },
                  icon: const Icon(Icons.clear, size: 20),
                  tooltip: 'Limpiar fechas',
                )
              ],
            ),
          ),
        ),
        Expanded(
          child: _filteredEvents.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _filteredEvents.length,
                  itemBuilder: (context, index) {
                    return EventCard(
                      event: _filteredEvents[index],
                      webSocketClient: widget.webSocketClient,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history,
              size: 48,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight),
          const SizedBox(height: 16),
          Text(
            'No hay eventos disponibles',
            style: TextStyle(
              fontSize: 16,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  final Event event;
  final WebSocketClient webSocketClient;

  const EventCard({
    super.key,
    required this.event,
    required this.webSocketClient,
  });

  Future<List<EventComment>> getCommentsForEvent(int eventId) async {
    final completer = Completer<List<EventComment>>();

    final subscription = webSocketClient.responses.listen((data) {
      if (data['type'] == 'comments' && data['eventId'] == eventId) {
        final comments = (data['comments'] as List)
            .map((c) => EventComment.fromJson(c))
            .toList();
        completer.complete(comments);
      }
    });

    webSocketClient.getComments(eventId);

    final result = await completer.future;
    subscription.cancel();
    return result;
  }

  String formatDate(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm:ss').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      color: isDark ? AppColors.cardDark : AppColors.cardLight,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 1,
      child: FutureBuilder<List<EventComment>>(
        future: getCommentsForEvent(event.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final hasComments = snapshot.hasData && snapshot.data!.isNotEmpty;

          return hasComments
              ? ExpansionTile(
                  title: _buildEventContent(context),
                  children: snapshot.data!
                      .map((comment) => CommentTile(comment: comment))
                      .toList(),
                )
              : ListTile(
                  title: _buildEventContent(context),
                );
        },
      ),
    );
  }

  Widget _buildEventContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                event.signalInfo ?? 'Sin información',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          formatDate(event.eventDateTime),
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class CommentTile extends StatelessWidget {
  final EventComment comment;

  const CommentTile({super.key, required this.comment});

  String formatDate(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm:ss').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Color(0xFF3498DB)),
              const SizedBox(width: 8),
              Text(
                comment.commentUser,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF3498DB),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                formatDate(comment.commentDateTime),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            comment.comment,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
