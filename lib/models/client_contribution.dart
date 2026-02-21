class ClientContribution {
  final int? id;
  final int clientId;
  final double amount;
  final DateTime date;

  ClientContribution({
    this.id,
    required this.clientId,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client_id': clientId,
      'amount': amount,
      'date': date.toIso8601String(),
    };
  }

  factory ClientContribution.fromMap(Map<String, dynamic> map) {
    return ClientContribution(
      id: map['id'],
      clientId: map['client_id'],
      amount: map['amount'],
      date: DateTime.parse(map['date']),
    );
  }
}
