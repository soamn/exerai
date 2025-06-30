import 'package:exerai/pages/session_runner.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:table_calendar/table_calendar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? user = FirebaseAuth.instance.currentUser;
  bool isLoading = false;

  Future<void> _signInWithGoogleAndAttachAnon() async {
    setState(() => isLoading = true);
    final GoogleSignIn googleSignIn = GoogleSignIn();
    // Sign out from any previous Google session to force account picker
    await googleSignIn.signOut();
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      setState(() => isLoading = false);
      return;
    }
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    try {
      final userCred = await FirebaseAuth.instance.currentUser
          ?.linkWithCredential(credential);
      setState(() {
        user = userCred?.user;
        isLoading = false;
      });
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        final userCred = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
        setState(() {
          user = userCred.user;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(
          // ignore: use_build_context_synchronously
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to link: ${e.message}')));
      }
    }
  }

  Future<void> _deletePlan(String planId) async {
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('plans')
        .doc(planId)
        .delete();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Center(child: Text('No user found.'));
    }
    final isAnon = user!.isAnonymous;
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAnon) ...[
              Text('Signed in as Guest', style: TextStyle(fontSize: 20)),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: isLoading ? null : _signInWithGoogleAndAttachAnon,
                child: isLoading
                    ? CircularProgressIndicator()
                    : Text('Sign in with Google and attach data'),
              ),
            ] else ...[
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .collection('completed_sessions')
                    .snapshots(),
                builder: (context, snapshot) {
                  int totalSeconds = 0;
                  int days = 0;
                  if (snapshot.hasData) {
                    final docs = snapshot.data!.docs;
                    days = docs.length;
                    for (final doc in docs) {
                      totalSeconds += (doc['duration'] ?? 0) as int;
                    }
                  }
                  double totalHours = totalSeconds / 3600.0;
                  double avgPerDay = days > 0 ? totalHours / days : 0;
                  return ShadCard(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Name: ${user!.displayName ?? "-"}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'Email: ${user!.email ?? "-"}',
                            style: TextStyle(fontSize: 16),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Total hours spent: ${totalHours.toStringAsFixed(2)} h',
                            style: TextStyle(fontSize: 16),
                          ),
                          Text(
                            'Avg time/day: ${avgPerDay.toStringAsFixed(2)} h',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.of(
                      // ignore: use_build_context_synchronously
                      context,
                    ).pushNamedAndRemoveUntil('/', (route) => false);
                  }
                },
                child: Text('Sign out'),
              ),
              SizedBox(height: 16),
            ],

            SizedBox(height: 16),
            // Calendar showing completed sessions
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection('completed_sessions')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return SizedBox();
                final docs = snapshot.data!.docs;
                final Map<DateTime, List<QueryDocumentSnapshot>> sessionsByDay =
                    {};
                for (final doc in docs) {
                  final ts = doc['date'];
                  DateTime? d;
                  if (ts is Timestamp) {
                    final t = ts.toDate();
                    d = DateTime(t.year, t.month, t.day);
                  } else if (ts is DateTime) {
                    d = DateTime(ts.year, ts.month, ts.day);
                  }
                  if (d != null) {
                    sessionsByDay.putIfAbsent(d, () => []).add(doc);
                  }
                }
                return TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2100, 12, 31),
                  focusedDay: DateTime.now(),
                  calendarFormat: CalendarFormat.month,
                  eventLoader: (date) =>
                      sessionsByDay[DateTime(
                        date.year,
                        date.month,
                        date.day,
                      )] ??
                      [],
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, date, _) {
                      final isCompleted = sessionsByDay.containsKey(
                        DateTime(date.year, date.month, date.day),
                      );
                      return Container(
                        decoration: BoxDecoration(
                          color: isCompleted ? Colors.green : null,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            color: isCompleted ? Colors.white : null,
                          ),
                        ),
                      );
                    },
                  ),
                  onDaySelected: (selectedDay, focusedDay) {
                    final sessions =
                        sessionsByDay[DateTime(
                          selectedDay.year,
                          selectedDay.month,
                          selectedDay.day,
                        )] ??
                        [];
                    if (sessions.isNotEmpty) {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(
                            'Sessions on ${selectedDay.year}-${selectedDay.month}-${selectedDay.day}',
                          ),
                          content: SizedBox(
                            width: 300,
                            child: ListView(
                              shrinkWrap: true,
                              children: sessions.map((doc) {
                                final exercises =
                                    (doc['exercises'] as List?) ?? [];
                                final duration = doc['duration'] ?? 0;
                                return ListTile(
                                  title: Text(
                                    'Duration: ${(duration / 60).toStringAsFixed(1)} min',
                                  ),
                                  subtitle: Text(
                                    exercises
                                        .map((e) => e.toString())
                                        .join(', '),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Close'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                );
              },
            ),
            SizedBox(height: 20),
            Text(
              'Your Plans',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 20),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .collection('plans')
                    .orderBy('created_at', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) return Text('No plans found.');
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, idx) {
                      final plan = docs[idx];
                      final exercises =
                          plan['exercises'] as List<dynamic>? ?? [];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: ShadCard(
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Plan (${exercises.length} exercises)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: "Delete",
                                      icon: Icon(Icons.delete),
                                      onPressed: () => _deletePlan(plan.id),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                SizedBox(
                                  height: 120,
                                  child: ListView.separated(
                                    itemCount: exercises.length,
                                    separatorBuilder: (_, __) =>
                                        Divider(height: 1),
                                    itemBuilder: (context, exIdx) {
                                      final ex = exercises[exIdx];
                                      return ListTile(
                                        dense: true,
                                        title: Text(
                                          ex['name'] ?? '-',
                                          style: TextStyle(fontSize: 15),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(height: 12),
                                ShadButton(
                                  onPressed: () => (
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SessionRunner(
                                          exercises: exercises
                                              .cast<Map<String, dynamic>>(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  child: Text('Start'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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
