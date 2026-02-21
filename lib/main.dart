import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'database/db_helper.dart';
import 'models/client.dart';
import 'models/agency.dart';
import 'models/payment.dart';
import 'models/client_contribution.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Client> _clients = [];

  @override
  void initState() {
    super.initState();
    _refreshClients();
  }

  void _refreshClients() async {
    final clients = await _dbHelper.getClients();
    setState(() {
      _clients = clients;
    });
  }

  void _showClientDialog({Client? client}) {
    final nameController = TextEditingController(text: client?.name);
    final projectController = TextEditingController(text: client?.projectName);
    final siteAddressController = TextEditingController(text: client?.siteAddress);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(client == null ? 'Add Client' : 'Edit Client'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Client Name')),
              TextField(
                  controller: projectController,
                  decoration: const InputDecoration(labelText: 'Project Name')),
              TextField(
                  controller: siteAddressController,
                  decoration: const InputDecoration(labelText: 'Site Address')),
            ],
          ),
        ),
        actions: [
          if (client != null)
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Client?'),
                    content: const Text('This will delete all agencies, payments, and history for this client. This action cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _dbHelper.deleteClient(client.id!);
                  _refreshClients();
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty &&
                  projectController.text.isNotEmpty) {
                final newClient = Client(
                  id: client?.id,
                  name: nameController.text,
                  projectName: projectController.text,
                  siteAddress: siteAddressController.text,
                  totalAmount: client?.totalAmount ?? 0.0,
                );
                if (client == null) {
                  await _dbHelper.insertClient(newClient);
                } else {
                  await _dbHelper.updateClient(newClient);
                }
                _refreshClients();
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: Text(client == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
      ),
      body: _clients.isEmpty
          ? const Center(child: Text('No clients added yet.'))
          : ListView.builder(
              itemCount: _clients.length,
              itemBuilder: (context, index) {
                final client = _clients[index];
                return ListTile(
                  title: Text(client.name),
                  subtitle: Text(
                      'Project: ${client.projectName}\nAddress: ${client.siteAddress}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _showClientDialog(client: client),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  isThreeLine: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ClientDetailScreen(client: client),
                      ),
                    ).then((_) => _refreshClients());
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showClientDialog(),
        tooltip: 'Add Client',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ClientDetailScreen extends StatefulWidget {
  final Client client;
  const ClientDetailScreen({super.key, required this.client});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Agency> _agencies = [];
  double _totalReceived = 0.0;
  double _paidByClientUntilToday = 0.0;
  double _paidBySelfUntilToday = 0.0;
  double _paidByClientTotal = 0.0;
  double _paidBySelfTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() async {
    final agencies = await _dbHelper.getAgenciesByClient(widget.client.id!);
    final totalReceived =
        await _dbHelper.getTotalClientContributions(widget.client.id!);
    
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final paidByClientUntilToday = await _dbHelper.getTotalPaymentsBySource(
        widget.client.id!, 'Client', upToDate: todayEnd);
    
    final paidBySelfUntilToday = await _dbHelper.getTotalPaymentsBySource(
        widget.client.id!, 'Self', upToDate: todayEnd);
    
    final paidByClientTotal = await _dbHelper.getTotalPaymentsBySource(
        widget.client.id!, 'Client');
    
    final paidBySelfTotal = await _dbHelper.getTotalPaymentsBySource(
        widget.client.id!, 'Self');

    setState(() {
      _agencies = agencies;
      _totalReceived = totalReceived;
      _paidByClientUntilToday = paidByClientUntilToday;
      _paidBySelfUntilToday = paidBySelfUntilToday;
      _paidByClientTotal = paidByClientTotal;
      _paidBySelfTotal = paidBySelfTotal;
    });
  }

  void _showAddContributionDialog() {
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Money from Client'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Amount Received'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Date: '),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    child: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (amountController.text.isNotEmpty) {
                  await _dbHelper.insertContribution(ClientContribution(
                    clientId: widget.client.id!,
                    amount: double.tryParse(amountController.text) ?? 0.0,
                    date: selectedDate,
                  ));
                  _refreshData();
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAgencyDialog({Agency? agency}) {
    final nameController = TextEditingController(text: agency?.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(agency == null ? 'Add Agency' : 'Edit Agency'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Agency Name'),
        ),
        actions: [
          if (agency != null)
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Agency?'),
                    content: const Text('This will also delete all payments for this agency.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _dbHelper.deleteAgency(agency.id!);
                  _refreshData();
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                if (agency == null) {
                  await _dbHelper.insertAgency(Agency(
                    name: nameController.text,
                    clientId: widget.client.id!,
                  ));
                } else {
                  await _dbHelper.updateAgency(Agency(
                    id: agency.id,
                    name: nameController.text,
                    clientId: agency.clientId,
                  ));
                }
                _refreshData();
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: Text(agency == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double currentBalance = _totalReceived - _paidByClientUntilToday;
    double futureClientPayments = _paidByClientTotal - _paidByClientUntilToday;
    double futureSelfPayments = _paidBySelfTotal - _paidBySelfUntilToday;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.client.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AnalyticsScreen(client: widget.client),
                ),
              );
            },
            tooltip: 'Payment Analytics',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ContributionHistoryScreen(clientId: widget.client.id!, clientName: widget.client.name),
                ),
              ).then((_) => _refreshData());
            },
            tooltip: 'Money Received History',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Received from Client:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('\$${_totalReceived.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Paid to Agencies (Client):'),
                        Text('\$${_paidByClientUntilToday.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                    if (futureClientPayments > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Future Client Payments:', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                          Text('\$${futureClientPayments.toStringAsFixed(2)}', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                        ],
                      ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Current Balance:',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('\$${currentBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: currentBalance >= 0
                                    ? Colors.green
                                    : Colors.red)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Paid by SELF (Until Today):',
                            style: TextStyle(fontStyle: FontStyle.italic)),
                        Text('\$${_paidBySelfUntilToday.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.orange)),
                      ],
                    ),
                    if (futureSelfPayments > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Future SELF Payments:', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12)),
                          Text('\$${futureSelfPayments.toStringAsFixed(2)}', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _showAddContributionDialog,
            icon: const Icon(Icons.add_card),
            label: const Text('Receive Money from Client'),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Agencies',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: _agencies.isEmpty
                ? const Center(child: Text('No agencies added yet.'))
                : ListView.builder(
                    itemCount: _agencies.length,
                    itemBuilder: (context, index) {
                      final agency = _agencies[index];
                      return ListTile(
                        leading: const Icon(Icons.business),
                        title: Text(agency.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _showAgencyDialog(agency: agency),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AgencyDetailScreen(agency: agency),
                            ),
                          );
                          _refreshData();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAgencyDialog(),
        tooltip: 'Add Agency',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ContributionHistoryScreen extends StatefulWidget {
  final int clientId;
  final String clientName;
  const ContributionHistoryScreen({super.key, required this.clientId, required this.clientName});

  @override
  State<ContributionHistoryScreen> createState() => _ContributionHistoryScreenState();
}

class _ContributionHistoryScreenState extends State<ContributionHistoryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<ClientContribution> _history = [];

  @override
  void initState() {
    super.initState();
    _refreshHistory();
  }

  void _refreshHistory() async {
    final history = await _dbHelper.getContributionsByClient(widget.clientId);
    setState(() {
      _history = history;
    });
  }

  void _showEditDialog(ClientContribution contribution) {
    final amountController = TextEditingController(text: contribution.amount.toString());
    DateTime selectedDate = contribution.date;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Received Money'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Date: '),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    child: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Entry?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _dbHelper.deleteContribution(contribution.id!);
                  _refreshHistory();
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (amountController.text.isNotEmpty) {
                  await _dbHelper.updateContribution(ClientContribution(
                    id: contribution.id,
                    clientId: contribution.clientId,
                    amount: double.tryParse(amountController.text) ?? 0.0,
                    date: selectedDate,
                  ));
                  _refreshHistory();
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.clientName} - Money History')),
      body: _history.isEmpty
          ? const Center(child: Text('No money received yet.'))
          : ListView.builder(
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final item = _history[index];
                return ListTile(
                  leading: const Icon(Icons.monetization_on, color: Colors.green),
                  title: Text('\$${item.amount.toStringAsFixed(2)}'),
                  subtitle: Text(DateFormat('yyyy-MM-dd').format(item.date)),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showEditDialog(item),
                  ),
                );
              },
            ),
    );
  }
}

class AgencyDetailScreen extends StatefulWidget {
  final Agency agency;
  const AgencyDetailScreen({super.key, required this.agency});

  @override
  State<AgencyDetailScreen> createState() => _AgencyDetailScreenState();
}

class _AgencyDetailScreenState extends State<AgencyDetailScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Payment> _payments = [];

  @override
  void initState() {
    super.initState();
    _refreshPayments();
  }

  void _refreshPayments() async {
    final payments = await _dbHelper.getPaymentsByAgency(widget.agency.id!);
    setState(() {
      _payments = payments;
    });
  }

  void _showPaymentDialog({Payment? payment}) {
    final amountController = TextEditingController(text: payment?.amount.toString());
    DateTime selectedDate = payment?.date ?? DateTime.now();
    String paymentGivenBy = payment?.paymentGivenBy ?? 'Client';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(payment == null ? 'Add Payment' : 'Edit Payment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Date: '),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      child: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: paymentGivenBy,
                  decoration: const InputDecoration(labelText: 'Payment Given By'),
                  items: ['Client', 'Self'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setDialogState(() => paymentGivenBy = newValue!);
                  },
                ),
              ],
            ),
          ),
          actions: [
            if (payment != null)
              TextButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Payment?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _dbHelper.deletePayment(payment.id!);
                    _refreshPayments();
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (amountController.text.isNotEmpty) {
                  final newPayment = Payment(
                    id: payment?.id,
                    agencyId: widget.agency.id!,
                    amount: double.tryParse(amountController.text) ?? 0.0,
                    date: selectedDate,
                    paymentGivenBy: paymentGivenBy,
                  );
                  if (payment == null) {
                    await _dbHelper.insertPayment(newPayment);
                  } else {
                    await _dbHelper.updatePayment(newPayment);
                  }
                  _refreshPayments();
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: Text(payment == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.agency.name} - Payments'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _payments.isEmpty
                ? const Center(child: Text('No payments recorded yet.'))
                : ListView.builder(
                    itemCount: _payments.length,
                    itemBuilder: (context, index) {
                      final payment = _payments[index];
                      final isFuture = payment.date.isAfter(DateTime.now());
                      return ListTile(
                        leading: Icon(
                          payment.paymentGivenBy == 'Client'
                              ? Icons.person
                              : Icons.account_circle,
                          color: payment.paymentGivenBy == 'Client'
                              ? Colors.blue
                              : Colors.orange,
                        ),
                        title: Text('\$${payment.amount.toStringAsFixed(2)}'),
                        subtitle: Text(
                            'By: ${payment.paymentGivenBy} | Date: ${DateFormat('yyyy-MM-dd').format(payment.date)}${isFuture ? " (Planned)" : ""}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showPaymentDialog(payment: payment),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPaymentDialog(),
        tooltip: 'Add Payment',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AnalyticsScreen extends StatefulWidget {
  final Client client;
  const AnalyticsScreen({super.key, required this.client});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Agency> _agencies = [];
  Map<int, List<Payment>> _agencyPayments = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final agencies = await _dbHelper.getAgenciesByClient(widget.client.id!);
    final allPaymentsRaw = await _dbHelper.getAllPaymentsForClient(widget.client.id!);
    
    Map<int, List<Payment>> paymentMap = {};
    for (var raw in allPaymentsRaw) {
      final payment = Payment.fromMap(raw);
      paymentMap.putIfAbsent(payment.agencyId, () => []).add(payment);
    }

    setState(() {
      _agencies = agencies;
      _agencyPayments = paymentMap;
      _isLoading = false;
    });
  }

  Future<void> _exportToPdf(DateTime spw, DateTime epw, DateTime scw, DateTime ecw) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();
    
    final clientRows = _generateDataRows('Client', spw, epw, scw, ecw);
    final selfRows = _generateDataRows('Self', spw, epw, scw, ecw);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, child: pw.Text('Expense Report: ${widget.client.name}')),
            pw.Paragraph(text: 'Project: ${widget.client.projectName}'),
            pw.Paragraph(text: 'Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}'),
            pw.SizedBox(height: 20),
            
            pw.Text('Payments by Client', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            _buildPdfTable(clientRows),
            pw.SizedBox(height: 30),
            
            pw.Text('Payments by Self', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            _buildPdfTable(selfRows),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  pw.Widget _buildPdfTable(List<List<String>> data) {
    return pw.TableHelper.fromTextArray(
      headers: ['Agency', 'Prev Week', 'Curr Week', 'Future', 'Total'],
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.centerRight,
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
      },
    );
  }

  List<List<String>> _generateDataRows(String source, DateTime spw, DateTime epw, DateTime scw, DateTime ecw) {
    List<List<String>> data = [];
    double totalPrev = 0, totalCurr = 0, totalFuture = 0, totalAll = 0;

    for (var agency in _agencies) {
      final payments = _agencyPayments[agency.id] ?? [];
      double prevSum = 0, currSum = 0, futureSum = 0;

      for (var p in payments) {
        if (p.paymentGivenBy != source) continue;
        if (p.date.isAfter(spw.subtract(const Duration(seconds: 1))) && p.date.isBefore(epw.add(const Duration(seconds: 1)))) {
          prevSum += p.amount;
        } else if (p.date.isAfter(scw.subtract(const Duration(seconds: 1))) && p.date.isBefore(ecw.add(const Duration(seconds: 1)))) {
          currSum += p.amount;
        } else if (p.date.isAfter(ecw)) {
          futureSum += p.amount;
        }
      }

      if (prevSum > 0 || currSum > 0 || futureSum > 0) {
        double rowTotal = prevSum + currSum + futureSum;
        data.add([
          agency.name,
          prevSum.toStringAsFixed(2),
          currSum.toStringAsFixed(2),
          futureSum.toStringAsFixed(2),
          rowTotal.toStringAsFixed(2)
        ]);
        totalPrev += prevSum;
        totalCurr += currSum;
        totalFuture += futureSum;
        totalAll += rowTotal;
      }
    }

    data.add([
      'TOTAL',
      totalPrev.toStringAsFixed(2),
      totalCurr.toStringAsFixed(2),
      totalFuture.toStringAsFixed(2),
      totalAll.toStringAsFixed(2)
    ]);
    return data;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));

    final now = DateTime.now();
    final startOfCurrWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final endOfCurrWeek = startOfCurrWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    final startOfPrevWeek = startOfCurrWeek.subtract(const Duration(days: 7));
    final endOfPrevWeek = startOfCurrWeek.subtract(const Duration(seconds: 1));

    return Scaffold(
      appBar: AppBar(
        title: Text('Analytics: ${widget.client.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => _exportToPdf(startOfPrevWeek, endOfPrevWeek, startOfCurrWeek, endOfCurrWeek),
            tooltip: 'Export PDF',
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('Payments by Client', 'Client', startOfPrevWeek, endOfPrevWeek, startOfCurrWeek, endOfCurrWeek),
            const SizedBox(height: 20),
            _buildSection('Payments by Self', 'Self', startOfPrevWeek, endOfPrevWeek, startOfCurrWeek, endOfCurrWeek),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String source, DateTime spw, DateTime epw, DateTime scw, DateTime ecw) {
    final data = _generateDataRows(source, spw, epw, scw, ecw);
    // Remove last row (Total) for standard rows list, we handle it separately or just use it.
    final totalRow = data.removeLast();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Agency')),
              DataColumn(label: Text('Prev Week')),
              DataColumn(label: Text('Curr Week')),
              DataColumn(label: Text('Future')),
              DataColumn(label: Text('Total')),
            ],
            rows: [
              ...data.map((row) => DataRow(cells: row.map((cell) => DataCell(Text(cell))).toList())),
              DataRow(
                color: WidgetStateProperty.all(Colors.grey.shade200),
                cells: totalRow.map((cell) => DataCell(Text(cell, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
