/// Real-world platform guidance for specific KRL Jabodetabek transfer
/// stations — e.g. "Transit ke Peron Bawah 1/2" at Manggarai — rather than
/// the generic "Transit di X." every other transfer gets. Matched by
/// station NAME (not an internal id/code), since names are what this table
/// was authored against and stay correct regardless of which provider or
/// station-code scheme supplied the trip.
///
/// [approachingFromName] must be the real station immediately *before*
/// [transferName] on the incoming leg (not the trip's ultimate origin,
/// except when that origin happens to be adjacent) — the signal that
/// actually determines which physical platform a train pulls into, since
/// some stations (e.g. Klender) sit on more than one approach, and most
/// riders board well before the transfer rather than at one of this table's
/// example stations. Passing the trip's origin instead of the true adjacent
/// stop will silently under-match for every rider who didn't board at that
/// exact example station.
///
/// Returns null when no specific rule matches — callers should fall back to
/// a generic "Transit di X." instruction in that case.
String? transferPlatformInstruction({
  required String? approachingFromName,
  required String transferName,
  required String? nextName,
}) {
  if (approachingFromName == null || nextName == null) {
    return null;
  }
  final from = _norm(approachingFromName);
  final at = _norm(transferName);
  final next = _norm(nextName);

  bool fromAny(List<String> names) => names.any((n) => from.contains(_norm(n)));
  bool nextIs(String name) => next.contains(_norm(name));

  switch (at) {
    case 'manggarai':
      // 'tebet'/'cikini' are the real immediately-adjacent stops on the
      // Bogor line just south/north of Manggarai — every Bogor-line rider
      // funnels through one of these right before Manggarai regardless of
      // their actual boarding station (Bogor, Bojonggede, Depok, Citayam...),
      // so matching only the line's two termini here would silently miss
      // the overwhelming majority of real Bogor-line trips.
      if (fromAny(['bogor', 'jakarta kota', 'tebet', 'cikini'])) {
        if (nextIs('matraman')) return 'Transit ke Peron Bawah 3/4.';
        if (nextIs('sudirman')) return 'Transit ke Peron Bawah 1/2.';
      }
      if (fromAny(['sudirman', 'matraman'])) {
        if (nextIs('tebet')) return 'Transit ke Peron Atas 11/12.';
        if (nextIs('cikini')) return 'Transit ke Peron Atas 9/10.';
      }
    case 'tanah abang':
      if (fromAny(['karet', 'bni city', 'duri'])) {
        if (nextIs('palmerah')) return 'Transit ke Peron 5/6.';
      }
      if (fromAny(['palmerah'])) {
        if (nextIs('karet') || nextIs('bni city')) return 'Transit ke Peron 2/3.';
        if (nextIs('duri')) return 'Transit ke Peron 1.';
      }
    case 'duri':
      if (fromAny(['tanah abang', 'angke'])) {
        if (nextIs('grogol')) return 'Transit ke Peron 5.';
      }
    case 'jatinegara':
      if (fromAny(['pondok jati'])) {
        if (nextIs('matraman')) return 'Transit ke Peron 2.';
      }
      if (fromAny(['matraman'])) {
        if (nextIs('pondok jati')) return 'Transit ke Peron 5/6.';
      }
      // Klender sits on both approaches to Jatinegara (via Pasar Senen and
      // via Manggarai) — "from Klender" alone can't tell them apart, so it
      // only resolves once we also know which station comes *after* the
      // transfer, matching each rule's actual pair.
      if (fromAny(['klender'])) {
        if (nextIs('matraman')) return 'Transit ke Peron 2.';
        if (nextIs('pondok jati')) return 'Transit ke Peron 5/6.';
      }
    case 'jakarta kota':
      if (fromAny(['jayakarta', 'bogor'])) {
        if (nextIs('kampung bandan')) return 'Transit ke Jalur 8.';
      }
      if (fromAny(['kampung bandan', 'priok'])) {
        if (nextIs('jayakarta')) return 'Transit di Peron 9/10/11.';
      }
    case 'kampung bandan':
      if (fromAny(['angke', 'rajawali'])) {
        if (nextIs('jakarta kota')) return 'Transit ke Peron Atas 6.';
        if (nextIs('ancol')) return 'Transit ke Peron Atas 7.';
      }
  }
  return null;
}

String _norm(String value) => value.trim().toLowerCase();
