class Agency {
  final int? id;
  final String name;
  final int clientId;

  Agency({this.id, required this.name, required this.clientId});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'client_id': clientId,
    };
  }

  factory Agency.fromMap(Map<String, dynamic> map) {
    return Agency(
      id: map['id'],
      name: map['name'],
      clientId: map['client_id'],
    );
  }
}
