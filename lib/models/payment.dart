class Payment {
  final int? id;
  final int agencyId;
  final double amount;
  final DateTime date;
  final String paymentGivenBy;

  Payment({
    this.id,
    required this.agencyId,
    required this.amount,
    required this.date,
    required this.paymentGivenBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'agency_id': agencyId,
      'amount': amount,
      'date': date.toIso8601String(),
      'payment_given_by': paymentGivenBy,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'],
      agencyId: map['agency_id'],
      amount: map['amount'],
      date: DateTime.parse(map['date']),
      paymentGivenBy: map['payment_given_by'],
    );
  }
}
