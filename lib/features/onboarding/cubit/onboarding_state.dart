class OnboardingState {
  const OnboardingState({
    this.busy = false,
    this.askBiometric = false,
    this.askPanic = false,
    this.error,
    this.restoreMessage,
  });

  final bool busy;
  final bool askBiometric;
  final bool askPanic;
  final String? error;
  final String? restoreMessage;

  OnboardingState copyWith({
    bool? busy,
    bool? askBiometric,
    bool? askPanic,
    String? error,
    String? restoreMessage,
    bool clearError = false,
    bool clearRestoreMessage = false,
  }) {
    return OnboardingState(
      busy: busy ?? this.busy,
      askBiometric: askBiometric ?? this.askBiometric,
      askPanic: askPanic ?? this.askPanic,
      error: clearError ? null : (error ?? this.error),
      restoreMessage: clearRestoreMessage
          ? null
          : (restoreMessage ?? this.restoreMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OnboardingState &&
      other.busy == busy &&
      other.askBiometric == askBiometric &&
      other.askPanic == askPanic &&
      other.error == error &&
      other.restoreMessage == restoreMessage;

  @override
  int get hashCode =>
      Object.hash(busy, askBiometric, askPanic, error, restoreMessage);
}
