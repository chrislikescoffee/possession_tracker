/// Application constants for PossessionTracker
class AppConstants {
  static const String appName = 'PossessionTracker';
  static const String appTagline = 'Spatial Visual Inventory & Storage Locator';

  /// Default maximum items allowed per library before requiring a license
  static const int defaultItemLimit = 50;

  // Roles
  static const String roleOwner = 'owner';
  static const String roleEditor = 'editor';
  static const String roleViewer = 'viewer';

  // Item Statuses
  static const String itemStatusStored = 'stored';
  static const String itemStatusRelocated = 'relocated';
  static const String itemStatusLent = 'lent';

  // Field Types for Dynamic Custom Fields
  static const String fieldTypeText = 'text';
  static const String fieldTypeNumber = 'number';
  static const String fieldTypeBoolean = 'boolean';
  static const String fieldTypeDate = 'date';
  static const String fieldTypeSelect = 'select';
}
