import '../../models/item_model.dart';
import '../../models/storage_location_model.dart';

class DiscoveredField {
  final String canonicalName;
  final int count;

  const DiscoveredField({required this.canonicalName, required this.count});
}

class FieldQueryUtils {
  /// Discovers all unique custom field names across items, grouped case-insensitively.
  static List<DiscoveredField> discoverFields(List<Item> items) {
    final Map<String, String> canonicalMap = {}; // lowercase -> first seen casing
    final Map<String, int> counts = {}; // lowercase -> count

    for (final item in items) {
      for (final key in item.customFields.keys) {
        final lower = key.trim().toLowerCase();
        if (lower.isEmpty) continue;

        canonicalMap.putIfAbsent(lower, () => key.trim());
        counts[lower] = (counts[lower] ?? 0) + 1;
      }
    }

    final result = counts.entries.map((e) {
      return DiscoveredField(
        canonicalName: canonicalMap[e.key] ?? e.key,
        count: e.value,
      );
    }).toList();

    result.sort((a, b) => b.count.compareTo(a.count));
    return result;
  }

  /// Case-insensitively retrieves a field value from an item
  static dynamic getFieldValue(Item item, String fieldName) {
    final target = fieldName.trim().toLowerCase();
    for (final entry in item.customFields.entries) {
      if (entry.key.trim().toLowerCase() == target) {
        return entry.value;
      }
    }
    return null;
  }

  /// Formats any field value into a clean, human-friendly presentation string (e.g. $45 instead of raw map)
  static String formatFieldValue(dynamic val) {
    if (val == null) return '';

    if (val is Map) {
      // 1. Currency format {amount, currency}
      if (val.containsKey('amount')) {
        final amtRaw = val['amount'];
        final cur = (val['currency'] as String?)?.trim().toUpperCase() ?? 'AUD';
        String amtStr;
        if (amtRaw is num) {
          amtStr = amtRaw % 1 == 0 ? amtRaw.toInt().toString() : amtRaw.toStringAsFixed(2);
        } else {
          final parsed = double.tryParse(amtRaw.toString());
          if (parsed != null) {
            amtStr = parsed % 1 == 0 ? parsed.toInt().toString() : parsed.toStringAsFixed(2);
          } else {
            amtStr = amtRaw.toString();
          }
        }

        switch (cur) {
          case 'AUD':
          case 'USD':
          case 'CAD':
          case 'NZD':
          case 'SGD':
          case 'HKD':
          case '\$':
            return '\$$amtStr';
          case 'EUR':
          case '€':
            return '€$amtStr';
          case 'GBP':
          case '£':
            return '£$amtStr';
          case 'JPY':
          case '¥':
            return '¥$amtStr';
          default:
            return '$cur \$$amtStr';
        }
      }

      // 2. Dimension format {length, height, width, depth, unit}
      if (val.containsKey('height') ||
          val.containsKey('width') ||
          val.containsKey('depth') ||
          val.containsKey('length')) {
        final l = val['length']?.toString() ?? '';
        final w = val['width']?.toString() ?? '';
        final h = val['height']?.toString() ?? '';
        final d = val['depth']?.toString() ?? '';
        final u = val['unit']?.toString() ?? 'cm';
        final parts = (l.isNotEmpty ? [l, w, h, d] : [h, w, d])
            .where((s) => s.isNotEmpty)
            .toList();
        if (parts.isEmpty) return '';
        return '${parts.join(' × ')} $u'.trim();
      }

      // 3. Weight format {weight/value, unit}
      if (val.containsKey('weight') || (val.containsKey('value') && val.containsKey('unit'))) {
        final w = val['weight'] ?? val['value'] ?? '';
        final u = val['unit'] ?? 'kg';
        return '$w $u'.trim();
      }

      // 4. General map fallback (clean key: value string)
      final parts = <String>[];
      val.forEach((k, v) {
        if (v != null && v.toString().isNotEmpty) {
          parts.add('$k: ${formatFieldValue(v)}');
        }
      });
      return parts.join(', ');
    }

    if (val is List) {
      return val.map((e) => formatFieldValue(e)).join(', ');
    }

    return val.toString();
  }

  /// Extracts numeric value from a field (even if stored inside structured currency/weight map or as number/string)
  static double? extractNumericValue(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is Map) {
      if (val.containsKey('amount')) return double.tryParse(val['amount'].toString());
      if (val.containsKey('weight')) return double.tryParse(val['weight'].toString());
      if (val.containsKey('value')) return double.tryParse(val['value'].toString());
    }
    if (val is String) {
      final sanitized = val.replaceAll(RegExp(r'[^\d.-]'), '');
      return double.tryParse(sanitized);
    }
    return null;
  }

  /// Traverses parents to build full hierarchical location breadcrumb path (e.g. "Main Shed > Top Shelf")
  static String buildLocationBreadcrumb(String? locationId, Map<String, StorageLocation> locationMap) {
    if (locationId == null || locationId.isEmpty) {
      return 'Unassigned / No Location';
    }
    if (!locationMap.containsKey(locationId)) {
      return 'Unknown Location';
    }

    final pathNames = <String>[];
    String? currentId = locationId;
    final visited = <String>{};

    while (currentId != null && locationMap.containsKey(currentId) && visited.add(currentId)) {
      final loc = locationMap[currentId]!;
      pathNames.insert(0, loc.name);
      currentId = loc.parentId;
    }

    return pathNames.join(' > ');
  }

  /// Comprehensive case-insensitive search matching standard fields + all custom attributes
  static bool itemMatchesSearch(Item item, String query) {
    if (query.trim().isEmpty) return true;
    final q = query.trim().toLowerCase();

    if (item.name.toLowerCase().contains(q)) return true;
    if ((item.description ?? '').toLowerCase().contains(q)) return true;
    if (item.effectiveItemTypeName.toLowerCase().contains(q)) return true;
    if (item.barcode != null && item.barcode!.toLowerCase().contains(q)) return true;
    if (item.tags.any((t) => t.toLowerCase().contains(q))) return true;

    for (final entry in item.customFields.entries) {
      if (entry.key.toLowerCase().contains(q)) return true;
      final formatted = formatFieldValue(entry.value).toLowerCase();
      if (formatted.contains(q)) return true;
    }

    return false;
  }

  /// Groups items by their location breadcrumb path
  static Map<String, List<Item>> groupByLocation(List<Item> items, Map<String, StorageLocation> locationMap) {
    final Map<String, List<Item>> groups = {};
    for (final item in items) {
      final breadcrumb = buildLocationBreadcrumb(item.storageLocationId, locationMap);
      groups.putIfAbsent(breadcrumb, () => []).add(item);
    }
    return groups;
  }

  /// Groups items by their Item Type name
  static Map<String, List<Item>> groupByItemType(List<Item> items) {
    final Map<String, List<Item>> groups = {};
    for (final item in items) {
      final key = item.effectiveItemTypeName;
      groups.putIfAbsent(key, () => []).add(item);
    }
    return groups;
  }

  /// Groups items by the formatted value of a matching custom field
  static Map<String, List<Item>> groupByField(List<Item> items, String fieldName) {
    final Map<String, List<Item>> groups = {};
    for (final item in items) {
      final val = getFieldValue(item, fieldName);
      final formatted = val != null ? formatFieldValue(val) : 'Unspecified';
      groups.putIfAbsent(formatted, () => []).add(item);
    }
    return groups;
  }

  /// Sorts items by standard fields (name, date, location, type) or custom attributes
  static List<Item> sortItems(
    List<Item> items, {
    required String sortBy,
    bool ascending = true,
    Map<String, StorageLocation>? locationMap,
  }) {
    final sorted = List<Item>.from(items);

    sorted.sort((a, b) {
      int cmp = 0;
      if (sortBy == 'name') {
        cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      } else if (sortBy == 'date' || sortBy == 'created_at') {
        cmp = a.createdAt.compareTo(b.createdAt);
      } else if (sortBy == 'location') {
        final locA = locationMap != null
            ? buildLocationBreadcrumb(a.storageLocationId, locationMap)
            : (a.storageLocationId ?? '');
        final locB = locationMap != null
            ? buildLocationBreadcrumb(b.storageLocationId, locationMap)
            : (b.storageLocationId ?? '');
        cmp = locA.toLowerCase().compareTo(locB.toLowerCase());
      } else if (sortBy == 'type') {
        cmp = a.effectiveItemTypeName.toLowerCase().compareTo(b.effectiveItemTypeName.toLowerCase());
      } else if (sortBy.startsWith('field:')) {
        final fieldName = sortBy.substring('field:'.length);
        final valA = getFieldValue(a, fieldName);
        final valB = getFieldValue(b, fieldName);

        final numA = extractNumericValue(valA);
        final numB = extractNumericValue(valB);

        if (numA != null && numB != null) {
          cmp = numA.compareTo(numB);
        } else if (numA != null) {
          cmp = -1;
        } else if (numB != null) {
          cmp = 1;
        } else {
          final strA = formatFieldValue(valA).toLowerCase();
          final strB = formatFieldValue(valB).toLowerCase();
          cmp = strA.compareTo(strB);
        }
      }

      if (cmp == 0) {
        cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return ascending ? cmp : -cmp;
    });

    return sorted;
  }
}
