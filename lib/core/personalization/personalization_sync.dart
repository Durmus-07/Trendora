import 'personalization_preferences.dart';

enum PersonalizationConflictPolicy { newestUpdateWins, localWins, serverWins }

class PersonalizationSyncResult {
  const PersonalizationSyncResult({
    required this.preferences,
    required this.synced,
    this.serverUpdatedAt,
  });

  final PersonalizationPreferences preferences;
  final bool synced;
  final DateTime? serverUpdatedAt;
}

abstract interface class PersonalizationSyncGateway {
  bool get enabled;

  Future<PersonalizationSyncResult> synchronize(
    PersonalizationPreferences local, {
    PersonalizationConflictPolicy policy =
        PersonalizationConflictPolicy.newestUpdateWins,
  });
}

class DisabledPersonalizationSyncGateway implements PersonalizationSyncGateway {
  const DisabledPersonalizationSyncGateway();

  @override
  bool get enabled => false;

  @override
  Future<PersonalizationSyncResult> synchronize(
    PersonalizationPreferences local, {
    PersonalizationConflictPolicy policy =
        PersonalizationConflictPolicy.newestUpdateWins,
  }) async {
    return PersonalizationSyncResult(preferences: local, synced: false);
  }
}
