// ignore_for_file: use_build_context_synchronously

import 'package:exerai/firebase_options.dart';
import 'package:exerai/pages/home.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    ShadApp.custom(
      themeMode: ThemeMode.light,
      darkTheme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadSlateColorScheme.light(),
      ),
      appBuilder: (context) {
        return MaterialApp(
          theme: Theme.of(context),
          builder: (context, child) {
            return ShadAppBuilder(child: child!);
          },
          debugShowCheckedModeBanner: false,
          home: Home(),
        );
      },
    ),
  );
}
