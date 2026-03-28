class ClientContribution {
  final int? id;
  final int clientId;
  final double amount;
  final DateTime date;
  final String mode;

  ClientContribution({
    this.id,
    required this.clientId,
    required this.amount,
    required this.date,
    this.mode = 'Online',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client_id': clientId,
      'amount': amount,
      'date': date.toIso8601String(),
      'mode': mode,
    };
  }

  factory ClientContribution.fromMap(Map<String, dynamic> map) {
    return ClientContribution(
      id: map['id'],
      clientId: map['client_id'],
      amount: map['amount'],
      date: DateTime.parse(map['date']),
      mode: map['mode'] ?? 'Online',
    );
  }
}
