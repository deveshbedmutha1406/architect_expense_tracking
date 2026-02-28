import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'database/db_helper.dart';
import 'database/backup_service.dart';
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
  final BackupService _backupService = BackupService();
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

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings & Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Backup your data and receipts to a zip file for safe keeping.'),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.upload_file, color: Colors.blue),
              title: const Text('Export Backup'),
              onTap: () async {
                Navigator.pop(context);
                await _backupService.exportBackup();
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_download, color: Colors.green),
              title: const Text('Import Backup'),
              subtitle: const Text('Warning: Replaces all current data'),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Restore Data?'),
                    content: const Text('This will delete all current entries and replace them with the backup. Proceed?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                
                if (confirm == true) {
                  if (context.mounted) Navigator.pop(context);
                  bool success = await _backupService.importBackup();
                  if (context.mounted) {
                    if (success) {
                      _refreshClients();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup restored successfully')));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restore failed or cancelled')));
                    }
                  }
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: 'Settings & Backup',
          ),
        ],
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
                        Text('₹${_totalReceived.toStringAsFixed(2)}',
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
                        Text('₹${_paidByClientUntilToday.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                    if (futureClientPayments > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Future Client Payments:', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                          Text('₹${futureClientPayments.toStringAsFixed(2)}', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                        ],
                      ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Current Balance:',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('₹${currentBalance.toStringAsFixed(2)}',
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
                        Text('₹${_paidBySelfUntilToday.toStringAsFixed(2)}',
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
                          Text('₹${futureSelfPayments.toStringAsFixed(2)}', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12)),
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
                  title: Text('₹${item.amount.toStringAsFixed(2)}'),
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
  final ImagePicker _picker = ImagePicker();
  Directory? _appDir;

  @override
  void initState() {
    super.initState();
    _initAppDir();
    _refreshPayments();
  }

  void _initAppDir() async {
    final dir = await getApplicationDocumentsDirectory();
    setState(() {
      _appDir = dir;
    });
  }

  Future<String?> _saveImage(XFile? image) async {
    if (image == null) return null;
    try {
      final appDir = _appDir ?? await getApplicationDocumentsDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(image.path)}';
      await File(image.path).copy('${appDir.path}/$fileName');
      return fileName; // Returns FILENAME only
    } catch (e) {
      debugPrint("Error saving image: $e");
      return null;
    }
  }

  void _refreshPayments() async {
    final payments = await _dbHelper.getPaymentsByAgency(widget.agency.id!);
    setState(() {
      _payments = payments;
    });
  }

  void _showFullScreenReceipt(String receiptPath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Receipt'),
              leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ),
            Expanded(
              child: _appDir == null
                  ? const Center(child: CircularProgressIndicator())
                  : Image.file(File('${_appDir!.path}/$receiptPath'), fit: BoxFit.contain),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDialog({Payment? payment}) {
    final amountController = TextEditingController(text: payment?.amount.toString());
    final qtyController = TextEditingController(text: (payment?.qty ?? 1.0).toString());
    final remarksController = TextEditingController(text: payment?.remarks ?? '');
    DateTime selectedDate = payment?.date ?? DateTime.now();
    String paymentGivenBy = payment?.paymentGivenBy ?? 'Client';
    String? localReceiptPath = payment?.receiptPath;

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
                TextField(
                  controller: qtyController,
                  decoration: const InputDecoration(labelText: 'Quantity (Default: 1)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: remarksController,
                  decoration: const InputDecoration(labelText: 'Remarks'),
                  maxLines: 2,
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
                  value: paymentGivenBy,
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
                const SizedBox(height: 20),
                if (localReceiptPath != null && _appDir != null)
                  SizedBox(
                    width: double.maxFinite,
                    child: Stack(
                      children: [
                        Image.file(File('${_appDir!.path}/$localReceiptPath'), height: 120, width: double.infinity, fit: BoxFit.cover),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: CircleAvatar(
                            backgroundColor: Colors.red,
                            radius: 15,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.close, color: Colors.white, size: 20),
                              onPressed: () => setDialogState(() => localReceiptPath = null),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        final XFile? image = await _picker.pickImage(source: ImageSource.camera);
                        if (image != null) {
                          final savedPath = await _saveImage(image);
                          setDialogState(() => localReceiptPath = savedPath);
                        }
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          final savedPath = await _saveImage(image);
                          setDialogState(() => localReceiptPath = savedPath);
                        }
                      },
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                    ),
                  ],
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
                    qty: double.tryParse(qtyController.text) ?? 1.0,
                    remarks: remarksController.text,
                    receiptPath: localReceiptPath,
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
                      final effectiveAmount = payment.amount * payment.qty;
                      return ListTile(
                        leading: Icon(
                          payment.paymentGivenBy == 'Client'
                              ? Icons.person
                              : Icons.account_circle,
                          color: payment.paymentGivenBy == 'Client'
                              ? Colors.blue
                              : Colors.orange,
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('₹${effectiveAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (payment.qty != 1.0)
                              Text('(₹${payment.amount.toStringAsFixed(2)} x ${payment.qty})', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'By: ${payment.paymentGivenBy} | Date: ${DateFormat('yyyy-MM-dd').format(payment.date)}${isFuture ? " (Planned)" : ""}'),
                            if (payment.remarks.isNotEmpty)
                              Text('Remarks: ${payment.remarks}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (payment.receiptPath != null && _appDir != null)
                              GestureDetector(
                                onTap: () => _showFullScreenReceipt(payment.receiptPath!),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.file(File('${_appDir!.path}/${payment.receiptPath!}'), fit: BoxFit.cover),
                                  ),
                                ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showPaymentDialog(payment: payment),
                            ),
                          ],
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

enum AnalyticsView { both, client, self, custom }

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
  List<Map<String, dynamic>> _allPayments = [];
  bool _isLoading = true;
  AnalyticsView _selectedView = AnalyticsView.both;

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
      _allPayments = allPaymentsRaw;
      _isLoading = false;
    });
  }

  Future<void> _exportToPdf(DateTime spw, DateTime epw, DateTime scw, DateTime ecw) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(marginBottom: 1.5 * PdfPageFormat.cm),
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, child: pw.Text('Expense Report: ${widget.client.name}')),
            pw.Paragraph(text: 'Project: ${widget.client.projectName}'),
            pw.Paragraph(text: 'Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}'),
            pw.SizedBox(height: 20),
            
            if (_selectedView == AnalyticsView.both || _selectedView == AnalyticsView.client) ...[
              pw.Text('Payments by Client', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              _buildPdfTable(_generateDataRows('Client', spw, epw, scw, ecw)),
            ],
            
            if (_selectedView == AnalyticsView.both) pw.SizedBox(height: 30),
            
            if (_selectedView == AnalyticsView.both || _selectedView == AnalyticsView.self) ...[
              pw.Text('Payments by Self', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              _buildPdfTable(_generateDataRows('Self', spw, epw, scw, ecw)),
            ],

            if (_selectedView == AnalyticsView.custom) ...[
              pw.Text('Detailed Payment Report (All)', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              _buildCustomPdfTable(_generateCustomDataRows()),
            ],
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  pw.Widget _buildCustomPdfTable(List<List<String>> data) {
    return pw.TableHelper.fromTextArray(
      headers: ['Date', 'Agency', 'Amount', 'Qty', 'Total', 'Receipt', 'Remarks'],
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.centerLeft,
      columnWidths: {
        0: const pw.FlexColumnWidth(1.2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(0.5),
        4: const pw.FlexColumnWidth(1),
        5: const pw.FlexColumnWidth(0.8),
        6: const pw.FlexColumnWidth(2),
      },
    );
  }

  List<List<String>> _generateCustomDataRows() {
    List<List<String>> data = [];
    double grandTotal = 0;

    // Sort by date
    final sortedPayments = List<Map<String, dynamic>>.from(_allPayments);
    sortedPayments.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));

    for (var p in sortedPayments) {
      double amount = (p['amount'] as num).toDouble();
      double qty = (p['qty'] as num?)?.toDouble() ?? 1.0;
      double total = amount * qty;
      grandTotal += total;

      data.add([
        DateFormat('yyyy-MM-dd').format(DateTime.parse(p['date'])),
        p['agency_name'] ?? 'Unknown',
        amount.toStringAsFixed(2),
        qty.toStringAsFixed(2),
        total.toStringAsFixed(2),
        p['receipt_path'] != null ? 'Yes' : 'No',
        p['remarks'] ?? '',
      ]);
    }

    data.add([
      'TOTAL',
      '',
      '',
      '',
      grandTotal.toStringAsFixed(2),
      '',
      '',
    ]);
    return data;
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
        double effectiveAmount = p.amount * p.qty;
        if (p.date.isAfter(spw.subtract(const Duration(seconds: 1))) && p.date.isBefore(epw.add(const Duration(seconds: 1)))) {
          prevSum += effectiveAmount;
        } else if (p.date.isAfter(scw.subtract(const Duration(seconds: 1))) && p.date.isBefore(ecw.add(const Duration(seconds: 1)))) {
          currSum += effectiveAmount;
        } else if (p.date.isAfter(ecw)) {
          futureSum += effectiveAmount;
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            SegmentedButton<AnalyticsView>(
              segments: const [
                ButtonSegment(value: AnalyticsView.both, label: Text('Both'), icon: Icon(Icons.all_inclusive)),
                ButtonSegment(value: AnalyticsView.client, label: Text('Client'), icon: Icon(Icons.person)),
                ButtonSegment(value: AnalyticsView.self, label: Text('Self'), icon: Icon(Icons.account_circle)),
                ButtonSegment(value: AnalyticsView.custom, label: Text('Custom'), icon: Icon(Icons.list_alt)),
              ],
              selected: {_selectedView},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _selectedView = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_selectedView == AnalyticsView.both || _selectedView == AnalyticsView.client)
              _buildSection('Payments by Client', 'Client', startOfPrevWeek, endOfPrevWeek, startOfCurrWeek, endOfCurrWeek),
            if (_selectedView == AnalyticsView.both) const Divider(height: 40),
            if (_selectedView == AnalyticsView.both || _selectedView == AnalyticsView.self)
              _buildSection('Payments by Self', 'Self', startOfPrevWeek, endOfPrevWeek, startOfCurrWeek, endOfCurrWeek),
            if (_selectedView == AnalyticsView.custom)
              _buildCustomSection(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showReceiptDialog(String receiptFilename) async {
    final directory = await getApplicationDocumentsDirectory();
    final fullPath = path.join(directory.path, receiptFilename);
    final file = File(fullPath);

    if (await file.exists()) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('Receipt View'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share),
                    tooltip: 'Share Receipt',
                    onPressed: () {
                      Share.shareXFiles([XFile(fullPath)], text: 'Receipt from Expense Tracker');
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.file(file, fit: BoxFit.contain),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt image not found.')));
    }
  }

  Widget _buildCustomSection() {
    final sortedPayments = List<Map<String, dynamic>>.from(_allPayments);
    sortedPayments.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
    
    double grandTotal = 0;
    for (var p in sortedPayments) {
      grandTotal += (p['amount'] as num).toDouble() * ((p['qty'] as num?)?.toDouble() ?? 1.0);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Detailed Payment Report (All)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Agency')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Qty')),
              DataColumn(label: Text('Total')),
              DataColumn(label: Text('Receipt')),
              DataColumn(label: Text('Remarks')),
            ],
            rows: [
              ...sortedPayments.map((p) {
                final amount = (p['amount'] as num).toDouble();
                final qty = (p['qty'] as num?)?.toDouble() ?? 1.0;
                final total = amount * qty;
                final receiptPath = p['receipt_path'] as String?;

                return DataRow(cells: [
                  DataCell(Text(DateFormat('yyyy-MM-dd').format(DateTime.parse(p['date'])))),
                  DataCell(Text(p['agency_name'] ?? 'Unknown')),
                  DataCell(Text('₹${amount.toStringAsFixed(2)}')),
                  DataCell(Text(qty.toStringAsFixed(2))),
                  DataCell(Text('₹${total.toStringAsFixed(2)}')),
                  DataCell(
                    receiptPath != null
                        ? InkWell(
                            onTap: () => _showReceiptDialog(receiptPath),
                            child: const Text('View', style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                          )
                        : const Text('-'),
                  ),
                  DataCell(Text(p['remarks'] ?? '')),
                ]);
              }),
              DataRow(
                color: WidgetStateProperty.all(Colors.grey.shade200),
                cells: [
                  const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                  DataCell(Text('₹${grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                ],
              ),
            ],
          ),
        ),
      ],
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
