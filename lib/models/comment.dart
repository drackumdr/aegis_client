import 'package:intl/intl.dart';

class EventComment {
  final int id;
  final int eventId;
  final String comment;
  final DateTime commentDateTime;
  final String commentUser;

  EventComment({
    required this.id,
    required this.eventId,
    required this.comment,
    required this.commentDateTime,
    required this.commentUser,
  });

  factory EventComment.fromJson(Map<String, dynamic> json) {
    return EventComment(
      id: json['id'] as int,
      eventId: json['eventId'] as int,
      comment: json['comment'] as String,
      commentDateTime: DateTime.parse(json['commentDateTime'] as String),
      commentUser: json['commentUser'] as String,
    );
  }

  @override
  String toString() {
    final formattedDate =
        DateFormat('dd/MM/yyyy HH:mm').format(commentDateTime);
    return '$comment - $commentUser ($formattedDate)';
  }
}
