class AutoClassifier {
  static const Map<String, List<String>> _rules = {
    'passport': ['passport', 'паспорт'],
    'id_card': ['id card', 'identity card', 'удостоверение', 'идентификац'],
    'driver_license': ['driver license', 'driving license', 'водительск'],
    'invoice': ['invoice', 'счёт', 'счет', 'фактура'],
    'receipt': ['receipt', 'чек', 'кассовый'],
    'contract': ['contract', 'agreement', 'договор', 'соглашение'],
    'tax': ['tax return', 'налог', 'налогова'],
    'bank_statement': ['bank statement', 'выписка', 'account statement'],
    'medical': ['medical', 'prescription', 'медицин', 'рецепт'],
    'insurance': ['insurance', 'policy', 'страхован', 'полис'],
  };

  String? classify({String? originalName, String? ocrText}) {
    final haystack = ('${originalName ?? ''}\n${ocrText ?? ''}').toLowerCase();
    if (haystack.trim().isEmpty) return null;

    String? best;
    var bestHits = 0;
    for (final entry in _rules.entries) {
      var hits = 0;
      for (final keyword in entry.value) {
        if (haystack.contains(keyword)) hits++;
      }
      if (hits > bestHits) {
        bestHits = hits;
        best = entry.key;
      }
    }
    return best;
  }
}
