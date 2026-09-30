class DictationSettings {
  bool voiceCommands;

  bool autoCapitalize;

  bool autoPeriod;

  bool continuous;

  String localeId;

  DictationSettings({
    this.voiceCommands = true,
    this.autoCapitalize = true,
    this.autoPeriod = true,
    this.continuous = true,
    this.localeId = 'ru_RU',
  });

  factory DictationSettings.fromJson(Map<String, dynamic> j) =>
      DictationSettings(
        voiceCommands: j['voiceCommands'] as bool? ?? true,
        autoCapitalize: j['autoCapitalize'] as bool? ?? true,
        autoPeriod: j['autoPeriod'] as bool? ?? true,
        continuous: j['continuous'] as bool? ?? true,
        localeId: j['localeId'] as String? ?? 'ru_RU',
      );

  Map<String, dynamic> toJson() => {
    'voiceCommands': voiceCommands,
    'autoCapitalize': autoCapitalize,
    'autoPeriod': autoPeriod,
    'continuous': continuous,
    'localeId': localeId,
  };
}
