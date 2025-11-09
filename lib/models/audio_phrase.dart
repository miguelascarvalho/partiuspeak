class AudioPhrase {
  final String phraseId;
  final String textPt;
  final String textEn;
  final String audioPath;
  final String corPadrao;
  final String corToque;

  AudioPhrase({
    required this.phraseId,
    required this.textPt,
    required this.textEn,
    required this.audioPath,
    required this.corPadrao,
    required this.corToque,
  });

  factory AudioPhrase.fromJson(Map<String, dynamic> json) {
    return AudioPhrase(
      phraseId: json['phrase_id'] as String? ?? '',
      textPt: json['text_pt'] as String? ?? '',
      textEn: json['text_en'] as String? ?? '',
      audioPath: json['audio_en_storage_path'] as String? ?? '',
      corPadrao: json['corPadrao'] as String? ?? '#CCCCCC',
      corToque: json['corToque'] as String? ?? '#00FF00',
    );
  }
}
