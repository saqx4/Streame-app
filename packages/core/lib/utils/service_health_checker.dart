import '../utils/app_logger.dart';
import '../error/either.dart';
import '../error/failures.dart';

/// Health check result for a service
class ServiceHealth {
  final String serviceName;
  final bool isHealthy;
  final String? message;
  final int? latencyMs;

  const ServiceHealth({
    required this.serviceName,
    required this.isHealthy,
    this.message,
    this.latencyMs,
  });

  @override
  String toString() {
    final status = isHealthy ? '✓ HEALTHY' : '✗ UNHEALTHY';
    final latency = latencyMs != null ? ' (${latencyMs}ms)' : '';
    final msg = message != null ? ' - $message' : '';
    return '$serviceName: $status$latency$msg';
  }
}

/// Utility for checking service health during startup
class ServiceHealthChecker {
  /// Check health of multiple services in parallel
  static Future<Map<String, ServiceHealth>> checkAll(
    Map<String, Future<Either<Failure, dynamic>> Function()> checks,
  ) async {
    final results = <String, ServiceHealth>{};
    
    final futures = checks.entries.map((entry) async {
      final serviceName = entry.key;
      final check = entry.value;
      
      final stopwatch = Stopwatch()..start();
      final result = await check();
      stopwatch.stop();
      
      final health = result.fold(
        (failure) => ServiceHealth(
          serviceName: serviceName,
          isHealthy: false,
          message: failure.message,
          latencyMs: stopwatch.elapsedMilliseconds,
        ),
        (_) => ServiceHealth(
          serviceName: serviceName,
          isHealthy: true,
          latencyMs: stopwatch.elapsedMilliseconds,
        ),
      );
      
      return MapEntry(serviceName, health);
    });

    final healthResults = await Future.wait(futures);
    for (final entry in healthResults) {
      results[entry.key] = entry.value;
    }
    
    return results;
  }

  /// Check health of a single service
  static Future<ServiceHealth> check(
    String serviceName,
    Future<Either<Failure, dynamic>> Function() check,
  ) async {
    final stopwatch = Stopwatch()..start();
    final result = await check();
    stopwatch.stop();
    
    return result.fold(
      (failure) => ServiceHealth(
        serviceName: serviceName,
        isHealthy: false,
        message: failure.message,
        latencyMs: stopwatch.elapsedMilliseconds,
      ),
      (_) => ServiceHealth(
        serviceName: serviceName,
        isHealthy: true,
        latencyMs: stopwatch.elapsedMilliseconds,
      ),
    );
  }

  /// Log health check results
  static void logResults(Map<String, ServiceHealth> results) {
    log.info('═══════════════════════════════════════════════════════════');
    log.info('[HealthCheck] Service Health Report');
    log.info('═══════════════════════════════════════════════════════════');
    
    final healthy = results.values.where((h) => h.isHealthy).length;
    final total = results.length;
    
    for (final health in results.values) {
      log.info(health.toString());
    }
    
    log.info('═══════════════════════════════════════════════════════════');
    log.info('[HealthCheck] Summary: $healthy/$total services healthy');
    log.info('═══════════════════════════════════════════════════════════');
  }

  /// Check if critical services are healthy
  static bool areCriticalServicesHealthy(
    Map<String, ServiceHealth> results,
    List<String> criticalServices,
  ) {
    for (final serviceName in criticalServices) {
      final health = results[serviceName];
      if (health == null || !health.isHealthy) {
        log.info('[HealthCheck] Critical service $serviceName is unhealthy');
        return false;
      }
    }
    return true;
  }
}
