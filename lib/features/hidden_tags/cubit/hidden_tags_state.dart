class HiddenTagsState {
  const HiddenTagsState({
    this.names = const [],
    this.busy = false,
    this.error,
  });

  final List<String> names;
  final bool busy;
  final String? error;

  HiddenTagsState copyWith({
    List<String>? names,
    bool? busy,
    String? error,
    bool clearError = false,
  }) {
    return HiddenTagsState(
      names: names ?? this.names,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
