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
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:fungiscan/infrastructure/services/authentication_service.dart';
import 'package:fungiscan/infrastructure/services/encryption_service.dart';
import 'package:fungiscan/infrastructure/services/notification_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:fungiscan/application/settings/settings_bloc.dart';
import 'package:fungiscan/application/auth/auth_bloc.dart';
import 'package:fungiscan/application/community/community_bloc.dart';

// Simple logger for debugging
import 'package:logging/logging.dart';

// Temporary mock classes to resolve errors until dependencies are installed
class Database {}

class Firebase {
  static Future<void> initializeApp() async {
    // Mock implementation - will be replaced with real Firebase once packages are installed
  }
}

class Purchases {
  static Future<void> configure(PurchasesConfiguration config) async {
    // Mock implementation - will be replaced with real RevenueCat once packages are installed
  }
}

class PurchasesConfiguration {
  final String apiKey;

  PurchasesConfiguration(this.apiKey);

  PurchasesConfiguration copyWith({bool? observerMode}) {
    return this;
  }
}

// For Sembast
final databaseFactoryIo = _MockDatabaseFactory();

class _MockDatabaseFactory {
  Future<Database> openDatabase(String path,
      {int? version, dynamic codec}) async {
    return Database();
  }
}

void main() async {
  // Keep splash screen visible while initializing app
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Configure logger
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  final logger = Logger('FungiScan');

  // Set preferred orientations - portrait only for better UX
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
    logger.info('Environment variables loaded successfully');
  } catch (e) {
    logger.warning('Failed to load .env file: $e');
    // Continue without environment variables
  }

  // Initialize Hive for secure local storage
  try {
    await Hive.initFlutter();
    await Hive.openBox('mushroomData');
    await Hive.openBox('userPreferences');
    await Hive.openBox('offlineCache');
    logger.info('Hive initialized successfully');
  } catch (e) {
    logger.severe('Hive initialization error: $e');
  }

  // Initialize Sembast for encrypted storage
  final encryptionService = EncryptionService();
  await encryptionService.initialize();

  try {
    final appDir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(appDir.path, 'mushrooms.db');
    // Open database but don't need to store reference since we'll use it through services
    await databaseFactoryIo.openDatabase(dbPath,
        version: 1, codec: encryptionService.getSembastCodec());
    logger.info('Sembast database initialized with encryption');
  } catch (e) {
    logger.severe('Sembast initialization error: $e');
  }

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    logger.info('Firebase initialized successfully');
  } catch (e) {
    logger.severe('Firebase initialization error: $e');
    // We'll continue without Firebase and use offline mode only
  }

  // Initialize RevenueCat for monetization (one-time purchases and subscription options)
  try {
    await Purchases.configure(
      PurchasesConfiguration(
        dotenv.env['REVENUE_CAT_API_KEY'] ?? 'your_revenue_cat_api_key',
      ).copyWith(
        observerMode: false,
      ),
    );
    logger.info('RevenueCat initialized successfully');
  } catch (e) {
    logger.warning('RevenueCat initialization error: $e');
  }

  // Initialize local database
  try {
    await DatabaseHelper.initialize();
    logger.info('Local database initialized successfully');
  } catch (e) {
    logger.severe('Database initialization error: $e');
    // Continue without database for demo
  }

  // Initialize ML service with TensorFlow Lite
  final mlService = MLService();
  try {
    await mlService.loadModel();
    logger.info('ML model loaded successfully');
  } catch (e) {
    logger.severe('ML service initialization error: $e');
  }

  // Initialize location service for foraging site tracking
  final locationService = LocationService();
  try {
    await locationService.initialize();
    logger.info('Location service initialized successfully');
  } catch (e) {
    logger.warning('Location service initialization error: $e');
  }

  // Initialize authentication service
  final authService = AuthenticationService();
  try {
    await authService.initialize();
    logger.info('Authentication service initialized successfully');
  } catch (e) {
    logger.warning('Authentication service initialization error: $e');
  }

  // Initialize notification service
  final notificationService = NotificationService();
  try {
    await notificationService.initialize();
    logger.info('Notification service initialized successfully');
  } catch (e) {
    logger.warning('Notification service initialization error: $e');
  }

  // Check connectivity for offline mode handling
  final connectivityResult = await Connectivity().checkConnectivity();
  final isOffline = connectivityResult == ConnectivityResult.none;
  logger
      .info('Initial connectivity state: ${isOffline ? 'offline' : 'online'}');

  // Repository setup
  final MushroomRepository mushroomRepository = MushroomRepositoryImpl();

  // Remove splash screen
  FlutterNativeSplash.remove();

  runApp(
    MyApp(
      mushroomRepository: mushroomRepository,
      mlService: mlService,
      locationService: locationService,
      authService: authService,
      notificationService: notificationService,
      encryptionService: encryptionService,
      isOffline: isOffline,
    ),
  );
}

class MyApp extends StatelessWidget {
  final MushroomRepository mushroomRepository;
  final MLService mlService;
  final LocationService locationService;
  final AuthenticationService authService;
  final NotificationService notificationService;
  final EncryptionService encryptionService;
  final bool isOffline;

  const MyApp({
    Key? key,
    required this.mushroomRepository,
    required this.mlService,
    required this.locationService,
    required this.authService,
    required this.notificationService,
    required this.encryptionService,
    required this.isOffline,
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
        BlocProvider(
          create: (context) => SettingsBloc(
            encryptionService: encryptionService,
          ),
        ),
        BlocProvider(
          create: (context) => AuthBloc(
            authService: authService,
          ),
        ),
        BlocProvider(
          create: (context) => CommunityBloc(
            mushroomRepository: mushroomRepository,
            isOffline: isOffline,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'MushroomMaster',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          fontFamily: 'Poppins',
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4CAF50),
            brightness: Brightness.light,
          ),
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
          cardTheme: CardTheme(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF388E3C),
            brightness: Brightness.dark,
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
          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: const Color(0xFF2A2A2A),
          ),
        ),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
