import 'package:flutter_test/flutter_test.dart';

import '../tool/verify_android_sign_in.dart';

void main() {
  const sha1 = 'EF:46:99:1E:0F:1D:E0:40:82:1B:2D:00:B0:A9:25:A2:D3:E8:00:30';
  Map<String, dynamic> config({
    String package = 'com.example.splitwize',
    String hash = 'ef46991e0f1de040821b2d00b0a925a2d3e80030',
    bool androidClient = true,
    bool webClient = true,
  }) =>
      {
        'project_info': {'project_id': 'splitwize-e5208'},
        'client': [
          {
            'client_info': {
              'mobilesdk_app_id': 'android-app-id',
              'android_client_info': {'package_name': package},
            },
            'oauth_client': [
              if (androidClient)
                {
                  'client_id': 'android-client.apps.googleusercontent.com',
                  'client_type': 1,
                  'android_info': {
                    'package_name': package,
                    'certificate_hash': hash
                  },
                },
              if (webClient)
                {
                  'client_id': 'web-client.apps.googleusercontent.com',
                  'client_type': 3,
                },
            ],
          }
        ],
      };

  List<String> validate(
    Map<String, dynamic> value, {
    String project = 'splitwize-e5208',
    String app = 'android-app-id',
  }) =>
      validateAndroidSignIn(
          config: value,
          packageName: 'com.example.splitwize',
          sha1: sha1,
          firebaseProjectId: project,
          firebaseAppId: app);

  test(
      'matching release signer succeeds regardless of fingerprint case or separators',
      () {
    expect(validate(config()), isEmpty);
    expect(validate(config(hash: sha1)), isEmpty);
  });

  test('web-only config identifies the missing Android OAuth registration', () {
    final errors = validate(config(androidClient: false));
    expect(errors.single, contains('No Android OAuth client'));
    expect(errors.single, contains(sha1));
    expect(errors.single, contains('ANDROID_GOOGLE_SERVICES_JSON'));
  });

  test('another signing certificate cannot pass the release check', () {
    expect(validate(config(hash: '00' * 20)).single,
        contains('No Android OAuth client'));
  });

  test('a different package is rejected', () {
    expect(validate(config(package: 'com.example.other')).single,
        contains('Expected one Firebase Android app'));
  });

  test('missing web client identifies Google provider setup', () {
    expect(validate(config(webClient: false)).single,
        contains('Enable Google in Firebase Authentication'));
  });

  test('mismatched Firebase Dart and Android configurations are rejected', () {
    expect(validate(config(), project: 'wrong-project').single,
        contains('different Firebase projects'));
    expect(validate(config(), app: 'wrong-app-id').single,
        contains('different Firebase Android app IDs'));
  });

  test('an Android OAuth client must belong to the matching package', () {
    final value = config();
    final client = (value['client'] as List).single as Map;
    final android = (client['oauth_client'] as List).first as Map;
    (android['android_info'] as Map)['package_name'] = 'com.example.other';
    expect(validate(value).single, contains('No Android OAuth client'));
  });
}
