import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exerai/pages/profile_page.dart';
import 'package:exerai/pages/session_runner.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

final generatePlanTool = FunctionDeclaration(
  'generatePlan',
  'generates a plan of exercises for the user',
  parameters: {
    'exercises': Schema.array(
      items: Schema.object(
        properties: {
          'id': Schema.string(description: 'id of the exercise'),
          'name': Schema.string(description: 'name of the exercise'),
        },
      ),
    ),
  },
);

class _HomeState extends State<Home> {
  final List<Map<String, dynamic>> _messages = [];
  final model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-2.5-flash',
    tools: [
      Tool.functionDeclarations([generatePlanTool]),
    ],
  );
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  bool _hasmessaged = false;
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _allExercises = [];
  final firestore = FirebaseFirestore.instance;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _loadExercises();
    _maybeSignInAnonymously();
    _fetchStreak();
  }

  Future<void> generatePlan(List exercises) async {
    final ids = exercises.map((e) => e['id'] as String).toList();
    List<Map<String, dynamic>> fetched = [];
    for (var i = 0; i < ids.length; i += 10) {
      final batch = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snapshot = await firestore
          .collection('exercises')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      fetched.addAll(snapshot.docs.map((doc) => doc.data()));
    }
    setState(() {
      _messages.add({'role': 'plan', 'plan': fetched, 'saved': false});
    });
  }

  Future<void> _loadExercises() async {
    final snapshot = await firestore.collection('exercises').get();
    final exercises = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'],
        'description': data['description'],
        'tags': data['tags'],
        'equipment': data['equipment'],
        'type': data['type'],
        'muscles_targated': data['muscles_targated'],
        'reps_or_duration': data['reps_or_duration'],
      };
    }).toList();
    setState(() {
      _allExercises = exercises;
    });
  }

  Future<void> _fetchStreak() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (doc.exists && doc.data()?['streak'] != null) {
      final lastCompleted = doc.data()?['last_completed'];
      int streak = doc['streak'] ?? 0;
      if (lastCompleted != null) {
        final lastDate = (lastCompleted as Timestamp).toDate();
        final now = DateTime.now();
        final diff = now
            .difference(DateTime(lastDate.year, lastDate.month, lastDate.day))
            .inDays;
        if (diff > 1) {
          // Missed a day, reset streak
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'streak': 0}, SetOptions(merge: true));
          streak = 0;
        }
      }
      setState(() {
        _streak = streak;
      });
    }
  }

  void _sendMessage() async {
    setState(() {
      _hasmessaged = true;
    });

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
      _controller.clear();
    });

    await Future.delayed(const Duration(milliseconds: 100));
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 80,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    try {
      final List<Content> prompt = [];

      prompt.add(
        Content.text("""
You are a helpful health asistant. You respond to all the general queries of users,
 and recommend exercises to the user.You also respond to all the general queries of the user
Here is the list of all available exercises in the database:
the exercises list has data such as name of exercise,its description,useful tags,equiment related to the
exercise,type of exercise , muscles that are targeted, and whether the exercise is reps based or timer based,
${_allExercises.isEmpty ? 'No exercises found.' : _allExercises.join(', ')}
use this information to recommend perfect exercise for the user's concern eg.( like rehab exercise plan or 
muscle gain etc.)
For recommending exercise plan Do not give exercise as plain text , use the generatePlan function ,
-generatePlan(exercises), this function allows you to recommend exercises that user can interactively perform,
the exercises parameter is defined like this [{"id":"exerciseid",name:"exerciseName"},{..},{..}] 
pass the id's and names of the exercise that you want to recommend to user correctly in the generatePlan function.
"""),
      );

      // Chat history
      for (final msg in _messages) {
        final contentText =
            (msg['role'] == 'user' ? 'User: ' : 'AI: ') +
            (msg['content'] ?? '');
        prompt.add(Content.text(contentText));
      }

      final response = await model.generateContent(prompt);
      final aiText = response.text ?? 'Generated';
      final functionCalls = response.functionCalls.toList();

      if (functionCalls.isNotEmpty) {
        for (final functionCall in functionCalls) {
          if (functionCall.name == 'generatePlan') {
            final exercisesArg = functionCall.args['exercises'];
            if (exercisesArg != null && exercisesArg is List) {
              // Accept both Map<String, dynamic> and Map<String, String>
              final exercises = exercisesArg.cast<Map<String, dynamic>>();
              generatePlan(exercises);
            }
          }
        }
      }
      setState(() {
        _messages.add({'role': 'ai', 'content': aiText});
        _isLoading = false;
      });

      await Future.delayed(const Duration(milliseconds: 100));
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      setState(() {
        _messages.add({'role': 'ai', 'content': 'Error: $e'});
        _isLoading = false;
      });
    }
  }

  Future<void> _maybeSignInAnonymously() async {
    final user = FirebaseAuth.instance.currentUser;
    // Only sign in anonymously if there is no user or the user is not signed in with Google
    if (user == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  Future<void> _savePlan(Map<String, dynamic> planMessage) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final planList = planMessage['plan'] as List<Map<String, dynamic>>;
    final userId = user.uid;

    final planData = {"created_at": Timestamp.now(), "exercises": planList};

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('plans')
          .add(planData);

      // Find and update the saved flag in _messages
      final index = _messages.indexOf(planMessage);
      if (index != -1) {
        setState(() {
          _messages[index]['saved'] = true;
          _messages.add({'role': 'ai', 'content': '✅ Plan saved!'});
        });
      }

      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text('✅ Plan saved')));
    } catch (e) {
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Failed to save plan: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Row(
            spacing: 4,
            children: [Icon(Icons.fitness_center_rounded), Text("ExerAI")],
          ),
          actions: [
            IconButton(
              onPressed: () => (Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfilePage()),
              )),
              icon: Icon(Icons.face_rounded),
            ),
          ],
          surfaceTintColor: Colors.transparent,
          // centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Text(
                      '🔥 Streak: $_streak days',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_hasmessaged)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.smart_toy, color: Colors.grey),
                        Text(
                          "Start by Saying Hi",
                          style: TextStyle(fontSize: 20, color: Colors.grey),
                        ),
                        SizedBox(height: 12),
                        Text(
                          "Ask anything about health or exercises!",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg['role'] == 'user';
                      if (msg['role'] == 'plan' && msg['plan'] is List) {
                        final planList =
                            msg['plan'] as List<Map<String, dynamic>>;
                        final isSaved = msg['saved'] == true;
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: ShadCard(
                            width: MediaQuery.of(context).size.width,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    SizedBox(
                                      height: 260,
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        physics: const BouncingScrollPhysics(),
                                        itemCount: planList.length,
                                        itemBuilder: (context, idx) {
                                          final exercise = planList[idx];
                                          return Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            child: ShadCard(
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  1.0,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      exercise['name'] ?? '',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                    if (exercise['description'] !=
                                                        null)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              top: 4.0,
                                                            ),
                                                        child: Text(
                                                          exercise['description'],
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 14,
                                                              ),
                                                        ),
                                                      ),
                                                    SizedBox(
                                                      height: 20,
                                                      child: Text(
                                                        "Muscles Targeted:",
                                                        style: TextStyle(
                                                          fontStyle:
                                                              FontStyle.italic,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                    if (exercise['muscles_targeted'] !=
                                                            null &&
                                                        exercise['muscles_targeted']
                                                            is List &&
                                                        (exercise['muscles_targeted']
                                                                as List)
                                                            .isNotEmpty)
                                                      Row(
                                                        children:
                                                            (exercise['muscles_targeted']
                                                                    as List)
                                                                .map<Widget>(
                                                                  (
                                                                    muscle,
                                                                  ) => Container(
                                                                    margin:
                                                                        const EdgeInsets.only(
                                                                          right:
                                                                              6,
                                                                        ),
                                                                    child: Card(
                                                                      color: Colors
                                                                          .grey
                                                                          .shade100,
                                                                      child: Padding(
                                                                        padding: const EdgeInsets.symmetric(
                                                                          horizontal:
                                                                              8,
                                                                          vertical:
                                                                              4,
                                                                        ),
                                                                        child: Text(
                                                                          muscle
                                                                              .toString(),
                                                                          style: const TextStyle(
                                                                            fontSize:
                                                                                10,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                )
                                                                .toList(),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    // Top shadow
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      child: IgnorePointer(
                                        child: Container(
                                          height: 16,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.transparent,
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Bottom shadow
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: IgnorePointer(
                                        child: Container(
                                          height: 16,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                              colors: [
                                                Colors.black.withAlpha(
                                                  (0.10 * 255).toInt(),
                                                ),
                                                Colors.transparent,
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Row(
                                  spacing: 6,
                                  children: [
                                    ShadButton(
                                      child: Text("Start"),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SessionRunner(
                                            exercises: planList,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (!isSaved)
                                      ShadButton(
                                        child: Text("Save Plan"),
                                        onPressed: () => _savePlan(msg),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      } else if (msg['content'] is String) {
                        return Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              border: isUser
                                  ? Border.all(color: Colors.black)
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  spreadRadius: -15,
                                  color: const Color.fromARGB(
                                    255,
                                    211,
                                    209,
                                    209,
                                  ),
                                  blurRadius: 20,
                                  offset: Offset(0, 1),
                                ),
                              ],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              msg['content'] as String,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        );
                      } else {
                        return SizedBox.shrink();
                      }
                    },
                  ),
                ),
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [SpinKitChasingDots(color: Colors.black)],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: ShadTextarea(
                      controller: _controller,
                      minHeight: 40,
                      resizable: false,
                      decoration: ShadDecoration(
                        shadows: ShadShadows.xl,
                        border: ShadBorder.none,
                        focusedBorder: ShadBorder.none,
                        secondaryFocusedBorder: ShadBorder.none,
                      ),
                      placeholder: Text('Type your message here'),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  SizedBox(width: 8),
                ],
              ),
              Padding(
                padding: EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ShadButton(
                      decoration: ShadDecoration(
                        border: ShadBorder(radius: BorderRadius.circular(100)),
                      ),
                      height: 30,
                      width: 30,
                      padding: EdgeInsets.zero,
                      onPressed: _isLoading ? null : _sendMessage,
                      child: Center(child: Icon(Icons.arrow_upward, size: 10)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
