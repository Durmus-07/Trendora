import 'package:flutter/foundation.dart';

import 'interest_catalog.dart';
import 'personalization_preferences.dart';
import 'personalization_storage.dart';
import 'personalization_sync.dart';

class PersonalizationService extends ChangeNotifier {
  factory PersonalizationService({
    required PersonalizationLocalRepository repository,
    required PersonalizationIdentityProvider identityProvider,
    PersonalizationSyncGateway syncGateway =
        const DisabledPersonalizationSyncGateway(),
  }) {
    return PersonalizationService._(repository, identityProvider, syncGateway);
  }

  PersonalizationService._(
    this._repository,
    this._identityProvider,
    this._syncGateway,
  );

  final PersonalizationLocalRepository _repository;
  final PersonalizationIdentityProvider _identityProvider;
  final PersonalizationSyncGateway _syncGateway;

  PersonalizationPreferences? _preferences;
  PersonalizationPreferences? get current => _preferences;

  Future<PersonalizationPreferences> initialize({
    String? authenticatedUserId,
  }) async {
    final userId = await _identityProvider.resolve(
      authenticatedUserId: authenticatedUserId,
    );
    _preferences = await _repository.load(userId);
    notifyListeners();
    return _preferences!;
  }

  Future<PersonalizationPreferences> getPreferences() async {
    return _preferences ?? initialize();
  }

  Future<PersonalizationPreferences> savePreferences(
    PersonalizationPreferences preferences,
  ) async {
    try {
      await _repository.save(preferences);
      _preferences = preferences;
      notifyListeners();
    } catch (_) {
      _preferences ??= preferences;
    }
    return _preferences!;
  }

  Future<PersonalizationPreferences> update(
    PersonalizationPreferences Function(PersonalizationPreferences current)
    transform,
  ) async {
    final existing = await getPreferences();
    return savePreferences(transform(existing));
  }

  Future<PersonalizationPreferences> setPersonalizationEnabled(bool enabled) {
    return update(
      (current) => current.copyWith(personalizationEnabled: enabled),
    );
  }

  Future<PersonalizationPreferences> addInterest(String interestId) {
    if (!TrendoraInterestCatalog.contains(interestId)) return getPreferences();
    return update(
      (current) =>
          current.copyWith(interests: {...current.interests, interestId}),
    );
  }

  Future<PersonalizationPreferences> removeInterest(String interestId) {
    return update((current) {
      final interests = {...current.interests}..remove(interestId);
      return current.copyWith(interests: interests);
    });
  }

  Future<PersonalizationPreferences> updateInterests(
    Iterable<String> interestIds,
  ) {
    final valid = interestIds.where(TrendoraInterestCatalog.contains).toSet();
    return update((current) => current.copyWith(interests: valid));
  }

  Future<PersonalizationPreferences> updateNotificationPreferences(
    Iterable<String> categories,
  ) {
    return update(
      (current) => current.copyWith(
        notificationCategories: categories
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toSet(),
      ),
    );
  }

  Future<PersonalizationPreferences> linkTrackedFinancialAssets(
    Iterable<String> symbols,
  ) {
    return update(
      (current) => current.copyWith(
        trackedFinancialAssets: symbols
            .map((item) => item.trim().toUpperCase())
            .where((item) => item.isNotEmpty)
            .toSet(),
      ),
    );
  }

  Future<PersonalizationPreferences> linkSavedAnalyses(
    Iterable<String> analysisIds,
  ) {
    return update(
      (current) => current.copyWith(
        savedAnalysisIds: analysisIds
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toSet(),
      ),
    );
  }

  Future<PersonalizationPreferences> resetPreferences() async {
    final existing = await getPreferences();
    try {
      _preferences = await _repository.reset(existing.userId);
      notifyListeners();
    } catch (_) {
      _preferences = PersonalizationPreferences.defaults(
        userId: existing.userId,
      );
    }
    return _preferences!;
  }

  Future<PersonalizationPreferences> synchronize() async {
    final local = await getPreferences();
    if (!_syncGateway.enabled) return local;
    try {
      final result = await _syncGateway.synchronize(local);
      if (result.synced) return savePreferences(result.preferences);
    } catch (_) {
      // Çevrimdışı kullanımda yerel veri geçerli kalır.
    }
    return local;
  }
}
