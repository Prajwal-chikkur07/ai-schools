import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared state: the current grade/subject context used across feature screens.
class ShellState {
  final String? selectedGrade;
  final String? selectedSubject;

  const ShellState({
    this.selectedGrade,
    this.selectedSubject,
  });

  ShellState copyWith({String? selectedGrade, String? selectedSubject, bool clearLocation = false}) {
    return ShellState(
      selectedGrade: clearLocation ? null : (selectedGrade ?? this.selectedGrade),
      selectedSubject: clearLocation ? null : (selectedSubject ?? this.selectedSubject),
    );
  }
}

class ShellNotifier extends StateNotifier<ShellState> {
  ShellNotifier() : super(const ShellState());

  void setLocation(String grade, String subject) =>
      state = state.copyWith(selectedGrade: grade, selectedSubject: subject);

  void clearLocation() => state = state.copyWith(clearLocation: true);
}

final shellProvider = StateNotifierProvider<ShellNotifier, ShellState>((ref) => ShellNotifier());
