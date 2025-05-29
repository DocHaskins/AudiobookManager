// lib/ui/widgets/tools/mp3_batch_converter_tool.dart
import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/metadata_service.dart';
import 'package:audiobook_organizer/ui/widgets/dialogs/conversion_progress_dialog.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class Mp3BatchConverterTool extends StatefulWidget {
  final LibraryManager libraryManager;

  const Mp3BatchConverterTool({
    Key? key,
    required this.libraryManager,
  }) : super(key: key);

  @override
  State<Mp3BatchConverterTool> createState() => _Mp3BatchConverterToolState();
}

class _Mp3BatchConverterToolState extends State<Mp3BatchConverterTool> {
  final MetadataService _metadataService = MetadataService();
  
  List<AudiobookFile> _mp3Files = [];
  Set<String> _selectedFiles = {};
  bool _isLoading = true;
  bool _isConverting = false;
  bool _isCancelled = false;
  String _statusMessage = '';
  
  // Conversion progress tracking
  int _totalToConvert = 0;
  int _convertedCount = 0;
  int _activeConversions = 0;
  Map<String, double> _fileProgress = {}; // Track progress for each file
  Map<String, String> _fileStatus = {}; // Track status for each file (converting, done, failed)
  Map<String, String> _errorMessages = {}; // Track error messages for failed files
  
  // Parallel processing settings
  int _parallelJobs = 1; // Default to 1 for compatibility, but will be updated
  int _maxParallelJobs = 1;
  static const int _maxSafeParallelJobs = 8; // Safety limit to prevent memory issues
  
  // Quality settings
  String _selectedBitrate = '128k'; // Default to higher quality
  final List<String> _bitrateOptions = ['64k', '96k', '128k', '160k', '192k', '256k'];
  bool _preserveOriginalBitrate = true;
  
  // Performance tracking
  DateTime? _conversionStartTime;
  Duration _totalElapsedTime = Duration.zero;
  Timer? _elapsedTimer;
  
  // Filter and sort options
  String _sortBy = 'title'; // 'title', 'author', 'size', 'date'
  bool _sortAscending = true;
  String _filterText = '';
  
  @override
  void initState() {
    super.initState();
    _initializeService();
    _detectSystemCapabilities();
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeService() async {
    await _metadataService.initialize();
    await _loadMp3Files();
  }

  Future<void> _detectSystemCapabilities() async {
    // Detect number of CPU cores
    final cpuCores = Platform.numberOfProcessors;
    setState(() {
      // Limit max parallel jobs to prevent memory issues
      _maxParallelJobs = cpuCores.clamp(1, _maxSafeParallelJobs);
      // Set default parallel jobs conservatively
      // For 8+ cores: 3-4 jobs
      // For 4-6 cores: 2 jobs  
      // For 1-3 cores: 1 job
      if (cpuCores >= 8) {
        _parallelJobs = 3;
      } else if (cpuCores >= 4) {
        _parallelJobs = 2;
      } else {
        _parallelJobs = 1;
      }
    });
    Logger.log('System has $cpuCores CPU cores. Max parallel: $_maxParallelJobs, Default: $_parallelJobs');
    Logger.log('Memory safety limit enforced: Maximum $_maxSafeParallelJobs parallel conversions');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildSettingsPanel(),
          const SizedBox(height: 16),
          _buildToolbar(),
          const SizedBox(height: 16),
          _buildStats(),
          const SizedBox(height: 16),
          Expanded(
            child: _buildFilesList(),
          ),
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 39, 176, 69).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.transform,
            color: Color.fromARGB(255, 39, 176, 69),
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MP3 to M4B Batch Converter',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Convert multiple MP3 audiobooks to M4B format with parallel processing',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings, color: Colors.grey[400], size: 20),
              const SizedBox(width: 8),
              Text(
                'Conversion Settings',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              // Hardware info button
              IconButton(
                onPressed: _showHardwareOptimizationInfo,
                icon: const Icon(Icons.memory, size: 20),
                color: Colors.blue,
                tooltip: 'Hardware Optimization Info',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Parallel jobs setting
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.speed, color: Colors.blue[400], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Parallel Conversions',
                          style: TextStyle(color: Colors.grey[300], fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Number of files to convert simultaneously.\n'
                                  'Higher values use more CPU and memory.\n'
                                  'Recommended: 1-4 for most systems.\n'
                                  'Each process uses ~200-500MB RAM.',
                          child: Icon(Icons.info_outline, color: Colors.grey[600], size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '1',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                        Expanded(
                          child: Slider(
                            value: _parallelJobs.toDouble(),
                            min: 1,
                            max: _maxParallelJobs.toDouble(),
                            divisions: _maxParallelJobs - 1,
                            label: _parallelJobs.toString(),
                            activeColor: _parallelJobs <= 4 ? Colors.blue : 
                                       (_parallelJobs <= 6 ? Colors.orange : Colors.red),
                            onChanged: _isConverting ? null : (value) {
                              setState(() {
                                _parallelJobs = value.round();
                              });
                            },
                          ),
                        ),
                        Text(
                          _maxParallelJobs.toString(),
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _parallelJobs <= 4 ? Colors.blue.withOpacity(0.2) :
                                   (_parallelJobs <= 6 ? Colors.orange.withOpacity(0.2) : 
                                    Colors.red.withOpacity(0.2)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _parallelJobs.toString(),
                            style: TextStyle(
                              color: _parallelJobs <= 4 ? Colors.blue :
                                     (_parallelJobs <= 6 ? Colors.orange : Colors.red),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_parallelJobs > 4) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _parallelJobs > 6 ? Colors.red.withOpacity(0.1) : 
                                 Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning, 
                              color: _parallelJobs > 6 ? Colors.red : Colors.orange,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _parallelJobs > 6 
                                  ? 'High memory usage! May cause crashes.'
                                  : 'Moderate memory usage. Monitor system.',
                              style: TextStyle(
                                color: _parallelJobs > 6 ? Colors.red : Colors.orange,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 32),
              // Bitrate setting
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.high_quality, color: Colors.green[400], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Audio Quality',
                          style: TextStyle(color: Colors.grey[300], fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedBitrate,
                              isExpanded: true,
                              underline: const SizedBox(),
                              dropdownColor: const Color(0xFF2A2A2A),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              items: _bitrateOptions.map((bitrate) {
                                String label = bitrate;
                                if (bitrate == '64k') label += ' (Smallest)';
                                if (bitrate == '128k') label += ' (Recommended)';
                                if (bitrate == '256k') label += ' (Highest)';
                                return DropdownMenuItem(
                                  value: bitrate,
                                  child: Text(label),
                                );
                              }).toList(),
                              onChanged: _isConverting ? null : (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedBitrate = value;
                                    _preserveOriginalBitrate = false;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Row(
                          children: [
                            Checkbox(
                              value: _preserveOriginalBitrate,
                              onChanged: _isConverting ? null : (value) {
                                setState(() {
                                  _preserveOriginalBitrate = value ?? false;
                                });
                              },
                              activeColor: Colors.green,
                            ),
                            Text(
                              'Preserve Original',
                              style: TextStyle(color: Colors.grey[300], fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Performance optimization tips
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tips_and_updates, color: Colors.blue[400], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Performance Tips',
                      style: TextStyle(
                        color: Colors.blue[400],
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Use SSD storage for 2-3x faster conversion',
                  style: TextStyle(color: Colors.blue[300], fontSize: 12),
                ),
                Text(
                  '• Close other applications to free up memory',
                  style: TextStyle(color: Colors.blue[300], fontSize: 12),
                ),
                Text(
                  '• Disable antivirus scanning on working directories',
                  style: TextStyle(color: Colors.blue[300], fontSize: 12),
                ),
                Text(
                  '• For 400+ files: Use 3-4 parallel conversions maximum',
                  style: TextStyle(color: Colors.blue[300], fontSize: 12),
                ),
              ],
            ),
          ),
          if (_isConverting) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 39, 176, 69).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.speed, color: Color.fromARGB(255, 39, 176, 69), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Active conversions: $_activeConversions / $_parallelJobs',
                    style: const TextStyle(color: Color.fromARGB(255, 39, 176, 69), fontSize: 12),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.timer, color: Color.fromARGB(255, 39, 176, 69), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Elapsed: ${_formatDuration(_totalElapsedTime)}',
                    style: const TextStyle(color: Color.fromARGB(255, 39, 176, 69), fontSize: 12),
                  ),
                  if (_convertedCount > 0 && _totalToConvert > _convertedCount) ...[
                    const SizedBox(width: 16),
                    const Icon(Icons.schedule, color: Color.fromARGB(255, 39, 176, 69), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'ETA: ${_calculateETA()}',
                      style: const TextStyle(color: Color.fromARGB(255, 39, 176, 69), fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search MP3 files...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (value) {
                  setState(() => _filterText = value);
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Sort dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: _sortBy,
              underline: const SizedBox(),
              dropdownColor: const Color(0xFF2A2A2A),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: const [
                DropdownMenuItem(value: 'title', child: Text('Title')),
                DropdownMenuItem(value: 'author', child: Text('Author')),
                DropdownMenuItem(value: 'size', child: Text('Size')),
                DropdownMenuItem(value: 'date', child: Text('Date')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _sortBy = value;
                    _sortFiles();
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          
          // Sort direction
          IconButton(
            onPressed: () {
              setState(() {
                _sortAscending = !_sortAscending;
                _sortFiles();
              });
            },
            icon: Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              color: Colors.grey[400],
            ),
            tooltip: _sortAscending ? 'Ascending' : 'Descending',
          ),
          
          const SizedBox(width: 16),
          
          // Select all/none buttons
          TextButton(
            onPressed: _isConverting ? null : _selectAll,
            child: const Text('Select All'),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _isConverting ? null : _selectNone,
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final filteredFiles = _getFilteredFiles();
    final totalSize = filteredFiles.fold<int>(
      0, (sum, file) => sum + file.fileSize
    );
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.audiotrack,
            label: 'Total MP3 Files',
            value: filteredFiles.length.toString(),
            color: Colors.blue,
          ),
          _buildStatItem(
            icon: Icons.check_circle_outline,
            label: 'Selected',
            value: _selectedFiles.length.toString(),
            color: const Color.fromARGB(255, 238, 195, 1),
          ),
          _buildStatItem(
            icon: Icons.storage,
            label: 'Total Size',
            value: _formatFileSize(totalSize),
            color: Colors.orange,
          ),
          if (_isConverting) ...[
            _buildStatItem(
              icon: Icons.published_with_changes,
              label: 'Progress',
              value: '$_convertedCount / $_totalToConvert',
              color: const Color.fromARGB(255, 39, 176, 69),
            ),
            _buildStatItem(
              icon: Icons.speed,
              label: 'Speed',
              value: _calculateSpeed(),
              color: Colors.cyan,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFilesList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final filteredFiles = _getFilteredFiles();
    
    if (filteredFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.audiotrack_outlined, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              _filterText.isEmpty 
                  ? 'No MP3 files found in library'
                  : 'No files match your search',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            if (_filterText.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _filterText = ''),
                child: const Text('Clear search'),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey[800]!),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 40), // Checkbox space
                Expanded(
                  flex: 3,
                  child: Text(
                    'Title',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Author',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    'Size',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 100,
                  child: Text(
                    'Duration',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 120,
                  child: Text(
                    'Status',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          
          // Files list
          Expanded(
            child: ListView.builder(
              itemCount: filteredFiles.length,
              itemBuilder: (context, index) {
                final file = filteredFiles[index];
                return _buildFileItem(file);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(AudiobookFile file) {
    final isSelected = _selectedFiles.contains(file.path);
    final isConverting = _fileStatus[file.path] == 'converting';
    final isDone = _fileStatus[file.path] == 'done';
    final isFailed = _fileStatus[file.path] == 'failed';
    final progress = _fileProgress[file.path] ?? 0.0;
    
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isConverting ? null : () => _toggleFileSelection(file),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Checkbox
                Checkbox(
                  value: isSelected,
                  onChanged: _isConverting ? null : (value) => _toggleFileSelection(file),
                  activeColor: Colors.blue,
                ),
                
                // Title
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.metadata?.title ?? file.filename,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (file.metadata?.series.isNotEmpty ?? false) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${file.metadata!.series} #${file.metadata!.seriesPosition}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Author
                Expanded(
                  flex: 2,
                  child: Text(
                    file.metadata?.authorsFormatted ?? 'Unknown',
                    style: TextStyle(color: Colors.grey[400]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                // Size
                SizedBox(
                  width: 100,
                  child: Text(
                    _formatFileSize(file.fileSize),
                    style: TextStyle(color: Colors.grey[400]),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Duration
                SizedBox(
                  width: 100,
                  child: Text(
                    file.metadata?.durationFormatted ?? '--:--',
                    style: TextStyle(color: Colors.grey[400]),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Status/Progress
                SizedBox(
                  width: 120,
                  child: _buildFileStatus(isConverting, isDone, isFailed, progress),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileStatus(bool isConverting, bool isDone, bool isFailed, double progress) {
    if (isDone) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 4),
          Text(
            'Completed',
            style: TextStyle(color: Colors.green[400], fontSize: 12),
          ),
        ],
      );
    }
    
    if (isFailed) {
      final errorMsg = _errorMessages[_fileStatus.entries
          .firstWhere((e) => e.value == 'failed')
          .key] ?? 'Failed';
      return Tooltip(
        message: errorMsg,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 16),
            const SizedBox(width: 4),
            Text(
              'Failed',
              style: TextStyle(color: Colors.red[400], fontSize: 12),
            ),
          ],
        ),
      );
    }
    
    if (isConverting) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[800],
            valueColor: const AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 39, 176, 69)),
            minHeight: 4,
          ),
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).toStringAsFixed(1)}%',
            style: const TextStyle(color: Color.fromARGB(255, 39, 176, 69), fontSize: 11),
          ),
        ],
      );
    }
    
    return const SizedBox();
  }

  Widget _buildBottomActions() {
    final hasSelection = _selectedFiles.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        children: [
          if (_statusMessage.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _isConverting 
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isConverting 
                      ? Colors.blue.withOpacity(0.3)
                      : Colors.green.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  if (_isConverting)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      Icons.info_outline,
                      color: Colors.green[400],
                      size: 16,
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _isConverting 
                            ? Colors.blue[300]
                            : Colors.green[300],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (hasSelection && !_isConverting) 
                      ? _startBatchConversion 
                      : null,
                  icon: _isConverting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.transform),
                  label: Text(
                    _isConverting 
                        ? 'Converting... ($_convertedCount/$_totalToConvert)'
                        : 'Convert Selected (${_selectedFiles.length})',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 39, 176, 69),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              if (_isConverting) ...[
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: _cancelConversion,
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  label: const Text('Cancel', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
              if (!_isConverting) ...[
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: _loadMp3Files,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey[600]!),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // Helper methods
  Future<void> _loadMp3Files() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading MP3 files from library...';
    });

    try {
      // Get all files from library
      final allFiles = widget.libraryManager.files;
      
      // Filter MP3 files
      final mp3Files = allFiles.where((file) => 
        file.extension.toLowerCase() == '.mp3'
      ).toList();

      setState(() {
        _mp3Files = mp3Files;
        _isLoading = false;
        _statusMessage = 'Found ${mp3Files.length} MP3 files in library';
      });

      // Apply initial sorting
      _sortFiles();
    } catch (e) {
      Logger.error('Error loading MP3 files', e);
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error loading files: $e';
      });
    }
  }

  List<AudiobookFile> _getFilteredFiles() {
    if (_filterText.isEmpty) return _mp3Files;
    
    final searchLower = _filterText.toLowerCase();
    return _mp3Files.where((file) {
      final title = (file.metadata?.title ?? file.filename).toLowerCase();
      final author = (file.metadata?.authorsFormatted ?? '').toLowerCase();
      final series = (file.metadata?.series ?? '').toLowerCase();
      
      return title.contains(searchLower) || 
             author.contains(searchLower) ||
             series.contains(searchLower);
    }).toList();
  }

  void _sortFiles() {
    _mp3Files.sort((a, b) {
      int result;
      
      switch (_sortBy) {
        case 'title':
          final aTitle = a.metadata?.title ?? a.filename;
          final bTitle = b.metadata?.title ?? b.filename;
          result = aTitle.compareTo(bTitle);
          break;
        case 'author':
          final aAuthor = a.metadata?.authorsFormatted ?? '';
          final bAuthor = b.metadata?.authorsFormatted ?? '';
          result = aAuthor.compareTo(bAuthor);
          break;
        case 'size':
          result = a.fileSize.compareTo(b.fileSize);
          break;
        case 'date':
          result = a.lastModified.compareTo(b.lastModified);
          break;
        default:
          result = 0;
      }
      
      return _sortAscending ? result : -result;
    });
  }

  void _toggleFileSelection(AudiobookFile file) {
    setState(() {
      if (_selectedFiles.contains(file.path)) {
        _selectedFiles.remove(file.path);
      } else {
        _selectedFiles.add(file.path);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedFiles = _getFilteredFiles().map((file) => file.path).toSet();
    });
  }

  void _selectNone() {
    setState(() {
      _selectedFiles.clear();
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String _calculateSpeed() {
    if (_convertedCount == 0 || _totalElapsedTime.inSeconds == 0) {
      return '-- files/hr';
    }
    
    final filesPerSecond = _convertedCount / _totalElapsedTime.inSeconds;
    final filesPerHour = filesPerSecond * 3600;
    
    if (filesPerHour >= 1) {
      return '${filesPerHour.toStringAsFixed(1)} files/hr';
    } else {
      final minutesPerFile = 1 / (filesPerSecond * 60);
      return '${minutesPerFile.toStringAsFixed(1)} min/file';
    }
  }

  String _calculateETA() {
    if (_convertedCount == 0 || _totalElapsedTime.inSeconds == 0) {
      return 'Calculating...';
    }
    
    final filesRemaining = _totalToConvert - _convertedCount;
    final avgSecondsPerFile = _totalElapsedTime.inSeconds / _convertedCount;
    final secondsRemaining = (filesRemaining * avgSecondsPerFile) / _parallelJobs;
    
    final eta = Duration(seconds: secondsRemaining.round());
    return _formatDuration(eta);
  }

  void _cancelConversion() {
    setState(() {
      _isCancelled = true;
      _statusMessage = 'Cancelling conversion...';
    });
  }

  Future<void> _startBatchConversion() async {
    if (_selectedFiles.isEmpty) return;

    // Check FFmpeg availability
    final ffmpegAvailable = await _metadataService.isFFmpegAvailableForConversion();
    if (!ffmpegAvailable) {
      _showErrorDialog(
        'FFmpeg Required',
        'FFmpeg is required for batch conversion.\n\n'
        'Please install FFmpeg and add it to your system PATH.\n'
        'Download from: https://ffmpeg.org/download.html',
      );
      return;
    }

    // Warn about high parallel conversion count
    if (_parallelJobs > 4) {
      final continueHighParallel = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('High Parallel Count Warning', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You have selected $_parallelJobs parallel conversions.',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'This may cause:',
                style: TextStyle(color: Colors.orange),
              ),
              const Text('• High memory usage (200-500MB per conversion)', style: TextStyle(color: Colors.grey)),
              const Text('• System slowdowns or freezes', style: TextStyle(color: Colors.grey)),
              const Text('• Potential crashes if memory runs out', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Recommended: 1-4 parallel conversions for stability',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() => _parallelJobs = 3);
                Navigator.of(context).pop(false);
              },
              child: const Text('Use Recommended (3)'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: Text('Continue with $_parallelJobs'),
            ),
          ],
        ),
      );

      if (continueHighParallel != true) return;
    }

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Row(
          children: [
            Icon(Icons.transform, color: Color.fromARGB(255, 39, 176, 69)),
            SizedBox(width: 8),
            Text('Batch Convert to M4B', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Convert ${_selectedFiles.length} MP3 file(s) to M4B format?',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.settings, color: Colors.blue, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'Conversion Settings:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Parallel conversions: $_parallelJobs${_parallelJobs > 4 ? " ⚠️ High memory usage" : ""}',
                    style: TextStyle(
                      color: _parallelJobs > 4 ? Colors.orange : Colors.blue,
                    ),
                  ),
                  Text(
                    '• Audio quality: ${_preserveOriginalBitrate ? "Preserve original" : _selectedBitrate}',
                    style: const TextStyle(color: Colors.blue),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This will:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const Text('• Convert each MP3 to M4B format', style: TextStyle(color: Colors.grey)),
            const Text('• Transfer all metadata and cover art', style: TextStyle(color: Colors.grey)),
            const Text('• Delete original MP3 files', style: TextStyle(color: Colors.grey)),
            const Text('• Update library with new M4B files', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. Make sure you have backups.',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color.fromARGB(255, 39, 176, 69),
              foregroundColor: Colors.white,
            ),
            child: const Text('Convert All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Start batch conversion
    setState(() {
      _isConverting = true;
      _isCancelled = false;
      _totalToConvert = _selectedFiles.length;
      _convertedCount = 0;
      _activeConversions = 0;
      _statusMessage = 'Starting batch conversion...';
      _fileProgress.clear();
      _fileStatus.clear();
      _errorMessages.clear();
      _conversionStartTime = DateTime.now();
      _totalElapsedTime = Duration.zero;
    });

    // Start elapsed time timer
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isConverting && mounted) {
        setState(() {
          _totalElapsedTime = DateTime.now().difference(_conversionStartTime!);
        });
      } else {
        timer.cancel();
      }
    });

    final selectedFilesList = _mp3Files.where(
      (file) => _selectedFiles.contains(file.path)
    ).toList();

    int successCount = 0;
    int failCount = 0;

    // Process files with parallel execution
    await _processFilesInParallel(selectedFilesList, successCount, failCount);

    // Stop elapsed timer
    _elapsedTimer?.cancel();

    // Show results
    setState(() {
      _isConverting = false;
      _statusMessage = _isCancelled 
          ? 'Conversion cancelled: $successCount succeeded, $failCount failed'
          : 'Conversion complete: $successCount succeeded, $failCount failed';
      _selectedFiles.clear();
    });

    // Reload library to reflect changes
    await _loadMp3Files();

    // Show results dialog
    if (mounted && !_isCancelled) {
      _showResultsDialog(successCount, failCount);
    }
  }

  Future<void> _processFilesInParallel(
    List<AudiobookFile> files,
    int successCount,
    int failCount,
  ) async {
    final queue = Queue<AudiobookFile>.from(files);
    final activeConversions = <Future<bool>>[];
    final results = <bool>[];
    
    // Track active processes to ensure cleanup
    final activeProcesses = <String>{};

    while (queue.isNotEmpty || activeConversions.isNotEmpty) {
      if (_isCancelled) break;

      // Start new conversions up to the parallel limit
      while (activeConversions.length < _parallelJobs && queue.isNotEmpty && !_isCancelled) {
        final file = queue.removeFirst();
        
        setState(() {
          _activeConversions = activeConversions.length + 1;
          _fileStatus[file.path] = 'converting';
          activeProcesses.add(file.path);
        });

        final future = _convertSingleFile(file).then((success) {
          setState(() {
            _activeConversions = activeConversions.length - 1;
            _convertedCount++;
            activeProcesses.remove(file.path);
            if (success) {
              _fileStatus[file.path] = 'done';
            } else {
              _fileStatus[file.path] = 'failed';
            }
          });
          results.add(success);
          return success;
        }).catchError((error) {
          setState(() {
            _activeConversions = activeConversions.length - 1;
            _convertedCount++;
            activeProcesses.remove(file.path);
            _fileStatus[file.path] = 'failed';
            _errorMessages[file.path] = error.toString();
          });
          results.add(false);
          return false;
        });

        activeConversions.add(future);
        
        // Add a small delay between starting conversions to prevent memory spikes
        if (queue.isNotEmpty) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      // Wait for at least one conversion to complete
      if (activeConversions.isNotEmpty) {
        final completed = await Future.wait(
          activeConversions.map((f) => f.then((result) => MapEntry(f, result)))
        );
        for (final entry in completed) {
          activeConversions.remove(entry.key);
        }
        
        // Small delay to allow memory to be freed
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Update status message
      setState(() {
        _statusMessage = 'Converting files... (Active: $_activeConversions, Completed: $_convertedCount/$_totalToConvert)';
      });
    }

    // Wait for all remaining conversions to complete
    if (!_isCancelled && activeConversions.isNotEmpty) {
      await Future.wait(activeConversions);
    }

    // Ensure all processes are marked as complete
    for (final path in activeProcesses) {
      if (_fileStatus[path] == 'converting') {
        setState(() {
          _fileStatus[path] = 'failed';
          _errorMessages[path] = 'Process terminated unexpectedly';
        });
      }
    }

    // Count results
    successCount = results.where((r) => r).length;
    failCount = results.where((r) => !r).length;
  }

  Future<bool> _convertSingleFile(AudiobookFile file) async {
    StreamController<ConversionProgress>? progressController;
    Timer? progressThrottleTimer;
    double lastReportedProgress = 0;
    
    try {
      if (file.metadata == null) {
        Logger.error('Cannot convert file without metadata: ${file.filename}');
        _errorMessages[file.path] = 'No metadata available';
        return false;
      }

      // Create M4B file path
      final originalPath = file.path;
      final directory = path_util.dirname(originalPath);
      final baseName = path_util.basenameWithoutExtension(originalPath);
      final m4bPath = path_util.join(directory, '$baseName.m4b');

      // Check if M4B file already exists
      if (await File(m4bPath).exists()) {
        Logger.warning('M4B file already exists, skipping: $m4bPath');
        _errorMessages[file.path] = 'M4B file already exists';
        return false;
      }

      Logger.log('Converting ${file.filename} to M4B...');

      // Create progress controller for individual file
      progressController = StreamController<ConversionProgress>.broadcast();
      
      // Throttle progress updates to reduce memory usage and UI updates
      progressController.stream.listen((progress) {
        // Only update if progress changed significantly (>2%) or is complete
        if ((progress.percentage - lastReportedProgress).abs() > 0.02 || 
            progress.percentage >= 1.0) {
          lastReportedProgress = progress.percentage;
          
          // Cancel previous timer if exists
          progressThrottleTimer?.cancel();
          
          // Delay the update slightly to batch rapid changes
          progressThrottleTimer = Timer(const Duration(milliseconds: 100), () {
            if (mounted && !_isCancelled) {
              setState(() {
                _fileProgress[file.path] = progress.percentage;
              });
            }
          });
        }
      });

      // Perform the conversion with quality settings
      final success = await _convertWithQualitySettings(
        originalPath,
        m4bPath,
        file.metadata!,
        progressController,
      );

      // Clean up resources
      progressThrottleTimer?.cancel();
      await progressController.close();

      if (success && !_isCancelled) {
        Logger.log('Conversion successful, updating library...');
        
        // Update the library manager to replace the old file with the new one
        final updateSuccess = await widget.libraryManager.replaceFileInLibrary(
          originalPath,
          m4bPath,
          file.metadata!,
        );

        if (updateSuccess) {
          // Delete the original MP3 file
          try {
            await File(originalPath).delete();
            Logger.log('Deleted original MP3 file: $originalPath');
          } catch (e) {
            Logger.warning('Failed to delete original file: $e');
          }
          
          return true;
        } else {
          Logger.error('Failed to update library after conversion');
          _errorMessages[file.path] = 'Library update failed';
          // Try to delete the converted file since library update failed
          try {
            await File(m4bPath).delete();
          } catch (e) {
            Logger.warning('Failed to cleanup converted file: $e');
          }
          return false;
        }
      } else {
        Logger.error('Failed to convert MP3 to M4B or was cancelled');
        _errorMessages[file.path] = _isCancelled ? 'Cancelled' : 'Conversion failed';
        return false;
      }
    } catch (e) {
      Logger.error('Error converting file: ${file.filename}', e);
      _errorMessages[file.path] = e.toString();
      return false;
    } finally {
      // Ensure resources are cleaned up
      progressThrottleTimer?.cancel();
      if (progressController != null && !progressController.isClosed) {
        await progressController.close();
      }
    }
  }

  Future<bool> _convertWithQualitySettings(
    String inputPath,
    String outputPath,
    AudiobookMetadata metadata,
    StreamController<ConversionProgress> progressController,
  ) async {
    // For now, use the existing conversion method
    // In a real implementation, you would modify the FFmpeg args to use the selected bitrate
    return await _metadataService.convertMP3ToM4B(
      inputPath,
      outputPath,
      metadata,
      progressController: progressController,
      totalDuration: metadata.audioDuration,
    );
  }

  void _showResultsDialog(int successCount, int failCount) {
    final errors = _errorMessages.entries.toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Row(
          children: [
            Icon(
              failCount == 0 ? Icons.check_circle : Icons.warning,
              color: failCount == 0 ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            const Text('Batch Conversion Complete', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Successfully converted: $successCount file(s)',
              style: const TextStyle(color: Colors.green),
            ),
            if (failCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Failed: $failCount file(s)',
                style: const TextStyle(color: Colors.red),
              ),
              if (errors.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: errors.map((entry) {
                        final filename = path_util.basename(entry.key);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $filename: ${entry.value}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Performance Statistics:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total time: ${_formatDuration(_totalElapsedTime)}',
                    style: const TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                  Text(
                    'Average speed: ${_calculateSpeed()}',
                    style: const TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                  Text(
                    'Parallel jobs used: $_parallelJobs',
                    style: const TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showHardwareOptimizationInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        contentPadding: const EdgeInsets.all(0),
        content: Container(
          width: 600,
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.memory, color: Colors.blue, size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Hardware Optimization Guide',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // System info
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.computer, color: Colors.blue, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Your System',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'CPU Cores: ${Platform.numberOfProcessors}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            Text(
                              'Recommended Parallel Jobs: ${_parallelJobs <= 4 ? _parallelJobs : "3-4"}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            const Text(
                              'Max Safe Parallel: $_maxSafeParallelJobs',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // CPU optimization
                      _buildInfoSection(
                        icon: Icons.memory,
                        title: 'CPU Optimization',
                        color: Colors.green,
                        content: [
                          'Most important for audio conversion',
                          '• Use 3-4 parallel conversions maximum',
                          '• Each conversion uses 2-4 CPU threads',
                          '• Modern CPUs have SIMD for audio processing',
                          '• Ensure good cooling to prevent throttling',
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Storage optimization
                      _buildInfoSection(
                        icon: Icons.storage,
                        title: 'Storage Optimization',
                        color: Color.fromARGB(255, 39, 176, 69),
                        content: [
                          'Often the biggest bottleneck',
                          '• SSD: 2-3x faster than HDD',
                          '• NVMe: 5-10x faster than HDD',
                          '• Separate input/output drives if possible',
                          '• Avoid network drives for best performance',
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Memory optimization
                      _buildInfoSection(
                        icon: Icons.memory,
                        title: 'Memory Usage',
                        color: Colors.cyan,
                        content: [
                          'Each conversion uses 200-500MB RAM',
                          '• 4 parallel = ~2GB RAM usage',
                          '• 8 parallel = ~4GB RAM usage',
                          '• Leave 4GB+ free for system stability',
                          '• Close Chrome/browsers to free memory',
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoSection({
    required IconData icon,
    required String title,
    required Color color,
    required List<String> content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...content.map((text) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              text,
              style: TextStyle(
                color: text.startsWith('•') ? Colors.grey[300] : Colors.white,
                fontSize: 14,
              ),
            ),
          )),
        ],
      ),
    );
  }
  
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}