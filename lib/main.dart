import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jsonld/globals/app_state.dart';
import 'package:jsonld/globals/router.dart';
import 'package:jsonld/database/database.dart';
import 'package:jsonld/globals/database_instance.dart';

late final SharedPreferences sharedPrefs;

main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sharedPrefs = await SharedPreferences.getInstance();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>(create: (context) => AppState()),
      ],
      builder: (context, child) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppState.of(context).theme,
        routerConfig: appRouter,
      ),
    );
  }
}
