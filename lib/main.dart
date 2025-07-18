import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/super_admin/super_admin_dashboard.dart';
//import 'screens/super_admin/schools_list_screen.dart';
//import 'screens/super_admin/create_school_screen.dart';
//import 'screens/super_admin/school_admin_dashboard.dart';
// import 'screens/principal/principal_dashboard.dart';
// import 'screens/teacher/teacher_dashboard.dart';
// import 'screens/student/student_dashboard.dart';
// import 'screens/support_staff/support_staff_dashboard.dart';
import 'utils/auth_guard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(SVMSchoolApp());
}

class SVMSchoolApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SVM School Management',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        primaryColor: Color(0xFF6C5CE7),
        // Note: accentColor is deprecated, use colorScheme instead
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFF6C5CE7),
          secondary: Color(0xFF74B9FF),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF6C5CE7),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Color(0xFF6C5CE7), width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignUpScreen(),
        '/super-admin': (context) => AuthGuard(
          child: SuperAdminDashboard(), // Fixed: Added missing SuperAdminDashboard()
          requiredRole: 'superadmin',
        ),
        /*'/schools': (context) => AuthGuard(
          child: SchoolsListScreen(),
          requiredRole: 'superadmin',
        ),
        '/create-school': (context) => AuthGuard(
          child: CreateSchoolScreen(),
          requiredRole: 'superadmin',
        ),
        '/school-admin': (context) => AuthGuard(
          child: SchoolAdminDashboard(),
          requiredRole: 'superadmin',
        ),*/
        // Commented out the following routes as requested
        // '/principal': (context) => AuthGuard(
        //   child: PrincipalDashboard(),
        //   requiredRole: 'principal',
        // ),
        // '/teacher': (context) => AuthGuard(
        //   child: TeacherDashboard(),
        //   requiredRole: 'teacher',
        // ),
        // '/student': (context) => AuthGuard(
        //   child: StudentDashboard(),
        //   requiredRole: 'student',
        // ),
        // '/support-staff': (context) => AuthGuard(
        //   child: SupportStaffDashboard(),
        //   requiredRole: 'support_staff',
        // ),
      },
    );
  }
}