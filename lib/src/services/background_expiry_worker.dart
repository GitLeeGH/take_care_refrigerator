import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'reminder_auth_boundary.dart';
import 'reminder_ledger.dart';
import 'verified_expiry_delivery.dart';

/// Fixed existing credential, no auto-refresh or persistence. Redirects rejected.
class BackgroundExpirySource implements VerifiedExpirySource {
  BackgroundExpirySource(
    this.client,
    this.project,
    this.publicKey,
    this.credential,
  ) {
    if (project.scheme != 'https' ||
        project.host.isEmpty ||
        project.userInfo.isNotEmpty ||
        (project.path.isNotEmpty && project.path != '/') ||
        project.hasQuery ||
        project.hasFragment) {
      throw ArgumentError('Configured HTTPS origin required');
    }
  }
  final http.Client client;
  final Uri project;
  final String publicKey;
  final BackgroundCredential credential;
  DateTime? verifiedAt;
  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final request =
        http.Request('GET', project.replace(path: path, queryParameters: query))
          ..followRedirects = false
          ..headers.addAll({
            'apikey': publicKey,
            'Authorization': 'Bearer ${credential.token}',
          });
    final response = await client.send(request);
    if (response.statusCode != 200) {
      throw StateError('Reminder verification unavailable');
    }
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > 1024 * 1024) {
        throw StateError('Reminder response too large');
      }
      bytes.addAll(chunk);
    }
    return jsonDecode(utf8.decode(bytes));
  }

  @override
  Future<String?> verifiedOwner() async {
    final value = await _get('/auth/v1/user');
    return value is Map<String, dynamic> && value['id'] is String
        ? value['id'] as String
        : null;
  }

  @override
  Future<List<Map<String, dynamic>>> currentRows(String owner) async {
    if (owner != credential.owner) throw StateError('Reminder account changed');
    final value = await _get('/rest/v1/ingredients', {
      'select': 'id,user_id,expiry_date,quantity',
      'user_id': 'eq.$owner',
      'order': 'id.asc',
      'limit': '501',
    });
    if (value is! List || value.any((v) => v is! Map<String, dynamic>)) {
      throw StateError('Invalid reminder response');
    }
    verifiedAt = DateTime.now();
    return value.cast<Map<String, dynamic>>();
  }
}

class BackgroundExpiryDestination implements VerifiedExpiryDestination {
  BackgroundExpiryDestination(
    this.ledger,
    this.guard,
    this.credential,
    this.source, {
    this.runId,
  });
  final String? runId;
  final ReminderLedger ledger;
  final BackgroundAuthGuard guard;
  final BackgroundCredential credential;
  final BackgroundExpirySource source;
  Map<String, Object> args(ReminderLease lease) => {
    'owner': lease.owner,
    'generation': lease.generation,
    'days': lease.daysBefore,
  };
  @override
  Future<bool> leaseCurrent(ReminderLease lease) async {
    final current = await guard.restore(lease);
    return current != null &&
        current.owner == credential.owner &&
        current.token == credential.token &&
        current.expiresAt == credential.expiresAt;
  }

  @override
  Future<bool> permissionGranted() async =>
      await ledger.channel.invokeMethod<bool>('permission') == true;
  @override
  Future<bool> claimDay(ReminderLease lease, String day) async {
    final parts = day.split('-').map(int.parse).toList();
    return ledger.claim(lease, DateTime(parts[0], parts[1], parts[2]));
  }

  @override
  Future<void> showGeneric(ReminderLease lease) async {
    if (!await leaseCurrent(lease) || source.verifiedAt == null) {
      throw StateError('Stale reminder');
    }
    await ledger.channel.invokeMethod<void>('deliver', {
      ...args(lease),
      'runId': runId,
      'project': source.project.host.split('.').first,
      'credentialDigest': sha256
          .convert(utf8.encode(credential.token))
          .toString(),
      'validatedAt': source.verifiedAt!.millisecondsSinceEpoch,
      'offsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
    });
  }
}

/// Injectable integration seam: OFF returns before storage, auth or network.
Future<VerifiedDeliveryResult> runBackgroundExpiryCycle({
  required bool enabled,
  required ReminderLedger ledger,
  required BackgroundCredentialReader credentials,
  required Uri project,
  required String publicKey,
  required http.Client client,
  DateTime Function()? now,
  String? runId,
}) async {
  if (!enabled) return VerifiedDeliveryResult.skipped;
  try {
    final first = await credentials.readFresh().timeout(
      const Duration(seconds: 5),
    );
    if (first == null) return VerifiedDeliveryResult.skipped;
    final value = await ledger.channel
        .invokeMapMethod<String, dynamic>('resume', {'owner': first.owner})
        .timeout(const Duration(seconds: 5));
    if (value == null ||
        value['generation'] is! String ||
        value['days'] is! int) {
      return VerifiedDeliveryResult.skipped;
    }
    final lease = ReminderLease(
      first.owner,
      value['generation'] as String,
      value['days'] as int,
    );
    final guard = BackgroundAuthGuard(ledger, credentials, now: now);
    final credential = await guard
        .restore(lease)
        .timeout(const Duration(seconds: 5));
    if (credential == null || credential.token != first.token) {
      return VerifiedDeliveryResult.skipped;
    }
    final source = BackgroundExpirySource(
      client,
      project,
      publicKey,
      credential,
    );
    return await VerifiedExpiryDelivery(
      source,
      BackgroundExpiryDestination(
        ledger,
        guard,
        credential,
        source,
        runId: runId,
      ),
      now: now,
    ).run(lease);
  } catch (_) {
    return VerifiedDeliveryResult.unavailable;
  }
}

/// Legacy retained entrypoint must never start asynchronous alarm work.
@pragma('vm:entry-point')
Future<void> verifiedExpiryAlarmCallback() async {}

Future<void> completeExpiryWork({
  required MethodChannel channel,
  required Future<VerifiedDeliveryResult> Function(String runId) cycle,
}) async {
  final id = await channel.invokeMethod<String>('start');
  if (id == null || id.isEmpty) return;
  var status = VerifiedDeliveryResult.unavailable;
  try {
    status = await cycle(id);
  } catch (_) {
    /* No sensitive logs. */
  }
  await channel.invokeMethod<void>('complete', {
    'runId': id,
    'status': status.name,
  });
}

Future<void> runVerifiedExpiryWork() async {
  WidgetsFlutterBinding.ensureInitialized();
  await completeExpiryWork(
    channel: const MethodChannel('refrigerator/reminder_completion_v1'),
    cycle: (runId) async {
      if (!recurringExpiryDeliveryEnabled) {
        return VerifiedDeliveryResult.skipped;
      }
      final client = http.Client();
      try {
        await dotenv.load(fileName: '.env');
        final project = Uri.parse(dotenv.env['SUPABASE_URL'] ?? '');
        return await runBackgroundExpiryCycle(
          enabled: recurringExpiryDeliveryEnabled,
          ledger: const ReminderLedger(),
          credentials: ExistingSupabaseCredentialReader.forProject(project),
          project: project,
          publicKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
          client: client,
          runId: runId,
        );
      } finally {
        client.close();
      }
    },
  );
}

/// Future explicit consent required. OS may delay or skip an interval.
Future<bool> scheduleVerifiedExpiryWakeups() async {
  if (!recurringExpiryDeliveryEnabled || !Platform.isAndroid) return false;
  return await const MethodChannel(
        'refrigerator/reminder_work_v1',
      ).invokeMethod<bool>('schedule') ==
      true;
}
