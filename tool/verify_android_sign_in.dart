import 'dart:convert';
import 'dart:io';

String _fingerprint(String value) =>
    value.replaceAll(RegExp('[^a-fA-F0-9]'), '').toUpperCase();

/// Validates the downloaded Firebase config against the release certificate.
/// This is a local consistency check, not a live OAuth sign-in test.
List<String> validateAndroidSignIn({
  required Map<String, dynamic> config,
  required String packageName,
  required String sha1,
  required String firebaseProjectId,
  required String firebaseAppId,
}) {
  final errors = <String>[];
  final project = config['project_info'] as Map? ?? const {};
  if (project['project_id'] != firebaseProjectId) {
    errors.add('google-services.json and FirebaseOptions.android use different '
        'Firebase projects. Use configuration from the same project.');
  }
  final clients = (config['client'] as List? ?? const [])
      .whereType<Map>()
      .where((client) =>
          (client['client_info'] as Map?)?['android_client_info'] is Map &&
          ((client['client_info'] as Map)['android_client_info']
                  as Map)['package_name'] ==
              packageName)
      .toList();
  if (clients.length != 1) {
    errors.add('Expected one Firebase Android app for package $packageName, '
        'but found ${clients.length}. Download its google-services.json.');
    return errors;
  }
  final client = clients.single;
  if ((client['client_info'] as Map)['mobilesdk_app_id'] != firebaseAppId) {
    errors.add('google-services.json and FirebaseOptions.android use different '
        'Firebase Android app IDs.');
  }
  final oauth = (client['oauth_client'] as List? ?? const []).whereType<Map>();
  final androidClientMatches = oauth.any((entry) {
    final android = entry['android_info'] as Map? ?? const {};
    return entry['client_type'] == 1 &&
        (entry['client_id'] as String? ?? '').isNotEmpty &&
        android['package_name'] == packageName &&
        _fingerprint(android['certificate_hash'] as String? ?? '') ==
            _fingerprint(sha1);
  });
  if (!androidClientMatches) {
    errors.add('No Android OAuth client matches package $packageName and '
        'release SHA-1 $sha1. Add this fingerprint in Firebase Project settings '
        '> Your apps > Android, download the updated google-services.json, '
        'and replace the ANDROID_GOOGLE_SERVICES_JSON GitHub Actions secret.');
  }
  if (!oauth.any((entry) =>
      entry['client_type'] == 3 &&
      (entry['client_id'] as String? ?? '').isNotEmpty)) {
    errors.add('The Firebase Android config has no web OAuth client. Enable '
        'Google in Firebase Authentication > Sign-in method, then download '
        'google-services.json again.');
  }
  return errors;
}

Future<void> main(List<String> args) async {
  try {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final packageName =
        RegExp(r'applicationId\s*=\s*"([^"]+)"').firstMatch(gradle)?.group(1);
    if (packageName == null) {
      throw StateError('Could not read the Android applicationId.');
    }
    final options = File('lib/firebase_options.dart').readAsStringSync();
    final androidOptions = RegExp(
      r'static const FirebaseOptions android\s*=\s*FirebaseOptions\((.*?)\);',
      dotAll: true,
    ).firstMatch(options)?.group(1);
    if (androidOptions == null) {
      throw StateError('FirebaseOptions.android is missing. Configure Firebase '
          'for Android and update the FIREBASE_OPTIONS_DART Actions secret.');
    }
    String option(String name) {
      final value = RegExp('$name\\s*:\\s*[\'"]([^\'"]+)[\'"]')
          .firstMatch(androidOptions)
          ?.group(1);
      if (value == null) throw StateError('Android Firebase $name is missing.');
      return value;
    }

    final javaHome = Platform.environment['JAVA_HOME'];
    final keytool = args.isNotEmpty
        ? args.single
        : javaHome != null
            ? '$javaHome/bin/keytool${Platform.isWindows ? '.exe' : ''}'
            : 'keytool';
    // This is the fixed sharedDebug signing configuration used by release
    // builds in android/app/build.gradle.kts, including GitHub Actions APKs.
    final certificate = await Process.run(keytool, [
      '-J-Duser.language=en',
      '-J-Duser.country=US',
      '-list',
      '-v',
      '-keystore',
      'android/app/debug.keystore',
      '-alias',
      'splitwize-debug',
      '-storepass',
      'android',
    ]);
    if (certificate.exitCode != 0) {
      throw StateError(
          'Could not inspect the shared release signing certificate. '
          'Check that keytool and android/app/debug.keystore are available.');
    }
    String digest(String algorithm) {
      final value = RegExp('$algorithm:\\s*([A-Fa-f0-9:]+)')
          .firstMatch(certificate.stdout as String)
          ?.group(1);
      if (value == null) {
        throw StateError('Could not read certificate $algorithm.');
      }
      return value;
    }

    final sha1 = digest('SHA1');
    stdout.writeln('Android package: $packageName');
    stdout.writeln('Release signing SHA-1: $sha1');
    stdout.writeln('Release signing SHA-256: ${digest('SHA256')}');
    final errors = validateAndroidSignIn(
      config: jsonDecode(
              File('android/app/google-services.json').readAsStringSync())
          as Map<String, dynamic>,
      packageName: packageName,
      sha1: sha1,
      firebaseProjectId: option('projectId'),
      firebaseAppId: option('appId'),
    );
    if (errors.isNotEmpty) {
      for (final error in errors) {
        stderr.writeln('ERROR: $error');
      }
      exitCode = 1;
      return;
    }
    stdout.writeln(
        'Android Google Sign-In configuration matches the release signer.');
  } catch (error) {
    stderr.writeln('Android Google Sign-In validation failed: $error');
    exitCode = 1;
  }
}
