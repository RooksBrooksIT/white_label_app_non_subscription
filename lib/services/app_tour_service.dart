import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subscription_rooks_app/widgets/interactive_tour/tour_step_model.dart';
import 'package:subscription_rooks_app/widgets/interactive_tour/interactive_tour_overlay.dart';

class AppTourService extends ChangeNotifier {
  static final AppTourService instance = AppTourService._internal();
  AppTourService._internal();

  static const String _prefKey = 'hasCompletedAppTour';
  bool _isTourActive = false;
  int _currentStepIndex = 0;
  List<TourStep> _steps = [];
  OverlayEntry? _overlayEntry;
  VoidCallback? _onTourCompleted;

  bool get isTourActive => _isTourActive;
  int get currentStepIndex => _currentStepIndex;
  int get totalSteps => _steps.length;
  TourStep? get currentStep =>
      _steps.isNotEmpty && _currentStepIndex < _steps.length
          ? _steps[_currentStepIndex]
          : null;

  /// Check if the user has previously finished or dismissed the tour.
  Future<bool> hasCompletedTour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// Mark the tour as completed in local storage.
  Future<void> markTourCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  /// Reset tour completion flag so it can be replayed.
  Future<void> resetTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  /// Start the interactive tour overlay.
  Future<void> startTour({
    required BuildContext context,
    required List<TourStep> steps,
    VoidCallback? onComplete,
    bool force = false,
  }) async {
    if (_isTourActive) {
      dismissTour();
    }

    if (!force) {
      final completed = await hasCompletedTour();
      if (completed) return;
    }

    if (steps.isEmpty) return;

    _steps = steps;
    _currentStepIndex = 0;
    _onTourCompleted = onComplete;
    _isTourActive = true;

    if (!context.mounted) return;
    final overlayState = Overlay.of(context, rootOverlay: true);

    _overlayEntry = OverlayEntry(
      builder: (ctx) => InteractiveTourOverlay(
        service: this,
      ),
    );

    overlayState.insert(_overlayEntry!);
    notifyListeners();
  }

  /// Advances to the next tour step or finishes the tour if on the last step.
  void nextStep() {
    if (_currentStepIndex < _steps.length - 1) {
      _currentStepIndex++;
      notifyListeners();
    } else {
      finishTour();
    }
  }

  /// Goes back to the previous tour step.
  void previousStep() {
    if (_currentStepIndex > 0) {
      _currentStepIndex--;
      notifyListeners();
    }
  }

  /// Jump to a specific step index.
  void goToStep(int index) {
    if (index >= 0 && index < _steps.length) {
      _currentStepIndex = index;
      notifyListeners();
    }
  }

  /// Complete and close the tour, saving the completion flag.
  void finishTour() {
    markTourCompleted();
    _cleanup();
    _onTourCompleted?.call();
  }

  /// Dismiss the tour immediately (e.g. user taps Skip).
  void dismissTour() {
    markTourCompleted();
    _cleanup();
  }

  void _cleanup() {
    _isTourActive = false;
    _overlayEntry?.remove();
    _overlayEntry = null;
    _steps = [];
    _currentStepIndex = 0;
    notifyListeners();
  }
}
