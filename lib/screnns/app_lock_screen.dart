import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/lock_service.dart';
import '../utils/app_theme.dart';

/// Full-screen lock gate shown at app start and on resume.
///
/// Shows a PIN keypad always.
/// On Android 10+ with enrolled biometrics, also shows a fingerprint button.
///
/// Usage:
///   AppLockScreen(onUnlocked: () { /* navigate away */ })
///
/// To set a PIN for the first time, use [AppPinSetupScreen].
class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const AppLockScreen({super.key, required this.onUnlocked});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  static const _pinLength = 4;

  String _entered = '';
  bool _error = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final ok = await LockService.instance.isBiometricAvailable();
    if (mounted) setState(() => _biometricAvailable = ok);
    if (ok) _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    final ok = await LockService.instance.authenticateWithBiometrics();
    if (ok && mounted) widget.onUnlocked();
  }

  void _onKey(String digit) {
    if (_entered.length >= _pinLength) return;
    setState(() {
      _entered += digit;
      _error = false;
    });
    if (_entered.length == _pinLength) _verify();
  }

  void _onDelete() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _verify() async {
    final ok = await LockService.instance.checkPin(_entered);
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
    } else {
      HapticFeedback.mediumImpact();
      setState(() {
        _error = true;
        _entered = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            // Lock illustration
            Image.asset('assets/lock_heart.webp', width: 90, height: 90),
            const SizedBox(height: 16),
            Text(
              'Collabo',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Entrez votre code PIN',
              style: TextStyle(fontSize: 14, color: AppColors.textMedium),
            ),
            const SizedBox(height: 32),
            // PIN dots
            _PinDots(entered: _entered.length, total: _pinLength, error: _error),
            if (_error) ...[
              const SizedBox(height: 12),
              Text(
                'Code incorrect. Réessayez.',
                style: TextStyle(color: Colors.red.shade600, fontSize: 13),
              ),
            ],
            const Spacer(),
            // Keypad
            _Keypad(
              onDigit: _onKey,
              onDelete: _onDelete,
              onBiometric: _biometricAvailable ? _tryBiometric : null,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── PIN setup screen (first launch / change PIN) ─────────────────

/// Two-step PIN setup: enter new PIN → confirm → save.
class AppPinSetupScreen extends StatefulWidget {
  /// Called when PIN is successfully saved.
  final VoidCallback onSaved;
  /// If true, shows a "Cancel" option (used from profile to change PIN).
  final bool canCancel;

  const AppPinSetupScreen({
    super.key,
    required this.onSaved,
    this.canCancel = false,
  });

  @override
  State<AppPinSetupScreen> createState() => _AppPinSetupScreenState();
}

class _AppPinSetupScreenState extends State<AppPinSetupScreen> {
  static const _pinLength = 4;

  String _first = '';
  String _second = '';
  bool _confirming = false;
  bool _error = false;

  String get _current => _confirming ? _second : _first;

  void _onKey(String digit) {
    if (_current.length >= _pinLength) return;
    setState(() {
      if (_confirming) {
        _second += digit;
      } else {
        _first += digit;
      }
      _error = false;
    });
    if (_current.length == _pinLength) {
      if (_confirming) {
        _save();
      } else {
        setState(() => _confirming = true);
      }
    }
  }

  void _onDelete() {
    if (_current.isEmpty) return;
    setState(() {
      if (_confirming) {
        _second = _second.substring(0, _second.length - 1);
      } else {
        _first = _first.substring(0, _first.length - 1);
      }
    });
  }

  Future<void> _save() async {
    if (_first == _second) {
      await LockService.instance.savePin(_first);
      if (mounted) widget.onSaved();
    } else {
      HapticFeedback.mediumImpact();
      setState(() {
        _error = true;
        _second = '';
        _confirming = false;
        _first = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _confirming ? 'Confirmez le PIN' : 'Choisissez un PIN à 4 chiffres';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: widget.canCancel
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textDark),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text('Changer le PIN',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              centerTitle: true,
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            Image.asset('assets/lock_heart.webp', width: 80, height: 80),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark),
            ),
            const SizedBox(height: 28),
            _PinDots(entered: _current.length, total: _pinLength, error: _error),
            if (_error) ...[
              const SizedBox(height: 12),
              Text(
                'Les codes ne correspondent pas. Réessayez.',
                style: TextStyle(color: Colors.red.shade600, fontSize: 13),
              ),
            ],
            const Spacer(),
            _Keypad(
              onDigit: _onKey,
              onDelete: _onDelete,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Shared sub-widgets ───────────────────────────────────────────

class _PinDots extends StatelessWidget {
  final int entered;
  final int total;
  final bool error;

  const _PinDots({
    required this.entered,
    required this.total,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final filled = i < entered;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: error
                ? Colors.red.shade400
                : filled
                    ? AppColors.primary
                    : Colors.transparent,
            border: Border.all(
              color: error
                  ? Colors.red.shade400
                  : filled
                      ? AppColors.primary
                      : AppColors.textLight,
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}

class _Keypad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onBiometric;

  const _Keypad({
    required this.onDigit,
    required this.onDelete,
    this.onBiometric,
  });

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      // Bottom row: biometric (or blank), 0, delete
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          ...rows.map((row) => _buildRow(row)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Biometric or empty
              SizedBox(
                width: 72,
                height: 72,
                child: onBiometric != null
                    ? _KeyButton(
                        onTap: onBiometric!,
                        child: Icon(Icons.fingerprint_rounded,
                            size: 30, color: AppColors.primary),
                      )
                    : const SizedBox(),
              ),
              _KeyButton(
                onTap: () => onDigit('0'),
                child: const Text('0',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
              ),
              _KeyButton(
                onTap: onDelete,
                child: const Icon(Icons.backspace_outlined,
                    size: 22, color: AppColors.textDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> digits) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: digits
            .map((d) => _KeyButton(
                  onTap: () => onDigit(d),
                  child: Text(d,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark)),
                ))
            .toList(),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _KeyButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primarySoft.withValues(alpha: 0.5),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
