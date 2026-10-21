enum ListeningContext { balanced, energy, calm, party, focus }

enum DiscoveryLevel { familiar, balanced, discovery, experimental }

extension DiscoveryLevelX on DiscoveryLevel {
  double get factor => switch (this) {
    DiscoveryLevel.familiar => 0.0,
    DiscoveryLevel.balanced => 0.35,
    DiscoveryLevel.discovery => 0.7,
    DiscoveryLevel.experimental => 1.0,
  };

  String get label => switch (this) {
    DiscoveryLevel.familiar => 'Привычное',
    DiscoveryLevel.balanced => 'Баланс',
    DiscoveryLevel.discovery => 'Открытия',
    DiscoveryLevel.experimental => 'Эксперимент',
  };
}
