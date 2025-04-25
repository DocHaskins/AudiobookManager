import 'package:audiobook_organizer/models/audiobook_metadata.dart';

abstract class MetadataProvider {
  Future<List<AudiobookMetadata>> search(String query);
  Future<AudiobookMetadata?> getById(String id);
}