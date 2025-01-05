class Event {
  final int id;
  final DateTime eventDateTime;
  final String? formatName;
  final String? receiverNumber;
  final String? line;
  final String? groupOrPartition;
  final String accountNumber;
  final String? partition;
  final String? eventType; // Changed from String to String?
  final String? accountName;
  final String? signalCode; // Changed from String to String?
  final String? signalInfo;
  final String? zoneOrUser;
  final String? simOrPhone;
  final bool isProcessed;
  final String? receptorName;
  final int? priority;
  final String? comments1;
  final String? comments2;
  final String? comments3;
  final String? comments4;
  final String? comments5;
  final String? comments6;
  final int? clientId;

  Event({
    required this.id,
    required this.eventDateTime,
    this.formatName,
    this.receiverNumber,
    this.line,
    this.groupOrPartition,
    required this.accountNumber,
    this.partition,
    this.eventType, // Changed from required
    this.accountName,
    this.signalCode, // Changed from required
    this.signalInfo,
    this.zoneOrUser,
    this.simOrPhone,
    required this.isProcessed,
    this.receptorName,
    this.priority,
    this.comments1,
    this.comments2,
    this.comments3,
    this.comments4,
    this.comments5,
    this.comments6,
    this.clientId,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    try {
      return Event(
        id: json['id'] as int,
        eventDateTime:
            DateTime.fromMillisecondsSinceEpoch(json['eventDateTime'] as int),
        formatName: json['formatName'] as String?,
        receiverNumber: json['receiverNumber'] as String?,
        line: json['line'] as String?,
        groupOrPartition: json['groupOrPartition'] as String?,
        accountNumber: json['accountNumber'] as String,
        partition: json['partition'] as String?,
        eventType: json['eventType'] as String? ?? 'Evento sin tipo',
        accountName: json['accountName'] as String?,
        signalCode: json['signalCode'] as String? ?? '',
        signalInfo: json['signalInfo'] as String?,
        zoneOrUser: json['zoneOrUser'] as String?,
        simOrPhone: json['simOrPhone'] as String?,
        isProcessed: json['isProcessed'] as bool,
        receptorName: json['receptorName'] as String?,
        priority: json['priority'] as int?,
        comments1: json['comments1'] as String?,
        comments2: json['comments2'] as String?,
        comments3: json['comments3'] as String?,
        comments4: json['comments4'] as String?,
        comments5: json['comments5'] as String?,
        comments6: json['comments6'] as String?,
        clientId: json['clientId'] as int?,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  String toString() {
    return 'Event{id: $id, eventDateTime: $eventDateTime, eventType: $eventType, signalInfo: $signalInfo}';
  }
}
