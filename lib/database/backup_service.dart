import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'db_helper.dart';
import 'package:sqflite/sqflite.dart';

class BackupService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> exportBackup() async {
    try {
      final data = await _dbHelper.getAllDataForBackup();
      final jsonString = jsonEncode(data);

      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${appDir.path}/backup_temp');
      if (await backupDir.exists()) await backupDir.delete(recursive: true);
      await backupDir.create();

      // Save JSON
      final jsonFile = File('${backupDir.path}/data.json');
      await jsonFile.writeAsString(jsonString);

      // Copy all receipts
      final List<FileSystemEntity> files = appDir.listSync();
      for (var file in files) {
        if (file is File && (file.path.endsWith('.jpg') || file.path.endsWith('.png') || file.path.endsWith('.jpeg'))) {
          await file.copy('${backupDir.path}/${file.uri.pathSegments.last}');
        }
      }

      // Create ZIP
      final encoder = ZipFileEncoder();
      final zipPath = '${appDir.path}/expense_tracker_backup_${DateTime.now().millisecondsSinceEpoch}.zip';
      encoder.create(zipPath);
      
      // Add files individually to the root of the ZIP
      final List<FileSystemEntity> backupFiles = backupDir.listSync();
      for (var file in backupFiles) {
        if (file is File) {
          encoder.addFile(file);
        }
      }
      encoder.close();

      // Share ZIP
      await Share.shareXFiles([XFile(zipPath)], text: 'Expense Tracker Backup');

      // Cleanup
      await backupDir.delete(recursive: true);
    } catch (e) {
      debugPrint('Backup Error: $e');
    }
  }

  Future<bool> importBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null) return false;

      final zipFile = File(result.files.single.path!);
      final appDir = await getApplicationDocumentsDirectory();
      
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find the JSON file first
      ArchiveFile? jsonArchiveFile;
      for (final file in archive) {
        if (file.name.endsWith('data.json')) {
          jsonArchiveFile = file;
          break;
        }
      }

      if (jsonArchiveFile == null) return false;

      final jsonContent = utf8.decode(jsonArchiveFile.content as List<int>);
      final Map<String, dynamic> data = jsonDecode(jsonContent);

      // Start Database transaction
      final Database db = await _dbHelper.database;
      await db.transaction((txn) async {
        // Clear all existing data
        await txn.delete('clients'); // Cascading deletes handle the rest

        // 1. Clients
        for (var client in data['clients']) {
          await txn.insert('clients', client);
        }
        // 2. Contributions
        for (var cont in data['client_contributions']) {
          await txn.insert('client_contributions', cont);
        }
        // 3. Agencies
        for (var agency in data['agencies']) {
          await txn.insert('agencies', agency);
        }
        // 4. Payments
        for (var payment in data['payments']) {
          await txn.insert('payments', payment);
        }
      });

      // Extract images
      for (final file in archive) {
        if (file.name.endsWith('.jpg') || file.name.endsWith('.png') || file.name.endsWith('.jpeg')) {
          final filename = file.name.split('/').last;
          if (filename.isEmpty) continue; // Skip directory entries
          final outFile = File('${appDir.path}/$filename');
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        }
      }

      return true;
    } catch (e) {
      debugPrint('Restore Error: $e');
      return false;
    }
  }
}
