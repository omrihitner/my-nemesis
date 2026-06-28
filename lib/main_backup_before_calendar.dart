import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      theme: ThemeData.dark(),
      home: const AuthGate(),
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
              const Text(
                'My Nemesis',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              ),
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
class GroupDashboardPage extends StatelessWidget {
  final dynamic group;

  const GroupDashboardPage({
    super.key,
    required this.group,
  });
Future<List<Map<String, dynamic>>> fetchMembersWithNames() async {
  final supabase = Supabase.instance.client;

  final members = await supabase
      .from('group_members')
      .select()
      .eq('group_id', group['id']);

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
      .eq('group_id', group['id']);

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
    .eq('group_id', group['id'])
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

  @override
  Widget build(BuildContext context) {
    final groupName = group['name'] ?? 'Unnamed Group';

    return Scaffold(
      appBar: AppBar(
        title: Text(groupName),
      ),
      body: Padding(
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
            const SizedBox(height: 30),
            

        
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
      .eq('group_id', group['id']),
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
            totals[userId] = (totals[userId] ?? 0) + ((score['score'] ?? 0) as int);
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
  style: TextStyle(
    fontWeight: FontWeight.bold,
  ),
),
                subtitle: Text(leaderName),
                trailing: Text(
                  '$leaderScore pts',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
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

            const Spacer(),
            FutureBuilder<List<dynamic>>(
  future: Supabase.instance.client
      .from('group_members')
      .select()
      .eq('group_id', group['id'])
      .eq('user_id', Supabase.instance.client.auth.currentUser!.id),
  builder: (context, snapshot) {
    final membership = snapshot.data?.isNotEmpty == true
        ? snapshot.data!.first
        : null;

    final role = membership?['role'];
    final isOwner = role == 'owner';

    if (!isOwner) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
            ElevatedButton.icon(
  onPressed: () async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    final inviteCode = DateTime.now().millisecondsSinceEpoch.toString();

 await supabase.from('invites').insert({
  'group_id': group['id'],
  'invited_by': user.id,
  'invite_code': inviteCode,
  'role': 'player',
});

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Invite Code'),
        content: Text(inviteCode),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  },
  icon: const Icon(Icons.person_add),
  label: const Text('Generate Player Invite'),
),

const SizedBox(height: 12),
ElevatedButton.icon(
  onPressed: () async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    final inviteCode = DateTime.now().millisecondsSinceEpoch.toString();

    await supabase.from('invites').insert({
      'group_id': group['id'],
      'invited_by': user.id,
      'invite_code': inviteCode,
      'role': 'judge',
    });

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Judge Invite Code'),
        content: Text(inviteCode),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  },
  icon: const Icon(Icons.gavel),
  label: const Text('Generate Judge Invite'),
),
      ],
    );
  },
),

FutureBuilder<List<dynamic>>(
  future: Supabase.instance.client
      .from('group_members')
      .select()
      .eq('group_id', group['id'])
      .eq('user_id', Supabase.instance.client.auth.currentUser!.id),
  builder: (context, snapshot) {
    final membership = snapshot.data?.isNotEmpty == true
        ? snapshot.data!.first
        : null;

    final role = membership?['role'];
    final canUpload = role == 'owner' || role == 'player';

    if (!canUpload) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const SizedBox(height: 12),

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
    .eq('group_id', group['id'])
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
        '${group['id']}/${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    await supabase.storage.from('Photos').upload(
          filePath,
          file,
        );

 final submission = await supabase
    .from('submissions')
    .insert({
      'group_id': group['id'],
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
      ],
    );
  },
),

FutureBuilder<List<dynamic>>(
  future: Supabase.instance.client
      .from('group_members')
      .select()
      .eq('group_id', group['id'])
      .eq('user_id', Supabase.instance.client.auth.currentUser!.id),
  builder: (context, snapshot) {
    final membership = snapshot.data?.isNotEmpty == true
        ? snapshot.data!.first
        : null;

    final role = membership?['role'];
    final canJudge = role == 'judge';

    if (!canJudge) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => JudgePhotosPage(group: group),
              ),
            );
          },
          icon: const Icon(Icons.star),
          label: const Text('Judge Photos'),
        ),
      ],
    );
  },
),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => LeaderboardPage(group: group),
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
      builder: (_) => BattleHistoryPage(group: group),
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
      builder: (_) => CalendarPage(group: group),
    ),
  );
},
  icon: const Icon(Icons.calendar_month),
  label: const Text('Calendar'),
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

      result.add({
        'id': submission['id'],
        'user_id': submission['user_id'],
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
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: List.generate(11, (score) {
                                    return ElevatedButton(
                                      onPressed: () async {
                                        try {
                                          await saveScore(
                                            submission['id'],
                                            score,
                                          );

                                          if (!context.mounted) return;

                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content:
                                                  Text('Score saved: $score'),
                                            ),
                                          );
                                        } catch (e) {
                                          if (!context.mounted) return;

                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text('Score error: $e'),
                                            ),
                                          );
                                        }
                                      },
                                      child: Text(score.toString()),
                                    );
                                                             }),
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
      };
    });

    final totals = days[dateKey]!['totals'] as Map<String, int>;

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

    String winnerName = 'No scores yet';

    if (totals.isNotEmpty) {
      final winnerId = totals.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      ).key;

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
class CalendarPage extends StatelessWidget {
  final dynamic group;

  const CalendarPage({
    super.key,
    required this.group,
  });
Future<List<Map<String, dynamic>>> fetchCalendarHistory() async {
  final supabase = Supabase.instance.client;

  final submissions = await supabase
      .from('submissions')
      .select()
      .eq('group_id', group['id']);

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
      };
    });

    final totals = days[dateKey]!['totals'] as Map<String, int>;

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

    String winnerName = 'No winner yet';

    if (totals.isNotEmpty) {
      final winnerId = totals.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      ).key;

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
    final now = DateTime.now();
final firstDayOfMonth = DateTime(now.year, now.month, 1);
final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
final emptyStartDays = firstDayOfMonth.weekday % 7;
final calendarCells = [
  ...List.generate(emptyStartDays, (_) => null),
  ...List.generate(daysInMonth, (index) => index + 1),
];

const months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

final monthTitle = '${months[now.month - 1]} ${now.year}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
Text(
  monthTitle,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),
const Row(
  children: [
    Expanded(
      child: Center(child: Text('Sun')),
    ),
    Expanded(
      child: Center(child: Text('Mon')),
    ),
    Expanded(
      child: Center(child: Text('Tue')),
    ),
    Expanded(
      child: Center(child: Text('Wed')),
    ),
    Expanded(
      child: Center(child: Text('Thu')),
    ),
    Expanded(
      child: Center(child: Text('Fri')),
    ),
    Expanded(
      child: Center(child: Text('Sat')),
    ),
  ],
),

const SizedBox(height: 8),

            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
              children: calendarCells.map((day) {
                final dateKey = day == null
    ? null
    : '${now.year}-${now.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
            final isToday =
    day == now.day &&
    now.month == DateTime.now().month &&
    now.year == DateTime.now().year;

return Container(
  alignment: Alignment.center,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(10),
    color: day == null
        ? Colors.transparent
        : Colors.grey.shade800,
    border: isToday
        ? Border.all(color: Colors.white, width: 2)
        : null,
  ),
child: Text(
  day == null ? '' : day.toString(),
  style: const TextStyle(
    fontWeight: FontWeight.bold,
  ),
),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}