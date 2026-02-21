class Client {
  final int? id;
  final String name;
  final String projectName;
  final String siteAddress;
  final double totalAmount;

  Client({
    this.id,
    required this.name,
    required this.projectName,
    required this.siteAddress,
    required this.totalAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'project_name': projectName,
      'site_address': siteAddress,
      'total_amount': totalAmount,
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'],
      name: map['name'],
      projectName: map['project_name'],
      siteAddress: map['site_address'],
      totalAmount: map['total_amount'],
    );
  }
}
