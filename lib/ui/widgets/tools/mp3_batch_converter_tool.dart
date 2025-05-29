// lib/ui/widgets/tools/mp3_batch_converter_tool.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/audio_conversion_service.dart';
import 'package:audiobook_organizer/utils/audio_processors/base_audio_processor.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class Mp3BatchConverterTool extends StatefulWidget {
  final LibraryManager libraryManager;
  final AudioConversionService audioConversionService;

  const Mp3BatchConverterTool({
    Key? key,
    required this.libraryManager,
    required this.audioConversionService,
  }) : super(key: key);

  @override
  State<Mp3BatchConverterTool> createState() => _Mp3BatchConverterToolState();
}

class _Mp3BatchConverterToolState extends State<Mp3BatchConverterTool> {
  // Data state
  List<AudiobookFile> _mp3Files = [];
  Set<String> _selectedFiles = {};
  bool _isLoading = true;
  bool _isConverting = false;
  String _statusMessage = '';

  // UI state
  bool _isSettingsExpanded = false;
  bool _showTips = false;

  // Configuration
  bool _preserveOriginalBitrate = true;
  String _selectedBitrate = '128k';
  final List<String> _bitrateOptions = ['64k', '96k', '128k', '160k', '192k', '256k'];
  int _parallelJobs = 1;
  int _maxParallelJobs = 1;

  // Filter and sort
  String _sortBy = 'title';
  bool _sortAscending = true;
  String _filterText = '';

  // Progress display (populated from service updates)
  ProcessingUpdate? _currentProgressUpdate;
  StreamSubscription<ProcessingUpdate>? _progressSubscription;
  
  // Individual file progress (extracted from service metadata)
  Map<String, FileProgressDisplay> _fileProgressInfo = {};

  @override
  void initState() {
    super.initState();
    _initializeComponent();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeComponent() async {
    // Initialize the audio conversion service
    await widget.audioConversionService.initialize();
    
    // Detect system capabilities for UI configuration
    _detectSystemCapabilities();
    
    // Load MP3 files
    await _loadMp3Files();
  }

  void _detectSystemCapabilities() {
    final capabilities = widget.audioConversionService.systemCapabilities;
    if (capabilities != null) {
      setState(() {
        _maxParallelJobs = capabilities.cpuCores.clamp(1, 8);
        
        // Set default parallel jobs based on cores
        if (capabilities.cpuCores >= 8) {
          _parallelJobs = 3;
        } else if (capabilities.cpuCores >= 4) {
          _parallelJobs = 2;
        } else {
          _parallelJobs = 1;
        }
        
        _parallelJobs = _parallelJobs.clamp(1, _maxParallelJobs);
      });
      
      Logger.log('UI: Detected ${capabilities.cpuCores} cores, max parallel jobs: $_maxParallelJobs');
    } else {
      setState(() {
        _maxParallelJobs = 4;
        _parallelJobs = 1;
      });
      Logger.warning('UI: System capabilities not detected, using defaults');
    }
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
          _buildStats(),
          const SizedBox(height: 16),
          _buildSettingsPanel(),
          const SizedBox(height: 16),
          if (_isConverting) _buildProgressPanel(),
          if (_isConverting) const SizedBox(height: 16),
          _buildToolbar(),
          const SizedBox(height: 16),
          Expanded(child: _buildFilesList()),
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

  Widget _buildProgressPanel() {
    if (_currentProgressUpdate == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color.fromARGB(255, 39, 176, 69).withOpacity(0.3)),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color.fromARGB(255, 39, 176, 69),
          ),
        ),
      );
    }

    final update = _currentProgressUpdate!;
    final progress = update.progress ?? 0.0;
    final completedCount = _getCompletedCount();
    final failedCount = _getFailedCount();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color.fromARGB(255, 39, 176, 69).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.transform, color: Color.fromARGB(255, 39, 176, 69), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Conversion Progress',
                style: TextStyle(
                  color: Color.fromARGB(255, 39, 176, 69),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (update.speed?.isNotEmpty == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    update.speed!,
                    style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Progress bar
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[800],
            valueColor: const AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 39, 176, 69)),
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          
          // Progress info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toStringAsFixed(1)}%',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              if (update.completedFiles != null && update.totalFiles != null)
                Text(
                  '${update.completedFiles} / ${update.totalFiles} files',
                  style: TextStyle(color: Colors.grey[400]),
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Time information
          Row(
            children: [
              if (update.elapsedTime != null)
                Expanded(
                  child: _buildTimeCard(
                    icon: Icons.timer,
                    label: 'Elapsed',
                    value: _formatDuration(update.elapsedTime!),
                    color: Colors.blue,
                  ),
                ),
              if (update.elapsedTime != null && update.estimatedTimeRemaining != null)
                const SizedBox(width: 12),
              if (update.estimatedTimeRemaining != null)
                Expanded(
                  child: _buildTimeCard(
                    icon: Icons.schedule,
                    label: 'ETA',
                    value: _formatDuration(update.estimatedTimeRemaining!),
                    color: Colors.orange,
                  ),
                ),
              if ((update.elapsedTime != null || update.estimatedTimeRemaining != null) && (completedCount > 0 || failedCount > 0))
                const SizedBox(width: 12),
              if (completedCount > 0 || failedCount > 0)
                Expanded(
                  child: _buildTimeCard(
                    icon: completedCount > 0 ? Icons.check_circle : Icons.error,
                    label: 'Status',
                    value: '$completedCount✓ ${failedCount > 0 ? '$failedCount✗' : ''}',
                    color: failedCount > 0 ? Colors.orange : const Color.fromARGB(255, 39, 176, 69),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Current status
          if (update.stage.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Text(
                update.stage,
                style: TextStyle(color: Colors.blue[300], fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () {
              setState(() {
                _isSettingsExpanded = !_isSettingsExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
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
                  Icon(
                    _isSettingsExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable content
          if (_isSettingsExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Colors.grey),
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
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text('1', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                Expanded(
                                  child: Slider(
                                    value: _parallelJobs.toDouble(),
                                    min: 1,
                                    max: _maxParallelJobs.toDouble(),
                                    divisions: _maxParallelJobs > 1 ? _maxParallelJobs - 1 : null,
                                    label: _parallelJobs.toString(),
                                    activeColor: Colors.blue,
                                    onChanged: _isConverting ? null : (value) {
                                      setState(() {
                                        _parallelJobs = value.round();
                                      });
                                    },
                                  ),
                                ),
                                Text(_maxParallelJobs.toString(), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _parallelJobs.toString(),
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      
                      // Audio quality setting
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
                                Checkbox(
                                  value: _preserveOriginalBitrate,
                                  onChanged: _isConverting ? null : (value) {
                                    setState(() {
                                      _preserveOriginalBitrate = value ?? true;
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
                            if (!_preserveOriginalBitrate) ...[
                              const SizedBox(height: 8),
                              Container(
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
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
          ),
          
          const SizedBox(width: 16),
          
          // Select all/none
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
    final totalSize = filteredFiles.fold<int>(0, (sum, file) => sum + file.fileSize);
    final completedCount = _getCompletedCount();
    final failedCount = _getFailedCount();
    
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
          if (_isConverting && completedCount > 0) 
            _buildStatItem(
              icon: Icons.check_circle,
              label: 'Completed',
              value: completedCount.toString(),
              color: const Color.fromARGB(255, 39, 176, 69),
            ),
          if (_isConverting && failedCount > 0)
            _buildStatItem(
              icon: Icons.error,
              label: 'Failed',
              value: failedCount.toString(),
              color: Colors.red,
            ),
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
      return const Center(child: CircularProgressIndicator());
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
              border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 40),
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
                  width: 150,
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
    final fileName = path_util.basename(file.path);
    final progressInfo = _fileProgressInfo[fileName];
    
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
        border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
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
                
                // Status (from service progress data)
                SizedBox(
                  width: 150,
                  child: _buildFileStatus(progressInfo),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileStatus(FileProgressDisplay? progressInfo) {
    if (progressInfo == null) {
      return const SizedBox();
    }
    
    switch (progressInfo.status) {
      case 'waiting':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, color: Colors.grey[500], size: 16),
            const SizedBox(width: 4),
            Text(
              'Waiting...',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        );
        
      case 'converting':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progressInfo.progress,
                    backgroundColor: Colors.grey[800],
                    valueColor: const AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 39, 176, 69)),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(progressInfo.progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Color.fromARGB(255, 39, 176, 69), fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Converting',
                  style: TextStyle(color: Colors.grey[400], fontSize: 10),
                ),
                if (progressInfo.speed.isNotEmpty)
                  Text(
                    progressInfo.speed,
                    style: const TextStyle(color: Color.fromARGB(255, 39, 176, 69), fontSize: 10),
                  ),
              ],
            ),
          ],
        );
        
      case 'completed':
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
        
      case 'failed':
        return Tooltip(
          message: progressInfo.errorMessage,
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
          if (_statusMessage.isNotEmpty && !_isConverting) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.green[400],
                    size: 16,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: TextStyle(color: Colors.green[300]),
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
                  onPressed: (hasSelection && !_isConverting) ? _startBatchConversion : null,
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
                        ? 'Converting...'
                        : 'Convert Selected (${_selectedFiles.length})',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 39, 176, 69),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // SIMPLE ACTION METHODS (No processing logic)

  Future<void> _startBatchConversion() async {
    if (_selectedFiles.isEmpty) return;

    // Validate environment
    final validation = await widget.audioConversionService.validateEnvironment();
    if (!validation.isValid) {
      _showErrorDialog('Requirements Not Met', validation.issues.join('\n'));
      return;
    }

    // Get confirmation
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    // Start conversion via service
    await _executeConversion();
  }

  Future<void> _executeConversion() async {
    setState(() {
      _isConverting = true;
      _statusMessage = 'Starting batch conversion...';
      _currentProgressUpdate = null;
      _fileProgressInfo.clear();
    });

    try {
      // Get selected files
      final selectedFilesList = _mp3Files.where(
        (file) => _selectedFiles.contains(file.path)
      ).toList();

      // Create configuration
      final config = AudioProcessingConfig(
        parallelJobs: _parallelJobs,
        bitrate: _preserveOriginalBitrate ? null : _selectedBitrate,
        preserveOriginalBitrate: _preserveOriginalBitrate,
      );

      // Listen to progress updates from the service
      _progressSubscription = widget.audioConversionService.progressStream?.listen(
        (update) {
          if (mounted) {
            _updateFromProgressUpdate(update);
          }
        },
        onError: (error) {
          Logger.error('Progress stream error: $error');
          if (mounted) {
            setState(() {
              _statusMessage = 'Progress tracking error: $error';
            });
          }
        },
      );

      // Start the conversion (service handles all processing)
      final result = await widget.audioConversionService.startBatchConversion(
        files: selectedFilesList,
        config: config,
      );

      // Handle the result
      await _handleConversionResult(result);

    } catch (e) {
      Logger.error('Error in batch conversion: $e');
      if (mounted) {
        setState(() {
          _statusMessage = 'Error: $e';
          _isConverting = false;
        });
      }
    } finally {
      _progressSubscription?.cancel();
      _progressSubscription = null;
    }
  }

  void _updateFromProgressUpdate(ProcessingUpdate update) {
    setState(() {
      _currentProgressUpdate = update;
      _statusMessage = update.stage;
      
      // Extract individual file progress from metadata
      _extractFileProgressFromMetadata(update.metadata);
    });
  }

  void _extractFileProgressFromMetadata(Map<String, dynamic> metadata) {
    try {
      // Extract file progress information from service metadata
      final fileProgress = metadata['file_progress'] as Map<dynamic, dynamic>?;
      final fileStatus = metadata['file_status'] as Map<dynamic, dynamic>?;
      final fileSpeed = metadata['file_speed'] as Map<dynamic, dynamic>?;
      final completedFiles = metadata['completed_files'] as List<dynamic>?;
      final failedFiles = metadata['failed_files'] as Map<dynamic, dynamic>?;

      // Clear existing progress info
      _fileProgressInfo.clear();

      // Process file progress data
      if (fileProgress != null && fileStatus != null) {
        for (final entry in fileProgress.entries) {
          final fileName = entry.key.toString();
          final progress = (entry.value as num?)?.toDouble() ?? 0.0;
          final status = fileStatus[fileName]?.toString() ?? 'waiting';
          final speed = fileSpeed?[fileName]?.toString() ?? '';

          _fileProgressInfo[fileName] = FileProgressDisplay(
            fileName: fileName,
            status: status,
            progress: progress,
            speed: speed,
            errorMessage: '',
          );
        }
      }

      // Process completed files
      if (completedFiles != null) {
        for (final completedFile in completedFiles) {
          final fileName = completedFile.toString();
          _fileProgressInfo[fileName] = FileProgressDisplay(
            fileName: fileName,
            status: 'completed',
            progress: 1.0,
            speed: '',
            errorMessage: '',
          );
        }
      }

      // Process failed files
      if (failedFiles != null) {
        for (final entry in failedFiles.entries) {
          final fileName = entry.key.toString();
          final errorMessage = entry.value.toString();
          _fileProgressInfo[fileName] = FileProgressDisplay(
            fileName: fileName,
            status: 'failed',
            progress: 0.0,
            speed: '',
            errorMessage: errorMessage,
          );
        }
      }
    } catch (e) {
      Logger.error('Error extracting file progress from metadata: $e');
    }
  }

  int _getCompletedCount() {
    return _currentProgressUpdate?.metadata['success_count'] as int? ?? 0;
  }

  int _getFailedCount() {
    return _currentProgressUpdate?.metadata['failed_count'] as int? ?? 0;
  }

  Future<void> _handleConversionResult(ProcessingResult result) async {
    if (!mounted) return;
    
    setState(() {
      _isConverting = false;
      _currentProgressUpdate = null;
      _fileProgressInfo.clear();
      _selectedFiles.clear();
    });

    if (result.success) {
      setState(() {
        _statusMessage = 'Conversion completed: ${result.successCount} files converted successfully';
      });
      _showResultsDialog(result.successCount, result.errorCount, result.errors);
    } else {
      setState(() {
        _statusMessage = 'Conversion failed: ${result.errorCount} errors occurred';
      });
      _showResultsDialog(result.successCount, result.errorCount, result.errors);
    }

    // Reload library to reflect changes
    await _loadMp3Files();
  }

  Future<void> _cancelConversion() async {
    await widget.audioConversionService.cancelCurrentOperation();
    if (mounted) {
      setState(() {
        _statusMessage = 'Conversion cancelled';
        _isConverting = false;
        _currentProgressUpdate = null;
        _fileProgressInfo.clear();
      });
    }
  }

  // HELPER METHODS (Data management only)

  Future<void> _loadMp3Files() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading MP3 files from library...';
    });

    try {
      final allFiles = widget.libraryManager.files;
      final mp3Files = allFiles.where((file) => 
        file.extension.toLowerCase() == '.mp3'
      ).toList();

      setState(() {
        _mp3Files = mp3Files;
        _isLoading = false;
        _statusMessage = 'Found ${mp3Files.length} MP3 files in library';
      });

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

  // DIALOG METHODS

  Future<bool> _showConfirmationDialog() async {
    final result = await showDialog<bool>(
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
        content: Text(
          'Convert ${_selectedFiles.length} MP3 file(s) to M4B format?\n\n'
          'Settings:\n'
          '• Parallel conversions: $_parallelJobs\n'
          '• Audio quality: ${_preserveOriginalBitrate ? "Preserve original" : _selectedBitrate}\n\n'
          'This will delete the original MP3 files after successful conversion.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 39, 176, 69),
            ),
            child: const Text('Convert All'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showResultsDialog(int successCount, int failCount, List<ProcessingError> errors) {
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
            Text('Successfully converted: $successCount file(s)', style: const TextStyle(color: Colors.green)),
            if (failCount > 0) ...[
              const SizedBox(height: 8),
              Text('Failed: $failCount file(s)', style: const TextStyle(color: Colors.red)),
              if (errors.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: errors.map((error) {
                        final filename = path_util.basename(error.filePath);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $filename: ${error.message}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ],
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
        content: Text(message, style: const TextStyle(color: Colors.grey)),
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

// Simple data class to hold file progress information from service
class FileProgressDisplay {
  final String fileName;
  final String status;
  final double progress;
  final String speed;
  final String errorMessage;

  const FileProgressDisplay({
    required this.fileName,
    required this.status,
    required this.progress,
    required this.speed,
    required this.errorMessage,
  });
}