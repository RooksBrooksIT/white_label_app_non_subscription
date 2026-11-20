import 'package:flutter_test/flutter_test.dart';
import 'package:subscription_rooks_app/services/app_update_service.dart';

void main() {
  group('AppUpdateService - Semantic Version Comparison', () {
    test('identical versions return 0', () {
      expect(AppUpdateService.compareSemanticVersions('2.0.0', '2.0.0'), 0);
      expect(AppUpdateService.compareSemanticVersions('1.0', '1.0.0'), 0);
      expect(AppUpdateService.compareSemanticVersions('2.0.0+14', '2.0.0+19'), 0);
    });

    test('newer major version returns 1', () {
      expect(AppUpdateService.compareSemanticVersions('3.0.0', '2.0.0'), 1);
      expect(AppUpdateService.compareSemanticVersions('2.0.0', '3.0.0'), -1);
    });

    test('newer minor version returns 1', () {
      expect(AppUpdateService.compareSemanticVersions('2.1.0', '2.0.0'), 1);
      expect(AppUpdateService.compareSemanticVersions('2.0.0', '2.1.0'), -1);
    });

    test('newer patch version returns 1', () {
      expect(AppUpdateService.compareSemanticVersions('2.0.1', '2.0.0'), 1);
      expect(AppUpdateService.compareSemanticVersions('2.0.0', '2.0.1'), -1);
    });

    test('numerical segments compare correctly when length differs (e.g. 10 vs 9)', () {
      expect(AppUpdateService.compareSemanticVersions('2.10.0', '2.9.0'), 1);
      expect(AppUpdateService.compareSemanticVersions('2.9.0', '2.10.0'), -1);
    });
  });

  group('AppUpdateService - Update Availability Evaluation', () {
    test('same version and build number -> not available', () {
      final available = AppUpdateService.checkIsUpdateAvailable(
        installedVersion: '2.0.0',
        installedBuildNumber: 19,
        latestVersion: '2.0.0',
        latestBuildNumber: 19,
      );
      expect(available, false);
    });

    test('newer patch version -> available', () {
      final available = AppUpdateService.checkIsUpdateAvailable(
        installedVersion: '2.0.0',
        installedBuildNumber: 19,
        latestVersion: '2.0.1',
        latestBuildNumber: 20,
      );
      expect(available, true);
    });

    test('newer minor version -> available', () {
      final available = AppUpdateService.checkIsUpdateAvailable(
        installedVersion: '2.0.0',
        installedBuildNumber: 19,
        latestVersion: '2.1.0',
        latestBuildNumber: 25,
      );
      expect(available, true);
    });

    test('newer major version -> available', () {
      final available = AppUpdateService.checkIsUpdateAvailable(
        installedVersion: '2.0.0',
        installedBuildNumber: 19,
        latestVersion: '3.0.0',
        latestBuildNumber: 30,
      );
      expect(available, true);
    });

    test('same version but higher build number -> available', () {
      final available = AppUpdateService.checkIsUpdateAvailable(
        installedVersion: '2.0.0',
        installedBuildNumber: 14,
        latestVersion: '2.0.0',
        latestBuildNumber: 19,
      );
      expect(available, true);
    });

    test('installed version is ahead of latest -> not available', () {
      final available = AppUpdateService.checkIsUpdateAvailable(
        installedVersion: '2.1.0',
        installedBuildNumber: 20,
        latestVersion: '2.0.0',
        latestBuildNumber: 19,
      );
      expect(available, false);
    });
  });

  group('AppUpdateService - Mandatory vs Optional Evaluation', () {
    test('forceUpdate flag set to true -> mandatory', () {
      final mandatory = AppUpdateService.checkIsMandatory(
        installedVersion: '2.0.0',
        installedBuildNumber: 19,
        minimumSupportedVersion: '2.0.0',
        minimumSupportedBuildNumber: 19,
        forceUpdate: true,
        updateRequired: false,
      );
      expect(mandatory, true);
    });

    test('updateRequired flag set to true -> mandatory', () {
      final mandatory = AppUpdateService.checkIsMandatory(
        installedVersion: '2.0.0',
        installedBuildNumber: 19,
        minimumSupportedVersion: '2.0.0',
        minimumSupportedBuildNumber: 19,
        forceUpdate: false,
        updateRequired: true,
      );
      expect(mandatory, true);
    });

    test('installed version below minimumSupportedVersion -> mandatory', () {
      final mandatory = AppUpdateService.checkIsMandatory(
        installedVersion: '1.9.9',
        installedBuildNumber: 15,
        minimumSupportedVersion: '2.0.0',
        minimumSupportedBuildNumber: 19,
        forceUpdate: false,
        updateRequired: false,
      );
      expect(mandatory, true);
    });

    test('installed version matches minimum version but build number below minimum -> mandatory', () {
      final mandatory = AppUpdateService.checkIsMandatory(
        installedVersion: '2.0.0',
        installedBuildNumber: 14,
        minimumSupportedVersion: '2.0.0',
        minimumSupportedBuildNumber: 19,
        forceUpdate: false,
        updateRequired: false,
      );
      expect(mandatory, true);
    });

    test('installed version meets or exceeds minimum -> optional', () {
      final mandatory = AppUpdateService.checkIsMandatory(
        installedVersion: '2.0.0',
        installedBuildNumber: 19,
        minimumSupportedVersion: '2.0.0',
        minimumSupportedBuildNumber: 18,
        forceUpdate: false,
        updateRequired: false,
      );
      expect(mandatory, false);
    });
  });
}
