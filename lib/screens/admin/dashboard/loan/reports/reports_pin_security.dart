
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';

class ReportsPinSecurity {
  ReportsPinSecurity._();

  static const FlutterSecureStorage _storage =
  FlutterSecureStorage();

  static final LocalAuthentication _localAuth =
  LocalAuthentication();

  static final Pbkdf2 _pbkdf2 = Pbkdf2.hmacSha256(
    iterations: 100000,
    bits: 256,
  );

  static final Map<String, int> _failedAttempts = {};
  static final Map<String, DateTime> _lockedUntil = {};

  static const String _forgotToken = '__FORGOT_PIN__';

  static const Color _blue = Color(0xFF2457D6);
  static const Color _darkBlue = Color(0xFF173B9A);
  static const Color _lightBlue = Color(0xFFEAF1FF);

  static const Map<String, String> questions = {
    'q1': 'आपके बचपन के दोस्त का नाम क्या है?',
    'q2': 'आपके पहले स्कूल का नाम क्या था?',
    'q3': 'आपके गाँव/शहर का नाम क्या है?',
    'q4': 'आपका पसंदीदा शिक्षक कौन था?',
    'q5': 'आपकी पहली नौकरी/काम क्या था?',
  };

  // ------------------------------------------------------------
  // PREMIUM DIALOG THEME
  // ------------------------------------------------------------

  static ThemeData _premiumTheme(BuildContext context) {
    final base = Theme.of(context);

    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: _blue,
        secondary: _blue,
        surface: Colors.white,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF7F9FE),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 15,
        ),
        labelStyle: const TextStyle(
          color: Color(0xFF69758B),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          color: _blue,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFE2E8F3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFE2E8F3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: _blue,
            width: 1.6,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Colors.redAccent,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Colors.redAccent,
            width: 1.5,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _blue,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.all(_blue),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // PREMIUM DIALOG ANIMATION
  // ------------------------------------------------------------

  static Future<T?> _showPremiumDialog<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Reports security',
      barrierColor: Colors.black.withValues(alpha: 0.48),
      transitionDuration: const Duration(milliseconds: 190),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Center(
            child: Theme(
              data: _premiumTheme(context),
              child: builder(context),
            ),
          ),
        );
      },
      transitionBuilder: (
          context,
          animation,
          secondaryAnimation,
          child,
          ) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.94,
              end: 1,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // PREMIUM DIALOG CARD
  // ------------------------------------------------------------

  static Widget _premiumCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget content,
    required List<Widget> actions,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 430,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(27),
            border: Border.all(
              color: const Color(0xFFE8EDF7),
            ),
            boxShadow: [
              BoxShadow(
                color: _darkBlue.withValues(alpha: 0.14),
                blurRadius: 35,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  22,
                  20,
                  16,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF4779F5),
                            _darkBlue,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(17),
                        boxShadow: [
                          BoxShadow(
                            color: _blue.withValues(alpha: 0.22),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Color(0xFF17233C),
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: Color(0xFF78849A),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 1,
                color: const Color(0xFFF0F3F9),
              ),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                    MediaQuery.of(context).size.height * 0.57,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      18,
                      20,
                      8,
                    ),
                    child: content,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  16,
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 6,
                  children: actions,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _securityNote(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _lightBlue,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_outlined,
            color: _blue,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF344B7C),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _pinInput({
    required TextEditingController controller,
    required String label,
    String? errorText,
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      obscureText: true,
      maxLength: 4,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        errorText: errorText,
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          size: 20,
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // STORAGE KEY
  // ------------------------------------------------------------

  static String _key(String uid, String field) {
    return 'reports_pin_${uid}_$field';
  }

  // ------------------------------------------------------------
  // DIALOG CONTROLLER DISPOSAL
  // ------------------------------------------------------------

  static Future<void> _disposeDialogControllers(
      List<TextEditingController> controllers,
      ) async {
    await Future<void>.delayed(
      const Duration(milliseconds: 500),
    );

    for (final controller in controllers) {
      controller.dispose();
    }
  }

  // ------------------------------------------------------------
  // OPEN REPORTS
  // ------------------------------------------------------------

  static Future<void> open({
    required BuildContext context,
    required VoidCallback onUnlocked,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _message(context, 'Admin login नहीं है।');
      return;
    }

    final uid = user.uid;

    final lockedUntil = _lockedUntil[uid];

    if (lockedUntil != null &&
        DateTime.now().isBefore(lockedUntil)) {
      final seconds =
          lockedUntil.difference(DateTime.now()).inSeconds + 1;

      _message(
        context,
        'बहुत गलत PIN डाले गए। $seconds सेकंड बाद प्रयास करें।',
      );

      return;
    }

    final savedPinHash = await _storage.read(
      key: _key(uid, 'pin_hash'),
    );

    if (!context.mounted) return;

    if (savedPinHash == null) {
      final setup = await _showSetupDialog(
        context,
        allowBiometricOption: true,
      );

      if (setup == null || !context.mounted) return;

      final biometricEnabled = await _checkAndTestBiometric(
        context,
        setup.enableBiometric,
      );

      if (setup.enableBiometric && !biometricEnabled) {
        if (context.mounted) {
          _message(
            context,
            'Biometric verify नहीं हुआ। PIN setup दोबारा करें और biometric बंद करके try करें।',
          );
        }

        return;
      }

      await _saveSetup(
        uid,
        setup,
        biometricEnabled,
      );

      if (!context.mounted) return;

      _message(
        context,
        'Reports PIN successfully created.',
      );

      onUnlocked();
      return;
    }

    final enteredPin = await _showPinDialog(context);

    if (!context.mounted || enteredPin == null) return;

    if (enteredPin == _forgotToken) {
      await _recoverPin(context, uid);
      return;
    }

    final correct = await _verifyHash(
      uid: uid,
      field: 'pin',
      enteredValue: enteredPin,
    );

    if (!context.mounted) return;

    if (correct) {
      _failedAttempts[uid] = 0;
      _lockedUntil.remove(uid);

      onUnlocked();
      return;
    }

    final attempts = (_failedAttempts[uid] ?? 0) + 1;
    _failedAttempts[uid] = attempts;

    if (attempts >= 5) {
      _failedAttempts[uid] = 0;

      _lockedUntil[uid] =
          DateTime.now().add(const Duration(seconds: 60));

      _message(
        context,
        '5 बार गलत PIN। 60 सेकंड के लिए lock किया गया।',
      );
    } else {
      _message(
        context,
        'गलत PIN। बाकी प्रयास: ${5 - attempts}',
      );
    }
  }

  // ------------------------------------------------------------
  // PIN SETUP DIALOG
  // ------------------------------------------------------------

  static Future<_ReportsPinSetup?> _showSetupDialog(
      BuildContext context, {
        required bool allowBiometricOption,
      }) async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    final answerController = TextEditingController();

    String selectedQuestion = questions.keys.first;
    bool enableBiometric = false;
    String? error;

    final result = await _showPremiumDialog<_ReportsPinSetup>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return _premiumCard(
              context: context,
              title: 'Create Reports PIN',
              subtitle: 'Reports को सुरक्षित रखने के लिए',
              icon: Icons.security_rounded,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _securityNote(
                    '4-digit PIN बनाइए। PIN भूलने पर security question से recovery कर सकेंगे।',
                  ),
                  const SizedBox(height: 16),
                  _pinInput(
                    controller: pinController,
                    label: '4-digit PIN',
                  ),
                  const SizedBox(height: 12),
                  _pinInput(
                    controller: confirmController,
                    label: 'Confirm PIN',
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: selectedQuestion,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Security Question',
                      prefixIcon: Icon(
                        Icons.help_outline_rounded,
                        size: 20,
                      ),
                    ),
                    items: questions.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;

                      setDialogState(() {
                        selectedQuestion = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: answerController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Security Answer',
                      prefixIcon: Icon(
                        Icons.key_rounded,
                        size: 20,
                      ),
                    ),
                  ),
                  if (allowBiometricOption) ...[
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FE),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: CheckboxListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                        ),
                        value: enableBiometric,
                        title: const Text(
                          'Enable fingerprint / biometric recovery',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        secondary: const Icon(
                          Icons.fingerprint_rounded,
                          color: _blue,
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            enableBiometric = value ?? false;
                          });
                        },
                      ),
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final pin = pinController.text.trim();
                    final confirm = confirmController.text.trim();

                    final answer = _normalizeAnswer(
                      answerController.text,
                    );

                    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
                      setDialogState(() {
                        error =
                        'PIN exactly 4 digits का होना चाहिए।';
                      });
                      return;
                    }

                    if (pin != confirm) {
                      setDialogState(() {
                        error = 'PIN और Confirm PIN match नहीं हैं।';
                      });
                      return;
                    }

                    if (answer.length < 2) {
                      setDialogState(() {
                        error =
                        'Security answer कम से कम 2 characters का रखें।';
                      });
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      _ReportsPinSetup(
                        pin: pin,
                        question: selectedQuestion,
                        answer: answer,
                        enableBiometric: enableBiometric,
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.check_rounded,
                    size: 18,
                  ),
                  label: const Text('Save PIN'),
                ),
              ],
            );
          },
        );
      },
    );

    await _disposeDialogControllers([
      pinController,
      confirmController,
      answerController,
    ]);

    return result;
  }

  // ------------------------------------------------------------
  // SAVE PIN + SECURITY QUESTION
  // ------------------------------------------------------------

  static Future<void> _saveSetup(
      String uid,
      _ReportsPinSetup setup,
      bool biometricEnabled,
      ) async {
    await _saveHash(
      uid: uid,
      field: 'pin',
      value: setup.pin,
    );

    await _saveHash(
      uid: uid,
      field: 'answer',
      value: setup.answer,
    );

    await _storage.write(
      key: _key(uid, 'question'),
      value: setup.question,
    );

    await _storage.write(
      key: _key(uid, 'biometric_enabled'),
      value: biometricEnabled ? 'true' : 'false',
    );
  }

  static Future<void> _saveNewPin(
      String uid,
      String pin,
      ) async {
    await _saveHash(
      uid: uid,
      field: 'pin',
      value: pin,
    );
  }

  // ------------------------------------------------------------
  // HASH STORAGE
  // ------------------------------------------------------------

  static Future<void> _saveHash({
    required String uid,
    required String field,
    required String value,
  }) async {
    final salt = _randomBytes(16);

    final hash = await _hashValue(
      value: value,
      salt: salt,
    );

    await _storage.write(
      key: _key(uid, '${field}_salt'),
      value: base64Encode(salt),
    );

    await _storage.write(
      key: _key(uid, '${field}_hash'),
      value: base64Encode(hash),
    );
  }

  static Future<bool> _verifyHash({
    required String uid,
    required String field,
    required String enteredValue,
  }) async {
    final saltText = await _storage.read(
      key: _key(uid, '${field}_salt'),
    );

    final savedHashText = await _storage.read(
      key: _key(uid, '${field}_hash'),
    );

    if (saltText == null || savedHashText == null) {
      return false;
    }

    final salt = base64Decode(saltText);
    final savedHash = base64Decode(savedHashText);

    final enteredHash = await _hashValue(
      value: enteredValue,
      salt: salt,
    );

    if (enteredHash.length != savedHash.length) {
      return false;
    }

    int difference = 0;

    for (int i = 0; i < enteredHash.length; i++) {
      difference |= enteredHash[i] ^ savedHash[i];
    }

    return difference == 0;
  }

  static Future<List<int>> _hashValue({
    required String value,
    required List<int> salt,
  }) async {
    final secret = await _pbkdf2.deriveKeyFromPassword(
      password: value,
      nonce: salt,
    );

    return secret.extractBytes();
  }

  static List<int> _randomBytes(int length) {
    final random = Random.secure();

    return List<int>.generate(
      length,
          (_) => random.nextInt(256),
    );
  }

  static String _normalizeAnswer(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  // ------------------------------------------------------------
  // VERIFY PIN DIALOG
  // ------------------------------------------------------------

  static Future<String?> _showPinDialog(
      BuildContext context,
      ) async {
    final controller = TextEditingController();
    String? error;

    final result = await _showPremiumDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return _premiumCard(
              context: context,
              title: 'Enter Reports PIN',
              subtitle: 'आपके Reports सुरक्षित हैं',
              icon: Icons.lock_rounded,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _securityNote(
                    'Reports देखने के लिए अपना 4-digit PIN verify करें।',
                  ),
                  const SizedBox(height: 18),
                  _pinInput(
                    controller: controller,
                    label: '4-digit PIN',
                    errorText: error,
                    autofocus: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      _forgotToken,
                    );
                  },
                  child: const Text('Forgot PIN?'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    if (controller.text.length != 4) {
                      setDialogState(() {
                        error = '4-digit PIN डालें।';
                      });
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      controller.text,
                    );
                  },
                  icon: const Icon(
                    Icons.verified_user_rounded,
                    size: 18,
                  ),
                  label: const Text('Verify'),
                ),
              ],
            );
          },
        );
      },
    );

    await _disposeDialogControllers([
      controller,
    ]);

    return result;
  }

  // ------------------------------------------------------------
  // FORGOT PIN / RECOVERY
  // ------------------------------------------------------------

  static Future<void> _recoverPin(
      BuildContext context,
      String uid,
      ) async {
    final biometricEnabled = await _storage.read(
      key: _key(uid, 'biometric_enabled'),
    ) ==
        'true';

    if (!context.mounted) return;

    final recoveryMethod = await _showPremiumDialog<String>(
      context: context,
      builder: (dialogContext) {
        return _premiumCard(
          context: dialogContext,
          title: 'Recover Reports PIN',
          subtitle: 'अपनी identity verify करें',
          icon: Icons.manage_accounts_rounded,
          content: _securityNote(
            'PIN reset करने से पहले recovery method से verification जरूरी है।',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, 'answer');
              },
              icon: const Icon(
                Icons.question_answer_rounded,
                size: 18,
              ),
              label: const Text('Security Answer'),
            ),
            if (biometricEnabled)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext, 'biometric');
                },
                icon: const Icon(
                  Icons.fingerprint_rounded,
                  size: 18,
                ),
                label: const Text('Biometric'),
              ),
          ],
        );
      },
    );

    if (!context.mounted || recoveryMethod == null) return;

    if (recoveryMethod == 'answer') {
      final questionKey = await _storage.read(
        key: _key(uid, 'question'),
      );

      final question =
          questions[questionKey] ?? 'आपका Security Question';

      final answer = await _showAnswerDialog(
        context,
        question,
      );

      if (!context.mounted || answer == null) return;

      final correct = await _verifyHash(
        uid: uid,
        field: 'answer',
        enteredValue: _normalizeAnswer(answer),
      );

      if (!context.mounted) return;

      if (!correct) {
        _message(context, 'Security answer गलत है।');
        return;
      }

      final newPin = await _showNewPinDialog(context);

      if (!context.mounted || newPin == null) return;

      await _saveNewPin(uid, newPin);

      _failedAttempts[uid] = 0;
      _lockedUntil.remove(uid);

      _message(
        context,
        'PIN reset हो गया। अब नए PIN से Reports खोलें।',
      );

      return;
    }

    if (recoveryMethod == 'biometric') {
      final authenticated = await _authenticateBiometric();

      if (!context.mounted) return;

      if (!authenticated) {
        _message(
          context,
          'Biometric verification failed.',
        );
        return;
      }

      final setup = await _showSetupDialog(
        context,
        allowBiometricOption: false,
      );

      if (!context.mounted || setup == null) return;

      await _saveSetup(
        uid,
        setup,
        true,
      );

      _failedAttempts[uid] = 0;
      _lockedUntil.remove(uid);

      _message(
        context,
        'PIN और Security Question reset हो गए।',
      );
    }
  }

  // ------------------------------------------------------------
  // SECURITY ANSWER DIALOG
  // ------------------------------------------------------------

  static Future<String?> _showAnswerDialog(
      BuildContext context,
      String question,
      ) async {
    final controller = TextEditingController();

    final result = await _showPremiumDialog<String>(
      context: context,
      builder: (dialogContext) {
        return _premiumCard(
          context: dialogContext,
          title: 'Security Answer',
          subtitle: 'अपना saved answer verify करें',
          icon: Icons.question_answer_rounded,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _lightBlue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  question,
                  style: const TextStyle(
                    color: Color(0xFF29457D),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Answer',
                  prefixIcon: Icon(
                    Icons.key_rounded,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  controller.text,
                );
              },
              icon: const Icon(
                Icons.verified_rounded,
                size: 18,
              ),
              label: const Text('Verify'),
            ),
          ],
        );
      },
    );

    await _disposeDialogControllers([
      controller,
    ]);

    return result;
  }

  // ------------------------------------------------------------
  // NEW PIN DIALOG
  // ------------------------------------------------------------

  static Future<String?> _showNewPinDialog(
      BuildContext context,
      ) async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();

    String? error;

    final result = await _showPremiumDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return _premiumCard(
              context: context,
              title: 'Create New PIN',
              subtitle: 'अपना नया Reports PIN सेट करें',
              icon: Icons.lock_reset_rounded,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _securityNote(
                    'नया PIN 4 digits का होना चाहिए।',
                  ),
                  const SizedBox(height: 16),
                  _pinInput(
                    controller: pinController,
                    label: 'New 4-digit PIN',
                  ),
                  const SizedBox(height: 12),
                  _pinInput(
                    controller: confirmController,
                    label: 'Confirm New PIN',
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final pin = pinController.text;
                    final confirm = confirmController.text;

                    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
                      setDialogState(() {
                        error =
                        'PIN exactly 4 digits का होना चाहिए।';
                      });
                      return;
                    }

                    if (pin != confirm) {
                      setDialogState(() {
                        error = 'दोनों PIN match नहीं हैं।';
                      });
                      return;
                    }

                    Navigator.pop(dialogContext, pin);
                  },
                  icon: const Icon(
                    Icons.check_rounded,
                    size: 18,
                  ),
                  label: const Text('Reset PIN'),
                ),
              ],
            );
          },
        );
      },
    );

    await _disposeDialogControllers([
      pinController,
      confirmController,
    ]);

    return result;
  }

  // ------------------------------------------------------------
  // BIOMETRIC
  // ------------------------------------------------------------

  static Future<bool> _checkAndTestBiometric(
      BuildContext context,
      bool requested,
      ) async {
    if (!requested) return false;

    final available =
    await _localAuth.getAvailableBiometrics();

    if (available.isEmpty) {
      if (context.mounted) {
        _message(
          context,
          'Device पर fingerprint/biometric set नहीं है।',
        );
      }

      return false;
    }

    return _authenticateBiometric();
  }

  static Future<bool> _authenticateBiometric() async {
    try {
      final supported =
      await _localAuth.isDeviceSupported();

      if (!supported) return false;

      return await _localAuth.authenticate(
        localizedReason:
        'Reports PIN recovery के लिए biometric verify करें',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------
  // MESSAGE
  // ------------------------------------------------------------

  static void _message(
      BuildContext context,
      String message,
      ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }
}

// ------------------------------------------------------------
// PIN SETUP MODEL
// ------------------------------------------------------------

class _ReportsPinSetup {
  final String pin;
  final String question;
  final String answer;
  final bool enableBiometric;

  const _ReportsPinSetup({
    required this.pin,
    required this.question,
    required this.answer,
    required this.enableBiometric,
  });
}
