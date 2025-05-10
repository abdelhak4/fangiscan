import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fungiscan/application/identification/identification_bloc.dart';
import 'package:fungiscan/application/map/map_bloc.dart';
import 'package:fungiscan/data/datasources/local/database_helper.dart';
import 'package:fungiscan/data/repositories/mushroom_repository_impl.dart';
import 'package:fungiscan/domain/repositories/mushroom_repository.dart';
import 'package:fungiscan/infrastructure/services/ml_service.dart';
import 'package:fungiscan/infrastructure/services/location_service.dart';
import 'package:fungiscan/presentation/screens/home_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Firebase initialization is disabled for web development
  // await Firebase.initializeApp();
  
  // Initialize local database
  try {
    await DatabaseHelper.initialize();
  } catch (e) {
    print('Database initialization error: $e');
    // Continue without database for demo
  }
  
  // Initialize services
  final mlService = MLService();
  try {
    await mlService.loadModel();
  } catch (e) {
    print('ML service initialization error: $e');
    // Continue without ML model for demo
  }
  
  final locationService = LocationService();
  try {
    await locationService.initialize();
  } catch (e) {
    print('Location service initialization error: $e');
    // Continue without location for demo
  }
  
  // Repository setup
  final MushroomRepository mushroomRepository = MushroomRepositoryImpl();
  
  runApp(MyApp(
    mushroomRepository: mushroomRepository,
    mlService: mlService,
    locationService: locationService,
  ));
}

class MyApp extends StatelessWidget {
  final MushroomRepository mushroomRepository;
  final MLService mlService;
  final LocationService locationService;
  
  const MyApp({
    Key? key,
    required this.mushroomRepository,
    required this.mlService,
    required this.locationService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => IdentificationBloc(
            mushroomRepository: mushroomRepository,
            mlService: mlService,
          ),
        ),
        BlocProvider(
          create: (context) => MapBloc(
            mushroomRepository: mushroomRepository,
            locationService: locationService,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'FungiScan',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          fontFamily: 'Poppins',
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Color(0xFF4CAF50),
            elevation: 0,
            centerTitle: true,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF4CAF50),
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4CAF50),
              side: const BorderSide(
                color: Color(0xFF4CAF50),
                width: 1.5,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        darkTheme: ThemeData.dark().copyWith(
          primaryColor: const Color(0xFF388E3C),
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFF388E3C),
            secondary: Colors.amber,
            background: const Color(0xFF121212),
            surface: const Color(0xFF1E1E1E),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E1E1E),
            foregroundColor: Color(0xFF4CAF50),
            elevation: 0,
            centerTitle: true,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF388E3C),
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
