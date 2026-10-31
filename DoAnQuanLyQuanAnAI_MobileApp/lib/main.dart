import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/locale_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/cart_provider.dart';
import 'package:doanquanlyquananai_mobileapp/l10n/app_localizations.dart';
import 'package:doanquanlyquananai_mobileapp/screens/splash_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/login_screen.dart';
import 'package:doanquanlyquananai_mobileapp/core/storage/local_cache.dart';
import 'package:doanquanlyquananai_mobileapp/services/menu_provider.dart';
import 'package:doanquanlyquananai_mobileapp/services/table_provider.dart';
import 'package:doanquanlyquananai_mobileapp/services/dashboard_provider.dart';
import 'package:doanquanlyquananai_mobileapp/services/order_provider.dart';
import 'package:doanquanlyquananai_mobileapp/services/customer_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doanquanlyquananai_mobileapp/services/booking_notification_provider.dart';

// Cấu hình Supabase Cloud Database (Thay thế YOUR_SUPABASE_ANON_KEY bằng anon key của bạn)
const String supabaseUrl = 'https://usaybsihqbymbemnqzgr.supabase.co';
const String supabaseAnonKey = 'sb_publishable_oDIUjhTQpjEfr2qLZzDkYQ_Dhc4vYmE';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalCache.init();
  
  // Khởi tạo kết nối trực tiếp đến CSDL Đám mây Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SmartRestaurantApp());
}

class SmartRestaurantApp extends StatelessWidget {
  const SmartRestaurantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => LocaleService()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => MenuProvider()),
        ChangeNotifierProvider(create: (_) => TableProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => BookingNotificationProvider()),
      ],
      child: Consumer<LocaleService>(
        builder: (context, localeService, _) {
          return MaterialApp(
            title: 'Reserve & Relish - AI Smart Restaurant POS',
            theme: AppTheme.lightTheme,
            home: const SplashScreen(),
            routes: {
              '/login': (context) => const LoginScreen(),
            },
            debugShowCheckedModeBanner: false,
            locale: localeService.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          );
        },
      ),
    );
  }
}
