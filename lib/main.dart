import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';

const supabaseUrl = 'https://pwlidahqnfczjgqikzzy.supabase.co';
const supabaseAnonKey = 'sb_publishable_xDxJd7g0SvwMtQ9L-1BATQ__ql0v8Ay';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      theme: ThemeData(
        brightness: Brightness.dark,
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        cardColor: const Color(0xFF1A1A1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE10600),
          secondary: Colors.white,
          surface: Color(0xFF1A1A1A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0A0A),
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
          color: const Color(0xFF1A1A1A),
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

  late VideoPlayerController _logoController;

  @override
  void initState() {
    super.initState();

    _logoController = VideoPlayerController.asset('assets/video/splash.mp4');

    _logoController.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _logoController.play();
    });

    _logoController.addListener(() {
      final isFinished = !_logoController.value.isPlaying &&
          _logoController.value.position >= _logoController.value.duration &&
          _logoController.value.duration > Duration.zero;

      if (isFinished) {
        // Freeze on the final frame instead of looping or restarting.
        _logoController.pause();
        _logoController.seekTo(_logoController.value.duration);
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  Future<void> signUp() async {
    setState(() => isLoading = true);

    try {
      await Supabase.instance.client.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created. Try logging in.')),
      );
    } catch (e) {
      showError(e.toString());
    }

    setState(() => isLoading = false);
  }

  Future<void> login() async {
    setState(() => isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ListView(
            shrinkWrap: true,
            children: [
_logoController.value.isInitialized
                  ? SizedBox(
                      height: 280,
                      width: 280 * _logoController.value.aspectRatio,
                      child: VideoPlayer(_logoController),
                    )
                  : const SizedBox(height: 280),
              const SizedBox(height: 40),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 24),
              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                ElevatedButton(
                  onPressed: login,
                  child: const Text('Login'),
                ),
                TextButton(
                  onPressed: signUp,
                  child: const Text('Create Account'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;

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

  @override
  Widget build(BuildContext context) {
    final email = supabase.auth.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Nemesis'),
        actions: [
          IconButton(
            onPressed: () async {
              await logout();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Logged in as: $email'),
            const SizedBox(height: 30),
            const Text(
              'My Groups',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: fetchGroups(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  final groups = snapshot.data ?? [];

                  if (groups.isEmpty) {
                    return const Center(
                      child: Text('No groups yet. Create your first group.'),
                    );
                  }

                  return ListView.builder(
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];

                    return Card(
  child: ListTile(
    title: Text(group['name'] ?? 'Unnamed Group'),
    subtitle: const Text('You are the owner'),
    trailing: const Icon(Icons.arrow_forward_ios),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupDashboardPage(group: group),
        ),
      );
    },
  ),
);
                    },
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final created = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateGroupPage(),
                    ),
                  );

                  if (created == true) {
                    setState(() {});
                  }
                },
                child: const Text('Create Group'),
              ),
            ),
            const SizedBox(height: 12),

SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: () async {
  final joined = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const JoinGroupPage(),
    ),
  );

  if (joined == true) {
    setState(() {});
  }
},
    child: const Text('Join Group'),
  ),
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
      await supabase.from('users').upsert({
        'id': user.id,
        'username': user.email,
      });

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
      body: Padding(
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
                hintText: 'Example: Omri vs David',
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

  @override
  void initState() {
    super.initState();
    _loadMyRole();
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
    setState(() => _myRole = membership?['role']);
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

    return members.map<Map<String, dynamic>>((member) {
      final user = users.firstWhere(
        (u) => u['id'] == member['user_id'],
        orElse: () => {'username': 'Unknown'},
      );

      return {
        'username': user['username'],
        'role': member['role'],
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchBattleStatus() async {
    final supabase = Supabase.instance.client;

    final members = await supabase
        .from('group_members')
        .select()
        .eq('group_id', widget.group['id']);

    final battleMembers = members
        .where((m) => m['role'] == 'owner' || m['role'] == 'player')
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

    return battleMembers.map<Map<String, dynamic>>((member) {
      final user = users.firstWhere(
        (u) => u['id'] == member['user_id'],
        orElse: () => {'username': 'Unknown'},
      );

      final hasSubmitted = submissions.any(
        (submission) => submission['user_id'] == member['user_id'],
      );

      return {
        'username': user['username'],
        'role': member['role'],
        'hasSubmitted': hasSubmitted,
      };
    }).toList();
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
    if (membership['role'] != 'judge') return 0;
    if (membership['notify_judge_reminder'] == false) return 0;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final submissions = await supabase
        .from('submissions')
        .select()
        .eq('group_id', widget.group['id'])
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
Future<int> _unreadChatCount() async {
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
    if (membership['notify_chat'] == false) return 0;

    final lastRead = membership['last_chat_read_at'];

    var query = supabase
        .from('messages')
        .select()
        .eq('group_id', widget.group['id']);

    if (lastRead != null) {
      query = query.gt('created_at', lastRead);
    }

    final unread = await query;
    return unread.length;
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
        title: Text(role == 'judge' ? 'Judge Invite Code' : 'Invite Code'),
        content: Text(inviteCode),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupName = widget.group['name'] ?? 'Unnamed Group';
    final isOwner = _myRole == 'owner';
    final canUpload = _myRole == 'owner' || _myRole == 'player';
    final canJudge = _myRole == 'judge';

    return Scaffold(
      appBar: AppBar(
        title: Text(groupName),
       actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'player_invite') {
                _generateInvite('player');
              } else if (value == 'judge_invite') {
                _generateInvite('judge');
              } else if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsPage(group: widget.group),
                  ),
                );
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
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'rules',
                child: Text('Rules'),
              ),
              const PopupMenuItem(
                value: 'notifications',
                child: Text('Notifications'),
              ),
              if (isOwner) ...[
                const PopupMenuItem(
                  value: 'player_invite',
                  child: Text('Generate Player Invite'),
                ),
                const PopupMenuItem(
                  value: 'judge_invite',
                  child: Text('Generate Judge Invite'),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: Text('Settings'),
                ),
              ],
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                groupName,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text('Group Dashboard'),
              const SizedBox(height: 20),
              FutureBuilder<List<String>>(
                future: _checkNewUploads(),
                builder: (context, snapshot) {
                  final names = snapshot.data ?? [];
                  if (names.isEmpty) return const SizedBox.shrink();

                  final text = names.length == 1
                      ? '📸 ${names.first} just uploaded their photo!'
                      : '📸 ${names.join(', ')} just uploaded their photos!';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Card(
                      color: const Color(0xFFE10600).withOpacity(0.15),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          text,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                },
              ),
              FutureBuilder<int>(
                future: _checkPendingJudging(),
                builder: (context, snapshot) {
                  final pending = snapshot.data ?? 0;
                  if (pending == 0) return const SizedBox.shrink();

                  final text = pending == 1
                      ? '⚖️ 1 photo is waiting for your score!'
                      : '⚖️ $pending photos are waiting for your score!';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Card(
                      color: Colors.amber.withOpacity(0.15),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          text,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              FutureBuilder<List<dynamic>>(
                future: fetchMembersWithNames(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: ListTile(
                        leading: Icon(Icons.people),
                        title: Text('Members'),
                        subtitle: Text('Loading...'),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.people),
                        title: const Text('Members'),
                        subtitle: Text('Error: ${snapshot.error}'),
                      ),
                    );
                  }

                  final members = snapshot.data ?? [];

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.people),
                      title: Text(
                        '👥 Members (${members.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        members.map((m) {
                          String icon = '👤';

                          if (m['role'] == 'owner') {
                            icon = '👑';
                          } else if (m['role'] == 'player') {
                            icon = '⚔️';
                          } else if (m['role'] == 'judge') {
                            icon = '⚖️';
                          }

                          return '$icon ${m['username']}';
                        }).join('\n'),
                      ),
                    ),
                  );
                },
              ),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: fetchBattleStatus(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: ListTile(
                        leading: Icon(Icons.today),
                        title: Text('Today’s Battle'),
                        subtitle: Text('Loading battle status...'),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.today),
                        title: const Text('Today’s Battle'),
                        subtitle: Text('Error: ${snapshot.error}'),
                      ),
                    );
                  }

                  final players = snapshot.data ?? [];

                  final statusLines = players.map((player) {
                    final icon = player['role'] == 'owner' ? '👑' : '👤';
                    final status =
                        player['hasSubmitted'] ? '✅ Submitted' : '❌ Waiting';

                    return '$icon ${player['username']} — $status';
                  }).join('\n');

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.today),
                      title: const Text('Today’s Battle'),
                      subtitle: Text(statusLines),
                    ),
                  );
                },
              ),
              FutureBuilder<List<dynamic>>(
                future: Supabase.instance.client
                    .from('submissions')
                    .select()
                    .eq('group_id', widget.group['id']),
                builder: (context, submissionsSnapshot) {
                  if (!submissionsSnapshot.hasData) {
                    return const Card(
                      child: ListTile(
                        title: Text('Current Leader'),
                        subtitle: Text('Loading...'),
                      ),
                    );
                  }

                  final submissions = submissionsSnapshot.data ?? [];

                  return FutureBuilder<List<dynamic>>(
                    future: Supabase.instance.client.from('scores').select(),
                    builder: (context, scoresSnapshot) {
                      if (!scoresSnapshot.hasData) {
                        return const Card(
                          child: ListTile(
                            title: Text('Current Leader'),
                            subtitle: Text('Loading scores...'),
                          ),
                        );
                      }

                      final scores = scoresSnapshot.data ?? [];
                      final totals = <String, int>{};

                      for (final submission in submissions) {
                        final userId = submission['user_id'];

                        final submissionScores = scores.where(
                          (score) => score['submission_id'] == submission['id'],
                        );

                        for (final score in submissionScores) {
                          totals[userId] =
                              (totals[userId] ?? 0) + ((score['score'] ?? 0) as int);
                        }
                      }

                      if (totals.isEmpty) {
                        return const Card(
                          child: ListTile(
                            leading: Text('🏆', style: TextStyle(fontSize: 28)),
                            title: Text('Current Leader'),
                            subtitle: Text('No scores yet'),
                          ),
                        );
                      }

                      final leaderId = totals.entries.reduce(
                        (a, b) => a.value >= b.value ? a : b,
                      ).key;

                      final leaderScore = totals[leaderId] ?? 0;

                      return FutureBuilder<List<dynamic>>(
                        future: Supabase.instance.client
                            .from('users')
                            .select()
                            .eq('id', leaderId),
                        builder: (context, userSnapshot) {
                          final users = userSnapshot.data ?? [];
                          final leaderName =
                              users.isNotEmpty ? users.first['username'] : 'Unknown';

                          return Card(
                            child: ListTile(
                              leading: const Text(
                                '🏆',
                                style: TextStyle(fontSize: 28),
                              ),
                              title: const Text(
                                '🏆 Current Leader',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(leaderName),
                              trailing: Text(
                                '$leaderScore pts',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              if (canUpload)
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
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
                        if (!context.mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('You already submitted today 📸'),
                          ),
                        );

                        return;
                      }

                      final picker = ImagePicker();

                      final image = await picker.pickImage(
                        source: ImageSource.camera,
                      );

                      if (image == null) return;

                      final file = File(image.path);

                      final filePath =
                          '${widget.group['id']}/${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

                      await supabase.storage.from('Photos').upload(
                            filePath,
                            file,
                          );

                      final submission = await supabase
                          .from('submissions')
                          .insert({
                            'group_id': widget.group['id'],
                            'user_id': user.id,
                            'photo_url': filePath,
                          })
                          .select()
                          .single();

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Submission saved: ${submission['id']}'),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Upload error: $e'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Upload Today’s Photo'),
                ),
              if (canJudge) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JudgePhotosPage(group: widget.group),
                      ),
                    );
                  },
                  icon: const Icon(Icons.star),
                  label: const Text('Judge Photos'),
                ),
              ],
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LeaderboardPage(group: widget.group),
                    ),
                  );
                },
                icon: const Icon(Icons.leaderboard),
                label: const Text('Leaderboard'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BattleHistoryPage(group: widget.group),
                    ),
                  );
                },
                icon: const Icon(Icons.history),
                label: const Text('Battle History'),
              ),
              const SizedBox(height: 12),
             ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CalendarPage(group: widget.group),
                    ),
                  );
                },
                icon: const Icon(Icons.calendar_month),
                label: const Text('Calendar'),
              ),
            const SizedBox(height: 12),
              FutureBuilder<int>(
                future: _unreadChatCount(),
                builder: (context, snapshot) {
                  final unreadCount = snapshot.data ?? 0;

                  return ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatPage(group: widget.group),
                        ),
                      ).then((_) => setState(() {}));
                    },
                    icon: const Icon(Icons.chat_bubble),
                    label: Text(
                      unreadCount > 0
                          ? 'Group Chat ($unreadCount)'
                          : 'Group Chat',
                    ),
                  );
                },
              ),
            ],
          ),
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

await supabase.from('group_members').insert({
  'group_id': invite['group_id'],
  'user_id': user.id,
  'role': invite['role'] ?? 'player',
});

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Joined group')),
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
        title: const Text('Join Group'),
      ),
      body: Padding(
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
        .gte('submitted_at', startOfDay.toIso8601String())
        .lt('submitted_at', endOfDay.toIso8601String())
        .order('submitted_at', ascending: false);

    final result = <Map<String, dynamic>>[];

    for (final submission in submissions) {
      final signedUrl = await supabase.storage
          .from('Photos')
          .createSignedUrl(submission['photo_url'], 60 * 60);

      final existingScores = await supabase
          .from('scores')
          .select()
          .eq('submission_id', submission['id'])
          .eq('judge_id', judge!.id);

    final uploader = users.firstWhere(
        (u) => u['id'] == submission['user_id'],
        orElse: () => {'username': 'Unknown'},
      );

      result.add({
        'id': submission['id'],
        'user_id': submission['user_id'],
        'username': anonymousJudging ? null : uploader['username'],
        'photo_url': submission['photo_url'],
        'signed_url': signedUrl,
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

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Judge Photos'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchSubmissions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final submissions = snapshot.data ?? [];

          if (submissions.isEmpty) {
            return const Center(child: Text('No photos submitted yet'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: submissions.length,
            itemBuilder: (context, index) {
              final submission = submissions[index];
              final myScore = submission['my_score'];

              return Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  Image.network(
                      submission['signed_url'],
                      height: 300,
                      fit: BoxFit.cover,
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
                                          content: Text('Score error: $e'),
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
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Example: old photo, duplicate, rule violation',
          ),
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo disqualified')),
      );

      setState(() {});
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Disqualify error: $e')),
      );
    }
  },
  icon: const Icon(Icons.block),
  label: const Text('Disqualify Photo'),
),

                              ],
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
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
        .inFilter('role', ['owner', 'player']);

    final users = await supabase.from('users').select();

    final results = <Map<String, dynamic>>[];

    for (final member in members) {
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
        'total_score': totalScore,
      });
    }

    results.sort(
      (a, b) => b['total_score'].compareTo(a['total_score']),
    );

    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
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
            return const Center(child: Text('No scores yet'));
          }

final winner = results.first;

return ListView(
  padding: const EdgeInsets.all(16),
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
        subtitle: Text(winner['username']),
        trailing: Text(
          '${winner['total_score']} pts',
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

      final icon = index == 0 ? '🏆' : '👤';

      return Card(
        child: ListTile(
          leading: Text(
            icon,
            style: const TextStyle(fontSize: 28),
          ),
          title: Text(row['username']),
          subtitle: Text(row['role']),
          trailing: Text(
            '${row['total_score']} pts',
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
    );
  }
}
class BattleHistoryPage extends StatelessWidget {
  final dynamic group;

  const BattleHistoryPage({
    super.key,
    required this.group,
  });
Future<List<Map<String, dynamic>>> fetchHistory() async {
  final supabase = Supabase.instance.client;

  final submissions = await supabase
      .from('submissions')
      .select()
      .eq('group_id', group['id'])
      .order('submitted_at', ascending: false);

  final scores = await supabase.from('scores').select();
  final users = await supabase.from('users').select();

  final days = <String, Map<String, dynamic>>{};

  for (final submission in submissions) {
    final submittedAt = submission['submitted_at'];
    final dateKey = submittedAt.toString().split('T').first;
    final userId = submission['user_id'];

    days.putIfAbsent(dateKey, () {
      return {
        'date': submittedAt,
        'totals': <String, int>{},
        'submittedTimes': <String, String>{},
      };
    });

    final totals = days[dateKey]!['totals'] as Map<String, int>;
    final submittedTimes = days[dateKey]!['submittedTimes'] as Map<String, String>;
    submittedTimes[userId] = submittedAt.toString();

    final submissionScores = scores.where(
      (score) => score['submission_id'] == submission['id'],
    );

    for (final score in submissionScores) {
      totals[userId] = (totals[userId] ?? 0) + ((score['score'] ?? 0) as int);
    }
  }

  final history = <Map<String, dynamic>>[];

for (final day in days.values) {
    final totals = day['totals'] as Map<String, int>;
    final submittedTimes = day['submittedTimes'] as Map<String, String>;

    String winnerName = 'No scores yet';

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
      final winnerId = topUserIds.first;

      final winnerUser = users.firstWhere(
        (user) => user['id'] == winnerId,
        orElse: () => {'username': 'Unknown'},
      );

      winnerName = winnerUser['username'];
    }

history.add({
  'date': day['date'],
  'dateKey': day['date'].toString().split('T').first,
  'winner': winnerName,
});
  }

  return history;
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Battle History'),
      ),
body: FutureBuilder<List<Map<String, dynamic>>>(
  future: fetchHistory(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return Center(child: Text('Error: ${snapshot.error}'));
    }

    final history = snapshot.data ?? [];

    if (history.isEmpty) {
      return const Center(child: Text('No battle history yet'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final item = history[index];

        return Card(
         child: ListTile(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BattleDetailsPage(
          group: group,
          item: item,
        ),
      ),
    );
  },
            leading: const Text(
              '📅',
              style: TextStyle(fontSize: 28),
            ),
            title: Text(
  '🏆 ${item['winner']}',
  style: const TextStyle(fontWeight: FontWeight.bold),
),
subtitle: Text(
  (() {
    final date = DateTime.parse(item['date']);

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  })(),
),
          ),
        );
      },
    );
  },
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

  final result = <Map<String, dynamic>>[];

  for (final submission in submissions) {
    final signedUrl = await supabase.storage
        .from('Photos')
        .createSignedUrl(submission['photo_url'], 60 * 60);

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
body: SingleChildScrollView(
  child: Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '🏆 Winner: ${item['winner']}',
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),

      const SizedBox(height: 12),

Text(
  (() {
    final date = DateTime.parse(item['date']);

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return '📅 ${date.day} ${months[date.month - 1]} ${date.year}';
  })(),
  style: const TextStyle(fontSize: 16),
),
const SizedBox(height: 16),

FutureBuilder<List<Map<String, dynamic>>>(
  future: fetchBattlePhotos(),
  builder: (context, snapshot) {
    final photos = snapshot.data ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚔️ Battle Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            if (photos.isEmpty)
              const Text('No scores yet')
            else
              ...photos.map((photo) {
                return Text(
                  '${photo['username']}: ${photo['total_score']} pts',
                );
              }),
          ],
        ),
      ),
    );
  },
),
const SizedBox(height: 24),

FutureBuilder<List<Map<String, dynamic>>>(
  future: fetchBattlePhotos(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return Text('Photo error: ${snapshot.error}');
    }

    final photos = snapshot.data ?? [];

    if (photos.isEmpty) {
      return const Text('No photos for this day');
    }

return Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      '📸 Photos submitted: ${photos.length}',
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),

    const SizedBox(height: 12),

...photos.map((photo) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📸 ${photo['username']}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),



        const SizedBox(height: 8),

        Image.network(
          photo['signed_url'],
          height: 250,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
        const SizedBox(height: 8),

if (photo['is_disqualified'] == true) ...[
  const Text(
    '🚫 Disqualified',
    style: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
    ),
  ),

  Text(
    photo['disqualification_reason'] ?? 'No reason provided',
    style: const TextStyle(fontSize: 14),
  ),
] else
  Text(
    '⭐ Total Score: ${photo['total_score']}',
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
    ),
  ),

const SizedBox(height: 8),

const Text(
  'Judge Breakdown',
  style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 4),

...(photo['judge_details'] as List).map((judge) {
if (judge['disqualified'] == true) {
  return Text(
    '⚖️ ${judge['judge_name']}: 🚫 Disqualified — ${judge['reason'] ?? 'No reason'}',
  );
}

  return Text(
    '⚖️ ${judge['judge_name']}: ⭐ ${judge['score']}',
  );
}),
      ],
    ),
  );
}),
  ],
);
  },
),
    ],
  ),
),
),
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
          .inFilter('role', ['owner', 'player']);

      final sortedMembers = [...members]
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : Padding(
                  padding: const EdgeInsets.all(16),
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
    );
  }
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

class _SettingsPageState extends State<SettingsPage> {
  bool _anonymousJudging = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
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
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading settings: $e')),
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Setting saved')),
      );
    } catch (e) {
      if (!mounted) return;

      // Revert the switch if saving failed
      setState(() => _anonymousJudging = !value);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving setting: $e')),
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Settings'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                ],
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
    });

    _controller.addListener(() {
      final isFinished = !_controller.value.isPlaying &&
          _controller.value.position >= _controller.value.duration &&
          _controller.value.duration > Duration.zero;

      if (isFinished && !_navigated) {
        _navigated = true;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AuthGate()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const SizedBox.shrink(),
      ),
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
class RulesPage extends StatefulWidget {
  final dynamic group;
  final bool isOwner;

  const RulesPage({
    super.key,
    required this.group,
    required this.isOwner,
  });

  @override
  State<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends State<RulesPage> {
  final _controller = TextEditingController();
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadRules();
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
        _controller.text = group['rules'] ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading rules: $e')),
      );
    }
  }

  Future<void> _saveRules() async {
    final supabase = Supabase.instance.client;

    setState(() => _saving = true);

    try {
      final result = await supabase
          .from('groups')
          .update({'rules': _controller.text})
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
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving rules: $e')),
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rules'),
        actions: [
          if (widget.isOwner && !_loading)
            IconButton(
              icon: Icon(_editing ? Icons.close : Icons.edit),
              onPressed: _saving
                  ? null
                  : () => setState(() => _editing = !_editing),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: _editing
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            decoration: const InputDecoration(
                              hintText: 'Write the group rules here...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _saving ? null : _saveRules,
                          child: Text(_saving ? 'Saving...' : 'Save Rules'),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      child: _controller.text.trim().isEmpty
                          ? const Text('No rules have been added yet.')
                          : Text(
                              _controller.text,
                              style: const TextStyle(fontSize: 15, height: 1.5),
                            ),
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
      final image = await picker.pickImage(source: source);
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
        SnackBar(content: Text('Error sending photo: $e')),
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
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
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
      appBar: AppBar(
        title: const Text('Group Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('No messages yet — say hi!'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
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
                                    : const Color(0xFF1A1A1A),
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
                                          child: Image.network(
                                            snapshot.data!,
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
                    icon: const Icon(Icons.add_a_photo_outlined),
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
                    icon: const Icon(Icons.send, color: Color(0xFFE10600)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
        SnackBar(content: Text('Error saving: $e')),
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
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
                ],
              ),
            ),
    );
  }
}