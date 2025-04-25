// File: lib/ui/debug/debug_tools_menu.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';

import 'package:audiobook_organizer/services/audiobook_scanner.dart';
import 'package:audiobook_organizer/services/metadata_matcher.dart';
import 'package:audiobook_organizer/utils/debug_tools.dart';
import 'package:audiobook_organizer/utils/directory_lister.dart';

class DebugToolsMenu extends StatelessWidget {
  const DebugToolsMenu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Debug Tools',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Directory Browser'),
            subtitle: const Text('Browse and analyze directory structure'),
            onTap: () => _openDirectoryBrowser(context),
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Metadata Debug Console'),
            subtitle: const Text('Test metadata matching'),
            onTap: () => _openMetadataDebugConsole(context),
          ),
          ListTile(
            leading: const Icon(Icons.save),
            title: const Text('Generate Directory Report'),
            subtitle: const Text('Save a report of your audiobook files'),
            onTap: () => _generateDirectoryReport(context),
          ),
        ],
      ),
    );
  }

  Future<void> _openDirectoryBrowser(BuildContext context) async {
    final scanner = Provider.of<AudiobookScanner>(context, listen: false);
    
    // Allow user to select a directory
    final String? selectedDir = await getDirectoryPath();
    if (selectedDir == null) return;
    
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DirectoryDebugView(
          initialDirectory: selectedDir,
          scanner: scanner,
        ),
      ),
    );
  }

  void _openMetadataDebugConsole(BuildContext context) {
    final scanner = Provider.of<AudiobookScanner>(context, listen: false);
    final matcher = Provider.of<MetadataMatcher>(context, listen: false);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MetadataDebugConsole(
          matcher: matcher,
          scanner: scanner,
        ),
      ),
    );
  }

  Future<void> _generateDirectoryReport(BuildContext context) async {
    final scanner = Provider.of<AudiobookScanner>(context, listen: false);
    
    // Allow user to select a directory
    final String? selectedDir = await getDirectoryPath();
    if (selectedDir == null) return;
    
    // Show loading dialog
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Generating Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Please wait...'),
          ],
        ),
      ),
    );
    
    try {
      // Generate report
      final lister = DirectoryLister(scanner);
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final outputPath = '$selectedDir/audiobook_report_$timestamp.txt';
      
      await lister.saveAudiobookReportToFile(selectedDir, outputPath);
      
      // Close loading dialog
      if (!context.mounted) return;
      Navigator.pop(context);
      
      // Show success dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Report Generated'),
          content: Text('Report saved to: $outputPath'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Close loading dialog
      if (!context.mounted) return;
      Navigator.pop(context);
      
      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to generate report: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}