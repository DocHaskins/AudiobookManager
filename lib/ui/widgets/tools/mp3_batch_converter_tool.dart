// lib/ui/widgets/tools/mp3_batch_converter_tool.dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/audio_conversion_service.dart';
import 'package:audiobook_organizer/utils/audio_processors/base_audio_processor.dart';
import 'package:audiobook_organizer/utils/system_optimization/hardware_detector.dart';
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

class _Mp3BatchConverterToolState extends State<Mp3BatchConverterTool> with TickerProviderStateMixin {
  List<AudiobookFile> _mp3Files = [];
  Set<String> _selectedFiles = {};
  bool _isLoading = true;
  bool _isConverting = false;
  String _statusMessage = '';

  bool _isSettingsExpanded = false;
  bool _showTips = false;
  bool _preserveOriginalBitrate = true;
  
  // Enhanced progress tracking
  ProcessingUpdate? _currentUpdate;
  StreamSubscription<ProcessingUpdate>? _progressSubscription;
  DateTime? _conversionStartTime;
  Timer? _progressTimer;
  
  // Individual file progress tracking with enhanced data
  Map<String, FileProgressInfo> _fileProgress = {};
  List<String> _processingQueue = [];
  int _completedCount = 0;
  int _failedCount = 0;
  
  // Performance metrics
  double _overallProgress = 0.0;
  String _currentSpeed = '';
  Duration _elapsedTime = Duration.zero;
  Duration? _estimatedTimeRemaining;
  
  // Animation controllers for smooth progress
  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;
  
  // Quality settings
  String _selectedBitrate = '128k';
  final List<String> _bitrateOptions = ['64k', '96k', '128k', '160k', '192k', '256k'];
  
  // System capabilities and settings
  int _parallelJobs = 1;
  int _maxParallelJobs = 1;
  static const int _maxSafeParallelJobs = 8;
  
  // Filter and sort options
  String _sortBy = 'title';
  bool _sortAscending = true;
  String _filterText = '';
  
  @override
  void initState() {
    super.initState();
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressAnimationController, curve: Curves.easeInOut),
    );
    _initializeServices();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _progressTimer?.cancel();
    _progressAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    // First initialize the audio conversion service
    await widget.audioConversionService.initialize();
    
    // Then detect system capabilities
    _detectSystemCapabilities();
    
    // Finally load MP3 files
    await _loadMp3Files();
  }

  void _detectSystemCapabilities() {
    final capabilities = widget.audioConversionService.systemCapabilities;
    if (capabilities != null) {
      setState(() {
        // Ensure _maxParallelJobs is always at least 1
        _maxParallelJobs = capabilities.cpuCores.clamp(1, _maxSafeParallelJobs);
        
        // Set default parallel jobs based on cores, ensuring it's within valid range
        if (capabilities.cpuCores >= 8) {
          _parallelJobs = 3;
        } else if (capabilities.cpuCores >= 4) {
          _parallelJobs = 2;
        } else {
          _parallelJobs = 1;
        }
        
        // Ensure _parallelJobs doesn't exceed _maxParallelJobs
        _parallelJobs = _parallelJobs.clamp(1, _maxParallelJobs);
      });
      Logger.log('System capabilities detected: ${capabilities.cpuCores} cores, parallel jobs: $_parallelJobs, max: $_maxParallelJobs');
    } else {
      // Fallback values if capabilities detection fails
      setState(() {
        _maxParallelJobs = 4; // Safe default
        _parallelJobs = 1;    // Conservative default
      });
      Logger.warning('System capabilities not detected, using fallback values');
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
              if (_currentSpeed.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _currentSpeed,
                    style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Overall progress bar
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return Column(
                children: [
                  LinearProgressIndicator(
                    value: _overallProgress,
                    backgroundColor: Colors.grey[800],
                    valueColor: const AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 39, 176, 69)),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(_overallProgress * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$_completedCount / ${_selectedFiles.length} files',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Time information
          Row(
            children: [
              // Elapsed time
              Expanded(
                child: _buildTimeCard(
                  icon: Icons.timer,
                  label: 'Elapsed',
                  value: _formatDuration(_elapsedTime),
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              
              // Estimated time remaining
              Expanded(
                child: _buildTimeCard(
                  icon: Icons.schedule,
                  label: 'ETA',
                  value: _estimatedTimeRemaining != null 
                      ? _formatDuration(_estimatedTimeRemaining!)
                      : '--:--',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              
              // Status
              Expanded(
                child: _buildTimeCard(
                  icon: Icons.info,
                  label: 'Status',
                  value: _getShortStatus(),
                  color: const Color.fromARGB(255, 39, 176, 69),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Current status message
          if (_statusMessage.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Text(
                _statusMessage,
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

  String _getShortStatus() {
    if (_currentUpdate?.stage.isNotEmpty == true) {
      final stage = _currentUpdate!.stage;
      if (stage.contains('Converting')) return 'Converting';
      if (stage.contains('Processing')) return 'Processing';
      if (stage.contains('Finalizing')) return 'Finalizing';
      return 'Working';
    }
    return 'Starting';
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
          // Header - always visible and clickable
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
                  IconButton(
                    onPressed: _showHardwareOptimizationInfo,
                    icon: const Icon(Icons.memory, size: 20),
                    color: Colors.blue,
                    tooltip: 'Hardware Optimization Info',
                  ),
                  Icon(
                    _isSettingsExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          // Collapsible content
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _isSettingsExpanded 
                ? CrossFadeState.showSecond 
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(),
            secondChild: Padding(
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
                                Text('1', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                Expanded(
                                  child: Slider(
                                    value: _parallelJobs.toDouble(),
                                    min: 1,
                                    max: _maxParallelJobs.toDouble(),
                                    divisions: _maxParallelJobs > 1 ? _maxParallelJobs - 1 : null,
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
                                Text(_maxParallelJobs.toString(), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
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
                            // Only show dropdown when preserve original is false
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
                  const SizedBox(height: 16),
                  // Performance tips - collapsible
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              _showTips = !_showTips;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
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
                                const Spacer(),
                                Icon(
                                  _showTips ? Icons.expand_less : Icons.expand_more,
                                  color: Colors.blue[400],
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 200),
                          crossFadeState: _showTips 
                              ? CrossFadeState.showSecond 
                              : CrossFadeState.showFirst,
                          firstChild: const SizedBox(),
                          secondChild: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Divider(color: Colors.blue),
                                const SizedBox(height: 8),
                                Text('• Use SSD storage for 2-3x faster conversion', 
                                    style: TextStyle(color: Colors.blue[300], fontSize: 12)),
                                Text('• Close other applications to free up memory', 
                                    style: TextStyle(color: Colors.blue[300], fontSize: 12)),
                                Text('• Disable antivirus scanning on working directories', 
                                    style: TextStyle(color: Colors.blue[300], fontSize: 12)),
                                Text('• For 400+ files: Use 3-4 parallel conversions maximum', 
                                    style: TextStyle(color: Colors.blue[300], fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
    final totalSize = filteredFiles.fold<int>(0, (sum, file) => sum + file.fileSize);
    
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
              icon: Icons.check_circle,
              label: 'Completed',
              value: _completedCount.toString(),
              color: const Color.fromARGB(255, 39, 176, 69),
            ),
            if (_failedCount > 0)
              _buildStatItem(
                icon: Icons.error,
                label: 'Failed',
                value: _failedCount.toString(),
                color: Colors.red,
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
    final progressInfo = _fileProgress[file.path];
    
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
                
                // Enhanced status display
                SizedBox(
                  width: 150,
                  child: _buildEnhancedFileStatus(file, progressInfo),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedFileStatus(AudiobookFile file, FileProgressInfo? progressInfo) {
    if (progressInfo == null) {
      return const SizedBox();
    }
    
    switch (progressInfo.status) {
      case FileStatus.waiting:
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
        
      case FileStatus.converting:
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
        
      case FileStatus.completed:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 16),
            const SizedBox(width: 4),
            Column(
              children: [
                Text(
                  'Completed',
                  style: TextStyle(color: Colors.green[400], fontSize: 12),
                ),
                if (progressInfo.elapsedTime != null)
                  Text(
                    _formatDuration(progressInfo.elapsedTime!),
                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                  ),
              ],
            ),
          ],
        );
        
      case FileStatus.failed:
        return Tooltip(
          message: progressInfo.errorMessage ?? 'Unknown error',
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

  // PROCESSING METHODS - Enhanced with better progress tracking

  Future<void> _startBatchConversion() async {
    if (_selectedFiles.isEmpty) return;

    // Validate environment
    final validation = await widget.audioConversionService.validateEnvironment();
    if (!validation.isValid) {
      _showErrorDialog('Requirements Not Met', validation.issues.join('\n'));
      return;
    }

    // Warn about high parallel conversion count
    if (_parallelJobs > 4) {
      final continueHighParallel = await _showParallelWarningDialog();
      if (!continueHighParallel) return;
    }

    // Get confirmation
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    // Start conversion
    await _executeConversion();
  }

  Future<void> _executeConversion() async {
    setState(() {
      _isConverting = true;
      _statusMessage = 'Starting batch conversion...';
      _conversionStartTime = DateTime.now();
      _completedCount = 0;
      _failedCount = 0;
      _overallProgress = 0.0;
      _currentSpeed = '';
      _elapsedTime = Duration.zero;
      _estimatedTimeRemaining = null;
      
      // Initialize file progress tracking
      _fileProgress.clear();
      _processingQueue.clear();
      
      // Set up initial file progress info
      for (final filePath in _selectedFiles) {
        _fileProgress[filePath] = FileProgressInfo(
          filePath: filePath,
          status: FileStatus.waiting,
          progress: 0.0,
        );
        _processingQueue.add(filePath);
      }
    });

    // Start progress timer for elapsed time tracking
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_conversionStartTime != null) {
        setState(() {
          _elapsedTime = DateTime.now().difference(_conversionStartTime!);
        });
      }
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

      // Start conversion and listen to progress with enhanced tracking
      _progressSubscription = widget.audioConversionService.progressStream?.listen(
        (update) {
          if (mounted) {
            _handleProgressUpdate(update);
          }
        },
        onError: (error) {
          Logger.error('Error in conversion progress stream: $error');
          if (mounted) {
            setState(() {
              _statusMessage = 'Progress tracking error: $error';
            });
          }
        },
      );

      final result = await widget.audioConversionService.startBatchConversion(
        files: selectedFilesList,
        config: config,
      );

      // Handle result
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
      _progressTimer?.cancel();
      _progressTimer = null;
    }
  }

  void _handleProgressUpdate(ProcessingUpdate update) {
    setState(() {
      _currentUpdate = update;
      _statusMessage = update.stage;
      _overallProgress = update.progress?.clamp(0.0, 1.0) ?? 0.0;
      
      // Extract speed information
      if (update.speed?.isNotEmpty == true) {
        _currentSpeed = update.speed!;
      }
      
      // Calculate ETA
      if (update.estimatedTimeRemaining != null) {
        _estimatedTimeRemaining = update.estimatedTimeRemaining;
      } else if (_elapsedTime.inSeconds > 0 && _overallProgress > 0.01) {
        // Calculate ETA based on current progress
        final totalEstimatedSeconds = _elapsedTime.inSeconds / _overallProgress;
        final remainingSeconds = totalEstimatedSeconds - _elapsedTime.inSeconds;
        if (remainingSeconds > 0) {
          _estimatedTimeRemaining = Duration(seconds: remainingSeconds.round());
        }
      }
      
      // Update individual file progress
      _updateIndividualFileProgress(update);
      
      // Update completed/failed counts
      _updateCompletionCounts();
    });
    
    // Animate progress bar
    _progressAnimationController.animateTo(_overallProgress);
  }

  void _updateIndividualFileProgress(ProcessingUpdate update) {
    // Handle current file being processed
    if (update.currentFile != null) {
      final currentFile = update.currentFile!;
      String? matchingFilePath = _findMatchingFilePath(currentFile);
      
      if (matchingFilePath != null) {
        final existing = _fileProgress[matchingFilePath];
        if (existing != null) {
          _fileProgress[matchingFilePath] = existing.copyWith(
            status: FileStatus.converting,
            progress: update.progress?.clamp(0.0, 1.0) ?? existing.progress,
            speed: update.speed ?? existing.speed,
          );
        }
      }
    }
    
    // Handle metadata updates for completed/failed files
    if (update.metadata.isNotEmpty) {
      // Handle completed files
      if (update.metadata.containsKey('completed_files')) {
        final completedFiles = update.metadata['completed_files'] as List<String>?;
        if (completedFiles != null) {
          for (final completedFile in completedFiles) {
            String? matchingFilePath = _findMatchingFilePath(completedFile);
            if (matchingFilePath != null) {
              final existing = _fileProgress[matchingFilePath];
              if (existing != null) {
                _fileProgress[matchingFilePath] = existing.copyWith(
                  status: FileStatus.completed,
                  progress: 1.0,
                  elapsedTime: existing.startTime != null 
                      ? DateTime.now().difference(existing.startTime!)
                      : null,
                );
              }
            }
          }
        }
      }
      
      // Handle failed files
      if (update.metadata.containsKey('failed_files')) {
        final failedFiles = update.metadata['failed_files'] as Map<String, String>?;
        if (failedFiles != null) {
          for (final entry in failedFiles.entries) {
            String? matchingFilePath = _findMatchingFilePath(entry.key);
            if (matchingFilePath != null) {
              final existing = _fileProgress[matchingFilePath];
              if (existing != null) {
                _fileProgress[matchingFilePath] = existing.copyWith(
                  status: FileStatus.failed,
                  errorMessage: entry.value,
                  elapsedTime: existing.startTime != null 
                      ? DateTime.now().difference(existing.startTime!)
                      : null,
                );
              }
            }
          }
        }
      }
      
      // Handle files that just started
      if (update.metadata.containsKey('started_files')) {
        final startedFiles = update.metadata['started_files'] as List<String>?;
        if (startedFiles != null) {
          for (final startedFile in startedFiles) {
            String? matchingFilePath = _findMatchingFilePath(startedFile);
            if (matchingFilePath != null) {
              final existing = _fileProgress[matchingFilePath];
              if (existing != null) {
                _fileProgress[matchingFilePath] = existing.copyWith(
                  status: FileStatus.converting,
                  startTime: DateTime.now(),
                );
              }
            }
          }
        }
      }
    }
  }

  String? _findMatchingFilePath(String fileName) {
    // Try to find the full path that matches the given filename
    for (final filePath in _selectedFiles) {
      if (path_util.basename(filePath) == path_util.basename(fileName) ||
          filePath == fileName ||
          path_util.basenameWithoutExtension(filePath) == path_util.basenameWithoutExtension(fileName)) {
        return filePath;
      }
    }
    return null;
  }

  void _updateCompletionCounts() {
    _completedCount = _fileProgress.values
        .where((info) => info.status == FileStatus.completed)
        .length;
    
    _failedCount = _fileProgress.values
        .where((info) => info.status == FileStatus.failed)
        .length;
  }

  Future<void> _handleConversionResult(ProcessingResult result) async {
    if (!mounted) return;
    
    setState(() {
      _isConverting = false;
      _currentUpdate = null;
      
      // Final update of file statuses based on result
      if (result.success) {
        // Mark successful conversions
        for (final outputFile in result.outputFiles) {
          final baseName = path_util.basenameWithoutExtension(outputFile);
          String? matchingInputFile = _findMatchingFilePathByBasename(baseName);
          
          if (matchingInputFile != null) {
            final existing = _fileProgress[matchingInputFile];
            if (existing != null) {
              _fileProgress[matchingInputFile] = existing.copyWith(
                status: FileStatus.completed,
                progress: 1.0,
                elapsedTime: existing.startTime != null 
                    ? DateTime.now().difference(existing.startTime!)
                    : null,
              );
            }
          }
        }
      }
      
      // Mark failed conversions
      for (final error in result.errors) {
        final existing = _fileProgress[error.filePath];
        if (existing != null) {
          _fileProgress[error.filePath] = existing.copyWith(
            status: FileStatus.failed,
            errorMessage: error.message,
            elapsedTime: existing.startTime != null 
                ? DateTime.now().difference(existing.startTime!)
                : null,
          );
        }
      }
      
      // Update final counts
      _updateCompletionCounts();
      
      // Clear selection
      _selectedFiles.clear();
    });

    if (result.success) {
      setState(() {
        _statusMessage = 'Conversion completed: ${result.successCount} files converted successfully in ${_formatDuration(_elapsedTime)}';
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

  String? _findMatchingFilePathByBasename(String baseName) {
    for (final filePath in _selectedFiles) {
      if (path_util.basenameWithoutExtension(filePath) == baseName) {
        return filePath;
      }
    }
    return null;
  }

  Future<void> _cancelConversion() async {
    await widget.audioConversionService.cancelCurrentOperation();
    if (mounted) {
      setState(() {
        _statusMessage = 'Conversion cancelled after ${_formatDuration(_elapsedTime)}';
        _isConverting = false;
        _currentUpdate = null;
        
        // Update any files that were converting to cancelled
        for (final filePath in _fileProgress.keys.toList()) {
          final existing = _fileProgress[filePath];
          if (existing != null && existing.status == FileStatus.converting) {
            _fileProgress[filePath] = existing.copyWith(
              status: FileStatus.failed,
              errorMessage: 'Cancelled by user',
              elapsedTime: existing.startTime != null 
                  ? DateTime.now().difference(existing.startTime!)
                  : null,
            );
          }
        }
        
        _updateCompletionCounts();
      });
    }
    
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  // HELPER METHODS

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

  Future<bool> _showParallelWarningDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('High Parallel Count Warning', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'You have selected $_parallelJobs parallel conversions.\n\n'
          'This may cause high memory usage and system slowdowns.\n\n'
          'Recommended: 1-4 parallel conversions for stability.',
          style: const TextStyle(color: Colors.grey),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Continue with $_parallelJobs'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

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
            Text('Total time: ${_formatDuration(_elapsedTime)}', style: const TextStyle(color: Colors.blue)),
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
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.memory, color: Colors.blue, size: 24),
                    SizedBox(width: 12),
                    Text(
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      
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
                      
                      _buildInfoSection(
                        icon: Icons.storage,
                        title: 'Storage Optimization',
                        color: const Color.fromARGB(255, 39, 176, 69),
                        content: [
                          'Often the biggest bottleneck',
                          '• SSD: 2-3x faster than HDD',
                          '• NVMe: 5-10x faster than HDD',
                          '• Separate input/output drives if possible',
                          '• Avoid network drives for best performance',
                        ],
                      ),
                      const SizedBox(height: 16),
                      
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

// Enhanced file progress tracking classes
enum FileStatus {
  waiting,
  converting,
  completed,
  failed,
}

class FileProgressInfo {
  final String filePath;
  final FileStatus status;
  final double progress;
  final String speed;
  final String? errorMessage;
  final DateTime? startTime;
  final Duration? elapsedTime;

  const FileProgressInfo({
    required this.filePath,
    required this.status,
    required this.progress,
    this.speed = '',
    this.errorMessage,
    this.startTime,
    this.elapsedTime,
  });

  FileProgressInfo copyWith({
    String? filePath,
    FileStatus? status,
    double? progress,
    String? speed,
    String? errorMessage,
    DateTime? startTime,
    Duration? elapsedTime,
  }) {
    return FileProgressInfo(
      filePath: filePath ?? this.filePath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      errorMessage: errorMessage ?? this.errorMessage,
      startTime: startTime ?? this.startTime,
      elapsedTime: elapsedTime ?? this.elapsedTime,
    );
  }
}