// =============================================================================
// lib/ui/widgets/detail/sections/file_info_section.dart
// =============================================================================

import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/ui/widgets/detail/metadata_utils.dart';

class FileInfoSection extends StatelessWidget {
  final AudiobookFile book;

  const FileInfoSection({
    Key? key,
    required this.book,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final metadata = book.metadata;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FILE INFORMATION',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          
          // Essential file information
          _buildInfoRow('File Name', book.filename),
          _buildInfoRow('File Path', book.path, isPath: true),
          _buildInfoRow('File Size', MetadataUtils.formatFileSize(book.fileSize)),
          _buildInfoRow('Date Added', MetadataUtils.formatDate(book.lastModified)),
          _buildInfoRow('Format', book.extension.replaceFirst('.', '').toUpperCase()),
          
          // Metadata-dependent information
          if (metadata?.audioDuration != null)
            _buildInfoRow('Duration', metadata!.durationFormatted)
          else
            _buildInfoRow('Duration', 'Not available'),
            
          if (metadata?.language.isNotEmpty ?? false)
            _buildInfoRow('Language', metadata!.language),

        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isPath = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: isPath
                    ? SelectableText(
                        value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      )
                    : Text(
                        value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        maxLines: isPath ? null : 3,
                        overflow: isPath ? null : TextOverflow.ellipsis,
                      ),
              ),
            ],
          ),
          if (isPath && value.length > 60) const SizedBox(height: 4),
        ],
      ),
    );
  }
}