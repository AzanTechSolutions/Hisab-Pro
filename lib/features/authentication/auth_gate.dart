import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisab_pro/core/theme/design_tokens.dart';
import 'package:hisab_pro/features/user_profiles/profile_providers.dart';
import 'package:hisab_pro/features/user_profiles/user_profile.dart';
import 'package:local_auth/local_auth.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key, this.selectedProfileId});

  final String? selectedProfileId;

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  final _pinController = TextEditingController();
  final _localAuth = LocalAuthentication();
  bool _isLoading = false;
  String? _errorMessage;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  UserProfile? _targetProfile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTargetProfile();
    });
  }

  Future<void> _loadTargetProfile() async {
    try {
      final profilesAsync = await ref.read(profileCatalogProvider.future);
      if (!mounted) return;

      if (profilesAsync.isEmpty) {
        context.go('/profiles/create');
        return;
      }

      UserProfile? target;
      if (widget.selectedProfileId != null) {
        target = profilesAsync.where((p) => p.id == widget.selectedProfileId).firstOrNull;
      }
      target ??= profilesAsync.first;

      setState(() {
        _targetProfile = target;
      });

      if (target.biometricEnabled) {
        _attemptBiometricAuth(target.id);
      }
    } catch (e) {
      if (mounted) {
        context.go('/profiles/create');
      }
    }
  }

  Future<void> _attemptBiometricAuth(String profileId) async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return;

      final didAuth = await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock your Hisab Pro ledger',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (didAuth && mounted) {
        setState(() => _isLoading = true);
        final profile = await ref
            .read(profileManagerServiceProvider)
            .unlockProfileWithBiometrics(profileId: profileId);

        if (profile != null && mounted) {
          ref.read(activeProfileProvider.notifier).setActiveProfile(profile);
          context.go('/dashboard');
        } else if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Biometric key unlock failed. Please enter your PIN.';
          });
        }
      }
    } catch (_) {
      // Gracefully fall back to PIN on biometric failure or cancel
    }
  }

  Future<void> _handlePinSubmit() async {
    if (_targetProfile == null) return;

    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      final waitSec = _lockoutUntil!.difference(DateTime.now()).inSeconds;
      setState(() {
        _errorMessage = 'Too many failed attempts. Wait $waitSec seconds.';
      });
      return;
    }

    final pin = _pinController.text.trim();
    if (pin.length < 4) {
      setState(() => _errorMessage = 'Enter your 4-digit PIN');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await ref
          .read(profileManagerServiceProvider)
          .unlockProfileWithPin(profileId: _targetProfile!.id, pin: pin);

      if (!mounted) return;

      if (profile != null) {
        _failedAttempts = 0;
        ref.read(activeProfileProvider.notifier).setActiveProfile(profile);
        context.go('/dashboard');
      } else {
        _failedAttempts++;
        if (_failedAttempts >= 5) {
          _lockoutUntil = DateTime.now().add(const Duration(seconds: 30));
          _errorMessage = 'Too many failed attempts. Locked for 30s.';
        } else {
          _errorMessage = 'Incorrect PIN. Try again. ($_failedAttempts/5)';
        }
        _pinController.clear();
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unlock failed: ${e.toString()}';
        });
      }
    }
  }

  void _onNumpadPress(String val) {
    if (_pinController.text.length < 6) {
      setState(() {
        _pinController.text += val;
        _errorMessage = null;
      });
      if (_pinController.text.length == 4) {
        _handlePinSubmit();
      }
    }
  }

  void _onNumpadDelete() {
    if (_pinController.text.isNotEmpty) {
      setState(() {
        _pinController.text =
            _pinController.text.substring(0, _pinController.text.length - 1);
        _errorMessage = null;
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _targetProfile;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (profile == null) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.deepNavy : AppColors.neutral,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 36,
                  color: AppColors.emerald,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.emerald),
              ),
              const SizedBox(height: 16),
              Text(
                'Hisab Pro',
                style: AppTextStyles.headline.copyWith(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.deepNavy : AppColors.neutral,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/profiles'),
            icon: const Icon(Icons.people_outline, size: 20),
            label: const Text('Switch Profile'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Profile Avatar & Name
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.emerald.withValues(alpha: 0.15),
                  child: Text(
                    profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : 'H',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: AppColors.emerald,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  profile.fullName,
                  style: AppTextStyles.title.copyWith(fontSize: 22),
                ),
                Text(
                  '@${profile.username}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // PIN Dots
                Text(
                  'Enter Secret PIN',
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < _pinController.text.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled
                            ? AppColors.emerald
                            : (isDark ? Colors.white24 : Colors.black12),
                        border: Border.all(
                          color: isFilled ? AppColors.emerald : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: AppSpacing.lg),
                if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),

                const SizedBox(height: AppSpacing.xl),

                // Custom Fintech Numpad
                _buildNumpad(profile),

                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.asset(
                        'assets/images/azantech_logo.png',
                        width: 16,
                        height: 16,
                        errorBuilder: (_, __, ___) => const SizedBox(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Developed by AzanTech Solutions',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad(UserProfile profile) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _numpadButton('1'),
              _numpadButton('2'),
              _numpadButton('3'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _numpadButton('4'),
              _numpadButton('5'),
              _numpadButton('6'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _numpadButton('7'),
              _numpadButton('8'),
              _numpadButton('9'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (profile.biometricEnabled)
                IconButton(
                  iconSize: 32,
                  icon: const Icon(Icons.fingerprint, color: AppColors.emerald),
                  onPressed: () => _attemptBiometricAuth(profile.id),
                )
              else
                const SizedBox(width: 68),
              _numpadButton('0'),
              IconButton(
                iconSize: 28,
                icon: const Icon(Icons.backspace_outlined),
                onPressed: _onNumpadDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numpadButton(String digit) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => _onNumpadPress(digit),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 68,
        height: 68,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          digit,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
