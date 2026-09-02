/// Trailing strip/row pill for pre-nudges — derived only from [goldCoins] / [redCards]
/// (LLD §2.0). No `badgeText` in the API.
enum NudgePillKind { none, coin, redCard }

class NudgePillDisplay {
  final NudgePillKind kind;
  final int count;

  const NudgePillDisplay._(this.kind, this.count);

  const NudgePillDisplay.none() : this._(NudgePillKind.none, 0);

  const NudgePillDisplay.coin(int count)
      : this._(NudgePillKind.coin, count);

  const NudgePillDisplay.redCard(int count)
      : this._(NudgePillKind.redCard, count);

  bool get hasPill => kind != NudgePillKind.none && count > 0;
}

/// If [goldCoins] > 0 → coin pill; else if [redCards] > 0 → red-card pill; else none.
NudgePillDisplay deriveNudgePill({int? goldCoins, int? redCards}) {
  if (goldCoins != null && goldCoins > 0) {
    return NudgePillDisplay.coin(goldCoins);
  }
  if (redCards != null && redCards > 0) {
    return NudgePillDisplay.redCard(redCards);
  }
  return const NudgePillDisplay.none();
}
