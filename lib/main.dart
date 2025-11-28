import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'constants/app_colors.dart';
import 'models/mission_model.dart';
import 'models/user_model.dart';
import 'models/auth_model.dart';
import 'models/parental_control_model.dart';
import 'models/screen_time_model.dart';
import 'screens/challenges_screen.dart';
import 'screens/community_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/login_screen.dart';
import 'screens/parental_control_screen.dart';
import 'screens/analytics_screen.dart';
import 'services/screen_time_service.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

/// ---------------- MAIN ----------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MindQuestApp());
}

/// ---------------- APP ROOT ----------------
class MindQuestApp extends StatelessWidget {
  const MindQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.interTextTheme();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthModel()),
        ChangeNotifierProvider(
          create: (_) => UserModel(
            username: 'MindQuest User',
            xp: 120,
            level: 3,
            streakDays: 3,
            badges: 5,
            rank: 42,
          ),
        ),
        ChangeNotifierProvider(create: (_) => MissionsModel()),
        ChangeNotifierProvider(create: (_) => ParentalControlModel()),
        ChangeNotifierProvider(
          create: (_) {
            final screenTimeModel = ScreenTimeModel();
            ScreenTimeService.initialize(screenTimeModel);
            return screenTimeModel;
          },
        ),
      ],
      child: MaterialApp(
        title: 'MindQuest',
        theme: buildTheme(Brightness.light).copyWith(textTheme: textTheme),
        darkTheme: buildTheme(Brightness.dark).copyWith(textTheme: textTheme),
        themeMode: ThemeMode.system,
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// ---------------- AUTH WRAPPER ----------------
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthModel>(
      builder: (context, authModel, child) {
        if (authModel.isAuthenticated) {
          // Check if re-authentication is needed
          return FutureBuilder<bool>(
            future: _checkReauthRequirement(authModel),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasData && snapshot.data == true) {
                // Re-authentication is required
                return const LoginScreen(); // Or redirect to re-auth screen
              }

              // User is authenticated and no re-auth is needed
              return const RootNav();
            },
          );
        } else {
          return const LoginScreen();
        }
      },
    );
  }

  Future<bool> _checkReauthRequirement(AuthModel authModel) async {
    if (authModel.firebaseUser != null) {
      return await authModel.shouldAskPassword();
    }
    return false;
  }
}

/// ---------------- BOTTOM NAV ----------------
class RootNav extends StatefulWidget {
  const RootNav({super.key});

  @override
  State<RootNav> createState() => _RootNavState();
}

class _RootNavState extends State<RootNav> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    ChallengesScreen(),
    CommunityScreen(),
    AnalyticsScreen(),
    ParentalControlScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedColor = AppColors.purple;
    final unselectedColor = Colors.grey;

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _screens[_index],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) {
          setState(() => _index = i);
        },
        selectedItemColor: selectedColor,
        unselectedItemColor: unselectedColor,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(LucideIcons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.target),
            label: 'Challenges',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.users),
            label: 'Community',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.barChart3),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.shield),
            label: 'Parental',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.user),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
