import 'package:flutter/material.dart';
import 'app_routes.dart';
import '../../features/splash/splash_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/home/home_page.dart';
import '../../features/pos/pos_page.dart';
import '../../features/invoices/invoice_history_page.dart';
import '../../features/invoices/invoice_detail_page.dart';
import '../../features/item_transactions/item_transactions_page.dart';
import '../../features/payment_notification/payment_notification_page.dart';
import '../../features/settings/api_settings_page.dart';
import '../../features/details/details_page.dart';

class AppRouter {
  AppRouter._();

  // Global Navigator Key for navigation without context
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Route Generator
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return _buildPageRoute(
          const SplashPage(),
          settings: settings,
        );

      case AppRoutes.login:
        return _buildPageRoute(
          const LoginPage(),
          settings: settings,
        );

      case AppRoutes.home:
        return _buildPageRoute(
          const HomePage(),
          settings: settings,
        );

      case AppRoutes.pos:
        return _buildPageRoute(
          const PosPage(),
          settings: settings,
        );

      case AppRoutes.invoices:
        return _buildPageRoute(
          const InvoiceHistoryPage(),
          settings: settings,
        );

      case AppRoutes.invoiceDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        final invoiceId = args?['invoiceId'] ?? args?['id'] ?? 1;
        return _buildPageRoute(
          InvoiceDetailPage(invoiceId: invoiceId),
          settings: settings,
        );

      case AppRoutes.itemTransactions:
        final args = settings.arguments as Map<String, dynamic>?;
        final itemId = args?['itemId'] ?? args?['id'];
        return _buildPageRoute(
          ItemTransactionsPage(initialItemId: itemId),
          settings: settings,
        );

      case AppRoutes.paymentNotification:
        return _buildPageRoute(
          const PaymentNotificationPage(),
          settings: settings,
        );

      case AppRoutes.settings:
        return _buildPageRoute(
          const ApiSettingsPage(),
          settings: settings,
        );

      case AppRoutes.details:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildPageRoute(
          DetailsPage(
            title: args?['title'] ?? 'Detail Page',
            content: args?['content'] ?? 'Tidak ada data',
          ),
          settings: settings,
        );

      default:
        return _buildPageRoute(
          _NotFoundPage(routeName: settings.name ?? 'Unknown'),
          settings: settings,
        );
    }
  }

  // Smooth slide and fade page transition
  static PageRouteBuilder<dynamic> _buildPageRoute(
    Widget page, {
    required RouteSettings settings,
  }) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        final offsetAnimation = animation.drive(tween);
        final fadeAnimation = animation.drive(Tween(begin: 0.0, end: 1.0));

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 250),
    );
  }

  // Navigation Helper Methods
  static BuildContext? get currentContext => navigatorKey.currentContext;

  static Future<T?>? pushNamed<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) {
    return navigatorKey.currentState?.pushNamed<T>(routeName, arguments: arguments);
  }

  static Future<T?>? pushReplacementNamed<T extends Object?, TO extends Object?>(
    String routeName, {
    TO? result,
    Object? arguments,
  }) {
    return navigatorKey.currentState?.pushReplacementNamed<T, TO>(
      routeName,
      result: result,
      arguments: arguments,
    );
  }

  static Future<T?>? pushNamedAndRemoveUntil<T extends Object?>(
    String routeName,
    bool Function(Route<dynamic>) predicate, {
    Object? arguments,
  }) {
    return navigatorKey.currentState?.pushNamedAndRemoveUntil<T>(
      routeName,
      predicate,
      arguments: arguments,
    );
  }

  static void pop<T extends Object?>([T? result]) {
    navigatorKey.currentState?.pop<T>(result);
  }
}

// Fallback 404 Not Found Page
class _NotFoundPage extends StatelessWidget {
  final String routeName;

  const _NotFoundPage({required this.routeName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Halaman Tidak Ditemukan'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 72,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(
                'Rute "$routeName" tidak ditemukan!',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Kembali'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
