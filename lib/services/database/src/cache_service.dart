import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '/services/services.dart';
import '/models/models.dart';

// --- TASK NAME ---
const String syncTaskName = "periodicSyncTask";

// --- CONFIGURATION HELPER ---
class _BoxConfig {
  final String boxName;
  final String collectionName;
  const _BoxConfig(this.boxName, this.collectionName);
}

class CacheService {
  static final FirebaseConfig _firebase = FirebaseConfig();

  // --- CONFIGURATION MAP ---
  // Maps specific keys to their Box and Firestore Collection names
  static const Map<String, _BoxConfig> _config = {
    'admin': _BoxConfig('admins', 'admins'),
    'leadCategory': _BoxConfig('leadCategory', 'leadCategory'),
    'leadStatus': _BoxConfig('leadStatus', 'leadStatus'),
    'leadPriority': _BoxConfig('leadPriority', 'leadPriority'),
    'dealStatus': _BoxConfig('dealStatus', 'dealStatus'),
    'task': _BoxConfig('tasks', 'tasks'),
  };

  static const String _metaBox = 'meta';

  // --- STATE ---
  bool _isInitialized = false;
  Timer? _periodicTimer;

  // Prevent duplicate network calls for the same missing ID
  static final Set<String> _pendingFetches = {};

  static dynamic _normalizeCacheValue(dynamic value) {
    return normalizeFromCache(value);
  }

  /// Recursively converts all Map keys to String and nested Maps/Lists too.
  /// Use this whenever reading raw data from a Hive box before passing to fromMap.
  static Map<String, dynamic> normalizeFromCache(dynamic value) {
    if (value is Map) {
      return value.map((key, entry) {
        final normalized = entry is Map
            ? normalizeFromCache(entry)
            : entry is List
            ? _normalizeList(entry)
            : entry;
        return MapEntry(key.toString(), normalized);
      });
    }
    return {};
  }

  static List<dynamic> _normalizeList(List list) {
    return list.map((e) => e is Map ? normalizeFromCache(e) : e).toList();
  }

  // ---------------- INITIALIZATION ----------------
  Future<void> init() async {
    if (_isInitialized) return;

    await Hive.initFlutter('mini_crm');
    await _openBoxes();
    await _initSyncScheduler();

    _isInitialized = true;
    debugPrint("CacheService initialized");
  }

  Future<void> _openBoxes() async {
    for (var conf in _config.values) {
      if (Hive.isBoxOpen(conf.boxName)) continue;
      try {
        await Hive.openBox<Map<dynamic, dynamic>>(conf.boxName);
      } catch (e, st) {
        debugPrint("Failed to open box ${conf.boxName}: $e");
        await ErrorService.recordError(e, st);
      }
    }
    if (!Hive.isBoxOpen(_metaBox)) {
      try {
        await Hive.openBox(_metaBox);
      } catch (e, st) {
        debugPrint("Failed to open meta box: $e");
        await ErrorService.recordError(e, st);
      }
    }
  }

  // ---------------- SCHEDULER ----------------
  Future<void> _initSyncScheduler() async {
    try {
      _periodicTimer?.cancel();
      // Sync all data every 6 hours as a fallback
      _periodicTimer = Timer.periodic(const Duration(hours: 6), (_) async {
        debugPrint("Timer-based full sync triggered...");
        await syncAllCollections();
      });
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  // ---------------- GENERIC GETTER ----------------
  /// Checks cache. If missing, triggers a background fetch for ONLY that item.
  static T? _getEntity<T>({
    required String uid,
    required String configKey,
    required T Function(String id, Map<String, dynamic> data) fromMap,
  }) {
    try {
      final conf = _config[configKey]!;
      final box = Hive.box<Map<dynamic, dynamic>>(conf.boxName);
      final data = box.get(uid);

      if (data != null) {
        // Found in cache
        final normalized = _normalizeCacheValue(data);
        return fromMap(uid, Map<String, dynamic>.from(normalized as Map));
      }

      // Not found: Fetch specific document from Firestore
      _fetchSingleDocument(uid, conf);

      return null;
    } catch (e, st) {
      debugPrint("Error getting $configKey ($uid): $e, $st");
      return null;
    }
  }

  /// Fetches a single document from Firestore and updates Hive
  static Future<void> _fetchSingleDocument(String uid, _BoxConfig conf) async {
    // 1. Debounce: If we are already fetching this ID, don't do it again.
    final fetchKey = "${conf.collectionName}_$uid";
    if (_pendingFetches.contains(fetchKey)) return;

    _pendingFetches.add(fetchKey);

    try {
      debugPrint(
        "Cache Miss: Fetching single doc $uid from ${conf.collectionName}",
      );

      // Check Auth
      if (!(await Spdb.checkLogin())) return;
      final cid = await Spdb.getCid();
      if (cid == null) return;

      if (uid.isEmpty) return;

      // 2. Fetch from Firestore
      final docSnap = await _firebase.users
          .doc(cid)
          .collection(conf.collectionName)
          .doc(uid)
          .get();

      if (docSnap.exists && docSnap.data() != null) {
        // 3. Update Cache
        final box = Hive.box<Map<dynamic, dynamic>>(conf.boxName);
        await box.put(uid, docSnap.data()!);
        debugPrint("Cache Updated: $uid added to ${conf.boxName}");
      } else {
        debugPrint("Document $uid does not exist in Firestore.");
      }
    } catch (e) {
      debugPrint("Single doc fetch failed: $e");
    } finally {
      _pendingFetches.remove(fetchKey);
    }
  }

  // ---------------- PUBLIC ACCESSORS ----------------



  static AdminModel? adminByUid(String uid) {
    return _getEntity<AdminModel>(
      uid: uid,
      configKey: 'admin',
      fromMap: AdminModel.fromMap,
    );
  }



  static LeadStatusModel? leadStatusByUid(String uid) {
    return _getEntity<LeadStatusModel>(
      uid: uid,
      configKey: 'leadStatus',
      fromMap: LeadStatusModel.fromMap,
    );
  }

  static LeadCategoryModel? leadCategoryByUid(String uid) {
    return _getEntity<LeadCategoryModel>(
      uid: uid,
      configKey: 'leadCategory',
      fromMap: LeadCategoryModel.fromMap,
    );
  }

  static LeadPriorityModel? leadPriorityByUid(String uid) {
    return _getEntity<LeadPriorityModel>(
      uid: uid,
      configKey: 'leadPriority',
      fromMap: LeadPriorityModel.fromMap,
    );
  }

  static DealStatusModel? dealStatusByUid(String uid) {
    return _getEntity<DealStatusModel>(
      uid: uid,
      configKey: 'dealStatus',
      fromMap: DealStatusModel.fromMap,
    );
  }

  static TaskModel? getTaskByUid(String uid) {
    return _getEntity<TaskModel>(
      uid: uid,
      configKey: 'task',
      fromMap: TaskModel.fromMap,
    );
  }

  // ---------------- LISTENABLE ACCESSORS ----------------
  static ValueListenable<List<AdminModel>> getAllListenableAdmins() {
    final conf = _config['admin']!;
    final box = Hive.box<Map<dynamic, dynamic>>(conf.boxName);

    return box.listenable().map((boxRef) {
      return boxRef.keys.map((key) {
        final raw = boxRef.get(key);
        if (raw == null) return null;
        final normalized = _normalizeCacheValue(raw);
        return AdminModel.fromMap(key.toString(), Map<String, dynamic>.from(normalized as Map));
      }).whereType<AdminModel>().toList();
    });
  }


  // ---------------- BULK SYNC FUNCTIONS ----------------

  /// Syncs specific collections based on the keys passed (e.g. ['employee', 'department'])
  /// If keys is empty, it syncs nothing.
  static Future<void> syncSelectedCollections(List<String> configKeys) async {
    if (configKeys.isEmpty) return;

    debugPrint("CacheService: Syncing selected: $configKeys");
    if (!(await Spdb.checkLogin())) return;
    final cid = await Spdb.getCid();
    if (cid == null) return;

    final userRef = _firebase.users.doc(cid);

    try {
      // Create a list of futures to run in parallel
      final futures = configKeys.map((key) async {
        final conf = _config[key];
        if (conf == null) return;

        // Fetch
        final snapshot = await userRef.collection(conf.collectionName).get();
        final box = Hive.box<Map<dynamic, dynamic>>(conf.boxName);

        // Clear and Write
        await box.clear();
        await box.putAll({for (var doc in snapshot.docs) doc.id: doc.data()});
        debugPrint("Synced ${conf.collectionName}");
      });

      await Future.wait(futures);

      // Update Sync Time
      Hive.box(_metaBox).put('lastSync', DateTime.now().millisecondsSinceEpoch);
    } catch (e, st) {
      debugPrint("Sync Selected Failed: $e");
      await ErrorService.recordError(e, st);
    }
  }

  /// Original Full Sync (Retained for periodic background tasks)
  static Future<void> syncAllCollections() async {
    await syncSelectedCollections(_config.keys.toList());
  }

  // ---------------- UTILS ----------------

  Future<void> clearAllBoxes() async {
    try {
      for (var conf in _config.values) {
        await Hive.box<Map<dynamic, dynamic>>(conf.boxName).clear();
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  DateTime? getLastSyncTime() {
    final metaBox = Hive.box(_metaBox);
    final ts = metaBox.get('lastSync');
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts);
  }

  Future<void> dispose() async {
    _periodicTimer?.cancel();
  }
}

// Extension to map ValueListenable<Box> to ValueListenable<List<T>>
extension ValueListenableExtension<K, V> on ValueListenable<Box<V>> {
  ValueListenable<T> map<T>(T Function(Box<V> box) mapper) {
    return _MappedValueListenable(this, mapper);
  }
}

class _MappedValueListenable<K, V, T> extends ValueListenable<T> {
  final ValueListenable<Box<V>> original;
  final T Function(Box<V> box) mapper;

  _MappedValueListenable(this.original, this.mapper);

  @override
  T get value => mapper(original.value);

  @override
  void addListener(VoidCallback listener) => original.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      original.removeListener(listener);
}
