class ScriptureQuote {
  const ScriptureQuote({required this.reference, required this.text});

  final String reference;
  final String text;

  Map<String, dynamic> toJson() => {'reference': reference, 'text': text};

  factory ScriptureQuote.fromJson(Map<String, dynamic> json) {
    return ScriptureQuote(
      reference: json['reference'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }
}
