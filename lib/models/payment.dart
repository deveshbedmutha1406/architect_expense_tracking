class Payment {
  final int? id;
  final int agencyId;
  final double amount;
  final DateTime date;
  final String paymentGivenBy;
  final double qty;
  final String remarks;
  final String? receiptPath; // Stores filename only (relative to App Docs)

  Payment({
    this.id,
    required this.agencyId,
    required this.amount,
    required this.date,
    required this.paymentGivenBy,
    this.qty = 1.0,
    this.remarks = '',
    this.receiptPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'agency_id': agencyId,
      'amount': amount,
      'date': date.toIso8601String(),
      'payment_given_by': paymentGivenBy,
      'qty': qty,
      'remarks': remarks,
      'receipt_path': receiptPath,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'],
      agencyId: map['agency_id'],
      amount: map['amount'],
      date: DateTime.parse(map['date']),
      paymentGivenBy: map['payment_given_by'],
      qty: (map['qty'] as num?)?.toDouble() ?? 1.0,
      remarks: map['remarks'] ?? '',
      receiptPath: map['receipt_path'],
    );
  }
}
