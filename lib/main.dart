import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:confetti/confetti.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const supabaseUrl = 'https://pwlidahqnfczjgqikzzy.supabase.co';
const supabaseAnonKey = 'sb_publishable_xDxJd7g0SvwMtQ9L-1BATQ__ql0v8Ay';

const kBgColor = Color(0xFF15131B);
const kSurfaceColor = Color(0xFF1E1A24);
const kAccentGold = Color(0xFFF3A93B);
const kAccentTeal = Color(0xFF4FD1C2);

class StatOption {
  final String key;
  final String label;
  final String suffix;

  const StatOption({required this.key, required this.label, this.suffix = ''});
}

const kStatOptions = [
  StatOption(key: 'wins', label: '🏆 Wins'),
  StatOption(key: 'currentStreak', label: '🔥 Streak'),
  StatOption(key: 'longestStreak', label: '⭐ Best Streak'),
  StatOption(key: 'submissions', label: '📸 Photos Submitted'),
  StatOption(key: 'disqualifications', label: '🚫 Disqualifications'),
  StatOption(key: 'winRate', label: '📊 Win Rate', suffix: '%'),
];

const kDefaultStatKeys = ['wins', 'currentStreak', 'longestStreak'];

class StoreItemDef {
  final String key;
  final String name;
  final int cost;
  final String description;
  final FaIconData icon;
  final bool comingSoon;

  const StoreItemDef({
    required this.key,
    required this.name,
    required this.cost,
    required this.description,
    required this.icon,
    this.comingSoon = false,
  });
}

const kStoreItems = [
  StoreItemDef(
    key: 'custom_title',
    name: 'Custom Title',
    cost: 20,
    description: 'Unlock a cosmetic badge next to your name.',
    icon: FontAwesomeIcons.tag,
  ),
  StoreItemDef(
    key: 'score_insurance',
    name: 'Score Insurance',
    cost: 12,
    description: 'Add a visible +1 to today\'s score (once you\'ve submitted).',
    icon: FontAwesomeIcons.shieldHalved,
  ),
  StoreItemDef(
    key: 'streak_shield',
    name: 'Streak Shield',
    cost: 15,
    description: 'Forgive one missed day without breaking your streak.',
    icon: FontAwesomeIcons.fire,
  ),
  StoreItemDef(
    key: 'dare_card',
    name: 'Dare Card',
    cost: 25,
    description: 'Force tomorrow to be a themed Challenge Day for the group.',
    icon: FontAwesomeIcons.diceD6,
  ),
  StoreItemDef(
    key: 'anonymous_submission',
    name: 'Anonymous Submission',
    cost: 10,
    description: 'Hide your name on today\'s submission (once you\'ve submitted).',
    icon: FontAwesomeIcons.userSecret,
  ),
  StoreItemDef(
    key: 'freeze',
    name: 'Freeze',
    cost: 30,
    description: 'Force a rival to skip a day. Coming soon.',
    icon: FontAwesomeIcons.snowflake,
    comingSoon: true,
  ),
];

Future<int> fetchCoinBalance(String groupId, String userId) async {
  final supabase = Supabase.instance.client;
  final rows = await supabase
      .from('coin_transactions')
      .select('amount')
      .eq('group_id', groupId)
      .eq('user_id', userId);

  var total = 0;
  for (final r in rows) {
    total += (r['amount'] ?? 0) as int;
  }
  return total;
}

class DoodleBackground extends StatelessWidget {
  final Color color;
  final double spacing;

  const DoodleBackground({super.key, this.color = Colors.white, this.spacing = 64});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _DoodlePainter(color: color, spacing: spacing),
      ),
    );
  }
}

class _DoodlePainter extends CustomPainter {
  final Color color;
  final double spacing;

  const _DoodlePainter({required this.color, required this.spacing});

  static const _glyphs = [
    FontAwesomeIcons.camera,
    FontAwesomeIcons.star,
    FontAwesomeIcons.fire,
    FontAwesomeIcons.trophy,
    FontAwesomeIcons.scaleBalanced,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const glyphSize = 19.0;
    var row = 0;
    for (double y = -spacing; y < size.height + spacing; y += spacing) {
      final offsetX = row.isOdd ? spacing / 2 : 0.0;
      var col = 0;
      for (double x = -spacing; x < size.width + spacing; x += spacing) {
        final icon = _glyphs[(row + col) % _glyphs.length];
        final tp = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              fontSize: glyphSize,
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
              color: color.withOpacity(0.05),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + offsetX, y));
        col++;
      }
      row++;
    }
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.spacing != spacing;
}

/// Wraps a page's content with the group's chosen app background (the
/// doodle pattern in one of a few tints, or a custom photo). Pass
/// [group] wherever it's available so the page respects that group's
/// choice; pages with no group context (Home, auth/onboarding) just get
/// the neutral default pattern.
class AppBackground extends StatelessWidget {
  final dynamic group;
  final Widget child;

  const AppBackground({super.key, this.group, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = group?['background_theme'] as String? ?? 'default';
    final photoPath = group?['theme_photo_url'] as String?;

    if (theme == 'photo' && photoPath != null) {
      return Stack(
        children: [
          Positioned.fill(
            child: FutureBuilder<String>(
              future: Supabase.instance.client.storage
                  .from('Photos')
                  .createSignedUrl(photoPath, 60 * 60),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Container(color: kBgColor);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(imageUrl: snapshot.data!, fit: BoxFit.cover),
                    Container(color: kBgColor.withOpacity(0.78)),
                  ],
                );
              },
            ),
          ),
          child,
        ],
      );
    }

    final color = switch (theme) {
      'warm' => kAccentGold,
      'cool' => kAccentTeal,
      _ => Colors.white,
    };

    return Stack(
      children: [
        Positioned.fill(child: DoodleBackground(color: color)),
        child,
      ],
    );
  }
}

final analytics = FirebaseAnalytics.instance;

final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

const kNotificationChannel = AndroidNotificationChannel(
  'my_nemesis_default',
  'Notifications',
  description: 'Chat, uploads, scores and rule updates',
  importance: Importance.high,
);

Future<void> _showLocalNotification(RemoteMessage message) async {
  final notification = message.notification;
  if (notification == null) return;

  await flutterLocalNotificationsPlugin.show(
    id: notification.hashCode,
    title: notification.title,
    body: notification.body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        kNotificationChannel.id,
        kNotificationChannel.name,
        channelDescription: kNotificationChannel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}

String roleLabel(String? role) {
  switch (role) {
    case 'judge':
      return 'Judge (scores photos, doesn\'t play)';
    case 'judge_hybrid':
      return 'Judge who also plays';
    case 'owner':
      return 'Owner';
    default:
      return 'Player';
  }
}

Future<void> playFeedbackSound() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('sound_effects_enabled') ?? true) {
    SystemSound.play(SystemSoundType.click);
  }
}

Future<void> maybeRequestReview() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('review_prompted') == true) return;
  await prefs.setBool('review_prompted', true);

  final inAppReview = InAppReview.instance;
  if (await inAppReview.isAvailable()) {
    inAppReview.requestReview();
  }
}

const _kStreakMilestones = [3, 7, 14, 30];
const _kWinMilestones = [1, 5, 10, 25, 50];

Future<void> checkAchievementMilestones(BuildContext context, Map<String, int> stats) async {
  final prefs = await SharedPreferences.getInstance();

  final bestStreak = prefs.getInt('ach_best_streak') ?? 0;
  final bestWins = prefs.getInt('ach_best_wins') ?? 0;
  final longestStreak = stats['longestStreak'] ?? 0;
  final totalWins = stats['totalWins'] ?? 0;

  String? unlockedTitle;
  String unlockedEmoji = '🏅';

  for (final m in _kStreakMilestones.reversed) {
    if (longestStreak >= m && bestStreak < m) {
      unlockedTitle = '$m-Day Streak';
      unlockedEmoji = '🔥';
      break;
    }
  }

  if (unlockedTitle == null) {
    for (final m in _kWinMilestones.reversed) {
      if (totalWins >= m && bestWins < m) {
        unlockedTitle = m == 1 ? 'First Win' : '$m Wins';
        unlockedEmoji = '🏆';
        break;
      }
    }
  }

  if (longestStreak > bestStreak) await prefs.setInt('ach_best_streak', longestStreak);
  if (totalWins > bestWins) await prefs.setInt('ach_best_wins', totalWins);

  if (unlockedTitle == null) return;
  if (!context.mounted) return;

  HapticFeedback.mediumImpact();
  playFeedbackSound();
  analytics.logEvent(name: 'achievement_unlocked', parameters: {'achievement': unlockedTitle});

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: kSurfaceColor,
      title: Text('$unlockedEmoji Achievement Unlocked!', textAlign: TextAlign.center),
      content: Text(
        unlockedTitle!,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Nice!'),
        ),
      ],
    ),
  );
}

Future<void> sendNotification({
  required String type,
  required String groupId,
  required String senderId,
  required String senderName,
  String? photoPath,
}) async {
  try {
    await Supabase.instance.client.functions.invoke(
      'send-notification',
      body: {
        'type': type,
        'groupId': groupId,
        'senderId': senderId,
        'senderName': senderName,
        if (photoPath != null) 'photoPath': photoPath,
      },
    );
  } catch (_) {}
}
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  // Route uncaught errors to Crashlytics instead of only the debug console.
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // FCM only auto-displays a system notification when the app is backgrounded
  // or closed. When it's open in the foreground, we have to show it ourselves.
  // Wrapped in try/catch so a notification-setup failure can never block app
  // startup — it should degrade to "no foreground notifications", not a hang.
  try {
    await flutterLocalNotificationsPlugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_launcher_foreground'),
      ),
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(kNotificationChannel);
    FirebaseMessaging.onMessage.listen(_showLocalNotification);
  } catch (e, st) {
    FirebaseCrashlytics.instance.recordError(e, st, fatal: false);
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const MyNemesisApp());
}

class MyNemesisApp extends StatelessWidget {
  const MyNemesisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Nemesis',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior(),
      theme: ThemeData(
        brightness: Brightness.dark,
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        scaffoldBackgroundColor: kBgColor,
        cardColor: kSurfaceColor,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE10600),
          secondary: Colors.white,
          surface: kSurfaceColor,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kBgColor,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
       elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE10600),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFE10600),
          ),
        ),
        cardTheme: CardThemeData(
          color: kSurfaceColor,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: kSurfaceColor,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? const Color(0xFFE10600)
                : Colors.grey,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? const Color(0xFFE10600).withOpacity(0.5)
                : Colors.grey.shade800,
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      return const LoginPage();
    }

    return const HomePage();
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty) {
      showError('Please enter your email.');
      return;
    }
    if (password.isEmpty) {
      showError('Please enter your password.');
      return;
    }

    setState(() => isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (userId != null) {
            await Supabase.instance.client
                .from('users')
                .update({'fcm_token': fcmToken})
                .eq('id', userId);
          }
        }
      } catch (_) {}

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('invalid') || message.contains('credentials')) {
        showError('Wrong email or password. Please try again.');
      } else if (message.contains('network') || message.contains('socket')) {
        showError('No internet connection. Please check your network.');
      } else if (message.contains('too many')) {
        showError('Too many attempts. Please wait a moment and try again.');
      } else if (message.contains('email') && message.contains('confirm')) {
        showError('Please confirm your email first. Check your inbox.');
      } else {
        showError('Something went wrong. Please try again.');
      }
    }

    setState(() => isLoading = false);
  }

  Future<bool> _needsNickname(String userId) async {
       try {
         final profile = await Supabase.instance.client
             .from('users')
             .select('username, display_name')
             .eq('id', userId)
             .maybeSingle();

         final username = profile?['username'] as String?;
         final displayName = profile?['display_name'] as String?;

         final effectiveName = (displayName?.isNotEmpty == true)
             ? displayName
             : username;

         if (effectiveName == null || effectiveName.isEmpty) return true;
         if (effectiveName.contains('@')) return true;
         return false;
       } catch (e) {
         return false;
       }
     }
  Future<void> _signInWithGoogle() async {
    setState(() => isLoading = true);

    try {
      const webClientId =
          '541449642996-k1uqilt2e4grlmfqp9n8f0gei7j3vdpu.apps.googleusercontent.com';

      final GoogleSignIn googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize(serverClientId: webClientId);

      final googleUser = await googleSignIn.authenticate();

      final authorization = await googleUser.authorizationClient
              .authorizationForScopes(['email', 'profile']) ??
          await googleUser.authorizationClient
              .authorizeScopes(['email', 'profile']);

      final idToken = googleUser.authentication.idToken;
      final accessToken = authorization.accessToken;

      if (idToken == null) {
        throw 'No ID Token found.';
      }

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final currentUser = Supabase.instance.client.auth.currentUser;
      final needsNickname = currentUser != null
          ? await _needsNickname(currentUser.id)
          : false;

      if (!mounted) return;

      if (needsNickname) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfilePage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      showError('Google Sign In failed. Please try again.');
    }

    if (mounted) setState(() => isLoading = false);
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _forgotPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      showError('Enter your email above first, then tap Forgot Password.');
      return;
    }

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Check your inbox.'),
        ),
      );
    } catch (e) {
      showError('Something went wrong. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ListView(
            shrinkWrap: true,
            children: [
              Image.asset(
                'assets/icon/app_icon.png',
                height: 180,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: FaIcon(
                      _showPassword
                          ? FontAwesomeIcons.eyeSlash
                          : FontAwesomeIcons.eye,
                    ),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _forgotPassword,
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                ElevatedButton(
                  onPressed: login,
                  child: const Text('Login'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _signInWithGoogle,
                  icon: const Text('G', style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  )),
                  label: const Text('Continue with Google'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SignUpPage()),
                    );
                  },
                  child: const Text("Don't have an account? Sign Up"),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    final url = Uri.parse(
                        'https://sugared-hellebore-0ba.notion.site/398f6483ef768004b84ffe0c2897d139');
                    try {
                      await launchUrl(url,
                          mode: LaunchMode.externalApplication);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Could not open browser. Please try again.')),
                      );
                    }
                  },
                  child: const Text(
                    'Privacy Policy',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Total photos submitted per user in a group.
Future<Map<String, int>> fetchGroupSubmissionCounts(String groupId) async {
  final supabase = Supabase.instance.client;
  final submissions = await supabase.from('submissions').select().eq('group_id', groupId);

  final counts = <String, int>{};
  for (final s in submissions) {
    final uid = s['user_id'] as String;
    counts[uid] = (counts[uid] ?? 0) + 1;
  }
  return counts;
}

/// Disqualification counts per user in a group (scores marked disqualified
/// on that user's own submissions).
Future<Map<String, int>> fetchGroupDisqualificationCounts(String groupId) async {
  final supabase = Supabase.instance.client;
  final submissions = await supabase.from('submissions').select().eq('group_id', groupId);
  if (submissions.isEmpty) return {};

  final submissionIds = submissions.map((s) => s['id']).toList();
  final scores = await supabase
      .from('scores')
      .select()
      .inFilter('submission_id', submissionIds)
      .eq('disqualified', true);

  final counts = <String, int>{};
  for (final sc in scores) {
    final submission = submissions.firstWhere(
      (s) => s['id'] == sc['submission_id'],
      orElse: () => <String, dynamic>{},
    );
    if (submission.isEmpty) continue;
    final uid = submission['user_id'] as String;
    counts[uid] = (counts[uid] ?? 0) + 1;
  }
  return counts;
}

/// Win counts per user in a group: for each day with judged submissions,
/// whoever had the highest total score that day (earliest submission
/// breaking ties) gets credit for one win. This is the app's scoring model —
/// a daily win is worth 1 point, not the raw judge score total, which only
/// decides who wins that individual day.
class DayOutcome {
  final Map<String, int> totals;
  final String? winnerId;
  final Set<String> judgeIds;

  const DayOutcome({required this.totals, required this.winnerId, required this.judgeIds});
}

/// Shared per-day scoring computation: totals per submitter, the winner
/// (highest total, earliest submission breaking ties), and the set of real
/// judges (excludes synthetic Score Insurance rows, which have no judge_id
/// and must never count toward judging-coin payouts). Operates on an
/// already-fetched day's submissions plus the full scores list for the
/// range they came from — callers own the fetching/bucketing so this stays
/// a pure, reusable computation rather than another duplicated DB round trip.
DayOutcome computeDayOutcome(List<dynamic> daySubmissions, List<dynamic> allScores) {
  final totals = <String, int>{};
  final submittedTimes = <String, String>{};
  final judgeIds = <String>{};

  for (final s in daySubmissions) {
    final uid = s['user_id'] as String;
    submittedTimes[uid] = s['submitted_at'].toString();
    final subScores = allScores.where((sc) => sc['submission_id'] == s['id']);
    for (final sc in subScores) {
      totals[uid] = (totals[uid] ?? 0) + ((sc['score'] ?? 0) as int);
      final judgeId = sc['judge_id'];
      if (judgeId != null && sc['source'] != 'insurance') {
        judgeIds.add(judgeId as String);
      }
    }
  }

  if (totals.isEmpty) {
    return DayOutcome(totals: totals, winnerId: null, judgeIds: judgeIds);
  }

  final maxScore = totals.values.reduce((a, b) => a > b ? a : b);
  final topUserIds = totals.entries
      .where((e) => e.value == maxScore)
      .map((e) => e.key)
      .toList()
    ..sort((a, b) => submittedTimes[a]!.compareTo(submittedTimes[b]!));

  return DayOutcome(totals: totals, winnerId: topUserIds.first, judgeIds: judgeIds);
}

Future<Map<String, int>> fetchGroupWinCounts(
  String groupId, {
  DateTime? from,
  DateTime? to,
}) async {
  final supabase = Supabase.instance.client;

  var query = supabase.from('submissions').select().eq('group_id', groupId);
  if (from != null) query = query.gte('submitted_at', from.toIso8601String());
  if (to != null) query = query.lt('submitted_at', to.toIso8601String());
  final submissions = await query;

  if (submissions.isEmpty) return {};

  final submissionIds = submissions.map((s) => s['id']).toList();
  final scores = await supabase
      .from('scores')
      .select()
      .inFilter('submission_id', submissionIds);

  final byDay = <String, List<dynamic>>{};
  for (final s in submissions) {
    final date = DateTime.parse(s['submitted_at'].toString());
    byDay.putIfAbsent(_dateKeyForStreak(date), () => []).add(s);
  }

  final wins = <String, int>{};

  for (final daySubs in byDay.values) {
    final outcome = computeDayOutcome(daySubs, scores);
    if (outcome.winnerId != null) {
      wins[outcome.winnerId!] = (wins[outcome.winnerId!] ?? 0) + 1;
    }
  }

  return wins;
}

Future<Map<String, dynamic>?> fetchGroupLeader(String groupId) async {
  final wins = await fetchGroupWinCounts(groupId);

  if (wins.isEmpty) return null;

  final leaderId = wins.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  final leaderWins = wins[leaderId] ?? 0;

  final supabase = Supabase.instance.client;
  final users = await supabase.from('users').select().eq('id', leaderId);
  final leaderName = users.isNotEmpty ? users.first['username'] : 'Unknown';

  final membership = await supabase
      .from('group_members')
      .select('custom_title')
      .eq('group_id', groupId)
      .eq('user_id', leaderId)
      .maybeSingle();

  return {
    'name': leaderName,
    'score': leaderWins,
    'custom_title': membership?['custom_title'],
  };
}

Future<int> fetchGroupUnreadCount(String groupId) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) return 0;

  final membership = await supabase
      .from('group_members')
      .select()
      .eq('group_id', groupId)
      .eq('user_id', user.id)
      .maybeSingle();

  if (membership == null) return 0;
  if (membership['notify_chat'] == false) return 0;

  final lastRead = membership['last_chat_read_at'];

  var query = supabase.from('messages').select().eq('group_id', groupId);

  if (lastRead != null) {
    query = query.gt('created_at', lastRead);
  }

  final unread = await query;
  return unread.length;
}

String _dateKeyForStreak(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// Current consecutive-day submission streak per user in a group. A streak
/// stays alive through the end of today even if today isn't submitted yet
/// (it only breaks once a full calendar day is missed).
Future<Map<String, int>> fetchGroupStreaks(String groupId) async {
  final supabase = Supabase.instance.client;

  final submissions = await supabase
      .from('submissions')
      .select()
      .eq('group_id', groupId);
  final shields = await supabase.from('streak_shields').select().eq('group_id', groupId);

  final datesByUser = <String, Set<String>>{};
  for (final s in submissions) {
    final userId = s['user_id'] as String;
    final date = DateTime.parse(s['submitted_at'].toString());
    datesByUser.putIfAbsent(userId, () => {}).add(_dateKeyForStreak(date));
  }
  // A purchased Streak Shield counts its covered date as if it were
  // submitted, so one missed day doesn't reset the streak.
  for (final shield in shields) {
    final userId = shield['user_id'] as String;
    datesByUser.putIfAbsent(userId, () => {}).add(shield['covered_date'] as String);
  }

  final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  final streaks = <String, int>{};

  datesByUser.forEach((userId, dates) {
    var cursor = today;
    if (!dates.contains(_dateKeyForStreak(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var streak = 0;
    while (dates.contains(_dateKeyForStreak(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    streaks[userId] = streak;
  });

  return streaks;
}

/// Longest-ever submission streak per member within a single group.
Future<Map<String, int>> fetchGroupLongestStreaks(String groupId) async {
  final supabase = Supabase.instance.client;

  final submissions = await supabase
      .from('submissions')
      .select()
      .eq('group_id', groupId);
  final shields = await supabase.from('streak_shields').select().eq('group_id', groupId);

  final datesByUser = <String, Set<DateTime>>{};
  for (final s in submissions) {
    final userId = s['user_id'] as String;
    final date = DateTime.parse(s['submitted_at'].toString());
    datesByUser
        .putIfAbsent(userId, () => {})
        .add(DateTime(date.year, date.month, date.day));
  }
  for (final shield in shields) {
    final userId = shield['user_id'] as String;
    datesByUser.putIfAbsent(userId, () => {}).add(DateTime.parse(shield['covered_date'] as String));
  }

  final longest = <String, int>{};
  datesByUser.forEach((userId, dateSet) {
    final dates = dateSet.toList()..sort();
    var currentRun = 1;
    var best = 1;
    for (var i = 1; i < dates.length; i++) {
      final diff = dates[i].difference(dates[i - 1]).inDays;
      currentRun = diff == 1 ? currentRun + 1 : 1;
      if (currentRun > best) best = currentRun;
    }
    longest[userId] = best;
  });

  return longest;
}

/// Lifetime achievement stats for a user, aggregated across every group
/// they belong to (longest streak is the best of any single group, not
/// summed across groups; wins and disqualifications are totals).
Future<Map<String, int>> fetchUserAchievements(String userId) async {
  final supabase = Supabase.instance.client;

  final memberships = await supabase
      .from('group_members')
      .select('group_id')
      .eq('user_id', userId);

  final groupIds = memberships.map((m) => m['group_id'] as String).toSet();

  var longestStreak = 0;
  var totalWins = 0;
  var totalDisqualifications = 0;

  for (final groupId in groupIds) {
    final submissions = await supabase
        .from('submissions')
        .select()
        .eq('group_id', groupId);

    if (submissions.isEmpty) continue;

    final submissionIds = submissions.map((s) => s['id']).toSet();
    final allScores = await supabase.from('scores').select();
    final groupScores =
        allScores.where((sc) => submissionIds.contains(sc['submission_id'])).toList();

    // Longest streak this user ever had in this group.
    final myDates = submissions
        .where((s) => s['user_id'] == userId)
        .map((s) => DateTime.parse(s['submitted_at'].toString()))
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList()
      ..sort();

    if (myDates.isNotEmpty) {
      var currentRun = 1;
      var best = 1;
      for (var i = 1; i < myDates.length; i++) {
        final diff = myDates[i].difference(myDates[i - 1]).inDays;
        currentRun = diff == 1 ? currentRun + 1 : 1;
        if (currentRun > best) best = currentRun;
      }
      if (best > longestStreak) longestStreak = best;
    }

    // Disqualifications: scores marked disqualified on this user's own submissions.
    for (final sc in groupScores) {
      if (sc['disqualified'] != true) continue;
      final submission = submissions.firstWhere(
        (s) => s['id'] == sc['submission_id'],
        orElse: () => {},
      );
      if (submission['user_id'] == userId) totalDisqualifications++;
    }

    // Wins: for each day, whoever had the highest total score (earliest
    // submission breaking ties) is the winner.
    final byDay = <String, List<dynamic>>{};
    for (final s in submissions) {
      final date = DateTime.parse(s['submitted_at'].toString());
      byDay.putIfAbsent(_dateKeyForStreak(date), () => []).add(s);
    }

    for (final daySubs in byDay.values) {
      final totals = <String, int>{};
      final submittedTimes = <String, String>{};

      for (final s in daySubs) {
        final uid = s['user_id'] as String;
        submittedTimes[uid] = s['submitted_at'].toString();
        final subScores = groupScores.where((sc) => sc['submission_id'] == s['id']);
        for (final sc in subScores) {
          totals[uid] = (totals[uid] ?? 0) + ((sc['score'] ?? 0) as int);
        }
      }

      if (totals.isEmpty) continue;

      final maxScore = totals.values.reduce((a, b) => a > b ? a : b);
      final topUserIds = totals.entries
          .where((e) => e.value == maxScore)
          .map((e) => e.key)
          .toList()
        ..sort((a, b) => submittedTimes[a]!.compareTo(submittedTimes[b]!));

      if (topUserIds.first == userId) totalWins++;
    }
  }

  return {
    'longestStreak': longestStreak,
    'totalWins': totalWins,
    'totalDisqualifications': totalDisqualifications,
  };
}

/// Turns a raw exception into a short, user-friendly message instead of
/// showing Dart/Postgrest internals directly in a snackbar.
String friendlyError(Object e) {
  final message = e.toString().toLowerCase();
  if (message.contains('network') ||
      message.contains('socket') ||
      message.contains('failed host lookup') ||
      message.contains('connection')) {
    return 'No internet connection. Please check your network and try again.';
  }
  if (message.contains('permission') ||
      message.contains('rls') ||
      message.contains('policy')) {
    return 'You don\'t have permission to do that.';
  }
  if (message.contains('duplicate') || message.contains('unique constraint')) {
    return 'That already exists.';
  }
  if (message.contains('timeout')) {
    return 'The request timed out. Please try again.';
  }
  return 'Something went wrong. Please try again.';
}

void navigateToGroupTab(BuildContext context, dynamic group, int index, [int currentIndex = 0]) {
  if (index == currentIndex) return;

  HapticFeedback.selectionClick();

  if (index == 0) {
    // The dashboard is always directly below on the stack (see the
    // currentIndex == 0 branch below) — pop back to it instead of pushing a
    // fresh instance, so the back button never skips past it to the group list.
    Navigator.pop(context);
    return;
  }

  late final Widget page;
  switch (index) {
    case 1:
      page = CalendarPage(group: group);
      break;
    case 2:
      page = ChatPage(group: group);
      break;
    case 3:
      page = LeaderboardPage(group: group);
      break;
    default:
      return;
  }

  if (currentIndex == 0) {
    // Leaving the dashboard for a tab: push (not replace) so the back
    // button returns to the dashboard instead of the group list.
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  } else {
    // Switching between two non-dashboard tabs: replace so the stack
    // doesn't grow with every tab switch.
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }
}

Widget buildGroupBottomNav(BuildContext context, dynamic group, int currentIndex) {
  return FutureBuilder<int>(
    future: fetchGroupUnreadCount(group['id']),
    builder: (context, snapshot) {
      final hasUnread = (snapshot.data ?? 0) > 0;
      return BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          if (index == currentIndex) return;
          navigateToGroupTab(context, group, index, currentIndex);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: kBgColor,
        selectedItemColor: const Color(0xFFE10600),
        unselectedItemColor: Colors.white54,
        items: [
          const BottomNavigationBarItem(icon: FaIcon(FontAwesomeIcons.house), label: 'Home'),
          const BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.calendarDays), label: 'Calendar'),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const FaIcon(FontAwesomeIcons.commentDots),
                if (hasUnread)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE10600),
                        shape: BoxShape.circle,
                        border: Border.all(color: kBgColor, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Chat',
          ),
          const BottomNavigationBarItem(icon: FaIcon(FontAwesomeIcons.trophy), label: 'Leaderboard'),
        ],
      );
    },
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowNotificationPrompt());
  }

  Future<void> _maybeShowNotificationPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('notification_prompt_shown') == true) return;
    await prefs.setBool('notification_prompt_shown', true);

    if (!mounted) return;

    final enable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🔔 Stay in the loop'),
        content: const Text(
          'Turn on notifications to know when it\'s your turn to judge, '
          'someone uploads a photo, or your score comes in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (enable == true) {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
  }

  Future<List<dynamic>> fetchGroups() async {
  final user = supabase.auth.currentUser;

  if (user == null) {
    return [];
  }

  final memberships = await supabase
      .from('group_members')
      .select('group_id')
      .eq('user_id', user.id);

  final groupIds = memberships.map((m) => m['group_id']).toList();

  if (groupIds.isEmpty) {
    return [];
  }

  final groups = await supabase
      .from('groups')
      .select()
      .inFilter('id', groupIds)
      .order('created_at', ascending: false);

  return groups;
}

  Widget _groupCardChip(String label, {Color? accent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent?.withOpacity(0.6) ?? Colors.white24),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent ?? Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildGroupCard(dynamic group) {
    final backgroundColorHex = group['background_color'] as String?;
    final backgroundPhotoPath = group['background_photo_url'] as String?;
    final groupId = group['id'] as String;

    Widget cardContent(String? signedUrl, Map<String, dynamic>? leader, int unread, int myStreak) {
      final plain = signedUrl == null && backgroundColorHex == null;
      final baseColor = backgroundColorHex != null
          ? hexToColor(backgroundColorHex)
          : const Color(0xFF1E1E1E);

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 88,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: plain ? null : baseColor,
          gradient: plain
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2A2A2A), Color(0xFF161616)],
                )
              : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupDashboardPage(group: group),
                ),
              );
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (signedUrl != null)
                  CachedNetworkImage(imageUrl: signedUrl, fit: BoxFit.cover),
                if (signedUrl != null)
                  Container(color: Colors.black.withOpacity(0.45)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group['name'] ?? 'Unnamed Group',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (leader != null)
                                  _groupCardChip(
                                    (leader['custom_title'] as String?)?.isNotEmpty == true
                                        ? '🏆 ${leader['name']} "${leader['custom_title']}" · ${leader['score']} wins'
                                        : '🏆 ${leader['name']} · ${leader['score']} wins',
                                    accent: kAccentGold,
                                  ),
                                if (myStreak > 0)
                                  _groupCardChip('🔥 $myStreak', accent: kAccentGold),
                                _groupCardChip(unread > 0 ? '💬 $unread' : '💬 0'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const FaIcon(FontAwesomeIcons.chevronRight, size: 16, color: Colors.white70),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        backgroundPhotoPath != null
            ? supabase.storage.from('Photos').createSignedUrl(backgroundPhotoPath, 60 * 60)
            : Future.value(null),
        fetchGroupLeader(groupId),
        fetchGroupUnreadCount(groupId),
        fetchGroupStreaks(groupId),
      ]),
      builder: (context, snapshot) {
        final results = snapshot.data;
        final signedUrl = results?[0] as String?;
        final leader = results?[1] as Map<String, dynamic>?;
        final unread = results?[2] as int? ?? 0;
        final streaks = results?[3] as Map<String, int>? ?? {};
        final myStreak = streaks[supabase.auth.currentUser?.id] ?? 0;
        return cardContent(signedUrl, leader, unread, myStreak);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Nemesis'),
        actions: [
          IconButton(
            tooltip: 'My Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
            },
            icon: const FaIcon(FontAwesomeIcons.userCircle),
          ),
          PopupMenuButton<String>(
            icon: const FaIcon(FontAwesomeIcons.ellipsisVertical),
            onSelected: (value) async {
              if (value == 'logout') {
                await logout();
                if (!context.mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    FaIcon(FontAwesomeIcons.signOut, size: 16),
                    SizedBox(width: 10),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
  body: AppBackground(
        child: RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: FutureBuilder<List<dynamic>>(
            future: fetchGroups(),
            builder: (context, snapshot) {
              final groups = snapshot.data ?? [];
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting;

              return ListView(
                padding: EdgeInsets.fromLTRB(
                    20, 20, 20, MediaQuery.of(context).padding.bottom + 90),
                children: [
                  if (isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (snapshot.hasError)
                    Center(child: Text('Error: ${snapshot.error}'))
                  else if (groups.isEmpty)
                    const _EmptyState(
                      icon: FontAwesomeIcons.usersSlash,
                      title: 'No groups yet',
                      subtitle:
                          'Create your first group or join one with an invite code.',
                    )
                  else
                    ...groups.map((group) => _buildGroupCard(group)),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateJoinSheet(context),
        child: const FaIcon(FontAwesomeIcons.plus),
      ),
    );
  }

  void _showCreateJoinSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.plus),
              title: const Text('Create Group'),
              onTap: () async {
                Navigator.pop(context);
                final created = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateGroupPage()),
                );
                if (created == true) setState(() {});
              },
            ),
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.rightToBracket),
              title: const Text('Join Group'),
              onTap: () async {
                Navigator.pop(context);
                final joined = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const JoinGroupPage()),
                );
                if (joined == true) setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }
}

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final groupNameController = TextEditingController();
  final supabase = Supabase.instance.client;

  bool isLoading = false;

  Future<void> createGroup() async {
    final user = supabase.auth.currentUser;
    final groupName = groupNameController.text.trim();

    if (user == null) {
      showError('User not logged in');
      return;
    }

    if (groupName.isEmpty) {
      showError('Please enter a group name');
      return;
    }

    setState(() => isLoading = true);

    try {
      final existingProfile = await supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (existingProfile == null) {
        await supabase.from('users').upsert({
          'id': user.id,
          'username': user.email,
        });
      }

      final group = await supabase
          .from('groups')
          .insert({
            'name': groupName,
            'owner_id': user.id,
            'anonymous_judging': false,
          })
          .select()
          .single();

      await supabase.from('group_members').insert({
        'group_id': group['id'],
        'user_id': user.id,
        'role': 'owner',
      });

      if (!mounted) return;

      analytics.logEvent(name: 'group_created');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group created')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      showError(e.toString());
    }

    setState(() => isLoading = false);
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
      ),
      body: AppBackground(
        child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'Create a new Nemesis group',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: groupNameController,
              decoration: const InputDecoration(
                labelText: 'Group name',
                hintText: 'Example: Nemesis vs Me',
              ),
            ),
            const SizedBox(height: 24),
            if (isLoading)
              const CircularProgressIndicator()
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: createGroup,
                  child: const Text('Create Group'),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }
}
class GroupDashboardPage extends StatefulWidget {
  final dynamic group;

  const GroupDashboardPage({
    super.key,
    required this.group,
  });

  @override
  State<GroupDashboardPage> createState() => _GroupDashboardPageState();
}

class _GroupDashboardPageState extends State<GroupDashboardPage> {
  String? _myRole;
  bool _ownerIsJudge = false;
  bool _judgeAlsoPlays = false;
  bool _uploading = false;
  String? _statsLeftUserId;
  String? _statsRightUserId;
  Set<String> _selectedStatKeys = kDefaultStatKeys.toSet();

  @override
  void initState() {
    super.initState();
    _loadMyRole();
    _maybeShowChallengePopup();
    _maybeShowWinCelebration();
    _loadSelectedStatKeys();
    _settleCoinPayouts(widget.group['id']);
  }

  Future<void> _loadSelectedStatKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('stats_bar_keys');
    if (saved == null || saved.isEmpty || !mounted) return;
    setState(() => _selectedStatKeys = saved.toSet());
  }

  /// Pays out coins for every completed-but-unsettled day (won/streak/judging)
  /// since the group's last settlement. Fire-and-forget, idempotent (safe to
  /// call every time the dashboard loads — days already settled are no-ops
  /// via the DB's partial unique index), uses UTC day boundaries throughout
  /// so payouts don't depend on which member's device happens to trigger it.
  Future<void> _settleCoinPayouts(String groupId) async {
    try {
      final supabase = Supabase.instance.client;

      final groupRow = await supabase
          .from('groups')
          .select('coins_settled_through')
          .eq('id', groupId)
          .single();

      final nowUtc = DateTime.now().toUtc();
      final yesterday = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day)
          .subtract(const Duration(days: 1));

      final settledThroughRaw = groupRow['coins_settled_through'] as String?;
      if (settledThroughRaw == null) {
        await supabase
            .from('groups')
            .update({'coins_settled_through': _dateKeyForStreak(yesterday)}).eq('id', groupId);
        return;
      }

      final settledThrough = DateTime.parse(settledThroughRaw);
      final startDay = DateTime.utc(
        settledThrough.year,
        settledThrough.month,
        settledThrough.day,
      ).add(const Duration(days: 1));

      if (startDay.isAfter(yesterday)) return;

      final submissions = await supabase.from('submissions').select().eq('group_id', groupId);
      final submissionIds = submissions.map((s) => s['id']).toList();
      final scores = submissionIds.isEmpty
          ? <dynamic>[]
          : await supabase.from('scores').select().inFilter('submission_id', submissionIds);
      final predictions = await supabase.from('predictions').select().eq('group_id', groupId);

      final predictionsByDay = <String, List<dynamic>>{};
      for (final p in predictions) {
        predictionsByDay.putIfAbsent(p['day'] as String, () => []).add(p);
      }

      final byDay = <String, List<dynamic>>{};
      final datesByUser = <String, Set<DateTime>>{};
      for (final s in submissions) {
        final date = DateTime.parse(s['submitted_at'].toString()).toUtc();
        final dayOnly = DateTime.utc(date.year, date.month, date.day);
        byDay.putIfAbsent(_dateKeyForStreak(dayOnly), () => []).add(s);
        datesByUser.putIfAbsent(s['user_id'] as String, () => {}).add(dayOnly);
      }

      int streakEndingOn(String userId, DateTime day) {
        final dates = datesByUser[userId] ?? {};
        if (!dates.contains(day)) return 0;
        var streak = 0;
        var cursor = day;
        while (dates.contains(cursor)) {
          streak++;
          cursor = cursor.subtract(const Duration(days: 1));
        }
        return streak;
      }

      Future<void> award(String userId, int amount, String reason, String dayKey) {
        return supabase.from('coin_transactions').upsert(
          {
            'group_id': groupId,
            'user_id': userId,
            'amount': amount,
            'reason': reason,
            'reference_date': dayKey,
          },
          onConflict: 'group_id,user_id,reason,reference_date',
          ignoreDuplicates: true,
        );
      }

      for (var day = startDay; !day.isAfter(yesterday); day = day.add(const Duration(days: 1))) {
        final dayKey = _dateKeyForStreak(day);
        final daySubs = byDay[dayKey] ?? [];
        final dayPredictions = predictionsByDay[dayKey] ?? [];
        String? winnerId;

        if (daySubs.isNotEmpty) {
          final outcome = computeDayOutcome(daySubs, scores);
          winnerId = outcome.winnerId;

          if (outcome.winnerId != null) {
            await award(outcome.winnerId!, 10, 'daily_win', dayKey);
            if (streakEndingOn(outcome.winnerId!, day) >= 3) {
              await award(outcome.winnerId!, 5, 'streak_bonus', dayKey);
            }
          }

          for (final judgeId in outcome.judgeIds) {
            await award(judgeId, 5, 'judging', dayKey);
          }
        }

        if (dayPredictions.isEmpty) continue;

        // Predictions pay out from a shared pot: correct predictors split the
        // incorrect predictors' stakes (plus get their own stake back). If
        // nobody guessed right (or there was no winner to guess at all), it's
        // a wash — everyone just gets their stake refunded, no house edge.
        final correct = winnerId == null
            ? <dynamic>[]
            : dayPredictions.where((p) => p['predicted_user_id'] == winnerId).toList();

        if (correct.isEmpty) {
          for (final p in dayPredictions) {
            await award(p['predictor_id'] as String, p['stake'] as int, 'prediction_refund', dayKey);
          }
        } else {
          final totalStake = dayPredictions.fold<int>(0, (sum, p) => sum + (p['stake'] as int));
          final correctStake = correct.fold<int>(0, (sum, p) => sum + (p['stake'] as int));
          final bonusEach = (totalStake - correctStake) ~/ correct.length;
          for (final p in correct) {
            await award(
              p['predictor_id'] as String,
              (p['stake'] as int) + bonusEach,
              'prediction_payout',
              dayKey,
            );
          }
        }
      }

      await supabase
          .from('groups')
          .update({'coins_settled_through': _dateKeyForStreak(yesterday)}).eq('id', groupId);
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(e, st, fatal: false);
    }
  }

  Future<void> _maybeShowWinCelebration() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final submissions = await supabase
        .from('submissions')
        .select()
        .eq('group_id', widget.group['id'])
        .gte('submitted_at', startOfDay.toIso8601String())
        .lt('submitted_at', endOfDay.toIso8601String());

    if (submissions.isEmpty) return;

    final submissionIds = submissions.map((s) => s['id']).toList();
    final scores = await supabase
        .from('scores')
        .select()
        .inFilter('submission_id', submissionIds);

    final scoredSubmissionIds = scores.map((s) => s['submission_id']).toSet();
    final allJudged = submissions.every((s) => scoredSubmissionIds.contains(s['id']));
    if (!allJudged) return;

    final totals = <String, int>{};
    final submittedTimes = <String, String>{};
    for (final submission in submissions) {
      final userId = submission['user_id'] as String;
      submittedTimes[userId] = submission['submitted_at'].toString();
      final subScores = scores.where((s) => s['submission_id'] == submission['id']);
      for (final score in subScores) {
        totals[userId] = (totals[userId] ?? 0) + ((score['score'] ?? 0) as int);
      }
    }

    if (totals.isEmpty) return;

    final maxScore = totals.values.reduce((a, b) => a > b ? a : b);
    final topUserIds = totals.entries
        .where((e) => e.value == maxScore)
        .map((e) => e.key)
        .toList()
      ..sort((a, b) => submittedTimes[a]!.compareTo(submittedTimes[b]!));
    final winnerId = topUserIds.first;

    if (winnerId != user.id) return;

    final prefs = await SharedPreferences.getInstance();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    final seenKey = 'win_celebrated_${widget.group['id']}_$todayKey';
    if (prefs.getBool(seenKey) == true) return;
    await prefs.setBool(seenKey, true);

    if (!mounted) return;

    HapticFeedback.mediumImpact();
    playFeedbackSound();
    analytics.logEvent(name: 'battle_won');

    showDialog(
      context: context,
      builder: (_) => _WinCelebrationDialog(score: maxScore),
    );
  }

  Future<void> _maybeShowChallengePopup() async {
    final challengesPerWeek = widget.group['challenges_per_week'] ?? 0;
    final forcedDate = widget.group['forced_challenge_date'] as String?;
    final forcedPrompt = widget.group['forced_challenge_prompt'] as String?;

    final today = DateTime.now();
    if (!isChallengeDay(widget.group['id'], challengesPerWeek, today,
        forcedChallengeDate: forcedDate)) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    final seenKey = 'challenge_seen_${widget.group['id']}_$todayKey';
    if (prefs.getBool(seenKey) == true) return;

    await prefs.setBool(seenKey, true);

    if (!mounted) return;

    final text = challengeTextFor(widget.group['id'], today,
        forcedChallengeDate: forcedDate, forcedChallengePrompt: forcedPrompt);

    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎯 Today\'s Challenge!'),
        content: Text(text),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadMyRole() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final membership = await supabase
        .from('group_members')
        .select()
        .eq('group_id', widget.group['id'])
        .eq('user_id', user.id)
        .maybeSingle();

    if (!mounted) return;
    setState(() {
      _myRole = membership?['role'];
      _ownerIsJudge = membership?['owner_is_judge'] ?? false;
      _judgeAlsoPlays = membership?['judge_also_plays'] ?? false;
    });

    _maybeShowGettingStarted();
  }

  Future<void> _maybeShowGettingStarted() async {
    if (_myRole != 'owner') return;

    final prefs = await SharedPreferences.getInstance();
    final seenKey = 'getting_started_seen_${widget.group['id']}';
    if (prefs.getBool(seenKey) == true) return;
    await prefs.setBool(seenKey, true);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🎉 Group created!'),
        content: const Text(
          'Two quick things to set up:\n\n'
          '👤 Invite your nemesis — tap the person-plus icon in the top bar.\n\n'
          '⚖️ Decide if you\'ll judge — by default you play. You can turn on '
          'judging for yourself from Manage Members if you\'d rather score than compete.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<int> _pendingJudgingCount() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return 0;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final submissions = await supabase
        .from('submissions')
        .select()
        .eq('group_id', widget.group['id'])
        .neq('user_id', user.id)
        .gte('submitted_at', startOfDay.toIso8601String())
        .lt('submitted_at', endOfDay.toIso8601String());

    if (submissions.isEmpty) return 0;

    final submissionIds = submissions.map((s) => s['id']).toList();

    final myScores = await supabase
        .from('scores')
        .select()
        .inFilter('submission_id', submissionIds)
        .eq('judge_id', user.id);

    final scoredIds = myScores.map((s) => s['submission_id']).toSet();

    return submissions.where((s) => !scoredIds.contains(s['id'])).length;
  }

  Future<Map<String, dynamic>> _hybridJudgeUploadStatus() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return {'canUpload': false, 'pending': 0};

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();

    final existingSubmission = await supabase
        .from('submissions')
        .select()
        .eq('group_id', widget.group['id'])
        .eq('user_id', user.id)
        .gte('submitted_at', startOfDay)
        .maybeSingle();

    // Already submitted today: nothing left to upload, so keep showing the
    // judge icon instead of a camera that would just say "already submitted."
    if (existingSubmission != null) return {'canUpload': false, 'pending': 0};

    final pending = await _pendingJudgingCount();
    return {'canUpload': pending == 0, 'pending': pending};
  }

  Future<List<Map<String, dynamic>>> fetchMembersWithNames() async {
    final supabase = Supabase.instance.client;

    final members = await supabase
        .from('group_members')
        .select()
        .eq('group_id', widget.group['id']);

    final userIds = members.map((m) => m['user_id']).toList();

    final users = await supabase
        .from('users')
        .select()
        .inFilter('id', userIds);

    final streaks = await fetchGroupStreaks(widget.group['id']);

    return members.map<Map<String, dynamic>>((member) {
      final user = users.firstWhere(
        (u) => u['id'] == member['user_id'],
        orElse: () => {'username': 'Unknown'},
      );

      return {
        'username': user['username'],
        'role': member['role'],
        'streak': streaks[member['user_id']] ?? 0,
        'custom_title': member['custom_title'],
      };
    }).toList();
  }

  // Includes every member regardless of their *current* role, not just
  // currently-competing ones — wins/streaks are historical, so someone who's
  // judge-only today but used to play (or vice versa) should still be
  // selectable for comparison.
  Future<List<Map<String, dynamic>>> _fetchStatsBarData() async {
    final supabase = Supabase.instance.client;

    final members = await supabase
        .from('group_members')
        .select()
        .eq('group_id', widget.group['id']);

    final userIds = members.map((m) => m['user_id']).toList();
    final users = userIds.isEmpty
        ? <dynamic>[]
        : await supabase.from('users').select().inFilter('id', userIds);

    final wins = await fetchGroupWinCounts(widget.group['id']);
    final currentStreaks = await fetchGroupStreaks(widget.group['id']);
    final longestStreaks = await fetchGroupLongestStreaks(widget.group['id']);
    final submissionCounts = await fetchGroupSubmissionCounts(widget.group['id']);
    final disqualifications = await fetchGroupDisqualificationCounts(widget.group['id']);

    final stats = members.map((m) {
      final uid = m['user_id'];
      final user = users.firstWhere(
        (u) => u['id'] == uid,
        orElse: () => {'username': 'Unknown'},
      );
      final submissions = submissionCounts[uid] ?? 0;
      final winCount = wins[uid] ?? 0;
      return {
        'user_id': uid,
        'username': user['username'],
        'wins': winCount,
        'currentStreak': currentStreaks[uid] ?? 0,
        'longestStreak': longestStreaks[uid] ?? 0,
        'submissions': submissions,
        'disqualifications': disqualifications[uid] ?? 0,
        'winRate': submissions == 0 ? 0 : ((winCount / submissions) * 100).round(),
      };
    }).toList();

    stats.sort((a, b) => (b['wins'] as int).compareTo(a['wins'] as int));
    return stats;
  }


  Widget _buildStatsBar(List<Map<String, dynamic>> stats) {
    Map<String, dynamic> a;
    Map<String, dynamic> b;
    final canPickPlayers = stats.length > 2;

    if (!canPickPlayers) {
      a = stats[0];
      b = stats[1];
    } else {
      final myId = Supabase.instance.client.auth.currentUser?.id;
      a = stats.firstWhere(
        (s) => s['user_id'] == (_statsLeftUserId ?? myId),
        orElse: () => stats[0],
      );
      b = stats.firstWhere(
        (s) => s['user_id'] == _statsRightUserId && s['user_id'] != a['user_id'],
        orElse: () => stats.firstWhere(
          (s) => s['user_id'] != a['user_id'],
          orElse: () => stats[1],
        ),
      );
    }

    Widget statRow(StatOption option, int aVal, int bVal) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$aVal${option.suffix}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: aVal > bVal ? kAccentGold : Colors.white,
                ),
              ),
            ),
            SizedBox(
              width: 110,
              child: Text(
                option.label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6)),
              ),
            ),
            Expanded(
              child: Text(
                '$bVal${option.suffix}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: bVal > aVal ? kAccentGold : Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final activeOptions = kStatOptions.where((o) => _selectedStatKeys.contains(o.key)).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const FaIcon(FontAwesomeIcons.chartSimple, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Head to Head',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _openComparePicker(stats, canPickPlayers),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: FaIcon(FontAwesomeIcons.sliders, size: 16, color: Colors.white70),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _MemberAvatar(username: a['username'] ?? '?', color: Colors.redAccent, size: 44),
                      const SizedBox(height: 6),
                      Text(
                        a['username'] ?? '?',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  'VS',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _MemberAvatar(username: b['username'] ?? '?', color: Colors.blueAccent, size: 44),
                      const SizedBox(height: 6),
                      Text(
                        b['username'] ?? '?',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            for (final option in activeOptions)
              statRow(option, a[option.key] as int, b[option.key] as int),
          ],
        ),
      ),
    );
  }

  Future<void> _openComparePicker(List<Map<String, dynamic>> stats, bool showPlayerPicker) async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ComparePickerSheet(
        stats: stats,
        showPlayerPicker: showPlayerPicker,
        initialLeftId: _statsLeftUserId ?? myId,
        initialRightId: _statsRightUserId,
        initialSelectedStats: _selectedStatKeys,
      ),
    );

    if (result == null || !mounted) return;

    final statKeys = (result['statKeys'] as List).cast<String>();

    setState(() {
      if (showPlayerPicker) {
        _statsLeftUserId = result['left'] as String?;
        _statsRightUserId = result['right'] as String?;
      }
      _selectedStatKeys = statKeys.toSet();
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('stats_bar_keys', statKeys);
  }

  Future<List<Map<String, dynamic>>> fetchBattleStatus() async {
    final supabase = Supabase.instance.client;

    final members = await supabase
        .from('group_members')
        .select()
        .eq('group_id', widget.group['id']);

    final battleMembers = members
        .where((m) => m['role'] == 'player' ||
            (m['role'] == 'owner' && (m['owner_is_judge'] != true || m['judge_also_plays'] == true)) ||
            (m['role'] == 'judge' && m['judge_also_plays'] == true))
        .toList();

    final userIds = battleMembers.map((m) => m['user_id']).toList();

    final users = await supabase
        .from('users')
        .select()
        .inFilter('id', userIds);

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final submissions = await supabase
        .from('submissions')
        .select()
        .eq('group_id', widget.group['id'])
        .inFilter('user_id', userIds)
        .gte('submitted_at', startOfDay.toIso8601String())
        .lt('submitted_at', endOfDay.toIso8601String());

    final submissionIds = submissions.map((s) => s['id']).toList();

    final scores = submissionIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await supabase
            .from('scores')
            .select()
            .inFilter('submission_id', submissionIds);

    return battleMembers.map<Map<String, dynamic>>((member) {
      final user = users.firstWhere(
        (u) => u['id'] == member['user_id'],
        orElse: () => {'username': 'Unknown'},
      );

      final matchingSubmissions = submissions
          .where((s) => s['user_id'] == member['user_id'])
          .toList();
      final hasSubmitted = matchingSubmissions.isNotEmpty;
      final submissionId = hasSubmitted ? matchingSubmissions.first['id'] : null;

      final submissionScores = submissionId == null
          ? <Map<String, dynamic>>[]
          : scores.where((sc) => sc['submission_id'] == submissionId).toList();

      final isDisqualified =
          submissionScores.any((sc) => sc['disqualified'] == true);
      final totalScore = submissionScores.fold<int>(
        0,
        (sum, sc) => sum + ((sc['score'] ?? 0) as int),
      );

      return {
        'username': user['username'],
        'role': member['role'],
        'hasSubmitted': hasSubmitted,
        'hasScore': submissionScores.isNotEmpty,
        'isDisqualified': isDisqualified,
        'totalScore': totalScore,
        'custom_title': member['custom_title'],
      };
    }).toList();
  }

  Widget _dashboardActionTile({
    required FaIconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              FaIcon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(Map<String, dynamic> player) {
    late final String label;
    late final Color color;

    if (!player['hasSubmitted']) {
      label = 'Waiting';
      color = Colors.white70;
    } else if (player['isDisqualified'] == true) {
      label = 'Disqualified';
      color = Colors.redAccent;
    } else if (player['hasScore'] == true) {
      label = '⭐ ${player['totalScore']} pts';
      color = Colors.greenAccent;
    } else {
      label = 'Awaiting Score';
      color = Colors.amberAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAllNotices() async {
    final notices = <Map<String, dynamic>>[];

    final challengesPerWeek = widget.group['challenges_per_week'] ?? 0;
    final forcedDate = widget.group['forced_challenge_date'] as String?;
    final forcedPrompt = widget.group['forced_challenge_prompt'] as String?;
    final today = DateTime.now();
    if (isChallengeDay(widget.group['id'], challengesPerWeek, today,
        forcedChallengeDate: forcedDate)) {
      final text = challengeTextFor(widget.group['id'], today,
          forcedChallengeDate: forcedDate, forcedChallengePrompt: forcedPrompt);
      notices.add({'text': '🎯 Today\'s Challenge: $text'});
    }

    final results = await Future.wait([
      _checkNewUploads(),
      _myWarningStatus(),
      _checkPendingJudging(),
    ]);

    final names = results[0] as List<String>;
    if (names.isNotEmpty) {
      final text = names.length == 1
          ? '📸 ${names.first} just uploaded their photo!'
          : '📸 ${names.join(', ')} just uploaded their photos!';
      notices.add({'text': text});
    }

    final warningStatus = results[1] as Map<String, int>;
    if ((warningStatus['unseen'] ?? 0) > 0) {
      final total = warningStatus['total']!;
      notices.add({
        'text': total == 1
            ? '⚠️ You have 1 warning for missed judging.'
            : '⚠️ You have $total warnings for missed judging.',
        'action': () => _acknowledgeWarnings(total),
      });
    }

    final pending = results[2] as int;
    if (pending > 0) {
      notices.add({
        'text': pending == 1
            ? '⚖️ 1 photo is waiting for your score!'
            : '⚖️ $pending photos are waiting for your score!',
      });
    }

    return notices;
  }

  Future<List<String>> _checkNewUploads() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final membership = await supabase
        .from('group_members')
        .select()
        .eq('group_id', widget.group['id'])
        .eq('user_id', user.id)
        .maybeSingle();

    if (membership == null) return [];
    if (membership['notify_uploads'] == false) return [];

    final lastSeen = membership['last_seen_at'];

    var query = supabase
        .from('submissions')
        .select()
        .eq('group_id', widget.group['id'])
        .neq('user_id', user.id);

    if (lastSeen != null) {
      query = query.gt('submitted_at', lastSeen);
    }

    final newSubmissions = await query;

    // Mark "seen" now, so this banner doesn't repeat next time.
    await supabase
        .from('group_members')
        .update({'last_seen_at': DateTime.now().toIso8601String()})
        .eq('group_id', widget.group['id'])
        .eq('user_id', user.id);

    if (newSubmissions.isEmpty) return [];

    final userIds = newSubmissions.map((s) => s['user_id']).toSet().toList();
    final users = await supabase
        .from('users')
        .select()
        .inFilter('id', userIds);

    return userIds.map((id) {
      final u = users.firstWhere(
        (u) => u['id'] == id,
        orElse: () => {'username': 'Someone'},
      );
      return u['username'] as String;
    }).toList();
  }
 Future<Map<String, int>> _myWarningStatus() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return {'total': 0, 'unseen': 0};

    final membership = await supabase
        .from('group_members')
        .select()
        .eq('group_id', widget.group['id'])
        .eq('user_id', user.id)
        .maybeSingle();

    if (membership == null) return {'total': 0, 'unseen': 0};
    if (membership['role'] != 'judge') return {'total': 0, 'unseen': 0};

    final total = (membership['warnings'] ?? 0) as int;
    final acknowledged = (membership['warnings_acknowledged'] ?? 0) as int;

    return {'total': total, 'unseen': total - acknowledged};
  }

  Future<void> _acknowledgeWarnings(int total) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase
        .from('group_members')
        .update({'warnings_acknowledged': total})
        .eq('group_id', widget.group['id'])
        .eq('user_id', user.id);

    if (mounted) setState(() {});
  }
  Future<int> _checkPendingJudging() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return 0;

    final membership = await supabase
        .from('group_members')
        .select()
        .eq('group_id', widget.group['id'])
        .eq('user_id', user.id)
        .maybeSingle();

    if (membership == null) return 0;
    final isJudging = membership['role'] == 'judge' ||
        (membership['role'] == 'owner' && membership['owner_is_judge'] == true);
    if (!isJudging) return 0;
    if (membership['notify_judge_reminder'] == false) return 0;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final submissions = await supabase
        .from('submissions')
        .select()
        .eq('group_id', widget.group['id'])
        .neq('user_id', user.id)
        .gte('submitted_at', startOfDay.toIso8601String())
        .lt('submitted_at', endOfDay.toIso8601String());

    if (submissions.isEmpty) return 0;

    final submissionIds = submissions.map((s) => s['id']).toList();

    final myScores = await supabase
        .from('scores')
        .select()
        .inFilter('submission_id', submissionIds)
        .eq('judge_id', user.id);

    final scoredIds = myScores.map((s) => s['submission_id']).toSet();

    return submissions
        .where((s) => !scoredIds.contains(s['id']))
        .length;
  }
Future<Map<String, dynamic>> _fetchHeaderData() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final photoPath = widget.group['background_photo_url'];

    final results = await Future.wait([
      fetchGroupLeader(widget.group['id']),
      _unreadChatCount(),
      fetchGroupStreaks(widget.group['id']),
      photoPath != null
          ? supabase.storage.from('Photos').createSignedUrl(photoPath, 60 * 60)
          : Future.value(null),
    ]);

    final streaks = results[2] as Map<String, int>;

    return {
      'leader': results[0] as Map<String, dynamic>?,
      'unread': results[1] as int,
      'backgroundUrl': results[3] as String?,
      'myStreak': streaks[user?.id] ?? 0,
    };
  }

  Widget _headerChip(String label, {Color? accent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent?.withOpacity(0.6) ?? Colors.white24),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent ?? Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

Future<int> _unreadChatCount() => fetchGroupUnreadCount(widget.group['id']);

  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: Text(
          'Are you sure you want to leave "${widget.group['name'] ?? 'this group'}"? '
          'You\'ll need a new invite to rejoin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase
          .from('group_members')
          .delete()
          .eq('group_id', widget.group['id'])
          .eq('user_id', user.id);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  Future<void> _deleteGroup() async {
    final controller = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Delete Group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This permanently deletes the group, all photos, scores, messages, '
                'and members. This cannot be undone.',
              ),
              const SizedBox(height: 16),
              Text(
                'Type "${widget.group['name'] ?? 'DELETE'}" to confirm:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: controller.text.trim() == (widget.group['name'] ?? 'DELETE')
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('Delete Forever'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    final supabase = Supabase.instance.client;
    final groupId = widget.group['id'];

    try {
      final submissions = await supabase
          .from('submissions')
          .select('id')
          .eq('group_id', groupId);
      final submissionIds = submissions.map((s) => s['id']).toList();

      if (submissionIds.isNotEmpty) {
        await supabase.from('scores').delete().inFilter('submission_id', submissionIds);
      }
      await supabase.from('submissions').delete().eq('group_id', groupId);
      await supabase.from('messages').delete().eq('group_id', groupId);
      await supabase.from('invites').delete().eq('group_id', groupId);
      await supabase.from('group_members').delete().eq('group_id', groupId);
      await supabase.from('groups').delete().eq('id', groupId);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  Future<void> _pickInviteRole() async {
    final role = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Invite as...'),
        children: [
          _inviteRoleOption(
            context,
            'player',
            FontAwesomeIcons.camera,
            'Player',
            'Submits a photo every day',
          ),
          _inviteRoleOption(
            context,
            'judge',
            FontAwesomeIcons.scaleBalanced,
            'Judge',
            'Scores photos, doesn\'t submit their own',
          ),
          _inviteRoleOption(
            context,
            'judge_hybrid',
            FontAwesomeIcons.userGroup,
            'Judge who also plays',
            'Scores photos AND submits their own',
          ),
        ],
      ),
    );
    if (role == null) return;
    _generateInvite(role);
  }

  Widget _inviteRoleOption(
    BuildContext context,
    String value,
    FaIconData icon,
    String title,
    String subtitle,
  ) {
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(context, value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            FaIcon(icon, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateInvite(String role) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    final inviteCode = DateTime.now().millisecondsSinceEpoch.toString();

    await supabase.from('invites').insert({
      'group_id': widget.group['id'],
      'invited_by': user.id,
      'invite_code': inviteCode,
      'role': role,
    });

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Invite Code — ${roleLabel(role)}'),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(inviteCode)),
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.copy, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: inviteCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.shareNodes, size: 20),
              onPressed: () {
                final groupName = widget.group['name'] ?? 'my group';
                SharePlus.instance.share(
                  ShareParams(
                    text: '🥊 Join my Nemesis group "$groupName" as a ${roleLabel(role)}!\n\n'
                        'Download My Nemesis and enter this invite code: $inviteCode',
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadPhoto() async {
    if (_uploading) return;
    setState(() => _uploading = true);

    try {
      final isJudging = _myRole == 'owner' ? _ownerIsJudge : _myRole == 'judge';

      if (isJudging && _judgeAlsoPlays) {
        final pending = await _pendingJudgingCount();
        if (pending > 0) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                pending == 1
                    ? 'Judge the pending photo before uploading your own.'
                    : 'Judge the $pending pending photos before uploading your own.',
              ),
            ),
          );
          setState(() => _uploading = false);
          return;
        }
      }

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User not logged in');
      }

      final todayStart = DateTime.now();
      final startOfDay = DateTime(
        todayStart.year,
        todayStart.month,
        todayStart.day,
      ).toIso8601String();

      final existingSubmission = await supabase
          .from('submissions')
          .select()
          .eq('group_id', widget.group['id'])
          .eq('user_id', user.id)
          .gte('submitted_at', startOfDay)
          .maybeSingle();

      if (existingSubmission != null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You already submitted today 📸'),
          ),
        );

        setState(() => _uploading = false);
        return;
      }

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('📸 Ready?'),
          content: const Text(
            'You\'ll take one photo right now for today\'s battle. No retakes, '
            'no gallery picks — once you submit it, that\'s your entry for the day.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('I\'m Ready'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        setState(() => _uploading = false);
        return;
      }

      final picker = ImagePicker();

      final image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image == null) {
        setState(() => _uploading = false);
        return;
      }

      final file = File(image.path);

      final filePath =
          '${widget.group['id']}/${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      await supabase.storage.from('Photos').upload(
            filePath,
            file,
          );

      await supabase.from('submissions').insert({
        'group_id': widget.group['id'],
        'user_id': user.id,
        'photo_url': filePath,
      }).select().single();

      // Notify other group members
      final userProfile = await supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .single();

      await sendNotification(
        type: 'upload',
        groupId: widget.group['id'],
        senderId: user.id,
        senderName: userProfile['username'] ?? 'Someone',
        photoPath: filePath,
      );

      if (!mounted) return;

      HapticFeedback.mediumImpact();
      playFeedbackSound();
      analytics.logEvent(name: 'photo_submitted');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo submitted! ✅'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyError(e)),
        ),
      );
    }
    if (mounted) setState(() => _uploading = false);
  }

  Widget _navBarIcon({
    required FaIconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool showBadge = false,
  }) {
    final color = selected ? const Color(0xFFE10600) : Colors.white54;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              FaIcon(icon, color: color, size: 24),
              if (showBadge)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE10600),
                      shape: BoxShape.circle,
                      border: Border.all(color: kBgColor, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: color, fontSize: selected ? 14 : 12)),
        ],
      ),
    );
  }

  Widget _middleActionButton({required bool showCamera, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFFE10600),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE10600).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: _uploading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              )
            : Center(
                child: FaIcon(
                  showCamera ? FontAwesomeIcons.camera : FontAwesomeIcons.scaleBalanced,
                  color: Colors.white,
                  size: 24,
                ),
              ),
      ),
    );
  }

  Widget _homeBottomBar(bool canUpload, bool isHybridJudge) {
    return SafeArea(
      top: false,
      child: Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: kBgColor,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navBarIcon(
            icon: FontAwesomeIcons.house,
            label: 'Home',
            selected: true,
            onTap: () {},
          ),
          _navBarIcon(
            icon: FontAwesomeIcons.calendarDays,
            label: 'Calendar',
            selected: false,
            onTap: () => navigateToGroupTab(context, widget.group, 1),
          ),
          isHybridJudge
              ? FutureBuilder<Map<String, dynamic>>(
                  future: _hybridJudgeUploadStatus(),
                  builder: (context, snapshot) {
                    final status = snapshot.data;
                    final canUploadNow = status?['canUpload'] as bool? ?? false;
                    final pending = status?['pending'] as int? ?? 0;
                    return _middleActionButton(
                      showCamera: canUploadNow,
                      onTap: canUploadNow
                          ? _uploadPhoto
                          : () {
                              if (pending > 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      pending == 1
                                          ? 'Judge the pending photo before you can upload your own.'
                                          : 'Judge the $pending pending photos before you can upload your own.',
                                    ),
                                  ),
                                );
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => JudgePhotosPage(group: widget.group),
                                ),
                              ).then((_) => setState(() {}));
                            },
                    );
                  },
                )
              : _middleActionButton(
                  showCamera: canUpload,
                  onTap: canUpload
                      ? _uploadPhoto
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => JudgePhotosPage(group: widget.group),
                            ),
                          );
                        },
                ),
          FutureBuilder<int>(
            future: fetchGroupUnreadCount(widget.group['id']),
            builder: (context, snapshot) {
              return _navBarIcon(
                icon: FontAwesomeIcons.commentDots,
                label: 'Chat',
                selected: false,
                showBadge: (snapshot.data ?? 0) > 0,
                onTap: () => navigateToGroupTab(context, widget.group, 2),
              );
            },
          ),
          _navBarIcon(
            icon: FontAwesomeIcons.trophy,
            label: 'Leaderboard',
            selected: false,
            onTap: () => navigateToGroupTab(context, widget.group, 3),
          ),
        ],
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupName = widget.group['name'] ?? 'Unnamed Group';
    final isOwner = _myRole == 'owner';
    final isJudging = isOwner ? _ownerIsJudge : _myRole == 'judge';
    final canUpload = !isJudging || _judgeAlsoPlays;
    final isHybridJudge = isJudging && _judgeAlsoPlays;
    final challengesPerWeek = widget.group['challenges_per_week'] ?? 0;
    final forcedDate = widget.group['forced_challenge_date'] as String?;
    final forcedPrompt = widget.group['forced_challenge_prompt'] as String?;
    final isTodayChallenge = isChallengeDay(
        widget.group['id'], challengesPerWeek, DateTime.now(),
        forcedChallengeDate: forcedDate);
    final challengeText = isTodayChallenge
        ? challengeTextFor(widget.group['id'], DateTime.now(),
            forcedChallengeDate: forcedDate, forcedChallengePrompt: forcedPrompt)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(groupName),
        actions: [
          if (isOwner)
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.userPlus),
              tooltip: 'Invite',
              onPressed: _pickInviteRole,
            ),
          PopupMenuButton<String>(
            icon: const FaIcon(FontAwesomeIcons.ellipsisVertical),
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsPage(group: widget.group),
                  ),
                ).then((_) => setState(() {}));
           } else if (value == 'rules') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RulesPage(
                      group: widget.group,
                      isOwner: isOwner,
                    ),
                  ),
                );
           } else if (value == 'notifications') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotificationSettingsPage(group: widget.group),
                  ),
                );
              } else if (value == 'weekly_recap') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WeeklyRecapPage(group: widget.group),
                  ),
                );
              } else if (value == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfilePage(),
                  ),
                );
              } else if (value == 'manage_members') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ManageMembersPage(group: widget.group),
                  ),
                );
              } else if (value == 'leave_group') {
                _leaveGroup();
              } else if (value == 'delete_group') {
                _deleteGroup();
              }
            },
          itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Text('My Profile'),
              ),
              const PopupMenuItem(
                value: 'rules',
                child: Text('Rules'),
              ),
              const PopupMenuItem(
                value: 'notifications',
                child: Text('Notifications'),
              ),
              const PopupMenuItem(
                value: 'weekly_recap',
                child: Text('Weekly Recap'),
              ),
             if (isOwner) ...[
                const PopupMenuItem(
                  value: 'manage_members',
                  child: Text('Manage Members'),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: Text('Settings'),
                ),
                const PopupMenuItem(
                  value: 'delete_group',
                  child: Text('Delete Group', style: TextStyle(color: Colors.redAccent)),
                ),
              ] else
                const PopupMenuItem(
                  value: 'leave_group',
                  child: Text('Leave Group', style: TextStyle(color: Colors.redAccent)),
                ),
            ],
          ),
        ],
      ),
body: AppBackground(
        group: widget.group,
        child: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FutureBuilder<Map<String, dynamic>>(
                future: _fetchHeaderData(),
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  final leader = data?['leader'] as Map<String, dynamic>?;
                  final unread = data?['unread'] as int? ?? 0;
                  final myStreak = data?['myStreak'] as int? ?? 0;
                  final backgroundUrl = data?['backgroundUrl'] as String?;
                  final backgroundColorHex = widget.group['background_color'] as String?;
                  final baseColor = backgroundColorHex != null
                      ? hexToColor(backgroundColorHex)
                      : kSurfaceColor;

                  return Container(
                    height: 160,
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (backgroundUrl != null)
                          CachedNetworkImage(imageUrl: backgroundUrl, fit: BoxFit.cover),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.1),
                                Colors.black.withOpacity(0.65),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                groupName,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (leader != null)
                                    _headerChip(
                                      (leader['custom_title'] as String?)?.isNotEmpty == true
                                          ? '🏆 ${leader['name']} "${leader['custom_title']}" · ${leader['score']} wins'
                                          : '🏆 ${leader['name']} · ${leader['score']} wins',
                                      accent: kAccentGold,
                                    ),
                                  if (myStreak > 0)
                                    _headerChip('🔥 Your streak: $myStreak', accent: kAccentGold),
                                  _headerChip(
                                    unread > 0 ? '💬 $unread unread' : '💬 No new messages',
                                  ),
                                  if (widget.group['anonymous_judging'] == true)
                                    _headerChip('🕶️ Anonymous judging', accent: kAccentTeal),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchAllNotices(),
                builder: (context, snapshot) {
                  final notices = snapshot.data ?? [];
                  if (notices.isEmpty) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Card(
                      color: const Color(0xFFE10600).withOpacity(0.1),
                      child: Column(
                        children: [
                          for (var i = 0; i < notices.length; i++) ...[
                            if (i > 0) const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      notices[i]['text'] as String,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (notices[i]['action'] != null)
                                    TextButton(
                                      onPressed: notices[i]['action'] as VoidCallback,
                                      child: const Text('Got it'),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: fetchBattleStatus(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: ListTile(
                        leading: FaIcon(FontAwesomeIcons.calendarCheck),
                        title: Text('Today’s Battle'),
                        subtitle: Text('Loading battle status...'),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Card(
                      child: ListTile(
                        leading: const FaIcon(FontAwesomeIcons.calendarCheck),
                        title: const Text('Today’s Battle'),
                        subtitle: Text('Error: ${snapshot.error}'),
                      ),
                    );
                  }

                  final players = snapshot.data ?? [];

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: Row(
                              children: [
                                const FaIcon(FontAwesomeIcons.calendarCheck),
                                const SizedBox(width: 8),
                                const Text(
                                  'Today’s Battle',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                if (challengeText != null) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: kAccentGold.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: kAccentGold.withOpacity(0.5)),
                                      ),
                                      child: Text(
                                        '🎯 $challengeText',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: kAccentGold,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Divider(height: 16),
                          for (final player in players)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  roleIcon(player['role'], size: 18, color: Colors.white70),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          player['username'] ?? 'Unknown',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if ((player['custom_title'] as String?)?.isNotEmpty == true)
                                          Text(
                                            player['custom_title'],
                                            style: const TextStyle(fontSize: 10, color: kAccentGold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  _buildStatusChip(player),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TodayPhotosPage(group: widget.group),
                                ),
                              );
                            },
                            icon: const FaIcon(FontAwesomeIcons.images),
                            label: const Text('View Today\'s Photos'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _dashboardActionTile(
                      icon: FontAwesomeIcons.coins,
                      color: kAccentGold,
                      label: 'Store',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StorePage(group: widget.group),
                          ),
                        ).then((_) => setState(() {}));
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dashboardActionTile(
                      icon: FontAwesomeIcons.gamepad,
                      color: kAccentTeal,
                      label: 'Mini-Games',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MiniGamesPage(group: widget.group),
                          ),
                        ).then((_) => setState(() {}));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<dynamic>>(
                future: fetchMembersWithNames(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: ListTile(
                        leading: FaIcon(FontAwesomeIcons.users),
                        title: Text('Members'),
                        subtitle: Text('Loading...'),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Card(
                      child: ListTile(
                        leading: const FaIcon(FontAwesomeIcons.users),
                        title: const Text('Members'),
                        subtitle: Text('Error: ${snapshot.error}'),
                      ),
                    );
                  }

                  final members = snapshot.data ?? [];

               const List<Color> palette = [
                    Colors.redAccent,
                    Colors.blueAccent,
                    Colors.greenAccent,
                    Colors.purpleAccent,
                    Colors.orangeAccent,
                    Colors.tealAccent,
                    Colors.pinkAccent,
                    Colors.amberAccent,
                  ];

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Text(
                            'Members (${members.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: members.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final m = entry.value;
                                  final color = palette[index % palette.length];
                                  final streak = (m['streak'] ?? 0) as int;

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 14),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            _MemberAvatar(
                                              username: m['username'] ?? '?',
                                              color: color,
                                            ),
                                            Positioned(
                                              left: -4,
                                              top: -4,
                                              child: Container(
                                                padding: const EdgeInsets.all(3),
                                                decoration: const BoxDecoration(
                                                  color: kBgColor,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: roleIcon(
                                                  m['role'],
                                                  size: 9,
                                                  color: Colors.white70,
                                                  compact: true,
                                                ),
                                              ),
                                            ),
                                            if (streak > 0)
                                              Positioned(
                                                right: -4,
                                                bottom: -2,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 4, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: kBgColor,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: kAccentGold, width: 1),
                                                  ),
                                                  child: Text(
                                                    '🔥$streak',
                                                    style: const TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      color: kAccentGold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          m['username'] ?? '?',
                                          style: const TextStyle(fontSize: 10),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if ((m['custom_title'] as String?)?.isNotEmpty == true)
                                          Text(
                                            m['custom_title'],
                                            style: const TextStyle(
                                              fontSize: 8,
                                              color: kAccentGold,
                                              fontStyle: FontStyle.italic,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchStatsBarData(),
                builder: (context, snapshot) {
                  final stats = snapshot.data ?? [];
                  if (stats.length < 2) return const SizedBox.shrink();
                  return _buildStatsBar(stats);
                },
              ),
            ],
     ),
        ),
      ),
      ),
      ),
      bottomNavigationBar: _homeBottomBar(canUpload, isHybridJudge),
    );
  }
}
class _WinCelebrationDialog extends StatefulWidget {
  final int score;

  const _WinCelebrationDialog({required this.score});

  @override
  State<_WinCelebrationDialog> createState() => _WinCelebrationDialogState();
}

class _WinCelebrationDialogState extends State<_WinCelebrationDialog> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          numberOfParticles: 30,
          maxBlastForce: 20,
          minBlastForce: 8,
          gravity: 0.3,
          colors: const [Color(0xFFE10600), Colors.white, Colors.amber, Colors.greenAccent],
        ),
        AlertDialog(
          backgroundColor: kSurfaceColor,
          title: const Text('🏆 You Won Today!', textAlign: TextAlign.center),
          content: Text(
            'Your photo scored ${widget.score} points — best of the day. Nice one!',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                maybeRequestReview();
              },
              child: const Text('Nice!'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ComparePickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> stats;
  final bool showPlayerPicker;
  final String? initialLeftId;
  final String? initialRightId;
  final Set<String> initialSelectedStats;

  const _ComparePickerSheet({
    required this.stats,
    required this.showPlayerPicker,
    required this.initialSelectedStats,
    this.initialLeftId,
    this.initialRightId,
  });

  @override
  State<_ComparePickerSheet> createState() => _ComparePickerSheetState();
}

class _ComparePickerSheetState extends State<_ComparePickerSheet> {
  String? _leftId;
  String? _rightId;
  String _activeSlot = 'left';
  late Set<String> _selectedStats;

  @override
  void initState() {
    super.initState();
    _leftId = widget.initialLeftId;
    _rightId = widget.initialRightId;
    _selectedStats = Set.of(widget.initialSelectedStats);
  }

  Map<String, dynamic>? _findById(String? id) {
    if (id == null) return null;
    final match = widget.stats.where((s) => s['user_id'] == id);
    return match.isEmpty ? null : match.first;
  }

  Widget _slot(String? userId, bool isActive, VoidCallback onTap) {
    final data = _findById(userId);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isActive ? kAccentGold.withOpacity(0.12) : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? kAccentGold : Colors.white24,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (data != null)
                _MemberAvatar(username: data['username'] ?? '?', color: kAccentGold, size: 40)
              else
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white38),
                  ),
                  child: const Icon(Icons.add, color: Colors.white38),
                ),
              const SizedBox(height: 8),
              Text(
                data != null ? (data['username'] ?? '?') : 'Choose',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: data != null ? Colors.white : Colors.white54,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _selectedStats.isNotEmpty &&
        (!widget.showPlayerPicker || (_leftId != null && _rightId != null));

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.showPlayerPicker ? 'Compare Players' : 'Customize Stats',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (widget.showPlayerPicker) ...[
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _slot(_leftId, _activeSlot == 'left', () => setState(() => _activeSlot = 'left')),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'VS',
                      style: TextStyle(color: kAccentGold, fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                  _slot(_rightId, _activeSlot == 'right', () => setState(() => _activeSlot = 'right')),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                _activeSlot == 'left' ? 'Pick the left player' : 'Pick the right player',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.5),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView(
                  shrinkWrap: true,
                  children: widget.stats.map((s) {
                    final uid = s['user_id'] as String;
                    final selected = _activeSlot == 'left' ? _leftId == uid : _rightId == uid;
                    final disabled = _activeSlot == 'left' ? _rightId == uid : _leftId == uid;
                    return ListTile(
                      enabled: !disabled,
                      leading: _MemberAvatar(username: s['username'] ?? '?', color: kAccentGold, size: 32),
                      title: Text(s['username'] ?? '?'),
                      trailing: selected
                          ? const FaIcon(FontAwesomeIcons.check, size: 16, color: kAccentGold)
                          : null,
                      onTap: disabled
                          ? null
                          : () {
                              setState(() {
                                if (_activeSlot == 'left') {
                                  _leftId = uid;
                                  _activeSlot = 'right';
                                } else {
                                  _rightId = uid;
                                  _activeSlot = 'left';
                                }
                              });
                            },
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              'Stats to show',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.5),
                fontWeight: FontWeight.bold,
              ),
            ),
            ...kStatOptions.map((option) {
              final checked = _selectedStats.contains(option.key);
              return CheckboxListTile(
                value: checked,
                title: Text(option.label),
                activeColor: kAccentGold,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedStats.add(option.key);
                    } else {
                      _selectedStats.remove(option.key);
                    }
                  });
                },
              );
            }),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canSave
                    ? () => Navigator.pop(context, {
                          'left': _leftId,
                          'right': _rightId,
                          'statKeys': _selectedStats.toList(),
                        })
                    : null,
                child: Text(widget.showPlayerPicker ? 'Compare' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class JoinGroupPage extends StatefulWidget {
  const JoinGroupPage({super.key});

  @override
  State<JoinGroupPage> createState() => _JoinGroupPageState();
}

class _JoinGroupPageState extends State<JoinGroupPage> {
  final inviteCodeController = TextEditingController();
  final supabase = Supabase.instance.client;

  bool isLoading = false;

  Future<void> joinGroup() async {
    final user = supabase.auth.currentUser;
    final inviteCode = inviteCodeController.text.trim();

    if (user == null) {
      showError('User not logged in');
      return;
    }

    if (inviteCode.isEmpty) {
      showError('Please enter an invite code');
      return;
    }

    setState(() => isLoading = true);

    try {
      final invite = await supabase
          .from('invites')
          .select()
          .eq('invite_code', inviteCode)
          .single();

      final existingMembership = await supabase
          .from('group_members')
          .select()
          .eq('group_id', invite['group_id'])
          .eq('user_id', user.id)
          .maybeSingle();

      if (existingMembership != null) {
        showError('You are already in this group');
        setState(() => isLoading = false);
        return;
      }

      final group = await supabase
          .from('groups')
          .select()
          .eq('id', invite['group_id'])
          .single();

      if (!mounted) return;

      final rawRole = invite['role'] as String? ?? 'player';
      final isHybrid = rawRole == 'judge_hybrid';
      final effectiveRole = isHybrid ? 'judge' : rawRole;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Join "${group['name']}"?'),
          content: Text('You\'ll be joining as: ${roleLabel(rawRole)}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Join'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        setState(() => isLoading = false);
        return;
      }

      await supabase.from('group_members').insert({
        'group_id': invite['group_id'],
        'user_id': user.id,
        'role': effectiveRole,
        if (isHybrid) 'judge_also_plays': true,
      });

      if (!mounted) return;

      analytics.logEvent(name: 'group_joined');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Joined group')),
      );

      final wantsRules = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('📋 Group Rules'),
          content: const Text('Want to check out this group\'s rules before you dive in?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('View Rules'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      if (wantsRules == true) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RulesPage(
              group: {'id': invite['group_id']},
              isOwner: false,
              showContinueButton: true,
            ),
          ),
        );
        if (!mounted) return;
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GroupDashboardPage(group: group),
        ),
        result: true,
      );
    } catch (e) {
      showError(e.toString());
    }

    setState(() => isLoading = false);
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Group'),
      ),
      body: AppBackground(
        child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'Enter invite code',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: inviteCodeController,
              decoration: const InputDecoration(
                labelText: 'Invite code',
              ),
            ),
            const SizedBox(height: 24),
            if (isLoading)
              const CircularProgressIndicator()
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: joinGroup,
                  child: const Text('Join Group'),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }
}
class JudgePhotosPage extends StatefulWidget {
  final dynamic group;

  const JudgePhotosPage({
    super.key,
    required this.group,
  });

  @override
  State<JudgePhotosPage> createState() => _JudgePhotosPageState();
}

class _JudgePhotosPageState extends State<JudgePhotosPage> {
  final _pageController = PageController();
  int _currentPage = 0;
  List<Map<String, dynamic>> _submissions = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadSubmissions() async {
    try {
      final result = await fetchSubmissions();
      if (!mounted) return;
      setState(() {
        _submissions = result;
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<List<Map<String, dynamic>>> fetchSubmissions() async {
    final supabase = Supabase.instance.client;
    final judge = supabase.auth.currentUser;

final today = DateTime.now();
final startOfDay = DateTime(today.year, today.month, today.day);
final endOfDay = startOfDay.add(const Duration(days: 1));

final groupData = await supabase
        .from('groups')
        .select()
        .eq('id', widget.group['id'])
        .single();

    final anonymousJudging = groupData['anonymous_judging'] ?? false;

    final users = await supabase.from('users').select();

    final submissions = await supabase
        .from('submissions')
        .select()
        .eq('group_id', widget.group['id'])
        .neq('user_id', judge!.id)
        .gte('submitted_at', startOfDay.toIso8601String())
        .lt('submitted_at', endOfDay.toIso8601String())
        .order('submitted_at', ascending: false);

    final submissionIds = submissions.map((s) => s['id']).toList();
    final allJudgeScores = submissionIds.isEmpty
        ? <dynamic>[]
        : await supabase
            .from('scores')
            .select()
            .eq('judge_id', judge!.id)
            .inFilter('submission_id', submissionIds);

    final signedUrls = await Future.wait(
      submissions.map(
        (s) => supabase.storage.from('Photos').createSignedUrl(s['photo_url'], 60 * 60),
      ),
    );

    final result = <Map<String, dynamic>>[];

    for (var i = 0; i < submissions.length; i++) {
      final submission = submissions[i];
      final signedUrl = signedUrls[i];

      final existingScores = allJudgeScores
          .where((s) => s['submission_id'] == submission['id'])
          .toList();

    final uploader = users.firstWhere(
        (u) => u['id'] == submission['user_id'],
        orElse: () => {'username': 'Unknown'},
      );

      result.add({
        'id': submission['id'],
        'user_id': submission['user_id'],
        'username': (anonymousJudging || submission['is_anonymous'] == true) ? null : uploader['username'],
        'photo_url': submission['photo_url'],
        'signed_url': signedUrl,
        'my_score': existingScores.isNotEmpty ? existingScores.first['score'] : null,
'my_disqualified': existingScores.isNotEmpty
    ? existingScores.first['disqualified']
    : false,
'my_reason': existingScores.isNotEmpty
    ? existingScores.first['reason']
    : null,
      });
    }

    return result;
  }

Future<void> saveScore(String submissionId, int score) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    await supabase.from('scores').insert({
      'submission_id': submissionId,
      'judge_id': user.id,
      'score': score,
      'disqualified': false,
    });

    HapticFeedback.lightImpact();
    playFeedbackSound();

    // Notify the photo owner
    final submission = await supabase
        .from('submissions')
        .select()
        .eq('id', submissionId)
        .single();

    final judgeProfile = await supabase
        .from('users')
        .select()
        .eq('id', user.id)
        .single();

    await sendNotification(
      type: 'score',
      groupId: submission['group_id'],
      senderId: user.id,
      senderName: judgeProfile['username'] ?? 'A judge',
    );

    await _loadSubmissions();
  }

  @override
  Widget build(BuildContext context) {
    final challengesPerWeek = widget.group['challenges_per_week'] ?? 0;
    final forcedDate = widget.group['forced_challenge_date'] as String?;
    final forcedPrompt = widget.group['forced_challenge_prompt'] as String?;
    final today = DateTime.now();
    final isTodayChallenge = isChallengeDay(widget.group['id'], challengesPerWeek, today,
        forcedChallengeDate: forcedDate);
    final challengeText = isTodayChallenge
        ? challengeTextFor(widget.group['id'], today,
            forcedChallengeDate: forcedDate, forcedChallengePrompt: forcedPrompt)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Judge Photos'),
      ),
      body: AppBackground(
        group: widget.group,
        child: Column(
        children: [
          if (challengeText != null)
            Container(
              width: double.infinity,
              color: const Color(0xFFE10600).withOpacity(0.15),
              padding: const EdgeInsets.all(14),
              child: Text(
                '🎯 Today\'s Challenge: $challengeText',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: Builder(
        builder: (context) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_loadError != null) {
            return Center(child: Text('Error: $_loadError'));
          }

          final submissions = _submissions;

          if (submissions.isEmpty) {
            return const _EmptyState(
              icon: FontAwesomeIcons.camera,
              title: 'No photos yet',
              subtitle: 'Players haven\'t submitted their photos today.',
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Photo ${_currentPage + 1} of ${submissions.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: submissions.length,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemBuilder: (context, index) {
                    final submission = submissions[index];
                    final myScore = submission['my_score'];

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullScreenPhotoPage(
                              imageUrl: submission['signed_url'],
                            ),
                          ),
                        );
                      },
                      child: Stack(
                        children: [
                          Hero(
                            tag: submission['signed_url'],
                            child: CachedNetworkImage(
                              imageUrl: submission['signed_url'],
                              height: 300,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const FaIcon(
                                FontAwesomeIcons.expand,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (submission['username'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 12),
                        child: Text(
                          '📸 ${submission['username']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(top: 8, left: 12),
                        child: Text(
                          '🕶️ Anonymous submission',
                          style: TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: myScore != null
                          ? Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        myScore == 0
            ? '🚫 Disqualified'
            : 'You scored this photo: $myScore ✅',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),

if (myScore == 0)
  Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      submission['my_reason'] ?? 'No reason provided',
      style: const TextStyle(
        fontSize: 14,
      ),
    ),
  ),
    ],
  )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Score this photo',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 10),
                               _ScoreSlider(
                                  onSubmit: (score) async {
                                    try {
                                      await saveScore(
                                        submission['id'],
                                        score,
                                      );

                                      if (!context.mounted) return;

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Score saved: $score'),
                                        ),
                                      );
                                    } catch (e) {
                                      if (!context.mounted) return;

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(friendlyError(e)),
                                        ),
                                      );
                                    }
                                  },
                                ),

                                const SizedBox(height: 12),

                             ElevatedButton.icon(
  onPressed: () async {
    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Disqualify Photo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This sets their score to 0 and takes them out of the running to win today.',
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Example: old photo, duplicate, rule violation',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                dialogContext,
                reasonController.text.trim(),
              );
            },
            child: const Text('Disqualify'),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) return;

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) return;

      await supabase.from('scores').insert({
        'submission_id': submission['id'],
        'judge_id': user.id,
        'score': 0,
        'disqualified': true,
        'reason': reason,
      });

      if (!context.mounted) return;

      HapticFeedback.mediumImpact();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo disqualified')),
      );

      await _loadSubmissions();
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  },
  icon: const FaIcon(FontAwesomeIcons.ban),
  label: const Text('Disqualify Photo'),
),

                              ],
                            ),
                    ),
                  ],
                ),
              ),
                    );
                  },
                ),
              ),
              if (submissions.length > 1)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 12,
                    top: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(submissions.length, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isActive ? 10 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive ? Colors.redAccent : Colors.white30,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          );
        },
      ),
          ),
        ],
      ),
      ),
    );
  }
}
class TodayPhotosPage extends StatelessWidget {
  final dynamic group;

  const TodayPhotosPage({super.key, required this.group});

  Future<List<Map<String, dynamic>>> fetchTodayPhotos() async {
    final supabase = Supabase.instance.client;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final groupData = await supabase
        .from('groups')
        .select()
        .eq('id', group['id'])
        .single();
    final anonymousJudging = groupData['anonymous_judging'] ?? false;

    final submissions = await supabase
        .from('submissions')
        .select()
        .eq('group_id', group['id'])
        .gte('submitted_at', startOfDay.toIso8601String())
        .lt('submitted_at', endOfDay.toIso8601String())
        .order('submitted_at', ascending: false);

    final users = await supabase.from('users').select();
    final scores = await supabase.from('scores').select();

    final signedUrls = await Future.wait(
      submissions.map(
        (s) => supabase.storage.from('Photos').createSignedUrl(s['photo_url'], 60 * 60),
      ),
    );

    final result = <Map<String, dynamic>>[];

    for (var i = 0; i < submissions.length; i++) {
      final submission = submissions[i];
      final signedUrl = signedUrls[i];

      final uploader = users.firstWhere(
        (u) => u['id'] == submission['user_id'],
        orElse: () => {'username': 'Unknown'},
      );

      final submissionScores = scores.where(
        (score) => score['submission_id'] == submission['id'],
      );

      final judgeDetails = <Map<String, dynamic>>[];
      int totalScore = 0;
      bool isDisqualified = false;
      String? disqualificationReason;

      for (final score in submissionScores) {
        final judgeUser = users.firstWhere(
          (u) => u['id'] == score['judge_id'],
          orElse: () => {'username': 'Unknown Judge'},
        );

        judgeDetails.add({
          'judge_name': judgeUser['username'],
          'score': score['score'],
          'disqualified': score['disqualified'],
          'reason': score['reason'],
          'source': score['source'] ?? 'judge',
        });

        totalScore += (score['score'] ?? 0) as int;

        if (score['disqualified'] == true) {
          isDisqualified = true;
          disqualificationReason = score['reason'];
        }
      }

      result.add({
        'signed_url': signedUrl,
        'username': (anonymousJudging || submission['is_anonymous'] == true) ? null : uploader['username'],
        'total_score': totalScore,
        'is_disqualified': isDisqualified,
        'disqualification_reason': disqualificationReason,
        'judge_details': judgeDetails,
      });
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Today\'s Photos')),
      body: AppBackground(
        group: group,
        child: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchTodayPhotos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final photos = snapshot.data ?? [];

          if (photos.isEmpty) {
            return const _EmptyState(
              icon: FontAwesomeIcons.camera,
              title: 'No photos yet',
              subtitle: 'No one has submitted a photo today.',
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📸 Photos submitted: ${photos.length}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _PhotoCarousel(photos: photos),
              ],
            ),
          );
        },
      ),
      ),
    );
  }
}
class _AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final String suffix;

  const _AnimatedCount({required this.value, this.style, this.suffix = ''});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, val, child) => Text('$val$suffix', style: style),
    );
  }
}

class LeaderboardPage extends StatelessWidget {
  final dynamic group;

  const LeaderboardPage({
    super.key,
    required this.group,
  });

  Future<List<Map<String, dynamic>>> fetchLeaderboard() async {
    final supabase = Supabase.instance.client;

final submissions = await supabase
    .from('submissions')
    .select()
    .eq('group_id', group['id']);

    final scores = await supabase.from('scores').select();

    final members = await supabase
        .from('group_members')
        .select()
        .eq('group_id', group['id'])
        .inFilter('role', ['owner', 'player', 'judge']);

    final competingMembers = members
        .where((m) => m['role'] == 'player' ||
            (m['role'] == 'owner' && (m['owner_is_judge'] != true || m['judge_also_plays'] == true)) ||
            (m['role'] == 'judge' && m['judge_also_plays'] == true))
        .toList();

    final users = await supabase.from('users').select();
    final streaks = await fetchGroupStreaks(group['id']);
    final wins = await fetchGroupWinCounts(group['id']);

    final results = <Map<String, dynamic>>[];

    for (final member in competingMembers) {
      final userId = member['user_id'];

      final user = users.firstWhere(
        (u) => u['id'] == userId,
        orElse: () => {'username': 'Unknown'},
      );

      final userSubmissions = submissions
          .where((s) => s['user_id'] == userId)
          .toList();

      int totalScore = 0;

      for (final submission in userSubmissions) {
        final submissionScores = scores
            .where((score) => score['submission_id'] == submission['id'])
            .toList();

        for (final score in submissionScores) {
          totalScore += (score['score'] ?? 0) as int;
        }
      }

      results.add({
        'username': user['username'],
        'role': member['role'],
        'wins': wins[userId] ?? 0,
        'total_score': totalScore,
        'streak': streaks[userId] ?? 0,
        'custom_title': member['custom_title'],
      });
    }

    // Rank by days won (the app's actual scoring model); raw judge points
    // only break ties between people with the same win count.
    results.sort((a, b) {
      final winDiff = (b['wins'] as int).compareTo(a['wins'] as int);
      if (winDiff != 0) return winDiff;
      return (b['total_score'] as int).compareTo(a['total_score'] as int);
    });

    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
      ),
      body: AppBackground(
        group: group,
        child: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchLeaderboard(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final results = snapshot.data ?? [];

        if (results.isEmpty) {
            return const _EmptyState(
              icon: FontAwesomeIcons.trophy,
              title: 'No scores yet',
              subtitle: 'Scores will appear here once photos are judged.',
            );
          }

final winner = results.first;

return ListView(
  padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
  children: [
    Card(
      child: ListTile(
        leading: const Text(
          '🏆',
          style: TextStyle(fontSize: 32),
        ),
        title: const Text(
  'Current Leader',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          (winner['custom_title'] as String?)?.isNotEmpty == true
              ? '${winner['username']} · "${winner['custom_title']}"'
              : winner['username'],
        ),
        trailing: _AnimatedCount(
          value: winner['wins'] as int,
          suffix: (winner['wins'] as int) == 1 ? ' win' : ' wins',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ),

    const SizedBox(height: 16),

...results.asMap().entries.map((entry) {
      final index = entry.key;
      final row = entry.value;

      const List<Color> palette = [
        Colors.redAccent,
        Colors.blueAccent,
        Colors.greenAccent,
        Colors.purpleAccent,
        Colors.orangeAccent,
        Colors.tealAccent,
        Colors.pinkAccent,
        Colors.amberAccent,
      ];

      final color = palette[index % palette.length];

      return Card(
        child: ListTile(
          leading: index == 0
              ? const Text('🏆', style: TextStyle(fontSize: 28))
              : _MemberAvatar(
                  username: row['username'] ?? '?',
                  color: color,
                ),
          title: Text(
            (row['custom_title'] as String?)?.isNotEmpty == true
                ? '${row['username']} · "${row['custom_title']}"'
                : row['username'],
          ),
          subtitle: Text(
            [
              row['role'] as String,
              if ((row['streak'] ?? 0) > 0) '🔥 ${row['streak']}',
              '${row['total_score']} pts',
            ].join(' • '),
          ),
          trailing: _AnimatedCount(
            value: row['wins'] as int,
            suffix: (row['wins'] as int) == 1 ? ' win' : ' wins',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }),
  ],
);
        },
      ),
      ),
      bottomNavigationBar: buildGroupBottomNav(context, group, 3),
    );
  }
}
class WeeklyRecapPage extends StatelessWidget {
  final dynamic group;

  const WeeklyRecapPage({super.key, required this.group});

  Future<Map<String, dynamic>> fetchWeeklyRecap() async {
    final supabase = Supabase.instance.client;

    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    final submissions = await supabase
        .from('submissions')
        .select()
        .eq('group_id', group['id'])
        .gte('submitted_at', startOfWeek.toIso8601String())
        .lt('submitted_at', endOfWeek.toIso8601String());

    final submissionIds = submissions.map((s) => s['id']).toSet();
    final allScores = await supabase.from('scores').select();
    final weekScores =
        allScores.where((sc) => submissionIds.contains(sc['submission_id'])).toList();

    final users = await supabase.from('users').select();
    final winsByUser =
        await fetchGroupWinCounts(group['id'], from: startOfWeek, to: endOfWeek);

    final submissionCountByUser = <String, int>{};
    final totalsByUser = <String, int>{};

    for (final s in submissions) {
      final uid = s['user_id'] as String;
      submissionCountByUser[uid] = (submissionCountByUser[uid] ?? 0) + 1;
    }

    for (final sc in weekScores) {
      final submission = submissions.firstWhere(
        (s) => s['id'] == sc['submission_id'],
        orElse: () => <String, dynamic>{},
      );
      if (submission.isEmpty) continue;
      final uid = submission['user_id'] as String;
      totalsByUser[uid] = (totalsByUser[uid] ?? 0) + ((sc['score'] ?? 0) as int);
    }

    final allUserIds = {
      ...submissionCountByUser.keys,
      ...totalsByUser.keys,
      ...winsByUser.keys,
    };

    final rows = allUserIds.map((uid) {
      final user = users.firstWhere(
        (u) => u['id'] == uid,
        orElse: () => {'username': 'Unknown'},
      );
      return {
        'username': user['username'],
        'submissions': submissionCountByUser[uid] ?? 0,
        'total_score': totalsByUser[uid] ?? 0,
        'wins': winsByUser[uid] ?? 0,
      };
    }).toList();

    // Rank by wins this week, raw points only break ties.
    rows.sort((a, b) {
      final winDiff = (b['wins'] as int).compareTo(a['wins'] as int);
      if (winDiff != 0) return winDiff;
      return (b['total_score'] as int).compareTo(a['total_score'] as int);
    });

    return {
      'startOfWeek': startOfWeek,
      'endOfWeek': endOfWeek.subtract(const Duration(days: 1)),
      'rows': rows,
    };
  }

  @override
  Widget build(BuildContext context) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    String fmt(DateTime d) => '${d.day} ${months[d.month - 1]}';

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Recap')),
      body: AppBackground(
        group: group,
        child: FutureBuilder<Map<String, dynamic>>(
        future: fetchWeeklyRecap(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final data = snapshot.data!;
          final startOfWeek = data['startOfWeek'] as DateTime;
          final endOfWeek = data['endOfWeek'] as DateTime;
          final rows = data['rows'] as List<Map<String, dynamic>>;

          if (rows.isEmpty) {
            return const _EmptyState(
              icon: FontAwesomeIcons.calendarCheck,
              title: 'No activity yet this week',
              subtitle: 'Submit a photo to see your weekly recap here.',
            );
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
            children: [
              Text(
                'Week of ${fmt(startOfWeek)} – ${fmt(endOfWeek)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...rows.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;

                const palette = [
                  Colors.redAccent,
                  Colors.blueAccent,
                  Colors.greenAccent,
                  Colors.purpleAccent,
                  Colors.orangeAccent,
                  Colors.tealAccent,
                  Colors.pinkAccent,
                  Colors.amberAccent,
                ];
                final color = palette[index % palette.length];

                return Card(
                  child: ListTile(
                    leading: index == 0
                        ? const Text('🏆', style: TextStyle(fontSize: 28))
                        : _MemberAvatar(username: row['username'] ?? '?', color: color),
                    title: Text(row['username'] ?? 'Unknown'),
                    subtitle: Text(
                      '${row['submissions']} submitted • ${row['total_score']} pts',
                    ),
                    trailing: Text(
                      (row['wins'] as int) == 1 ? '1 win' : '${row['wins']} wins',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
      ),
    );
  }
}

class BattleDetailsPage extends StatelessWidget {
  final dynamic group;
  final dynamic item;

  const BattleDetailsPage({
    super.key,
    required this.group,
    required this.item,
  });
Future<List<Map<String, dynamic>>> fetchBattlePhotos() async {
  final supabase = Supabase.instance.client;

  final startDate = DateTime.parse(item['dateKey']);
  final endDate = startDate.add(const Duration(days: 1));

  final submissions = await supabase
      .from('submissions')
      .select()
      .eq('group_id', group['id'])
      .gte('submitted_at', startDate.toIso8601String())
      .lt('submitted_at', endDate.toIso8601String());

  final users = await supabase.from('users').select();
  final scores = await supabase.from('scores').select();

  final signedUrls = await Future.wait(
    submissions.map(
      (s) => supabase.storage.from('Photos').createSignedUrl(s['photo_url'], 60 * 60),
    ),
  );

  final result = <Map<String, dynamic>>[];

  for (var i = 0; i < submissions.length; i++) {
    final submission = submissions[i];
    final signedUrl = signedUrls[i];

    final user = users.firstWhere(
      (u) => u['id'] == submission['user_id'],
      orElse: () => {'username': 'Unknown'},
    );

    final submissionScores = scores.where(
      (score) => score['submission_id'] == submission['id'],
    );
    final judgeDetails = <Map<String, dynamic>>[];

int totalScore = 0;
bool isDisqualified = false;
String? disqualificationReason;

for (final score in submissionScores) {
  final judgeUser = users.firstWhere(
    (u) => u['id'] == score['judge_id'],
    orElse: () => {'username': 'Unknown Judge'},
  );

  judgeDetails.add({
    'judge_name': judgeUser['username'],
    'score': score['score'],
    'disqualified': score['disqualified'],
    'reason': score['reason'],
    'source': score['source'] ?? 'judge',
  });

  totalScore += (score['score'] ?? 0) as int;

  if (score['disqualified'] == true) {
    isDisqualified = true;
    disqualificationReason = score['reason'];
  }
}

result.add({
  'signed_url': signedUrl,
  'username': user['username'],
  'submitted_at': submission['submitted_at'],
  'total_score': totalScore,
      'is_disqualified': isDisqualified,
'disqualification_reason': disqualificationReason,
'judge_details': judgeDetails,
    });
  }

  return result;
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Battle Details'),
      ),
body: AppBackground(
  group: group,
  child: SingleChildScrollView(
  padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
  child: FutureBuilder<List<Map<String, dynamic>>>(
    future: fetchBattlePhotos(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      if (snapshot.hasError) {
        return Center(child: Text('Error: ${snapshot.error}'));
      }

      final photos = snapshot.data ?? [];
      final maxScore = photos.isEmpty
          ? 0
          : photos
              .map((p) => p['total_score'] as int)
              .reduce((a, b) => a > b ? a : b);

      const List<Color> palette = [
        Colors.redAccent,
        Colors.blueAccent,
        Colors.greenAccent,
        Colors.purpleAccent,
        Colors.orangeAccent,
        Colors.tealAccent,
        Colors.pinkAccent,
        Colors.amberAccent,
      ];

      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final date = DateTime.parse(item['date']);
      final dateLabel = '${date.day} ${months[date.month - 1]} ${date.year}';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.amber.withOpacity(0.25),
                  Colors.amber.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const FaIcon(FontAwesomeIcons.trophy, color: Colors.amber, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['winner'],
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          FaIcon(
                            FontAwesomeIcons.calendarDays,
                            size: 13,
                            color: Colors.white.withOpacity(0.6),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            dateLabel,
                            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.6)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      FaIcon(FontAwesomeIcons.chartSimple, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Battle Summary',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (photos.isEmpty)
                    const Text('No scores yet')
                  else
                    ...photos.asMap().entries.map((entry) {
                      final index = entry.key;
                      final photo = entry.value;
                      final color = palette[index % palette.length];
                      final isWinner = photo['username'] == item['winner'];
                      final score = photo['total_score'] as int;
                      final ratio = maxScore == 0 ? 0.0 : score / maxScore;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            _MemberAvatar(
                              username: photo['username'] ?? '?',
                              color: color,
                              size: 32,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        photo['username'] ?? 'Unknown',
                                        style: TextStyle(
                                          fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                                          color: isWinner ? Colors.amber : Colors.white,
                                        ),
                                      ),
                                      Text(
                                        '$score pts',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: ratio,
                                      minHeight: 6,
                                      backgroundColor: Colors.white.withOpacity(0.08),
                                      valueColor: AlwaysStoppedAnimation(
                                        isWinner ? Colors.amber : color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              const FaIcon(FontAwesomeIcons.camera, size: 16),
              const SizedBox(width: 8),
              Text(
                'Photos submitted: ${photos.length}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (photos.isEmpty)
            const Text('No photos for this day')
          else
            _PhotoCarousel(photos: photos),
        ],
      );
    },
  ),
  ),
),
    );
  }
}

class _PhotoCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> photos;

  const _PhotoCarousel({required this.photos});

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _scoreChip(FaIconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 480,
          child: PageView.builder(
            controller: _pageController,
            itemCount: photos.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final photo = photos[index];
              final judgeDetails = photo['judge_details'] as List;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          photo['username'] != null
                              ? '📸 ${photo['username']}'
                              : '🕶️ Anonymous submission',
                          style: photo['username'] != null
                              ? const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                              : const TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FullScreenPhotoPage(
                                  imageUrl: photo['signed_url'],
                                  username: photo['username'],
                                ),
                              ),
                            );
                          },
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Hero(
                                  tag: photo['signed_url'],
                                  child: CachedNetworkImage(
                                    imageUrl: photo['signed_url'],
                                    height: 240,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const FaIcon(FontAwesomeIcons.expand, color: Colors.white, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (photo['is_disqualified'] == true) ...[
                          _scoreChip(FontAwesomeIcons.ban, 'Disqualified', Colors.redAccent),
                          const SizedBox(height: 6),
                          Text(
                            photo['disqualification_reason'] ?? 'No reason provided',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ] else
                          _scoreChip(
                            FontAwesomeIcons.star,
                            'Total Score: ${photo['total_score']}',
                            Colors.greenAccent,
                          ),
                        const SizedBox(height: 12),
                        const Row(
                          children: [
                            FaIcon(FontAwesomeIcons.scaleBalanced, size: 14),
                            SizedBox(width: 8),
                            Text(
                              'Judge Breakdown',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...judgeDetails.asMap().entries.map((entry) {
                          final judge = entry.value;
                          final disqualified = judge['disqualified'] == true;

                          if (judge['source'] == 'insurance') {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: kAccentGold.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const FaIcon(
                                      FontAwesomeIcons.shieldHalved,
                                      size: 13,
                                      color: kAccentGold,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text('Score Insurance', style: TextStyle(color: kAccentGold)),
                                  ),
                                  Row(
                                    children: [
                                      const FaIcon(FontAwesomeIcons.star, size: 13, color: kAccentGold),
                                      const SizedBox(width: 4),
                                      Text(
                                        '+${judge['score']}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: kAccentGold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                _MemberAvatar(
                                  username: judge['judge_name'] ?? '?',
                                  color: Colors.blueGrey,
                                  size: 28,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    judge['judge_name'] ?? 'Unknown Judge',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (disqualified)
                                  Text(
                                    'DQ — ${judge['reason'] ?? 'No reason'}',
                                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                  )
                                else
                                  Row(
                                    children: [
                                      const FaIcon(FontAwesomeIcons.star, size: 13, color: Colors.amber),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${judge['score']}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (photos.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(photos.length, (index) {
              final isActive = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 10 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive ? Colors.redAccent : Colors.white30,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class CalendarPage extends StatefulWidget {
  final dynamic group;

  const CalendarPage({
    super.key,
    required this.group,
  });

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  // Fixed palette. Member #1 in the group gets color[0], member #2 gets
  // color[1], and so on. Works for any number of members.
  static const List<Color> _palette = [
    Colors.redAccent,
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.purpleAccent,
    Colors.orangeAccent,
    Colors.tealAccent,
    Colors.pinkAccent,
    Colors.amberAccent,
  ];

  bool _loading = true;
  String? _errorMessage;
  bool _showListView = false;

  // userId -> color
  final Map<String, Color> _memberColors = {};
  // userId -> username
  final Map<String, String> _memberNames = {};
  // dateKey ("yyyy-MM-dd") -> battle item (same shape BattleDetailsPage expects)
  final Map<String, Map<String, dynamic>> _dayItems = {};

DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String? _selectedDayKey;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final supabase = Supabase.instance.client;

    try {
      // 1. Get the competing members (owner + player), sorted so colors
      // stay consistent every time the page loads.
      final members = await supabase
          .from('group_members')
          .select()
          .eq('group_id', widget.group['id'])
          .inFilter('role', ['owner', 'player', 'judge']);

      final competingMembers = members
          .where((m) => m['role'] == 'player' ||
              (m['role'] == 'owner' && (m['owner_is_judge'] != true || m['judge_also_plays'] == true)) ||
              (m['role'] == 'judge' && m['judge_also_plays'] == true))
          .toList();

      final sortedMembers = [...competingMembers]
        ..sort((a, b) => (a['user_id'] as String).compareTo(b['user_id'] as String));

      for (var i = 0; i < sortedMembers.length; i++) {
        final userId = sortedMembers[i]['user_id'] as String;
        _memberColors[userId] = _palette[i % _palette.length];
      }

      // 2. Get usernames for the legend.
      final users = await supabase.from('users').select();
      for (final user in users) {
        _memberNames[user['id']] = user['username'] ?? 'Unknown';
      }

      // 3. Get all submissions + scores for this group, same approach
      // already used in Battle History.
      final submissions = await supabase
          .from('submissions')
          .select()
          .eq('group_id', widget.group['id']);

      final scores = await supabase.from('scores').select();

     final days = <String, Map<String, dynamic>>{};

      for (final submission in submissions) {
        final submittedAt = submission['submitted_at'];
        final dateKey = submittedAt.toString().split('T').first;
        final userId = submission['user_id'];

       days.putIfAbsent(dateKey, () {
          return {
            'date': submittedAt,
            'totals': <String, int>{},
            'submittedUsers': <String>{},
            'submittedTimes': <String, String>{},
          };
        });

        final totals = days[dateKey]!['totals'] as Map<String, int>;
        final submittedUsers = days[dateKey]!['submittedUsers'] as Set<String>;
        final submittedTimes = days[dateKey]!['submittedTimes'] as Map<String, String>;
        submittedUsers.add(userId);
        submittedTimes[userId] = submittedAt.toString();

        final submissionScores = scores.where(
          (score) => score['submission_id'] == submission['id'],
        );

        for (final score in submissionScores) {
          totals[userId] = (totals[userId] ?? 0) + ((score['score'] ?? 0) as int);
        }
      }

     days.forEach((dateKey, day) {
        final totals = day['totals'] as Map<String, int>;
        final submittedUsers = day['submittedUsers'] as Set<String>;
        final submittedTimes = day['submittedTimes'] as Map<String, String>;

        // Every player who submitted gets a row, even if not scored yet (shows 0).
        final displayTotals = <String, int>{
          for (final userId in submittedUsers) userId: totals[userId] ?? 0,
        };

        String winnerName = 'No winner yet';
        String? winnerId;

        if (totals.isNotEmpty) {
          final maxScore = totals.values.reduce((a, b) => a > b ? a : b);
          final topUserIds = totals.entries
              .where((e) => e.value == maxScore)
              .map((e) => e.key)
              .toList();

          // Tie-break: earliest submission wins.
          topUserIds.sort(
            (a, b) => submittedTimes[a]!.compareTo(submittedTimes[b]!),
          );
          winnerId = topUserIds.first;
          winnerName = _memberNames[winnerId] ?? 'Unknown';
        }

        _dayItems[dateKey] = {
          'date': day['date'],
          'dateKey': dateKey,
          'winner': winnerName,
          'winnerId': winnerId,
          'totals': displayTotals,
        };
      });

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  String _dateKeyFor(DateTime day) {
    return '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  }

void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    final dateKey = _dateKeyFor(selectedDay);

    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      // Tapping the same day again closes the panel.
      _selectedDayKey = _selectedDayKey == dateKey ? null : dateKey;
    });
  }
  Widget? _selectedDayPanel() {
    if (_selectedDayKey == null) return null;

    final item = _dayItems[_selectedDayKey];

    final date = DateTime.parse(_selectedDayKey!);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final dateLabel = '${date.day} ${months[date.month - 1]} ${date.year}';

    if (item == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('$dateLabel — No battle on this day'),
        ),
      );
    }

    final rawTotals = item['totals'];
    final totals = rawTotals is Map
        ? Map<String, int>.from(rawTotals)
        : <String, int>{};
    final winnerId = item['winnerId'] as String?;

    if (totals.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('$dateLabel — No scores yet'),
        ),
      );
    }

    final sortedEntries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📅 $dateLabel',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...sortedEntries.map((e) {
              final userId = e.key;
              final score = e.value;
              final name = _memberNames[userId] ?? 'Unknown';
              final color = _memberColors[userId] ?? Colors.grey;
              final isWinner = userId == winnerId;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(isWinner ? '👑 $name' : name),
                    ),
                    Text(
                      '$score pts',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BattleDetailsPage(
                        group: widget.group,
                        item: item,
                      ),
                    ),
                  );
                },
                child: const Text('View Full Details →'),
              ),
            ),
          ],
        ),
      ),
    );
  }
Widget _monthlyStats() {
    final monthPrefix =
        '${_focusedDay.year}-${_focusedDay.month.toString().padLeft(2, '0')}';

    final wins = <String, int>{};

    _dayItems.forEach((dateKey, item) {
      if (!dateKey.startsWith(monthPrefix)) return;
      final winnerId = item['winnerId'] as String?;
      if (winnerId == null) return;
      wins[winnerId] = (wins[winnerId] ?? 0) + 1;
    });

    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final monthName = months[_focusedDay.month - 1];

    if (wins.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('No battles won yet in $monthName'),
        ),
      );
    }

    final sortedEntries = wins.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📊 $monthName Stats',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...sortedEntries.asMap().entries.map((e) {
              final isLeader = e.key == 0;
              final userId = e.value.key;
              final winCount = e.value.value;
              final name = _memberNames[userId] ?? 'Unknown';
              final color = _memberColors[userId] ?? Colors.grey;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(isLeader ? '👑 $name' : name),
                    ),
                    Text(
                      '$winCount ${winCount == 1 ? "win" : "wins"}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
Widget _dayCell(
    DateTime day, {
    bool isToday = false,
    bool isOutside = false,
    bool isSelected = false,
  }) {
    final item = _dayItems[_dateKeyFor(day)];
    final winnerId = item?['winnerId'] as String?;
    final color = winnerId != null ? _memberColors[winnerId] : null;

    final cell = Container(
      margin: const EdgeInsets.all(4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: isOutside
            ? Colors.transparent
            : (color ?? Colors.grey.shade800),
        border: isToday ? Border.all(color: Colors.white, width: 2) : null,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: (color ?? Colors.white).withOpacity(0.6),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Text(
        '${day.day}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isOutside ? Colors.grey : Colors.white,
        ),
      ),
    );

    if (!isSelected) return cell;

    return TweenAnimationBuilder<double>(
      key: ValueKey(_dateKeyFor(day)),
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: cell,
    );
  }

  Widget _historyListView() {
    final items = _dayItems.values.toList()
      ..sort((a, b) => (b['dateKey'] as String).compareTo(a['dateKey'] as String));

    if (items.isEmpty) {
      return const _EmptyState(
        icon: FontAwesomeIcons.clockRotateLeft,
        title: 'No battles yet',
        subtitle: 'Completed battle days will appear here.',
      );
    }

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final date = DateTime.parse(item['dateKey']);
        final dateLabel = '${date.day} ${months[date.month - 1]} ${date.year}';

        return Card(
          child: ListTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BattleDetailsPage(group: widget.group, item: item),
                ),
              );
            },
            leading: const Text('📅', style: TextStyle(fontSize: 28)),
            title: Text(dateLabel),
            subtitle: Text('Winner: ${item['winner']}'),
            trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 16),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: FaIcon(_showListView ? FontAwesomeIcons.calendarDays : FontAwesomeIcons.list),
            tooltip: _showListView ? 'Calendar view' : 'List view',
            onPressed: () => setState(() => _showListView = !_showListView),
          ),
        ],
      ),
     body: AppBackground(
        group: widget.group,
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : _showListView
                  ? _historyListView()
                  : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 32),
                  child: Column(
                    children: [
                      TableCalendar(
                        firstDay: DateTime(2024, 1, 1),
                        lastDay: DateTime(2030, 12, 31),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) =>
                            _selectedDay != null && isSameDay(_selectedDay, day),
                        onDaySelected: _onDaySelected,
                        onPageChanged: (focusedDay) {
                          setState(() => _focusedDay = focusedDay);
                        },
                        calendarFormat: CalendarFormat.month,
                        availableCalendarFormats: const {
                          CalendarFormat.month: 'Month',
                        },
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        daysOfWeekStyle: const DaysOfWeekStyle(
                          weekdayStyle: TextStyle(fontWeight: FontWeight.bold),
                          weekendStyle: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, focusedDay) =>
                              _dayCell(day),
                          todayBuilder: (context, day, focusedDay) =>
                              _dayCell(day, isToday: true),
                          outsideBuilder: (context, day, focusedDay) =>
                              _dayCell(day, isOutside: true),
                         selectedBuilder: (context, day, focusedDay) => _dayCell(
                            day,
                            isToday: isSameDay(day, DateTime.now()),
                            isSelected: true,
                          ),
                        ),
                      ),
                     if (_selectedDayPanel() != null) ...[
                        const SizedBox(height: 20),
                        _selectedDayPanel()!,
                      ],
                      const SizedBox(height: 20),
                      _monthlyStats(),
                      const SizedBox(height: 20),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Players',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: _memberColors.entries.map((entry) {
                          final name = _memberNames[entry.key] ?? 'Unknown';
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: entry.value,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(name),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
      ),
      bottomNavigationBar: buildGroupBottomNav(context, widget.group, 1),
    );
  }
}
class _PhotoCropPage extends StatefulWidget {
  final File imageFile;
  final double aspectRatio;

  const _PhotoCropPage({required this.imageFile, this.aspectRatio = 2.4});

  @override
  State<_PhotoCropPage> createState() => _PhotoCropPageState();
}

class _PhotoCropPageState extends State<_PhotoCropPage> {
  final _repaintKey = GlobalKey();
  final _transformController = TransformationController();
  bool _capturing = false;

  Future<void> _confirm() async {
    setState(() => _capturing = true);
    try {
      final boundary =
          _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final captured = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await captured.toByteData(format: ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      if (!mounted) return;
      Navigator.pop(context, bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Reposition Photo'),
        actions: [
          TextButton(
            onPressed: _capturing ? null : _confirm,
            child: _capturing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Use Photo'),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pinch to zoom, drag to reposition',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
              ),
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: widget.aspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RepaintBoundary(
                    key: _repaintKey,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return InteractiveViewer(
                          transformationController: _transformController,
                          minScale: 1.0,
                          maxScale: 4.0,
                          child: SizedBox(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            child: Image.file(widget.imageFile, fit: BoxFit.cover),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StorePage extends StatefulWidget {
  final dynamic group;
  const StorePage({super.key, required this.group});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  final supabase = Supabase.instance.client;
  bool _loading = true;
  bool _busy = false;
  int _balance = 0;
  Map<String, dynamic>? _todaySubmission;
  String? _customTitle;
  bool _submittedYesterday = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final groupId = widget.group['id'];

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final startOfYesterday = startOfDay.subtract(const Duration(days: 1));

    final results = await Future.wait<dynamic>([
      fetchCoinBalance(groupId, user.id),
      supabase
          .from('submissions')
          .select()
          .eq('group_id', groupId)
          .eq('user_id', user.id)
          .gte('submitted_at', startOfDay.toIso8601String())
          .lt('submitted_at', endOfDay.toIso8601String())
          .maybeSingle(),
      supabase
          .from('group_members')
          .select('custom_title')
          .eq('group_id', groupId)
          .eq('user_id', user.id)
          .maybeSingle(),
      supabase
          .from('submissions')
          .select()
          .eq('group_id', groupId)
          .eq('user_id', user.id)
          .gte('submitted_at', startOfYesterday.toIso8601String())
          .lt('submitted_at', startOfDay.toIso8601String())
          .maybeSingle(),
    ]);

    if (!mounted) return;
    setState(() {
      _balance = results[0] as int;
      _todaySubmission = results[1] as Map<String, dynamic>?;
      _customTitle = (results[2] as Map<String, dynamic>?)?['custom_title'] as String?;
      _submittedYesterday = results[3] != null;
      _loading = false;
    });
  }

  Future<void> _purchase(StoreItemDef item, Future<void> Function() applyEffect) async {
    final user = supabase.auth.currentUser;
    if (user == null || _busy) return;

    setState(() => _busy = true);
    try {
      final freshBalance = await fetchCoinBalance(widget.group['id'], user.id);
      if (freshBalance < item.cost) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not enough coins')),
        );
        return;
      }

      await supabase.from('coin_transactions').insert({
        'group_id': widget.group['id'],
        'user_id': user.id,
        'amount': -item.cost,
        'reason': 'purchase:${item.key}',
      });

      await applyEffect();

      analytics.logEvent(name: 'store_purchase', parameters: {'item': item.key});
      HapticFeedback.mediumImpact();
      playFeedbackSound();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} purchased!')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buyCustomTitle() async {
    final controller = TextEditingController(text: _customTitle ?? '');
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Custom Title'),
        content: TextField(
          controller: controller,
          maxLength: 24,
          decoration: const InputDecoration(hintText: 'e.g. The Undefeated'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Buy'),
          ),
        ],
      ),
    );

    if (title == null || title.isEmpty || !mounted) return;

    await _purchase(kStoreItems.firstWhere((i) => i.key == 'custom_title'), () async {
      await supabase
          .from('group_members')
          .update({'custom_title': title})
          .eq('group_id', widget.group['id'])
          .eq('user_id', supabase.auth.currentUser!.id);
    });
  }

  Future<void> _buyScoreInsurance() async {
    final submission = _todaySubmission;
    if (submission == null) return;

    await _purchase(kStoreItems.firstWhere((i) => i.key == 'score_insurance'), () async {
      await supabase.from('scores').insert({
        'submission_id': submission['id'],
        'judge_id': null,
        'score': 1,
        'disqualified': false,
        'source': 'insurance',
      });
    });
  }

  Future<void> _buyStreakShield() async {
    await _purchase(kStoreItems.firstWhere((i) => i.key == 'streak_shield'), () async {
      final today = DateTime.now();
      final yesterday =
          DateTime(today.year, today.month, today.day).subtract(const Duration(days: 1));
      await supabase.from('streak_shields').insert({
        'group_id': widget.group['id'],
        'user_id': supabase.auth.currentUser!.id,
        'covered_date': _dateKeyForStreak(yesterday),
      });
    });
  }

  Future<void> _buyDareCard() async {
    await _purchase(kStoreItems.firstWhere((i) => i.key == 'dare_card'), () async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final dateKey = _dateKeyForStreak(tomorrow);
      final prompt = kChallengePrompts[Random().nextInt(kChallengePrompts.length)];
      await supabase.from('groups').update({
        'forced_challenge_date': dateKey,
        'forced_challenge_prompt': prompt,
      }).eq('id', widget.group['id']);
      // Keep the shared group map (same instance the Dashboard reads) in
      // sync so the override applies immediately without a full reload.
      widget.group['forced_challenge_date'] = dateKey;
      widget.group['forced_challenge_prompt'] = prompt;
    });
  }

  Future<void> _buyAnonymousSubmission() async {
    final submission = _todaySubmission;
    if (submission == null) return;

    await _purchase(kStoreItems.firstWhere((i) => i.key == 'anonymous_submission'), () async {
      await supabase.from('submissions').update({'is_anonymous': true}).eq('id', submission['id']);
    });
  }

  void _onBuy(StoreItemDef item) {
    switch (item.key) {
      case 'custom_title':
        _buyCustomTitle();
        break;
      case 'score_insurance':
        _buyScoreInsurance();
        break;
      case 'streak_shield':
        _buyStreakShield();
        break;
      case 'dare_card':
        _buyDareCard();
        break;
      case 'anonymous_submission':
        _buyAnonymousSubmission();
        break;
    }
  }

  bool _canBuy(StoreItemDef item) {
    if (item.comingSoon) return false;
    if (_balance < item.cost) return false;
    if (item.key == 'score_insurance' || item.key == 'anonymous_submission') {
      return _todaySubmission != null;
    }
    if (item.key == 'streak_shield') {
      return !_submittedYesterday;
    }
    return true;
  }

  String? _disabledReason(StoreItemDef item) {
    if (item.comingSoon) return 'Coming soon';
    if (_balance < item.cost) return 'Not enough coins';
    if ((item.key == 'score_insurance' || item.key == 'anonymous_submission') &&
        _todaySubmission == null) {
      return 'Submit today\'s photo first';
    }
    if (item.key == 'streak_shield' && _submittedYesterday) {
      return 'No missed day to cover';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store'),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.circleQuestion),
            tooltip: 'How to earn coins',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('🪙 How to Earn Coins'),
                  content: const Text(
                    '🏆 Win the day — 10 coins\n\n'
                    '🔥 Win with a streak of 3+ — an extra 5 coins\n\n'
                    '⚖️ Judge a day — 5 coins, whether or not you win\n\n'
                    'Coins are paid out automatically once a day is finished.',
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: AppBackground(
        group: widget.group,
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
                children: [
                  Card(
                    color: kAccentGold.withOpacity(0.12),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const FaIcon(FontAwesomeIcons.coins, color: kAccentGold, size: 28),
                          const SizedBox(width: 12),
                          _AnimatedCount(
                            value: _balance,
                            suffix: ' coins',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: kAccentGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_customTitle != null && _customTitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Your title: "$_customTitle"',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                      ),
                    ),
                  for (final item in kStoreItems)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: kAccentGold.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: FaIcon(item.icon, color: kAccentGold, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.description,
                                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
                                  ),
                                  if (_disabledReason(item) != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _disabledReason(item)!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: (_canBuy(item) && !_busy) ? () => _onBuy(item) : null,
                              child: Text('${item.cost}🪙'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
      ),
    );
  }
}

class MiniGamesPage extends StatelessWidget {
  final dynamic group;

  const MiniGamesPage({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mini-Games')),
      body: AppBackground(
        group: group,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
          children: [
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const FaIcon(FontAwesomeIcons.bullseye, size: 28, color: kAccentGold),
                title: const Text('Predictions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: const Text('Bet coins on who wins today\'s battle.'),
                trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 14),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PredictionsPage(group: group)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const FaIcon(FontAwesomeIcons.masksTheater, size: 28, color: kAccentTeal),
                title: const Text('Real or Fake', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: const Text('Submit a sneaky photo, or catch someone else\'s bluff.'),
                trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 14),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BluffGamePage(group: group)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const int kPredictionStake = 5;

class PredictionsPage extends StatefulWidget {
  final dynamic group;

  const PredictionsPage({super.key, required this.group});

  @override
  State<PredictionsPage> createState() => _PredictionsPageState();
}

class _PredictionsPageState extends State<PredictionsPage> {
  final supabase = Supabase.instance.client;

  bool _loading = true;
  bool _placing = false;
  int _balance = 0;
  List<Map<String, dynamic>> _competingMembers = [];
  Map<String, Map<String, dynamic>> _usersById = {};
  Map<String, dynamic>? _todayPrediction;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final groupId = widget.group['id'];
    final todayKey = _dateKeyForStreak(DateTime.now());

    final results = await Future.wait<dynamic>([
      fetchCoinBalance(groupId, user.id),
      supabase
          .from('group_members')
          .select()
          .eq('group_id', groupId)
          .inFilter('role', ['owner', 'player', 'judge']),
      supabase.from('users').select(),
      supabase
          .from('predictions')
          .select()
          .eq('group_id', groupId)
          .eq('predictor_id', user.id)
          .order('day', ascending: false)
          .limit(14),
      supabase
          .from('coin_transactions')
          .select()
          .eq('group_id', groupId)
          .eq('user_id', user.id)
          .inFilter('reason', ['prediction_payout', 'prediction_refund']),
      supabase.from('groups').select('coins_settled_through').eq('id', groupId).single(),
    ]);

    if (!mounted) return;

    final members = (results[1] as List).cast<Map<String, dynamic>>();
    final competing = members
        .where((m) =>
            m['role'] == 'player' ||
            (m['role'] == 'owner' && (m['owner_is_judge'] != true || m['judge_also_plays'] == true)) ||
            (m['role'] == 'judge' && m['judge_also_plays'] == true))
        .toList();

    final users = (results[2] as List).cast<Map<String, dynamic>>();
    final usersById = {for (final u in users) u['id'] as String: u};

    final myPredictions = (results[3] as List).cast<Map<String, dynamic>>();
    final settlementTxs = (results[4] as List).cast<Map<String, dynamic>>();
    final settledThrough = (results[5] as Map<String, dynamic>)['coins_settled_through'] as String?;

    Map<String, dynamic>? today;
    final history = <Map<String, dynamic>>[];
    for (final p in myPredictions) {
      final day = p['day'] as String;
      if (day == todayKey) {
        today = p;
        continue;
      }

      String status;
      if (settledThrough == null || settledThrough.compareTo(day) < 0) {
        status = 'pending';
      } else {
        final payout = settlementTxs.where((t) => t['reference_date'] == day && t['reason'] == 'prediction_payout');
        final refund = settlementTxs.where((t) => t['reference_date'] == day && t['reason'] == 'prediction_refund');
        if (payout.isNotEmpty) {
          status = 'won:${payout.first['amount']}';
        } else if (refund.isNotEmpty) {
          status = 'refunded';
        } else {
          status = 'lost';
        }
      }
      history.add({...p, 'status': status});
    }

    setState(() {
      _balance = results[0] as int;
      _competingMembers = competing;
      _usersById = usersById;
      _todayPrediction = today;
      _history = history;
      _loading = false;
    });
  }

  Future<void> _confirmAndPlace(String targetUserId, String targetUsername) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Place Prediction'),
        content: Text('Bet $kPredictionStake 🪙 that $targetUsername wins today\'s battle?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Bet')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _placePrediction(targetUserId);
  }

  Future<void> _placePrediction(String targetUserId) async {
    final user = supabase.auth.currentUser;
    if (user == null || _placing) return;

    setState(() => _placing = true);
    try {
      final freshBalance = await fetchCoinBalance(widget.group['id'], user.id);
      if (freshBalance < kPredictionStake) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not enough coins')),
        );
        return;
      }

      await supabase.from('predictions').insert({
        'group_id': widget.group['id'],
        'day': _dateKeyForStreak(DateTime.now()),
        'predictor_id': user.id,
        'predicted_user_id': targetUserId,
        'stake': kPredictionStake,
      });

      await supabase.from('coin_transactions').insert({
        'group_id': widget.group['id'],
        'user_id': user.id,
        'amount': -kPredictionStake,
        'reason': 'stake:prediction',
      });

      analytics.logEvent(name: 'prediction_placed');
      HapticFeedback.mediumImpact();
      playFeedbackSound();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prediction locked in!')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Predictions')),
      body: AppBackground(
        group: widget.group,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
                  children: [
                    Card(
                      color: kAccentGold.withOpacity(0.12),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const FaIcon(FontAwesomeIcons.coins, color: kAccentGold, size: 28),
                            const SizedBox(width: 10),
                            _AnimatedCount(
                              value: _balance,
                              suffix: ' coins',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Who wins today?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Bet $kPredictionStake 🪙 on today\'s winner. Guess right and split the losers\' stakes.',
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    if (_todayPrediction != null)
                      Card(
                        child: ListTile(
                          leading: const FaIcon(FontAwesomeIcons.circleCheck, color: kAccentGold),
                          title: Text(
                            'You picked ${_usersById[_todayPrediction!['predicted_user_id']]?['username'] ?? 'Unknown'}',
                          ),
                          subtitle: const Text('Locked in for today — check back after judging.'),
                        ),
                      )
                    else if (_competingMembers.isEmpty)
                      const _EmptyState(
                        icon: FontAwesomeIcons.bullseye,
                        title: 'No one to bet on yet',
                        subtitle: 'Predictions open once your group has competing players.',
                      )
                    else
                      ..._competingMembers.map((m) {
                        final u = _usersById[m['user_id']];
                        final username = u?['username'] as String? ?? 'Unknown';
                        return Card(
                          child: ListTile(
                            leading: _MemberAvatar(username: username, color: kAccentGold, size: 36),
                            title: Text(username),
                            trailing: ElevatedButton(
                              onPressed: _placing ? null : () => _confirmAndPlace(m['user_id'] as String, username),
                              child: Text('Bet $kPredictionStake🪙'),
                            ),
                          ),
                        );
                      }),
                    if (_history.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text('Recent Results', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ..._history.map((p) {
                        final username = _usersById[p['predicted_user_id']]?['username'] as String? ?? 'Unknown';
                        final status = p['status'] as String;
                        String label;
                        Color color;
                        if (status == 'pending') {
                          label = 'Pending';
                          color = Colors.white54;
                        } else if (status.startsWith('won:')) {
                          label = '+${status.split(':')[1]} 🪙';
                          color = kAccentGold;
                        } else if (status == 'refunded') {
                          label = 'Refunded';
                          color = Colors.white54;
                        } else {
                          label = 'Lost';
                          color = Colors.redAccent;
                        }
                        return ListTile(
                          dense: true,
                          title: Text('${p['day']} — picked $username'),
                          trailing: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                        );
                      }),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

const int kBluffSubmitStake = 5;
const int kBluffGuessStake = 3;

/// Lazily resolves any 'Real or Fake' rounds whose guessing window has
/// closed — same pattern as [_settleCoinPayouts]: safe to call every time
/// the mini-game page loads, idempotent via the ledger's [reference_id]
/// partial unique index, so double-resolution from two devices is a no-op.
/// Payouts: correct guessers split the wrong guessers' stakes (plus get
/// their own stake back); if nobody caught the bluff, the submitter takes
/// the whole guess pot as a "fooled everyone" bonus; if nobody guessed at
/// all, the submitter just gets their entry stake refunded.
Future<void> resolveBluffRounds(String groupId) async {
  final supabase = Supabase.instance.client;
  try {
    final dueRounds = await supabase
        .from('bluff_rounds')
        .select()
        .eq('group_id', groupId)
        .eq('status', 'open')
        .lte('resolves_at', DateTime.now().toUtc().toIso8601String());

    for (final round in dueRounds) {
      final roundId = round['id'] as String;
      final guesses = await supabase.from('bluff_guesses').select().eq('round_id', roundId);

      final isReal = round['is_real'] as bool;
      final correct = guesses.where((g) => g['guess'] == isReal).toList();
      final wrong = guesses.where((g) => g['guess'] != isReal).toList();
      final wrongPot = wrong.length * kBluffGuessStake;

      Future<void> award(String userId, int amount, String reason) {
        return supabase.from('coin_transactions').upsert(
          {
            'group_id': groupId,
            'user_id': userId,
            'amount': amount,
            'reason': reason,
            'reference_id': roundId,
          },
          onConflict: 'group_id,user_id,reason,reference_id',
          ignoreDuplicates: true,
        );
      }

      if (correct.isNotEmpty) {
        final bonusEach = wrongPot ~/ correct.length;
        for (final g in correct) {
          await award(g['guesser_id'] as String, kBluffGuessStake + bonusEach, 'bluff_guess_correct');
        }
        await award(round['submitter_id'] as String, kBluffSubmitStake, 'bluff_submit_refund');
      } else if (wrong.isNotEmpty) {
        await award(round['submitter_id'] as String, kBluffSubmitStake + wrongPot, 'bluff_submit_bonus');
      } else {
        await award(round['submitter_id'] as String, kBluffSubmitStake, 'bluff_submit_refund');
      }

      await supabase
          .from('bluff_rounds')
          .update({'status': 'resolved'})
          .eq('id', roundId)
          .eq('status', 'open');
    }
  } catch (e, st) {
    FirebaseCrashlytics.instance.recordError(e, st, fatal: false);
  }
}

class BluffGamePage extends StatefulWidget {
  final dynamic group;

  const BluffGamePage({super.key, required this.group});

  @override
  State<BluffGamePage> createState() => _BluffGamePageState();
}

class _BluffGamePageState extends State<BluffGamePage> {
  final supabase = Supabase.instance.client;

  bool _loading = true;
  bool _busy = false;
  int _balance = 0;
  Map<String, Map<String, dynamic>> _usersById = {};
  List<Map<String, dynamic>> _toGuess = [];
  List<Map<String, dynamic>> _myOpen = [];
  List<Map<String, dynamic>> _resolved = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final groupId = widget.group['id'];

    await resolveBluffRounds(groupId);

    final results = await Future.wait<dynamic>([
      fetchCoinBalance(groupId, user.id),
      supabase.from('bluff_rounds').select().eq('group_id', groupId).order('created_at', ascending: false),
      supabase.from('users').select(),
    ]);

    if (!mounted) return;

    final rounds = (results[1] as List).cast<Map<String, dynamic>>();
    final users = (results[2] as List).cast<Map<String, dynamic>>();
    final usersById = {for (final u in users) u['id'] as String: u};

    final roundIds = rounds.map((r) => r['id']).toList();
    final allGuesses = roundIds.isEmpty
        ? <dynamic>[]
        : await supabase.from('bluff_guesses').select().inFilter('round_id', roundIds);

    final guessesByRound = <String, List<dynamic>>{};
    for (final g in allGuesses) {
      guessesByRound.putIfAbsent(g['round_id'] as String, () => []).add(g);
    }

    final signedUrls = <String, String>{};
    await Future.wait(rounds.map((r) async {
      signedUrls[r['id'] as String] =
          await supabase.storage.from('Photos').createSignedUrl(r['photo_url'], 60 * 60);
    }));

    final toGuess = <Map<String, dynamic>>[];
    final mine = <Map<String, dynamic>>[];
    final resolved = <Map<String, dynamic>>[];

    for (final r in rounds) {
      final rid = r['id'] as String;
      final guesses = guessesByRound[rid] ?? [];
      final myGuesses = guesses.where((g) => g['guesser_id'] == user.id).toList();
      final enriched = {
        ...r,
        'guesses': guesses,
        'my_guess': myGuesses.isEmpty ? null : myGuesses.first,
        'signed_url': signedUrls[rid],
      };

      if (r['status'] == 'resolved') {
        resolved.add(enriched);
      } else if (r['submitter_id'] == user.id || myGuesses.isNotEmpty) {
        mine.add(enriched);
      } else {
        toGuess.add(enriched);
      }
    }

    if (!mounted) return;
    setState(() {
      _balance = results[0] as int;
      _usersById = usersById;
      _toGuess = toGuess;
      _myOpen = mine;
      _resolved = resolved.take(10).toList();
      _loading = false;
    });
  }

  Future<void> _startRound() async {
    final user = supabase.auth.currentUser;
    if (user == null || _busy) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;

    if (!mounted) return;
    final isReal = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Real or Fake?'),
        content: const Text(
          'Did you actually take this photo yourself, or is it fake (downloaded, someone else\'s, AI-made, etc.)?\n\nOther players will try to guess which — pick honestly, the fun is in fooling them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('It\'s Fake'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('I Took It'),
          ),
        ],
      ),
    );
    if (isReal == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final freshBalance = await fetchCoinBalance(widget.group['id'], user.id);
      if (freshBalance < kBluffSubmitStake) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not enough coins')),
        );
        return;
      }

      final path = 'bluff_photos/${widget.group['id']}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('Photos').upload(
            path,
            File(image.path),
            fileOptions: const FileOptions(upsert: true),
          );

      await supabase.from('bluff_rounds').insert({
        'group_id': widget.group['id'],
        'submitter_id': user.id,
        'photo_url': path,
        'is_real': isReal,
        'resolves_at': DateTime.now().toUtc().add(const Duration(hours: 24)).toIso8601String(),
      });

      await supabase.from('coin_transactions').insert({
        'group_id': widget.group['id'],
        'user_id': user.id,
        'amount': -kBluffSubmitStake,
        'reason': 'stake:bluff_submit',
      });

      analytics.logEvent(name: 'bluff_round_started');
      HapticFeedback.mediumImpact();
      playFeedbackSound();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Round started! Open for 24 hours.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _guess(String roundId, bool guessReal) async {
    final user = supabase.auth.currentUser;
    if (user == null || _busy) return;

    setState(() => _busy = true);
    try {
      final freshBalance = await fetchCoinBalance(widget.group['id'], user.id);
      if (freshBalance < kBluffGuessStake) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not enough coins')),
        );
        return;
      }

      await supabase.from('bluff_guesses').insert({
        'round_id': roundId,
        'guesser_id': user.id,
        'guess': guessReal,
      });

      await supabase.from('coin_transactions').insert({
        'group_id': widget.group['id'],
        'user_id': user.id,
        'amount': -kBluffGuessStake,
        'reason': 'stake:bluff_guess',
      });

      analytics.logEvent(name: 'bluff_guess_placed');
      HapticFeedback.mediumImpact();
      playFeedbackSound();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guess locked in!')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _photoThumb(String? url) {
    return GestureDetector(
      onTap: url == null
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FullScreenPhotoPage(imageUrl: url)),
              ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: url == null
            ? Container(width: 64, height: 64, color: kSurfaceColor)
            : CachedNetworkImage(
                imageUrl: url,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
              ),
      ),
    );
  }

  Widget _toGuessCard(Map<String, dynamic> r) {
    final username = _usersById[r['submitter_id']]?['username'] as String? ?? 'Unknown';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _photoThumb(r['signed_url'] as String?),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$username\'s photo', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text(
                    'Real, or fake?',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : () => _guess(r['id'] as String, false),
                          child: Text('Fake ($kBluffGuessStake🪙)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _busy ? null : () => _guess(r['id'] as String, true),
                          child: Text('Real ($kBluffGuessStake🪙)'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _myOpenCard(Map<String, dynamic> r) {
    final user = supabase.auth.currentUser;
    final isMine = r['submitter_id'] == user?.id;
    final myGuess = r['my_guess'] as Map<String, dynamic>?;
    final username = _usersById[r['submitter_id']]?['username'] as String? ?? 'Unknown';
    final resolvesAt = DateTime.parse(r['resolves_at'] as String).toLocal();

    return Card(
      child: ListTile(
        leading: _photoThumb(r['signed_url'] as String?),
        title: Text(isMine ? 'Your round' : '$username\'s photo'),
        subtitle: Text(
          isMine
              ? 'Waiting for guesses — resolves ${_formatShortTime(resolvesAt)}'
              : 'You guessed ${myGuess?['guess'] == true ? 'Real' : 'Fake'} — resolves ${_formatShortTime(resolvesAt)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const FaIcon(FontAwesomeIcons.hourglassHalf, size: 16, color: Colors.white54),
      ),
    );
  }

  Widget _resolvedCard(Map<String, dynamic> r) {
    final user = supabase.auth.currentUser;
    final isMine = r['submitter_id'] == user?.id;
    final username = _usersById[r['submitter_id']]?['username'] as String? ?? 'Unknown';
    final isReal = r['is_real'] as bool;
    final myGuess = r['my_guess'] as Map<String, dynamic>?;
    final guesses = (r['guesses'] as List).cast<Map<String, dynamic>>();
    final correctCount = guesses.where((g) => g['guess'] == isReal).length;

    String resultLine;
    if (isMine) {
      resultLine = guesses.isEmpty
          ? 'No one guessed — stake refunded'
          : correctCount == 0
              ? 'You fooled everyone! 🎭'
              : '$correctCount/${guesses.length} caught it';
    } else if (myGuess != null) {
      final wasRight = myGuess['guess'] == isReal;
      resultLine = wasRight ? 'You were right! ✅' : 'You were fooled ❌';
    } else {
      resultLine = 'You didn\'t guess on this one';
    }

    return Card(
      color: kSurfaceColor,
      child: ListTile(
        leading: _photoThumb(r['signed_url'] as String?),
        title: Text('$username\'s photo was ${isReal ? 'REAL' : 'FAKE'}'),
        subtitle: Text(resultLine, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real or Fake'),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.plus),
            tooltip: 'Start a round',
            onPressed: _busy ? null : _startRound,
          ),
        ],
      ),
      body: AppBackground(
        group: widget.group,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
                  children: [
                    Card(
                      color: kAccentGold.withOpacity(0.12),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const FaIcon(FontAwesomeIcons.coins, color: kAccentGold, size: 28),
                            const SizedBox(width: 10),
                            _AnimatedCount(
                              value: _balance,
                              suffix: ' coins',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _startRound,
                        icon: const FaIcon(FontAwesomeIcons.masksTheater),
                        label: Text('Start a Round ($kBluffSubmitStake🪙)'),
                      ),
                    ),
                    if (_toGuess.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text('Guess These', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ..._toGuess.map(_toGuessCard),
                    ],
                    if (_myOpen.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text('Pending', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ..._myOpen.map(_myOpenCard),
                    ],
                    if (_resolved.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text('Revealed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ..._resolved.map(_resolvedCard),
                    ],
                    if (_toGuess.isEmpty && _myOpen.isEmpty && _resolved.isEmpty) ...[
                      const SizedBox(height: 40),
                      const _EmptyState(
                        icon: FontAwesomeIcons.masksTheater,
                        title: 'No rounds yet',
                        subtitle: 'Start one — submit a photo and see who you can fool.',
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

String _formatShortTime(DateTime t) {
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  final ampm = t.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $ampm';
}

class SettingsPage extends StatefulWidget {
  final dynamic group;

  const SettingsPage({
    super.key,
    required this.group,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

const List<String> kGroupBackgroundColors = [
  '#0A0A0A', // default black
  '#1A1A2E', // deep navy
  '#2D1B1B', // deep maroon
  '#1B2D1F', // deep forest
  '#241B2D', // deep purple
  '#2D2A1B', // deep olive
];

Color hexToColor(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  return Color(int.parse('ff$cleaned', radix: 16));
}

FaIconData roleIconData(String? role) {
  if (role == 'owner') return FontAwesomeIcons.shieldHalved;
  if (role == 'player') return FontAwesomeIcons.handFist;
  if (role == 'judge') return FontAwesomeIcons.scaleBalanced;
  return FontAwesomeIcons.userCircle;
}

/// Role icon widget — owner gets a shield with a small gear badge (admin,
/// not "winner"), everyone else gets a plain [roleIconData] glyph. Use
/// [compact] for very small contexts (e.g. an avatar badge) where the gear
/// overlay would be illegible.
Widget roleIcon(
  String? role, {
  double size = 18,
  Color color = Colors.white70,
  bool compact = false,
}) {
  if (role == 'owner' && !compact) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          FaIcon(FontAwesomeIcons.shieldHalved, size: size, color: color),
          Positioned(
            right: -size * 0.22,
            bottom: -size * 0.12,
            child: Container(
              padding: EdgeInsets.all(size * 0.06),
              decoration: const BoxDecoration(color: kBgColor, shape: BoxShape.circle),
              child: FaIcon(FontAwesomeIcons.gear, size: size * 0.5, color: color),
            ),
          ),
        ],
      ),
    );
  }
  return FaIcon(roleIconData(role), size: size, color: color);
}

const List<String> kChallengePrompts = [
  'Something orange',
  'Something that can fly',
  'A reflection',
  'Something round',
  'Something you can eat',
  'Something with wheels',
  'Something taller than you',
  'Something soft',
  'Something shiny',
  'Something striped',
  'Something with a face',
  'Something older than you',
  'Something you use every day',
  'Something blue',
  'Something broken',
  'Something you\'d bring to a desert island',
  'Something that makes noise',
  'Something upside down',
  'A shadow',
  'Something handmade',
  'Something in nature',
  'Something that smells good',
  'Something with numbers on it',
  'Something you\'re proud of',
  'Something green',
  'Something yellow',
  'Something purple',
  'Something cold',
  'Something warm',
  'Something that makes you laugh',
  'Something you\'re wearing',
  'Something with a story behind it',
  'Something you forgot you had',
  'Something with wings',
  'Something with legs',
  'Something you\'d never throw away',
  'Something that reminds you of childhood',
  'Something embarrassing',
  'Something expensive',
  'Something cheap',
  'Something you made yourself',
  'Something from another country',
  'Something transparent',
  'Something in your pocket right now',
  'Something that spins',
  'Something you use only once a year',
  'Something square',
  'Something metallic',
  'Something furry',
  'Something wet',
  'Something that glows',
  'Something small enough to fit in your hand',
  'Something bigger than your head',
  'Something pointy',
  'Something you\'d give as a gift',
  'Something you use in the kitchen',
  'Something with text on it',
  'Something you\'re grateful for',
];

final DateTime _challengeEpoch = DateTime(2024, 1, 1);

int _daysSinceEpoch(DateTime date) {
  return DateTime(date.year, date.month, date.day).difference(_challengeEpoch).inDays;
}

Set<int> _challengeWeekdaysForWeek(String groupId, int weekIndex, int challengesPerWeek) {
  if (challengesPerWeek <= 0) return {};
  final seed = (groupId.hashCode ^ (weekIndex * 7919)) & 0x7fffffff;
  final weekdays = List.generate(7, (i) => i)..shuffle(Random(seed));
  return weekdays.take(challengesPerWeek.clamp(0, 7)).toSet();
}

/// Deterministic: same group + same calendar day always gives the same
/// answer for every member, without needing a scheduled backend job.
/// [forcedChallengeDate] is a Dare Card purchase override (groups.forced_
/// challenge_date, 'YYYY-MM-DD') — pass the group row's value straight
/// through; it's already loaded wherever this is called from.
bool isChallengeDay(
  String groupId,
  int challengesPerWeek,
  DateTime date, {
  String? forcedChallengeDate,
}) {
  if (forcedChallengeDate != null && forcedChallengeDate == _dateKeyForStreak(date)) {
    return true;
  }
  if (challengesPerWeek <= 0) return false;
  final weekIndex = _daysSinceEpoch(date) ~/ 7;
  final weekdays = _challengeWeekdaysForWeek(groupId, weekIndex, challengesPerWeek);
  return weekdays.contains(date.weekday % 7);
}

String challengeTextFor(
  String groupId,
  DateTime date, {
  String? forcedChallengeDate,
  String? forcedChallengePrompt,
}) {
  if (forcedChallengeDate != null &&
      forcedChallengeDate == _dateKeyForStreak(date) &&
      forcedChallengePrompt != null) {
    return forcedChallengePrompt;
  }
  final dayIndex = _daysSinceEpoch(date);
  final seed = (groupId.hashCode ^ (dayIndex * 104729)) & 0x7fffffff;
  return kChallengePrompts[Random(seed).nextInt(kChallengePrompts.length)];
}

class _SettingsPageState extends State<SettingsPage> {
  bool _anonymousJudging = false;
  bool _freezeEnabled = false;
  bool _loading = true;
  bool _saving = false;
  bool _savingName = false;
  bool _uploadingBackground = false;

  final _nameController = TextEditingController();
  String? _backgroundColor;
  String? _backgroundPhotoUrl;
  int _challengesPerWeek = 0;
  String _backgroundTheme = 'default';
  String? _themePhotoUrl;
  bool _uploadingThemePhoto = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final supabase = Supabase.instance.client;

    try {
      final group = await supabase
          .from('groups')
          .select()
          .eq('id', widget.group['id'])
          .single();

      if (!mounted) return;

      setState(() {
        _anonymousJudging = group['anonymous_judging'] ?? false;
        _freezeEnabled = group['freeze_enabled'] ?? false;
        _nameController.text = group['name'] ?? '';
        _backgroundColor = group['background_color'];
        _backgroundPhotoUrl = group['background_photo_url'];
        _challengesPerWeek = group['challenges_per_week'] ?? 0;
        _backgroundTheme = group['background_theme'] ?? 'default';
        _themePhotoUrl = group['theme_photo_url'];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  Future<void> _updateAnonymousJudging(bool value) async {
    final supabase = Supabase.instance.client;

    setState(() {
      _anonymousJudging = value;
      _saving = true;
    });

try {
      final result = await supabase
          .from('groups')
          .update({'anonymous_judging': value})
          .eq('id', widget.group['id'])
          .select();

      if (!mounted) return;

      if (result.isEmpty) {
        setState(() => _anonymousJudging = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Save blocked by database permissions (no rows updated)',
            ),
          ),
        );
        setState(() => _saving = false);
        return;
      }

      widget.group['anonymous_judging'] = value;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Setting saved')),
      );
    } catch (e) {
      if (!mounted) return;

      // Revert the switch if saving failed
      setState(() => _anonymousJudging = !value);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<void> _updateFreezeEnabled(bool value) async {
    final supabase = Supabase.instance.client;

    setState(() {
      _freezeEnabled = value;
      _saving = true;
    });

    try {
      final result = await supabase
          .from('groups')
          .update({'freeze_enabled': value})
          .eq('id', widget.group['id'])
          .select();

      if (!mounted) return;

      if (result.isEmpty) {
        setState(() => _freezeEnabled = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Save blocked by database permissions (no rows updated)'),
          ),
        );
        setState(() => _saving = false);
        return;
      }

      widget.group['freeze_enabled'] = value;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Setting saved')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _freezeEnabled = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<void> _updateChallengesPerWeek(int value) async {
    final supabase = Supabase.instance.client;
    final previous = _challengesPerWeek;

    setState(() {
      _challengesPerWeek = value;
      _saving = true;
    });

    try {
      final result = await supabase
          .from('groups')
          .update({'challenges_per_week': value})
          .eq('id', widget.group['id'])
          .select();

      if (!mounted) return;

      if (result.isEmpty) {
        setState(() => _challengesPerWeek = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save blocked by database permissions')),
        );
      } else {
        widget.group['challenges_per_week'] = value;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Setting saved')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _challengesPerWeek = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<void> _saveGroupName() async {
    final supabase = Supabase.instance.client;
    final newName = _nameController.text.trim();

    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group name cannot be empty')),
      );
      return;
    }

    setState(() => _savingName = true);

    try {
      final result = await supabase
          .from('groups')
          .update({'name': newName})
          .eq('id', widget.group['id'])
          .select();

      if (!mounted) return;

      if (result.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save blocked by database permissions')),
        );
      } else {
        widget.group['name'] = newName;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group name updated')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }

    if (!mounted) return;
    setState(() => _savingName = false);
  }

  Future<void> _setBackgroundColor(String color) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase.from('groups').update({
        'background_color': color,
        'background_photo_url': null,
      }).eq('id', widget.group['id']);

      if (!mounted) return;

      setState(() {
        _backgroundColor = color;
        _backgroundPhotoUrl = null;
      });
      widget.group['background_color'] = color;
      widget.group['background_photo_url'] = null;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  Future<void> _uploadBackgroundPhoto() async {
    final supabase = Supabase.instance.client;
    final picker = ImagePicker();

    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;

    if (!mounted) return;
    final croppedBytes = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (_) => _PhotoCropPage(imageFile: File(image.path)),
      ),
    );
    if (croppedBytes == null) return;

    setState(() => _uploadingBackground = true);

    try {
      final path =
          'group_backgrounds/${widget.group['id']}/${DateTime.now().millisecondsSinceEpoch}.png';

      await supabase.storage.from('Photos').uploadBinary(
            path,
            croppedBytes,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/png'),
          );

      await supabase.from('groups').update({
        'background_photo_url': path,
        'background_color': null,
      }).eq('id', widget.group['id']);

      if (!mounted) return;

      setState(() {
        _backgroundPhotoUrl = path;
        _backgroundColor = null;
      });
      widget.group['background_photo_url'] = path;
      widget.group['background_color'] = null;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Background updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }

    if (!mounted) return;
    setState(() => _uploadingBackground = false);
  }

  Future<void> _resetBackground() async {
    final supabase = Supabase.instance.client;

    try {
      await supabase.from('groups').update({
        'background_color': null,
        'background_photo_url': null,
      }).eq('id', widget.group['id']);

      if (!mounted) return;

      setState(() {
        _backgroundColor = null;
        _backgroundPhotoUrl = null;
      });
      widget.group['background_color'] = null;
      widget.group['background_photo_url'] = null;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  Future<void> _setBackgroundTheme(String theme) async {
    final supabase = Supabase.instance.client;
    final previous = _backgroundTheme;

    setState(() {
      _backgroundTheme = theme;
      _saving = true;
    });

    try {
      final result = await supabase
          .from('groups')
          .update({'background_theme': theme})
          .eq('id', widget.group['id'])
          .select();

      if (!mounted) return;

      if (result.isEmpty) {
        setState(() => _backgroundTheme = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Save blocked by database permissions (no rows updated)',
            ),
          ),
        );
        setState(() => _saving = false);
        return;
      }

      widget.group['background_theme'] = theme;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Setting saved')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _backgroundTheme = previous);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<void> _uploadThemePhoto() async {
    final supabase = Supabase.instance.client;
    final picker = ImagePicker();

    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;

    if (!mounted) return;
    final croppedBytes = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (_) => _PhotoCropPage(imageFile: File(image.path), aspectRatio: 9 / 16),
      ),
    );
    if (croppedBytes == null) return;

    setState(() => _uploadingThemePhoto = true);

    try {
      final path =
          'group_theme_backgrounds/${widget.group['id']}/${DateTime.now().millisecondsSinceEpoch}.png';

      await supabase.storage.from('Photos').uploadBinary(
            path,
            croppedBytes,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/png'),
          );

      await supabase.from('groups').update({
        'background_theme': 'photo',
        'theme_photo_url': path,
      }).eq('id', widget.group['id']);

      if (!mounted) return;

      setState(() {
        _backgroundTheme = 'photo';
        _themePhotoUrl = path;
      });
      widget.group['background_theme'] = 'photo';
      widget.group['theme_photo_url'] = path;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Background updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }

    if (!mounted) return;
    setState(() => _uploadingThemePhoto = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Settings'),
      ),
      body: AppBackground(
        group: widget.group,
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Group Name', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _savingName ? null : _saveGroupName,
                              child: Text(_savingName ? 'Saving...' : 'Save Name'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Dashboard Background', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text(
                            'Pick a color or upload a photo for the dashboard header.',
                            style: TextStyle(fontSize: 13, color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: kGroupBackgroundColors.map((hex) {
                              final isSelected = _backgroundColor == hex && _backgroundPhotoUrl == null;
                              return GestureDetector(
                                onTap: () => _setBackgroundColor(hex),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: hexToColor(hex),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFFE10600) : Colors.white24,
                                      width: isSelected ? 3 : 1,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _uploadingBackground ? null : _uploadBackgroundPhoto,
                              icon: const FaIcon(FontAwesomeIcons.images),
                              label: Text(_uploadingBackground ? 'Uploading...' : 'Upload Photo'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: (_backgroundColor == null && _backgroundPhotoUrl == null)
                                  ? null
                                  : _resetBackground,
                              child: const Text('Reset to Default'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('App Background', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text(
                            'Sets the pattern behind every page for the whole group.',
                            style: TextStyle(fontSize: 13, color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Default'),
                                selected: _backgroundTheme == 'default',
                                onSelected: _saving ? null : (_) => _setBackgroundTheme('default'),
                              ),
                              ChoiceChip(
                                label: const Text('Warm'),
                                selected: _backgroundTheme == 'warm',
                                onSelected: _saving ? null : (_) => _setBackgroundTheme('warm'),
                              ),
                              ChoiceChip(
                                label: const Text('Cool'),
                                selected: _backgroundTheme == 'cool',
                                onSelected: _saving ? null : (_) => _setBackgroundTheme('cool'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _uploadingThemePhoto ? null : _uploadThemePhoto,
                              icon: const FaIcon(FontAwesomeIcons.images),
                              label: Text(
                                _uploadingThemePhoto
                                    ? 'Uploading...'
                                    : _backgroundTheme == 'photo'
                                        ? 'Change Photo'
                                        : 'Use a Photo from Gallery',
                              ),
                            ),
                          ),
                          if (_backgroundTheme == 'photo' && _themePhotoUrl != null) ...[
                            const SizedBox(height: 8),
                            const Text(
                              '✓ Custom photo in use',
                              style: TextStyle(fontSize: 12, color: Colors.white54),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: SwitchListTile(
                      title: const Text('Anonymous Judging'),
                      subtitle: const Text(
                        'When on, judges will not see who uploaded each photo.',
                      ),
                      value: _anonymousJudging,
                      onChanged: _saving ? null : _updateAnonymousJudging,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: SwitchListTile(
                      title: const Text('Freeze (Store item)'),
                      subtitle: const Text(
                        'Lets members spend coins to force a rival to skip a day. Off by default.',
                      ),
                      value: _freezeEnabled,
                      onChanged: _saving ? null : _updateFreezeEnabled,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Challenge Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text(
                            'Random days each week get a themed photo challenge (e.g. "something orange") instead of a free choice.',
                            style: TextStyle(fontSize: 13, color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: [0, 1, 2].map((n) {
                              return ChoiceChip(
                                label: Text(n == 0 ? 'Off' : '$n / week'),
                                selected: _challengesPerWeek == n,
                                onSelected: _saving
                                    ? null
                                    : (_) => _updateChallengesPerWeek(n),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.asset('assets/video/splash.mp4');

    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _controller.play();
    }).catchError((_) {
      // Video failed to load/decode — don't strand the user on a black screen.
      _proceed();
    });

    _controller.addListener(() {
      final isFinished = !_controller.value.isPlaying &&
          _controller.value.position >= _controller.value.duration &&
          _controller.value.duration > Duration.zero;

      if (isFinished) _proceed();
    });

    // Safety net: if the video never finishes for any reason (stuck decoder,
    // slow emulator, etc.), don't let the splash hang forever.
    Future.delayed(const Duration(seconds: 6), _proceed);
  }

  Future<void> _proceed() async {
    if (_navigated) return;
    _navigated = true;

    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    final termsAccepted = prefs.getBool('terms_accepted') ?? false;

    if (!mounted) return;

    Widget nextPage;
    if (!onboardingComplete) {
      nextPage = const OnboardingPage();
    } else if (!termsAccepted) {
      nextPage = const OnboardingPage(skipToTerms: true);
    } else {
      nextPage = const AuthGate();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => nextPage),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
body: _controller.value.isInitialized
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
class _ScoreSlider extends StatefulWidget {
  final Future<void> Function(int score) onSubmit;

  const _ScoreSlider({required this.onSubmit});

  @override
  State<_ScoreSlider> createState() => _ScoreSliderState();
}

class _ScoreSliderState extends State<_ScoreSlider> {
  double _value = 5;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(
            _value.round().toString(),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE10600),
            ),
          ),
        ),
        Slider(
          value: _value,
          min: 0,
          max: 10,
          divisions: 10,
          label: _value.round().toString(),
          onChanged: _submitting
              ? null
              : (v) => setState(() => _value = v),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0 = worst',
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5)),
              ),
              Text(
                '10 = best',
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _submitting
              ? null
              : () async {
                  setState(() => _submitting = true);
                  await widget.onSubmit(_value.round());
                },
          child: Text(_submitting ? 'Saving...' : 'Submit Score'),
        ),
      ],
    );
  }
}
const List<String> kRuleIcons = [
  '📸', '⏰', '⚖️', '🚫', '👑', '💬', '🏆', '🔥',
  '🎯', '🪙', '🤳', '🖼️', '🔁', '🎭', '⚠️', '🛡️',
  '📅', '🤝', '❗',
];

class RulesPage extends StatefulWidget {
  final dynamic group;
  final bool isOwner;
  final bool showContinueButton;

  const RulesPage({
    super.key,
    required this.group,
    required this.isOwner,
    this.showContinueButton = false,
  });

  @override
  State<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends State<RulesPage> {
  List<Map<String, String>> _rules = [];
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  // Best-effort icon guess for legacy rule lines that don't have an
  // explicit 'icon::text' marker, so they don't all default to the same icon.
  // Ordered most-specific-first, since a line like "No filters or edited
  // photos" would otherwise always fall through to the generic camera icon
  // just because it mentions "photos" too.
  String _guessIcon(String text) {
    final lower = text.toLowerCase();

    if (lower.contains('filter') || lower.contains('edit') || lower.contains('photoshop')) {
      return '🖼️';
    }
    if (lower.contains('selfie') || lower.contains('face')) {
      return '🤳';
    }
    if (lower.contains('streak')) {
      return '🔥';
    }
    if (lower.contains('challenge') || lower.contains('theme') || lower.contains('prompt')) {
      return '🎯';
    }
    if (lower.contains('coin') ||
        lower.contains('store') ||
        lower.contains('shop') ||
        lower.contains('purchase') ||
        lower.contains('buy')) {
      return '🪙';
    }
    if (lower.contains('anonymous') || lower.contains('secret') || lower.contains('hidden')) {
      return '🎭';
    }
    if (lower.contains('disqualif') || lower.contains('cheat') || lower.contains('fake')) {
      return '🛡️';
    }
    if (lower.contains('warn') || lower.contains('penalty') || lower.contains('strike')) {
      return '⚠️';
    }
    if (lower.contains('resubmit') ||
        lower.contains('retake') ||
        lower.contains('redo') ||
        lower.contains('again')) {
      return '🔁';
    }
    if (lower.contains('respect') ||
        lower.contains('fair') ||
        lower.contains('kind') ||
        lower.contains('sportsmanship')) {
      return '🤝';
    }
    if (lower.contains('daily') ||
        lower.contains('every day') ||
        lower.contains('each day') ||
        lower.contains('schedule')) {
      return '📅';
    }
    if (lower.contains('photo') ||
        lower.contains('camera') ||
        lower.contains('picture') ||
        lower.contains('upload') ||
        lower.contains('submit')) {
      return '📸';
    }
    if (lower.contains('time') ||
        lower.contains('late') ||
        lower.contains('deadline') ||
        lower.contains('midnight') ||
        lower.contains('hour')) {
      return '⏰';
    }
    if (lower.contains('judge') ||
        lower.contains('score') ||
        lower.contains('rating') ||
        lower.contains('point')) {
      return '⚖️';
    }
    if (lower.contains('chat') || lower.contains('message')) {
      return '💬';
    }
    if (lower.contains('win') ||
        lower.contains('leaderboard') ||
        lower.contains('champion') ||
        lower.contains('trophy')) {
      return '🏆';
    }
    if (lower.contains('no ') ||
        lower.contains("not allowed") ||
        lower.contains('banned') ||
        lower.contains('prohibit') ||
        lower.contains("don't") ||
        lower.contains('cannot') ||
        lower.contains("can't")) {
      return '🚫';
    }
    if (lower.contains('owner') || lower.contains('admin')) {
      return '👑';
    }
    return '❗';
  }

  List<Map<String, String>> _parseRules(String raw) {
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
          final separatorIndex = line.indexOf('::');
          if (separatorIndex == -1) {
            return {'icon': _guessIcon(line), 'text': line};
          }
          final icon = line.substring(0, separatorIndex).trim();
          final text = line.substring(separatorIndex + 2).trim();
          return {'icon': icon.isEmpty ? _guessIcon(text) : icon, 'text': text};
        })
        .toList();
  }

  String _serializeRules() {
    return _rules.map((r) => '${r['icon']}::${r['text']}').join('\n');
  }

  Future<void> _loadRules() async {
    final supabase = Supabase.instance.client;

    try {
      final group = await supabase
          .from('groups')
          .select()
          .eq('id', widget.group['id'])
          .single();

      if (!mounted) return;

      setState(() {
        _rules = _parseRules(group['rules'] ?? '');
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  Future<void> _saveRules() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    setState(() => _saving = true);

    try {
      final result = await supabase
          .from('groups')
          .update({'rules': _serializeRules()})
          .eq('id', widget.group['id'])
          .select();

      if (!mounted) return;

      if (result.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Save blocked by database permissions'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rules saved')),
        );
        setState(() => _editing = false);

        if (user != null) {
          final profile = await supabase
              .from('users')
              .select()
              .eq('id', user.id)
              .single();

          await sendNotification(
            type: 'rules',
            groupId: widget.group['id'],
            senderId: user.id,
            senderName: profile['username'] ?? 'The owner',
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<void> _showRuleDialog({int? editIndex}) async {
    final isNew = editIndex == null;
    String selectedIcon = isNew ? kRuleIcons.first : _rules[editIndex]['icon']!;
    final textController = TextEditingController(
      text: isNew ? '' : _rules[editIndex]['text'],
    );

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isNew ? 'Add Rule' : 'Edit Rule'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kRuleIcons.map((icon) {
                  final selected = icon == selectedIcon;
                  return ChoiceChip(
                    label: Text(icon, style: const TextStyle(fontSize: 18)),
                    selected: selected,
                    onSelected: (_) => setDialogState(() => selectedIcon = icon),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: 'Rule text...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (textController.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, {
                  'icon': selectedIcon,
                  'text': textController.text.trim(),
                });
              },
              child: Text(isNew ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      if (isNew) {
        _rules.add(result);
      } else {
        _rules[editIndex] = result;
      }
    });
  }

  void _deleteRule(int index) {
    setState(() => _rules.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rules'),
        actions: [
          if (widget.isOwner && !_loading)
            IconButton(
              icon: FaIcon(_editing ? FontAwesomeIcons.xmark : FontAwesomeIcons.pencil),
              onPressed: _saving
                  ? null
                  : () => setState(() => _editing = !_editing),
            ),
        ],
      ),
      body: AppBackground(
        group: widget.group,
        child: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rules.isEmpty && !_editing
                    ? const Center(child: Text('No rules have been added yet.'))
                    : ListView(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
                        children: [
                          for (var i = 0; i < _rules.length; i++)
                            Card(
                              child: ListTile(
                                leading: Text(
                                  _rules[i]['icon']!,
                                  style: const TextStyle(fontSize: 22),
                                ),
                                title: Text(_rules[i]['text']!),
                                onTap: _editing ? () => _showRuleDialog(editIndex: i) : null,
                                trailing: _editing
                                    ? IconButton(
                                        icon: const FaIcon(FontAwesomeIcons.xmark, color: Colors.redAccent),
                                        onPressed: () => _deleteRule(i),
                                      )
                                    : null,
                              ),
                            ),
                          if (_editing) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => _showRuleDialog(),
                              icon: const FaIcon(FontAwesomeIcons.plus),
                              label: const Text('Add Rule'),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _saving ? null : _saveRules,
                              child: Text(_saving ? 'Saving...' : 'Save Rules'),
                            ),
                          ],
                        ],
                      ),
          ),
          if (widget.showContinueButton && !_editing && !_loading)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Got it'),
                  ),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}
class ChatPage extends StatefulWidget {
  final dynamic group;

  const ChatPage({super.key, required this.group});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _messages = [];
  Map<String, String> _usernames = {};
  bool _loading = true;
  late final Stream<List<Map<String, dynamic>>> _messageStream;

 @override
  void initState() {
    super.initState();
    _loadUsernames();
    _markChatAsRead();

    _messageStream = supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('group_id', widget.group['id'])
        .order('created_at');

 _messageStream.listen((data) {
      if (!mounted) return;
      final sorted = [...data]
        ..sort((a, b) => (a['created_at'] as String)
            .compareTo(b['created_at'] as String));
      setState(() {
        _messages = sorted;
        _loading = false;
      });
      _scrollToBottom();
    });
  }

  Future<void> _loadUsernames() async {
    final members = await supabase
        .from('group_members')
        .select()
        .eq('group_id', widget.group['id']);

    final userIds = members.map((m) => m['user_id']).toList();

    final users = await supabase
        .from('users')
        .select()
        .inFilter('id', userIds);

    if (!mounted) return;
    setState(() {
      _usernames = {
        for (final u in users) u['id'] as String: (u['username'] ?? 'Unknown') as String,
      };
    });
  }
  Future<void> _markChatAsRead() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase
        .from('group_members')
        .update({'last_chat_read_at': DateTime.now().toIso8601String()})
        .eq('group_id', widget.group['id'])
        .eq('user_id', user.id);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }
final Map<String, Future<String>> _signedUrlCache = {};

  String _formatMessageTime(String? createdAt) {
       if (createdAt == null) return '';
       final dt = DateTime.tryParse(createdAt)?.toLocal();
       if (dt == null) return '';
       final now = DateTime.now();
       final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
       final hour = dt.hour.toString().padLeft(2, '0');
       final minute = dt.minute.toString().padLeft(2, '0');
       final time = '$hour:$minute';
       if (isToday) {
         return time;
       }
       final day = dt.day.toString().padLeft(2, '0');
       final month = dt.month.toString().padLeft(2, '0');
       return '$day/$month $time';
     }
  Future<String> _getSignedUrl(String path) {
    return _signedUrlCache.putIfAbsent(
      path,
      () => supabase.storage.from('Photos').createSignedUrl(path, 60 * 60),
    );
  }

  bool _uploadingPhoto = false;

  Future<void> _pickAndSendImage(ImageSource source) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    if (_uploadingPhoto) return;

    setState(() => _uploadingPhoto = true);

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: source, imageQuality: 85);
      if (image == null) return;

      final file = File(image.path);
      final filePath =
          'chat/${widget.group['id']}/${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      await supabase.storage.from('Photos').upload(filePath, file);

      await supabase.from('messages').insert({
        'group_id': widget.group['id'],
        'user_id': user.id,
        'content': '',
        'image_url': filePath,
      });
   } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }

    if (!mounted) return;
    setState(() => _uploadingPhoto = false);
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.camera),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.images),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    _messageController.clear();

 try {
      await supabase.from('messages').insert({
        'group_id': widget.group['id'],
        'user_id': user.id,
        'content': text,
      });

      final userProfile = await supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .single();

      await sendNotification(
        type: 'chat',
        groupId: widget.group['id'],
        senderId: user.id,
        senderName: userProfile['username'] ?? 'Someone',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = supabase.auth.currentUser?.id;

   return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Group Chat'),
      ),
      body: AppBackground(
        group: widget.group,
        child: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const _EmptyState(
                        icon: FontAwesomeIcons.commentDots,
                        title: 'No messages yet',
                        subtitle: 'Say hi to start the conversation!',
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg['user_id'] == myId;
                          final username = _usernames[msg['user_id']] ?? 'Unknown';

                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? const Color(0xFFE10600)
                                    : kSurfaceColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                           child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMe)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Text(
                                        username,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Color(0xFFE10600),
                                        ),
                                      ),
                                    ),
                                  if (msg['image_url'] != null)
                                    FutureBuilder<String>(
                                      future: _getSignedUrl(msg['image_url']),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData) {
                                          return const Padding(
                                            padding: EdgeInsets.all(12),
                                            child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          );
                                        }
                                        return ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: CachedNetworkImage(
                                            imageUrl: snapshot.data!,
                                            width: 200,
                                            fit: BoxFit.cover,
                                          ),
                                        );
                                      },
                                    ),
                                  if ((msg['content'] ?? '').isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        msg['content'],
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      _formatMessageTime(msg['created_at']),
                                      style: TextStyle(
                                        color: isMe
                                            ? Colors.white.withOpacity(0.75)
                                            : Colors.white.withOpacity(0.5),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
         IconButton(
                    onPressed: _showAttachmentOptions,
                    icon: const FaIcon(FontAwesomeIcons.cameraRetro),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sendMessage,
                    icon: const FaIcon(FontAwesomeIcons.paperPlane, color: Color(0xFFE10600)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
      bottomNavigationBar: buildGroupBottomNav(context, widget.group, 2),
    );
  }
}class NotificationSettingsPage extends StatefulWidget {
  final dynamic group;

  const NotificationSettingsPage({super.key, required this.group});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _notifyChat = true;
  bool _notifyUploads = true;
  bool _notifyJudgeReminder = true;
  bool _notifyRules = true;
  bool _notifySubmissionReminder = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final membership = await supabase
          .from('group_members')
          .select()
          .eq('group_id', widget.group['id'])
          .eq('user_id', user.id)
          .single();

      if (!mounted) return;

      setState(() {
        _notifyChat = membership['notify_chat'] ?? true;
        _notifyUploads = membership['notify_uploads'] ?? true;
        _notifyJudgeReminder = membership['notify_judge_reminder'] ?? true;
        _notifyRules = membership['notify_rules'] ?? true;
        _notifySubmissionReminder = membership['notify_submission_reminder'] ?? true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _update(String column, bool value) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      if (column == 'notify_chat') _notifyChat = value;
      if (column == 'notify_uploads') _notifyUploads = value;
      if (column == 'notify_judge_reminder') _notifyJudgeReminder = value;
      if (column == 'notify_rules') _notifyRules = value;
      if (column == 'notify_submission_reminder') _notifySubmissionReminder = value;
      _saving = true;
    });

    try {
      final result = await supabase
          .from('group_members')
          .update({column: value})
          .eq('group_id', widget.group['id'])
          .eq('user_id', user.id)
          .select();

      if (!mounted) return;

      if (result.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save blocked by database permissions')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: AppBackground(
        group: widget.group,
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Card(
                    child: SwitchListTile(
                      title: const Text('Chat Messages'),
                      subtitle: const Text('Alert me about new chat messages'),
                      value: _notifyChat,
                      onChanged: _saving
                          ? null
                          : (v) => _update('notify_chat', v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: SwitchListTile(
                      title: const Text('Photo Uploads'),
                      subtitle: const Text('Alert me when a player uploads a photo'),
                      value: _notifyUploads,
                      onChanged: _saving
                          ? null
                          : (v) => _update('notify_uploads', v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: SwitchListTile(
                      title: const Text('Judge Reminders'),
                      subtitle: const Text('Remind me to score waiting photos'),
                      value: _notifyJudgeReminder,
                      onChanged: _saving
                          ? null
                          : (v) => _update('notify_judge_reminder', v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: SwitchListTile(
                      title: const Text('Rules Updates'),
                      subtitle: const Text('Alert me when the owner changes the rules'),
                      value: _notifyRules,
                      onChanged: _saving
                          ? null
                          : (v) => _update('notify_rules', v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: SwitchListTile(
                      title: const Text('Submission Reminders'),
                      subtitle: const Text('Remind me if I haven\'t submitted today\'s photo'),
                      value: _notifySubmissionReminder,
                      onChanged: _saving
                          ? null
                          : (v) => _update('notify_submission_reminder', v),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}
class ManageMembersPage extends StatefulWidget {
  final dynamic group;

  const ManageMembersPage({super.key, required this.group});

  @override
  State<ManageMembersPage> createState() => _ManageMembersPageState();
}

class _ManageMembersPageState extends State<ManageMembersPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);

    final members = await supabase
        .from('group_members')
        .select()
        .eq('group_id', widget.group['id']);

    final userIds = members.map((m) => m['user_id']).toList();

    final users = await supabase
        .from('users')
        .select()
        .inFilter('id', userIds);

    final combined = members.map<Map<String, dynamic>>((m) {
      final user = users.firstWhere(
        (u) => u['id'] == m['user_id'],
        orElse: () => {'username': 'Unknown'},
      );
      return {
        'id': m['id'],
        'user_id': m['user_id'],
        'username': user['username'],
        'role': m['role'],
        'warnings': m['warnings'] ?? 0,
        'owner_is_judge': m['owner_is_judge'] ?? false,
        'judge_also_plays': m['judge_also_plays'] ?? false,
      };
    }).toList();

    if (!mounted) return;
    setState(() {
      _members = combined;
      _loading = false;
    });
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
          'Remove ${member['username']} from this group? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final result = await supabase
          .from('group_members')
          .delete()
          .eq('id', member['id'])
          .select();

      if (!mounted) return;

      if (result.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Remove blocked by database permissions')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member['username']} removed')),
        );
        _loadMembers();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }
Future<void> _issueWarning(Map<String, dynamic> member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Issue Warning'),
        content: Text(
          'Give ${member['username']} a warning? They currently have ${member['warnings']} warning(s).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Issue Warning'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final newCount = (member['warnings'] as int) + 1;

      final result = await supabase
          .from('group_members')
          .update({'warnings': newCount})
          .eq('id', member['id'])
          .select();

      if (!mounted) return;

      if (result.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save blocked by database permissions')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member['username']} now has $newCount warning(s)')),
        );
        _loadMembers();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }
  Future<void> _changeRole(Map<String, dynamic> member, String newRole) async {
    if (member['role'] == newRole) return;

    try {
      final result = await supabase
          .from('group_members')
          .update({'role': newRole})
          .eq('id', member['id'])
          .select();

      if (!mounted) return;

      if (result.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Role change blocked by database permissions')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member['username']} is now a $newRole')),
        );
        _loadMembers();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  Future<void> _toggleOwnerIsJudge(Map<String, dynamic> member, bool newValue) async {
    try {
      final result = await supabase
          .from('group_members')
          .update({'owner_is_judge': newValue})
          .eq('id', member['id'])
          .select();

      if (!mounted) return;

      if (result.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Change blocked by database permissions')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newValue ? 'You are now judging' : 'You are now playing')),
        );
        _loadMembers();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  Future<void> _toggleJudgeAlsoPlays(Map<String, dynamic> member, bool newValue) async {
    try {
      final result = await supabase
          .from('group_members')
          .update({'judge_also_plays': newValue})
          .eq('id', member['id'])
          .select();

      if (!mounted) return;

      if (result.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Change blocked by database permissions')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newValue
                  ? '${member['username']} can now also play'
                  : '${member['username']} is judge-only again',
            ),
          ),
        );
        _loadMembers();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  Future<void> _transferOwnership(Map<String, dynamic> newOwner) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transfer Ownership'),
        content: Text(
          'Make ${newOwner['username']} the new owner? You will become a regular '
          'player and lose access to group settings and member management.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final currentOwner = _members.firstWhere(
      (m) => m['role'] == 'owner',
      orElse: () => <String, dynamic>{},
    );

    if (currentOwner.isEmpty) return;

    try {
      await supabase.from('group_members').update({
        'role': 'owner',
        'owner_is_judge': false,
        'judge_also_plays': false,
      }).eq('id', newOwner['id']);

      await supabase.from('group_members').update({
        'role': 'player',
        'owner_is_judge': false,
        'judge_also_plays': false,
      }).eq('id', currentOwner['id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${newOwner['username']} is now the owner')),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  Widget _rolesExplainer() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: Colors.white.withOpacity(0.04),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FaIcon(FontAwesomeIcons.circleInfo, size: 14, color: Colors.white.withOpacity(0.6)),
                  const SizedBox(width: 8),
                  Text(
                    'Roles',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '📸 Player — submits a photo daily\n'
                '⚖️ Judge — scores photos, doesn\'t play\n'
                '🎮 Judge who also plays — does both\n\n'
                'Tap ⋮ on any member to change their role.',
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6), height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _memberCard(Map<String, dynamic> member) {
    final isOwnerRow = member['role'] == 'owner';
    final isJudge = member['role'] == 'judge';
    final warnings = member['warnings'] as int;
    final judgeAlsoPlays = member['judge_also_plays'] == true;

    return Card(
      child: ListTile(
        leading: roleIcon(member['role'], size: 24, color: Colors.white70),
        title: Text(member['username'] ?? 'Unknown'),
        subtitle: Text(
          isOwnerRow
              ? 'owner • '
                  '${member['owner_is_judge'] == true ? 'judging' : 'playing'}'
                  '${member['owner_is_judge'] == true && judgeAlsoPlays ? ' • also plays' : ''}'
              : (isJudge
                  ? '${member['role']}'
                      '${judgeAlsoPlays ? ' • also plays' : ''}'
                      '${warnings > 0 ? ' • ⚠️ $warnings warning(s)' : ''}'
                  : member['role']),
        ),
        trailing: isOwnerRow
            ? PopupMenuButton<String>(
                icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, color: Colors.white70),
                onSelected: (value) {
                  if (value == 'toggle_judging') {
                    _toggleOwnerIsJudge(member, member['owner_is_judge'] != true);
                  } else if (value == 'toggle_hybrid') {
                    _toggleJudgeAlsoPlays(member, !judgeAlsoPlays);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'toggle_judging',
                    child: Text(member['owner_is_judge'] == true ? 'Stop Judging' : 'Start Judging'),
                  ),
                  if (member['owner_is_judge'] == true)
                    PopupMenuItem(
                      value: 'toggle_hybrid',
                      child: Text(judgeAlsoPlays ? 'Judge only (stop playing)' : 'Also let me play'),
                    ),
                ],
              )
            : PopupMenuButton<String>(
                icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, color: Colors.white70),
                onSelected: (value) {
                  if (value == 'transfer') {
                    _transferOwnership(member);
                  } else if (value == 'make_judge') {
                    _changeRole(member, 'judge');
                  } else if (value == 'make_player') {
                    _changeRole(member, 'player');
                  } else if (value == 'toggle_hybrid') {
                    _toggleJudgeAlsoPlays(member, !judgeAlsoPlays);
                  } else if (value == 'warn') {
                    _issueWarning(member);
                  } else if (value == 'remove') {
                    _removeMember(member);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'transfer', child: Text('Make Owner')),
                  if (isJudge)
                    const PopupMenuItem(value: 'make_player', child: Text('Make Player'))
                  else
                    const PopupMenuItem(value: 'make_judge', child: Text('Make Judge')),
                  if (isJudge)
                    PopupMenuItem(
                      value: 'toggle_hybrid',
                      child: Text(judgeAlsoPlays ? 'Judge only (stop playing)' : 'Let them also play'),
                    ),
                  if (isJudge)
                    const PopupMenuItem(value: 'warn', child: Text('Issue Warning')),
                  const PopupMenuItem(value: 'remove', child: Text('Remove from Group')),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Members')),
      body: AppBackground(
        group: widget.group,
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
              children: [
                _rolesExplainer(),
                ..._members.map(_memberCard),
              ],
            ),
      ),
    );
  }
}
class FullScreenPhotoPage extends StatelessWidget {
  final String imageUrl;
  final String? username;

  const FullScreenPhotoPage({
    super.key,
    required this.imageUrl,
    this.username,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(username ?? 'Photo'),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: imageUrl,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      ),
    );
  }
}
class _EmptyState extends StatelessWidget {
  final FaIconData icon;
  final String title;
  final String? subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.9 + (0.1 * t), child: child),
        ),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(
                icon,
                size: 64,
                color: Colors.white.withOpacity(0.15),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
class _MemberAvatar extends StatelessWidget {
  final String username;
  final Color color;
  final double size;

  const _MemberAvatar({
    required this.username,
    required this.color,
    this.size = 36,
  });

  String get _initials {
    final parts = username.trim().split(RegExp(r'[\s@._]+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return username.isNotEmpty ? username[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.25),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.38,
          ),
        ),
      ),
    );
  }
}
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  final _usernameController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _showPassword = false;
  bool _soundEffectsEnabled = true;
  String? _profilePhotoUrl;
  String? _profilePhotoPath;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadSoundPreference();
  }

  Future<void> _loadSoundPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _soundEffectsEnabled = prefs.getBool('sound_effects_enabled') ?? true);
  }

  Future<void> _loadProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .single();

      if (!mounted) return;

      _usernameController.text =
          profile['display_name'] ?? profile['username'] ?? '';
      _profilePhotoPath = profile['profile_photo'];

      if (_profilePhotoPath != null) {
        final url = await supabase.storage
            .from('Photos')
            .createSignedUrl(_profilePhotoPath!, 60 * 60);
        if (!mounted) return;
        setState(() => _profilePhotoUrl = url);
      }

      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final picker = ImagePicker();
      final image = await showModalBottomSheet<XFile?>(
        context: context,
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.camera),
                title: const Text('Take Photo'),
                onTap: () async {
                  final img = await picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 85,
                  );
                  if (context.mounted) Navigator.pop(context, img);
                },
              ),
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.images),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  final img = await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                  );
                  if (context.mounted) Navigator.pop(context, img);
                },
              ),
            ],
          ),
        ),
      );

      if (image == null) return;

      final file = File(image.path);
      final filePath =
          'profiles/${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      await supabase.storage.from('Photos').upload(filePath, file);

      final url = await supabase.storage
          .from('Photos')
          .createSignedUrl(filePath, 60 * 60);

      await supabase
          .from('users')
          .update({'profile_photo': filePath})
          .eq('id', user.id);

      if (!mounted) return;
      setState(() {
        _profilePhotoPath = filePath;
        _profilePhotoUrl = url;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }
Future<void> _showDeleteConfirmation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account, all your photos, messages, and scores. This cannot be undone.\n\nAre you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.rpc('delete_user_account');

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your account has been deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }
  Future<void> _saveProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final newUsername = _usernameController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    if (newUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username cannot be empty.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await supabase
          .from('users')
          .update({'display_name': newUsername, 'username': newUsername})
          .eq('id', user.id);

      if (newPassword.isNotEmpty) {
        if (newPassword.length < 6) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Password must be at least 6 characters.')),
          );
          setState(() => _saving = false);
          return;
        }
        await supabase.auth.updateUser(
          UserAttributes(password: newPassword),
        );
        _newPasswordController.clear();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: AppBackground(
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 54,
                          backgroundColor:
                              const Color(0xFFE10600).withOpacity(0.2),
                          backgroundImage: _profilePhotoUrl != null
                              ? NetworkImage(_profilePhotoUrl!)
                              : null,
                          child: _profilePhotoUrl == null
                              ? Text(
                                  _usernameController.text.isNotEmpty
                                      ? _usernameController.text[0]
                                          .toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFE10600),
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE10600),
                              shape: BoxShape.circle,
                            ),
                            child: const FaIcon(
                              FontAwesomeIcons.camera,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    supabase.auth.currentUser?.email ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FutureBuilder<Map<String, int>>(
                    future: supabase.auth.currentUser == null
                        ? null
                        : fetchUserAchievements(supabase.auth.currentUser!.id),
                    builder: (context, snapshot) {
                      final stats = snapshot.data;
                      if (stats == null) return const SizedBox.shrink();

                      checkAchievementMilestones(context, stats);

                      Widget stat(String emoji, int value, String label) {
                        return Column(
                          children: [
                            Text(emoji, style: const TextStyle(fontSize: 22)),
                            const SizedBox(height: 4),
                            _AnimatedCount(
                              value: value,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              label,
                              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                stat('🔥', stats['longestStreak'] ?? 0, 'Longest\nStreak'),
                                stat('🏆', stats['totalWins'] ?? 0, 'Total\nWins'),
                                stat('🚫', stats['totalDisqualifications'] ?? 0, 'Disqualifi-\ncations'),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Card(
                    child: SwitchListTile(
                      title: const Text('Sound Effects'),
                      subtitle: const Text('Play a sound for wins, scores, and achievements.'),
                      value: _soundEffectsEnabled,
                      onChanged: (value) async {
                        setState(() => _soundEffectsEnabled = value);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('sound_effects_enabled', value);
                        if (value) playFeedbackSound();
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Username',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              hintText: 'Enter your username',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'New Password',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Leave blank to keep your current password',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _newPasswordController,
                            obscureText: !_showPassword,
                            decoration: InputDecoration(
                              hintText: 'New password',
                              suffixIcon: IconButton(
                                icon: FaIcon(_showPassword
                                    ? FontAwesomeIcons.eyeSlash
                                    : FontAwesomeIcons.eye),
                                onPressed: () => setState(
                                    () => _showPassword = !_showPassword),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveProfile,
                      child:
                          Text(_saving ? 'Saving...' : 'Save Changes'),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _showDeleteConfirmation,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Delete Account'),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}
class OnboardingPage extends StatefulWidget {
  final bool skipToTerms;

  const OnboardingPage({super.key, this.skipToTerms = false});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final PageController _pageController;
  int _currentPage = 0;
  bool _termsAccepted = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.skipToTerms ? _pages.length : 0;
    _pageController = PageController(initialPage: _currentPage);
  }

  static const String _privacyPolicyUrl =
      'https://sugared-hellebore-0ba.notion.site/398f6483ef768004b84ffe0c2897d139';
  static const String _termsOfServiceUrl =
      'https://sugared-hellebore-0ba.notion.site/Terms-of-Service-for-My-Nemesis-398f6483ef7680568620f5575e03a89f';

  Future<void> _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open browser. Please try again.')),
      );
    }
  }

  final List<Map<String, dynamic>> _pages = [
    {
      'icon': FontAwesomeIcons.handFist,
      'title': 'My Nemesis',
      'subtitle': 'The daily photo battle game',
      'description':
          'Challenge your nemesis to a daily photo battle. One photo. One judge. One winner.',
      'color': Color(0xFFE10600),
    },
    {
      'icon': FontAwesomeIcons.camera,
      'title': 'How it works',
      'subtitle': 'Simple. Brutal. Fun.',
      'description':
          '📸  Submit one random photo per day\n\n⚖️  A judge scores both photos 0–10\n\n🏆  The highest score wins the day\n\n⚡  Tie? First to submit wins',
      'color': Colors.white,
    },
    {
      'icon': FontAwesomeIcons.trophy,
      'title': 'Ready to battle?',
      'subtitle': 'Create a group and invite your nemesis',
      'description':
          'Everyone in a group has a role:\n\n📸  Players submit a photo\n\n⚖️  Judges score photos, but don\'t play\n\n🎮  A judge can also play if you want\n\nYou pick each person\'s role when you invite them.',
      'color': Color(0xFFE10600),
    },
  ];

  Future<void> _finish() async {
    if (!_termsAccepted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    await prefs.setBool('terms_accepted', true);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => _pageController.jumpToPage(_pages.length),
                child: const Text('Skip'),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) =>
                    setState(() => _currentPage = index),
                itemCount: _pages.length + 1,
                itemBuilder: (context, index) {
                  if (index == _pages.length) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.1),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const FaIcon(FontAwesomeIcons.fileLines, size: 56, color: Colors.white),
                          ),
                          const SizedBox(height: 40),
                          const Text(
                            'Just one more thing',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Please review and accept our policies to continue.',
                            style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.7)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          InkWell(
                            onTap: () => setState(() => _termsAccepted = !_termsAccepted),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _termsAccepted,
                                  onChanged: (value) =>
                                      setState(() => _termsAccepted = value ?? false),
                                ),
                                Expanded(
                                  child: Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      const Text('I agree to the ', style: TextStyle(color: Colors.white)),
                                      GestureDetector(
                                        onTap: () => _openUrl(_termsOfServiceUrl),
                                        child: const Text(
                                          'Terms of Service',
                                          style: TextStyle(
                                            color: Color(0xFFE10600),
                                            fontWeight: FontWeight.bold,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                      const Text(' and ', style: TextStyle(color: Colors.white)),
                                      GestureDetector(
                                        onTap: () => _openUrl(_privacyPolicyUrl),
                                        child: const Text(
                                          'Privacy Policy',
                                          style: TextStyle(
                                            color: Color(0xFFE10600),
                                            fontWeight: FontWeight.bold,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (page['color'] as Color).withOpacity(0.15),
                            border: Border.all(
                              color: page['color'] as Color,
                              width: 2,
                            ),
                          ),
                          child: FaIcon(
                            page['icon'] as FaIconData,
                            size: 56,
                            color: page['color'] as Color,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          page['title'] as String,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page['subtitle'] as String,
                          style: TextStyle(
                            fontSize: 16,
                            color: page['color'] as Color,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          page['description'] as String,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.7),
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length + 1,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _currentPage == index
                        ? const Color(0xFFE10600)
                        : Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _currentPage == _pages.length && !_termsAccepted
                      ? null
                      : () {
                          if (_currentPage < _pages.length) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            _finish();
                          }
                        },
                  child: Text(
                    _currentPage < _pages.length ? 'Next' : 'Get Started',
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nicknameController = TextEditingController();
  DateTime? _birthday;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;

  // Password rule checkers
  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _hasUppercase => _passwordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasNumber => _passwordController.text.contains(RegExp(r'[0-9]'));
  bool get _hasSymbol =>
      _passwordController.text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
  bool get _passwordsMatch =>
      _passwordController.text == _confirmPasswordController.text &&
      _confirmPasswordController.text.isNotEmpty;

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Select your birthday',
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final nickname = _nicknameController.text.trim();

    if (email.isEmpty) {
      _showError('Please enter your email.');
      return;
    }
    if (nickname.isEmpty) {
      _showError('Please enter a nickname.');
      return;
    }
    if (!_hasMinLength || !_hasUppercase || !_hasNumber || !_hasSymbol) {
      _showError('Password does not meet all requirements.');
      return;
    }
    if (!_passwordsMatch) {
      _showError('Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        await Supabase.instance.client.from('users').upsert({
          'id': response.user!.id,
          'username': nickname,
          'display_name': nickname,
          if (_birthday != null) 'birthday': _birthday!.toIso8601String().split('T').first,
        });
      }

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Account Created! 🎉'),
          content: const Text(
            'We sent a confirmation email to your inbox. Please confirm your email before logging in.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // Go back to login
              },
              child: const Text('Go to Login'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().toLowerCase();
      if (message.contains('already registered') ||
          message.contains('already exists')) {
        _showError('An account with this email already exists.');
      } else if (message.contains('rate limit')) {
        _showError('Too many signup attempts. Please wait a few minutes and try again.');
      } else {
        _showError('Something went wrong. Please try again.');
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _ruleRow(bool passed, String text) {
    return Row(
      children: [
        FaIcon(
          passed ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.circleXmark,
          size: 16,
          color: passed ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: passed ? Colors.green : Colors.grey,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Join My Nemesis',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Set up your account to start battling',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Nickname
            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: 'Nickname',
                hintText: 'What should people call you?',
                prefixIcon: FaIcon(FontAwesomeIcons.user),
              ),
            ),
            const SizedBox(height: 16),

            // Email
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: FaIcon(FontAwesomeIcons.envelope),
              ),
            ),
            const SizedBox(height: 16),

            // Password
            TextField(
              controller: _passwordController,
              obscureText: !_showPassword,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const FaIcon(FontAwesomeIcons.lock),
                suffixIcon: IconButton(
                  icon: FaIcon(_showPassword
                      ? FontAwesomeIcons.eyeSlash
                      : FontAwesomeIcons.eye),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Password rules
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Password must have:',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    _ruleRow(_hasMinLength, 'At least 8 characters'),
                    _ruleRow(_hasUppercase, 'One uppercase letter'),
                    _ruleRow(_hasNumber, 'One number'),
                    _ruleRow(_hasSymbol, 'One symbol (!@#\$%^&*)'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Confirm password
            TextField(
              controller: _confirmPasswordController,
              obscureText: !_showConfirmPassword,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const FaIcon(FontAwesomeIcons.lockOpen),
                suffixIcon: IconButton(
                  icon: FaIcon(_showConfirmPassword
                      ? FontAwesomeIcons.eyeSlash
                      : FontAwesomeIcons.eye),
                  onPressed: () => setState(
                      () => _showConfirmPassword = !_showConfirmPassword),
                ),
                errorText: _confirmPasswordController.text.isNotEmpty &&
                        !_passwordsMatch
                    ? 'Passwords do not match'
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            // Birthday
            GestureDetector(
              onTap: _pickBirthday,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Colors.white.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.cakeCandles, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      _birthday == null
                          ? 'Select your birthday (optional)'
                          : '${_birthday!.day}/${_birthday!.month}/${_birthday!.year}',
                      style: TextStyle(
                        color: _birthday == null
                            ? Colors.white.withOpacity(0.5)
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Sign up button
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed: _signUp,
                child: const Text('Create Account'),
              ),
          ],
        ),
      ),
    );
  }
}