import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdateService {
static bool _checkedThisSession = false;

static Future<void> checkForUpdate(BuildContext context) async {
if (_checkedThisSession) return;
_checkedThisSession = true;

try {
final packageInfo = await PackageInfo.fromPlatform();
final int currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 1;

final doc = await FirebaseFirestore.instance
.collection('app_config')
.doc('android_update')
.get(const GetOptions(source: Source.server));

if (!doc.exists || doc.data() == null) {
if (context.mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('DEBUG: android_update doc nahi mila')),
);
}
return;
}

final data = doc.data()!;
final int latestBuild = ((data['latest_build'] ?? 1) as num).toInt();
final String apkUrl = (data['apk_url'] ?? '').toString().trim();
final bool forceUpdate = (data['force_update'] ?? false) as bool;
final String message = (data['message'] ??
'BahiSaathi का नया वर्ज़न उपलब्ध है। ऐप के अंदर ही तुरंत अपडेट करें।')
.toString();

if (latestBuild > currentBuildNumber && apkUrl.isNotEmpty) {
if (!context.mounted) return;
_showInAppUpdateDialog(
context: context,
apkUrl: apkUrl,
latestBuild: latestBuild,
message: message,
forceUpdate: forceUpdate,
);
} else {
if (context.mounted) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(
'DEBUG: Phone Build=$currentBuildNumber | Server Build=$latestBuild',
),
duration: const Duration(seconds: 5),
),
);
}
}
} catch (e) {
if (context.mounted) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('DEBUG ERROR: $e'),
backgroundColor: Colors.red,
duration: const Duration(seconds: 6),
),
);
}
}
}
static void _showInAppUpdateDialog({
  required BuildContext context,
  required String apkUrl,
  required int latestBuild,
  required String message,
  required bool forceUpdate,
}) {
  bool isDownloading = false;
  double progress = 0.0;
  String statusText = '';
  bool hasError = false;
  String? readyApkPath;

  showDialog(
    context: context,
    barrierDismissible: !forceUpdate,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> triggerInstall(String path) async {
            try {
              if (!ctx.mounted) return;
              setDialogState(() {
                isDownloading = false;
                hasError = false;
                statusText = 'इंस्टॉलर खुल रहा है... कृपया Update दबाएं।';
              });

              final result = await OpenFilex.open(
                path,
                type: 'application/vnd.android.package-archive',
              );

              if (result.type != ResultType.done && ctx.mounted) {
                setDialogState(() {
                  hasError = true;
                  statusText =
                  'कृपया Settings से BahiSaathi के लिए "Install unknown apps" चालू करें (${result.message})।';
                });
              }
            } catch (e) {
              if (!ctx.mounted) return;
              setDialogState(() {
                isDownloading = false;
                hasError = true;
                statusText = 'इंस्टॉल त्रुटि: $e';
              });
            }
          }

          Future<void> startUpdateFlow() async {
            if (readyApkPath != null && await File(readyApkPath!).exists()) {
              await triggerInstall(readyApkPath!);
              return;
            }

            setDialogState(() {
              isDownloading = true;
              hasError = false;
              progress = 0.0;
              statusText = 'अपडेट की तैयारी हो रही है...';
            });

            HttpClient? client;
            try {
              final dir = await getTemporaryDirectory();
              final filePath = '${dir.path}/bahisaathi_v$latestBuild.apk';
              final file = File(filePath);
              if (await file.exists()) {
                try {
                  await file.delete();
                } catch (_) {}
              }

              client = HttpClient()
                ..connectionTimeout = const Duration(seconds: 45)
                ..idleTimeout = const Duration(seconds: 45);

              final request = await client.getUrl(Uri.parse(apkUrl));
              request.followRedirects = true;
              request.maxRedirects = 5;
              final response = await request.close();

              if (response.statusCode != 200) {
                throw Exception('सर्वर त्रुटि (${response.statusCode})');
              }

              final totalBytes = response.contentLength;
              int receivedBytes = 0;
              final sink = file.openWrite();

              await for (final chunk in response) {
                sink.add(chunk);
                receivedBytes += chunk.length;
                if (ctx.mounted) {
                  if (totalBytes > 0) {
                    final pct = (receivedBytes / totalBytes).clamp(0.0, 1.0);
                    setDialogState(() {
                      progress = pct;
                      statusText =
                      'डाउनलोड हो रहा है... ${(pct * 100).toStringAsFixed(0)}%';
                    });
                  } else {
                    final mb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
                    setDialogState(() {
                      progress = 0.0;
                      statusText = 'डाउनलोड हो रहा है... $mb MB';
                    });
                  }
                }
              }

              await sink.flush();
              await sink.close();
              client.close();
              client = null;

              final fileLen = await file.length();
              if (fileLen < 100 * 1024) {
                if (await file.exists()) {
                  await file.delete();
                }
                throw Exception('डाउनलोड फ़ाइल अधूरी है ($fileLen bytes)।');
              }

              readyApkPath = filePath;
              await triggerInstall(filePath);
            } catch (e) {
              client?.close();
              if (!ctx.mounted) return;
              setDialogState(() {
                isDownloading = false;
                hasError = true;
                statusText = 'डाउनलोड में समस्या आई: $e';
              });
            }
          }

          return PopScope(
            canPop: !forceUpdate && !isDownloading,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Row(
                children: [
                  Icon(Icons.system_update_rounded, color: Color(0xFF0B5318)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'नया अपडेट उपलब्ध है',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: const TextStyle(fontSize: 14.5, height: 1.4),
                  ),
                  if (isDownloading || statusText.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    if (isDownloading)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress > 0 ? progress : null,
                          minHeight: 8,
                          backgroundColor: Colors.green.shade100,
                          color: const Color(0xFF0B5318),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: hasError
                            ? Colors.red.shade700
                            : const Color(0xFF0B5318),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                if (!forceUpdate && !isDownloading)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'बाद में',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                if (hasError && !isDownloading)
                  TextButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: apkUrl));
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('डाउनलोड लिंक कॉपी हो गया है!'),
                          ),
                        );
                      }
                    },
                    child: const Text('लिंक कॉपी करें'),
                  ),
                if (!isDownloading)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B5318),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: startUpdateFlow,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(
                      readyApkPath != null
                          ? 'इंस्टॉल करें'
                          : 'अभी अपडेट करें',
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}
}
