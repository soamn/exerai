import 'dart:async';
import 'package:exerai/pages/player.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:audioplayers/audioplayers.dart';

class SessionRunner extends StatefulWidget {
  final List<Map<String, dynamic>> exercises;

  const SessionRunner({super.key, required this.exercises});

  @override
  State<SessionRunner> createState() => _SessionRunnerState();
}

class _SessionRunnerState extends State<SessionRunner> {
  int currentIndex = -1;
  bool isRest = false;
  int timerSeconds = 30;
  Timer? countdownTimer;
  int getReadySeconds = 5;
  bool getReadyActive = true;
  Timer? getReadyTimer;
  bool isotonicButtonEnabled = false;
  Timer? isotonicTimer;
  bool exerciseStarted = false;
  DateTime? sessionStartTime;
  DateTime? sessionEndTime;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _startGetReady();
  }

  void _startGetReady() {
    setState(() {
      getReadyActive = true;
      getReadySeconds = 10;
    });
    getReadyTimer?.cancel();
    getReadyTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        getReadySeconds--;
      });
      if (getReadySeconds <= 0) {
        timer.cancel();
        _startFirstExercise();
      }
    });
  }

  void _addGetReadyTime(int seconds) {
    setState(() {
      getReadySeconds += seconds;
    });
  }

  void _startFirstExercise() {
    getReadyTimer?.cancel();
    setState(() {
      getReadyActive = false;
      currentIndex = 0;
      isRest = false;
      sessionStartTime = DateTime.now(); // Start session timer
    });
    _startCountdownOrIsotonic();
  }

  void _startCountdownOrIsotonic() {
    final current = widget.exercises[currentIndex];
    setState(() {
      exerciseStarted = false;
    });
    if (current['execution_style'] == 'isotonic') {
      setState(() {
        isotonicButtonEnabled = false;
      });
      isotonicTimer?.cancel();
    } else {
      countdownTimer?.cancel();
    }
  }

  void _startExercise() async {
    // Play whistle sound
    await _audioPlayer.play(AssetSource('whistle.mp3'));
    final current = widget.exercises[currentIndex];
    setState(() {
      exerciseStarted = true;
    });
    if (current['execution_style'] == 'isotonic') {
      isotonicTimer?.cancel();
      setState(() {
        isotonicButtonEnabled = false;
      });
      isotonicTimer = Timer(Duration(seconds: 20), () {
        setState(() {
          isotonicButtonEnabled = true;
        });
      });
    } else if (current['execution_style'] == 'isometric') {
      // Parse seconds from reps_or_duration
      final repsOrDuration = current['reps_or_duration'] as String? ?? '';
      final match = RegExp(r'(\d+)').firstMatch(repsOrDuration);
      int seconds = 30;
      if (match != null) {
        seconds = int.tryParse(match.group(1) ?? '30') ?? 30;
      }
      _startCountdown(seconds);
    } else {
      _startCountdown();
    }
  }

  void _startCountdown([int seconds = 30]) {
    setState(() {
      timerSeconds = seconds;
    });
    countdownTimer?.cancel();
    countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        timerSeconds--;
      });
      if (timerSeconds <= 0) {
        timer.cancel();
        _nextPhase();
      }
    });
  }

  void _nextPhase() {
    if (isRest) {
      if (currentIndex + 1 < widget.exercises.length) {
        setState(() {
          currentIndex++;
          isRest = false;
        });
        _startCountdownOrIsotonic();
      } else {
        _showCompletion();
      }
    } else {
      // Only show rest if not after last exercise
      if (currentIndex + 1 < widget.exercises.length) {
        setState(() {
          isRest = true;
        });
        _startCountdown(30);
      } else {
        _showCompletion();
      }
    }
  }

  void _showCompletion() async {
    sessionEndTime = DateTime.now();
    final duration = sessionEndTime!.difference(sessionStartTime!).inSeconds;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final exercisesDone = widget.exercises.map((e) => e['name']).toList();
      final now = DateTime.now();
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('completed_sessions')
          .doc(); // Use auto-generated ID for multiple sessions per day
      await docRef.set({
        'date': now,
        'exercises': exercisesDone,
        'duration': duration,
      });
      await _updateStreak(user.uid, now);
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Workout Complete!"),
        content: Text("You have completed the session."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(
                context,
                rootNavigator: true,
              ).popUntil((route) => route.isFirst);
            },
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStreak(String uid, DateTime today) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
    final userSnap = await userDoc.get();
    int streak = 1;
    if (userSnap.exists && userSnap.data()?['last_completed'] != null) {
      final lastDate = (userSnap.data()?['last_completed'] as Timestamp)
          .toDate();
      final diff = today.difference(lastDate).inDays;
      if (diff == 1) {
        streak = (userSnap.data()?['streak'] ?? 0) + 1;
      }
    }
    await userDoc.set({
      'last_completed': today,
      'streak': streak,
    }, SetOptions(merge: true));
  }

  void _addTime(int seconds) {
    setState(() {
      timerSeconds += seconds;
    });
  }

  void _skip() {
    countdownTimer?.cancel();
    _nextPhase();
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    getReadyTimer?.cancel();
    isotonicTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIntro = currentIndex == -1 && getReadyActive;
    final isFinished = currentIndex >= widget.exercises.length;
    final current = isFinished || currentIndex == -1
        ? null
        : widget.exercises[currentIndex];

    return Scaffold(
      appBar: AppBar(title: Text("Exercise Session")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isIntro &&
                  !isFinished &&
                  !isRest &&
                  current != null &&
                  current['url'] is String &&
                  (current['url'] as String).isNotEmpty)
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: 800,
                      maxWidth: MediaQuery.of(context).size.width,
                    ),
                    child: Player(videoUrl: current['url'] as String),
                  ),
                ),
              if (isIntro)
                Column(
                  children: [
                    Text(
                      "Get Ready",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "$getReadySeconds",
                      style: TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () => _addGetReadyTime(5),
                          child: Text("+5 Seconds"),
                        ),
                        SizedBox(width: 16),
                        ShadButton(
                          onPressed: _startFirstExercise,
                          child: Text("Start"),
                        ),
                      ],
                    ),
                  ],
                )
              else if (!isFinished)
                Column(
                  children: [
                    Text(
                      isRest ? "Rest" : "${current?['name'] ?? ''}",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                      child: Text(
                        current?['reps_or_duration'],
                        style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                      ),
                    ),
                    if (!isRest &&
                        current != null &&
                        current['execution_style'] != null &&
                        current['execution_style'] != 'isometric' &&
                        current['reps_or_duration'] != null &&
                        current['reps_or_duration']
                            .toString()
                            .toLowerCase()
                            .contains('set') &&
                        exerciseStarted)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Complete all sets before moving to the next screen',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.orange[700],
                          ),
                        ),
                      ),
                    if (!isRest && !exerciseStarted)
                      ShadButton(
                        onPressed: _startExercise,
                        child: Text("Start"),
                      ),
                    if (!isRest &&
                        current?['execution_style'] == 'isotonic' &&
                        exerciseStarted)
                      Column(
                        children: [
                          Icon(
                            Icons.fitness_center,
                            size: 60,
                            color: isotonicButtonEnabled
                                ? Colors.green
                                : Colors.grey,
                          ),
                          SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: isotonicButtonEnabled
                                ? _nextPhase
                                : null,
                            child: Text(
                              isotonicButtonEnabled ? "Next" : "Next",
                            ),
                          ),
                        ],
                      ),
                    if (!isRest &&
                        current?['execution_style'] != 'isotonic' &&
                        exerciseStarted)
                      Column(
                        children: [
                          Text(
                            "$timerSeconds",
                            style: TextStyle(
                              fontSize: 80,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () => _addTime(10),
                                child: Text("+10 Seconds"),
                              ),
                              SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: () => _addTime(30),
                                child: Text("+30 Seconds"),
                              ),
                              SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: _skip,
                                child: Text("Skip"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    if (isRest)
                      Column(
                        children: [
                          Text(
                            "$timerSeconds",
                            style: TextStyle(
                              fontSize: 80,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () => _addTime(10),
                                child: Text("+10 Seconds"),
                              ),
                              SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: () => _addTime(30),
                                child: Text("+30 Seconds"),
                              ),
                              SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: _skip,
                                child: Text("Skip"),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              if (isFinished)
                Text(
                  "Session Complete!",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
