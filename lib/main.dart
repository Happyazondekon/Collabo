import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';
import 'services/lock_service.dart';
import 'services/notification_service.dart';
import 'auth/auth_wrapper.dart';
import 'screnns/app_lock_screen.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  await Firebase.initializeApp();

  // Initialise le service de notifications locales
  await CollaboNotificationService().initialize();

  runApp(const CollaboApp());
}

class CollaboApp extends StatelessWidget {
  const CollaboApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        StreamProvider<AppUser?>(
          create: (context) => context.read<AuthService>().userStream,
          initialData: null,
        ),
      ],
      child: MaterialApp(
        title: 'Collabo',
        theme: AppTheme.theme,
        home: const _AppLockGate(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

// ─── Lock Gate ────────────────────────────────────────────────────
// Shown at startup and whenever the app returns from background.
// If no PIN is set yet, we pass straight through to AuthWrapper.

class _AppLockGate extends StatefulWidget {
  const _AppLockGate();

  @override
  State<_AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<_AppLockGate> {
  // null = still checking; true = locked; false = unlocked / no PIN set
  bool? _locked;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _checkLock();
    _lifecycleListener = AppLifecycleListener(
      onResume: _onResume,
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  Future<void> _checkLock() async {
    final has = await LockService.instance.hasPin();
    if (mounted) setState(() => _locked = has);
  }

  Future<void> _onResume() async {
    // Re-lock when returning from background only if PIN is set.
    final has = await LockService.instance.hasPin();
    if (has && mounted) setState(() => _locked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_locked == null) {
      // Splash while checking
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_locked == true) {
      return AppLockScreen(onUnlocked: () => setState(() => _locked = false));
    }

    return const AuthWrapper();
  }
}
