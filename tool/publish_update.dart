import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

String _host(String sub) => [sub, 'googleapis', 'com'].join('.');
String _ghApi() => ['api', 'github', 'com'].join('.');
String _ghUploads() => ['uploads', 'github', 'com'].join('.');

Future<void> main(List<String> args) async {
  final releaseMessage = args.isNotEmpty
      ? args.join(' ')
      : 'BahiSaathi का नया अपडेट उपलब्ध है! बेहतर स्पीड और नए फ़ीचर्स के लिए अभी अपडेट करें।';

  // 1. Key files check
  final keyFile = File('firebase-admin-key.json');
  final ghFile = File('github-config.json');
  if (!keyFile.existsSync() || !ghFile.existsSync()) {
    print('❌ Error: "firebase-admin-key.json" aur "github-config.json" dono project folder mein hone chahiye!');
    exit(1);
  }
  final keyData = jsonDecode(await keyFile.readAsString()) as Map<String, dynamic>;
  final projectId = keyData['project_id'] as String;
  final clientEmail = keyData['client_email'] as String;
  final privateKeyPem = keyData['private_key'] as String;

  final ghData = jsonDecode(await ghFile.readAsString()) as Map<String, dynamic>;
  final ghOwner = (ghData['owner'] as String).trim();
  final ghRepo = (ghData['repo'] as String).trim();
  final ghToken = (ghData['token'] as String).trim();

  // 2. pubspec.yaml ka build number (+1) badhayein
  print('🚀 1. pubspec.yaml ka build number badha rahe hain...');
  final pubspecFile = File('pubspec.yaml');
  String pubspec = await pubspecFile.readAsString();
  final versionRegex = RegExp(r'version:\s*(\d+\.\d+\.\d+)\+(\d+)');
  final match = versionRegex.firstMatch(pubspec);

  if (match == null) {
    print('❌ pubspec.yaml mein version line nahi mili!');
    exit(1);
  }

  final versionName = match.group(1)!;
  final oldBuild = int.parse(match.group(2)!);
  final newBuild = oldBuild + 1;

  pubspec = pubspec.replaceFirst(versionRegex, 'version: $versionName+$newBuild');
  await pubspecFile.writeAsString(pubspec);
  print('✅ Naya Version: $versionName+$newBuild');

  // 3. Release APK Build karein
  print('🔨 2. Release APK build ho raha hai (30-60 second lagenge)...');
  final buildResult = await Process.run(
    'flutter',
    ['build', 'apk', '--split-per-abi'],
    runInShell: true,
  );
  if (buildResult.exitCode != 0) {
    print('❌ APK Build fail ho gaya:\n${buildResult.stderr}');
    exit(1);
  }
  final apkFile = File('build/app/outputs/flutter-apk/app-arm64-v8a-release.apk');
  if (!apkFile.existsSync()) {
    print('❌ app-arm64-v8a-release.apk nahi mili!');
    exit(1);
  }
  print('✅ APK taiyar hai (${(apkFile.lengthSync() / (1024 * 1024)).toStringAsFixed(1)} MB)');

  // 4. GitHub Release banayein aur APK upload karein
  print('🐙 3. GitHub Releases par naya APK upload ho raha hai...');
  final httpClient = HttpClient()
    ..connectionTimeout = const Duration(minutes: 5)
    ..idleTimeout = const Duration(minutes: 5);

  final tag = 'v$versionName-b$newBuild';
  final createRelUrl = Uri.https(_ghApi(), '/repos/$ghOwner/$ghRepo/releases');
  final relReq = await httpClient.postUrl(createRelUrl);
  relReq.headers.set('Authorization', 'Bearer $ghToken');
  relReq.headers.set('Accept', 'application/vnd.github+json');
  relReq.headers.set('User-Agent', 'BahiSaathi-Release-Bot');
  relReq.headers.set('Content-Type', 'application/json; charset=utf-8');
  relReq.add(utf8.encode(jsonEncode({
    'tag_name': tag,
    'name': 'BahiSaathi $versionName (Build $newBuild)',
    'body': releaseMessage,
    'draft': false,
    'prerelease': false,
  })));

  final relRes = await relReq.close();
  final relBody = await relRes.transform(utf8.decoder).join();
  if (relRes.statusCode != 201) {
    print('❌ GitHub Release Create Fail (${relRes.statusCode}): $relBody');
    httpClient.close();
    exit(1);
  }

  final relJson = jsonDecode(relBody) as Map<String, dynamic>;
  final releaseId = relJson['id'];
  final assetName = 'bahisaathi_v$newBuild.apk';

  final uploadAssetUrl = Uri.https(
    _ghUploads(),
    '/repos/$ghOwner/$ghRepo/releases/$releaseId/assets',
    {'name': assetName},
  );
  final apkBytes = await apkFile.readAsBytes();
  final assetReq = await httpClient.postUrl(uploadAssetUrl);
  assetReq.headers.set('Authorization', 'Bearer $ghToken');
  assetReq.headers.set('Accept', 'application/vnd.github+json');
  assetReq.headers.set('User-Agent', 'BahiSaathi-Release-Bot');
  assetReq.headers.set('Content-Type', 'application/vnd.android.package-archive');
  assetReq.contentLength = apkBytes.length;
  assetReq.add(apkBytes);

  final assetRes = await assetReq.close();
  final assetBody = await assetRes.transform(utf8.decoder).join();
  if (assetRes.statusCode != 201) {
    print('❌ GitHub APK Upload Fail (${assetRes.statusCode}): $assetBody');
    httpClient.close();
    exit(1);
  }

  final assetJson = jsonDecode(assetBody) as Map<String, dynamic>;
  final directDownloadUrl = assetJson['browser_download_url'] as String;
  print('✅ GitHub par APK upload ho gaya!');

  // 5. Firestore mein latest_build aur naya GitHub URL update karein
  print('🔥 4. Sabhi users ke liye Firestore update kar rahe hain...');
  final accessToken = await _getGoogleAccessToken(clientEmail, privateKeyPem);
  final firestoreUrl = Uri.https(
    _host('firestore'),
    '/v1/projects/$projectId/databases/(default)/documents/app_config/android_update',
  );

   final fsReq = await httpClient.patchUrl(firestoreUrl);
  fsReq.headers.set('Authorization', 'Bearer $accessToken');
  fsReq.headers.set('Content-Type', 'application/json; charset=utf-8');
  fsReq.add(utf8.encode(jsonEncode({
    'fields': {
      'latest_build': {'integerValue': '$newBuild'},
      'apk_url': {'stringValue': directDownloadUrl},
      'force_update': {'booleanValue': false},
      'message': {'stringValue': releaseMessage},
    }
  })));
  final fsRes = await fsReq.close();
  final fsBody = await fsRes.transform(utf8.decoder).join();
  httpClient.close();

  if (fsRes.statusCode != 200) {
    print('❌ Firestore Update Fail (${fsRes.statusCode}): $fsBody');
    exit(1);
  }

  // 6. GitHub par latest source code push karein
  print('📦 5. GitHub par latest source code push kar rahe hain...');
  await Process.run('git', ['add', '.'], runInShell: true);
  await Process.run('git', ['commit', '-m', 'Auto update build #$newBuild'], runInShell: true);
  var pushRes = await Process.run('git', ['push', 'origin', 'main'], runInShell: true);

  if (pushRes.exitCode == 0) {
    print('✅ GitHub par poora naya code bhi push ho gaya!');
  } else {
    print('⚠️ Git push error: ${pushRes.stderr}');
  }

  print('\n🎉 100% AUTO DONE! Build #$newBuild GitHub par upload hokar sabhi users ke phone par LIVE ho gaya hai!');

 }


Future<String> _getGoogleAccessToken(String clientEmail, String pem) async {
  final tokenUri = Uri.https(_host('oauth2'), '/token');
  final wwwHost = _host('www');
  final scope1 = Uri.https(wwwHost, '/auth/cloud-platform').toString();
  final scope2 = Uri.https(wwwHost, '/auth/datastore').toString();
  final scope3 = Uri.https(wwwHost, '/auth/drive').toString();


  final client = HttpClient();
  final timeReq = await client.headUrl(tokenUri);
  final timeRes = await timeReq.close();
  await timeRes.drain();
  final dateHeader = timeRes.headers.value(HttpHeaders.dateHeader);
  final serverTime = dateHeader != null
      ? HttpDate.parse(dateHeader).toUtc()
      : DateTime.now().toUtc();
  final now = serverTime.millisecondsSinceEpoch ~/ 1000;

  final header = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'RS256', 'typ': 'JWT'})))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({
    'iss': clientEmail,
    'scope': '$scope1 $scope2 $scope3',

    'aud': tokenUri.toString(),
    'iat': now,
    'exp': now + 3500,
  })))
      .replaceAll('=', '');

  final signingInput = '$header.$payload';
  final sigBytes = _signRs256PureDart(utf8.encode(signingInput), pem);
  final signature = base64Url.encode(sigBytes).replaceAll('=', '');
  final jwt = '$signingInput.$signature';

  final req = await client.postUrl(tokenUri);
  req.headers.set('Content-Type', 'application/x-www-form-urlencoded');
  final formBody =
      'grant_type=${Uri.encodeQueryComponent('urn:ietf:params:oauth:grant-type:jwt-bearer')}&assertion=${Uri.encodeQueryComponent(jwt)}';
  req.write(formBody);

  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  client.close();

  if (res.statusCode != 200) {
    throw Exception('Google OAuth Failed (${res.statusCode}): $body');
  }

  final tokenJson = jsonDecode(body) as Map<String, dynamic>;
  return tokenJson['access_token'] as String;
}

Uint8List _signRs256PureDart(List<int> message, String pem) {
  final cleanPem = pem
      .replaceAll(r'\n', '\n')
      .replaceAll('-----BEGIN PRIVATE KEY-----', '')
      .replaceAll('-----END PRIVATE KEY-----', '')
      .replaceAll(RegExp(r'\s+'), '');
  final pkcs8 = base64.decode(cleanPem);

  final top = _readAsn1(pkcs8, 0);
  int offset = top.contentOffset;
  offset = _readAsn1(pkcs8, offset).nextOffset;
  offset = _readAsn1(pkcs8, offset).nextOffset;
  final octets = _readAsn1(pkcs8, offset);
  final pkcs1 = pkcs8.sublist(octets.contentOffset, octets.nextOffset);

  final rsaSeq = _readAsn1(pkcs1, 0);
  int p = rsaSeq.contentOffset;
  p = _readAsn1(pkcs1, p).nextOffset;
  final nObj = _readAsn1(pkcs1, p);
  final n = _bytesToBigInt(pkcs1.sublist(nObj.contentOffset, nObj.nextOffset));
  p = nObj.nextOffset;
  p = _readAsn1(pkcs1, p).nextOffset;
  final dObj = _readAsn1(pkcs1, p);
  final d = _bytesToBigInt(pkcs1.sublist(dObj.contentOffset, dObj.nextOffset));

  final digest = _sha256(Uint8List.fromList(message));
  final digestInfoPrefix = <int>[
    0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01,
    0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20
  ];
  final t = <int>[...digestInfoPrefix, ...digest];
  final k = (n.bitLength + 7) ~/ 8;
  final psLen = k - t.length - 3;
  final em = Uint8List.fromList([0x00, 0x01, ...List.filled(psLen, 0xff), 0x00, ...t]);

  final m = _bytesToBigInt(em);
  final s = m.modPow(d, n);
  return _bigIntToBytes(s, k);
}

class _Asn1Obj {
  final int contentOffset;
  final int nextOffset;
  _Asn1Obj(this.contentOffset, this.nextOffset);
}

_Asn1Obj _readAsn1(Uint8List data, int offset) {
  int pos = offset + 1;
  int len = data[pos++];
  if ((len & 0x80) != 0) {
    final numBytes = len & 0x7f;
    len = 0;
    for (int i = 0; i < numBytes; i++) {
      len = (len << 8) | data[pos++];
    }
  }
  return _Asn1Obj(pos, pos + len);
}

BigInt _bytesToBigInt(Uint8List bytes) {
  BigInt result = BigInt.zero;
  for (final b in bytes) {
    result = (result << 8) | BigInt.from(b);
  }
  return result;
}

Uint8List _bigIntToBytes(BigInt number, int length) {
  final out = Uint8List(length);
  var n = number;
  for (int i = length - 1; i >= 0; i--) {
    out[i] = (n & BigInt.from(0xff)).toInt();
    n = n >> 8;
  }
  return out;
}

Uint8List _sha256(Uint8List data) {
  const k = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
  ];
  var h0 = 0x6a09e667, h1 = 0xbb67ae85, h2 = 0x3c6ef372, h3 = 0xa54ff53a;
  var h4 = 0x510e527f, h5 = 0x9b05688c, h6 = 0x1f83d9ab, h7 = 0x5be0cd19;
  int rotr(int x, int n) => ((x & 0xffffffff) >>> n) | ((x << (32 - n)) & 0xffffffff);
  final bitLen = data.length * 8;
  final padLen = ((data.length + 8) ~/ 64 + 1) * 64;
  final padded = Uint8List(padLen);
  padded.setAll(0, data);
  padded[data.length] = 0x80;
  final bd = ByteData.view(padded.buffer);
  bd.setUint64(padLen - 8, bitLen, Endian.big);
  final w = Uint32List(64);
  for (int offset = 0; offset < padLen; offset += 64) {
    for (int i = 0; i < 16; i++) {
      w[i] = bd.getUint32(offset + i * 4, Endian.big);
    }
    for (int i = 16; i < 64; i++) {
      final s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >>> 3);
      final s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >>> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
    }
    var a = h0, b = h1, c = h2, d = h3, e = h4, f = h5, g = h6, h = h7;
    for (int i = 0; i < 64; i++) {
      final s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
      final ch = (e & f) ^ ((~e) & g);
      final temp1 = (h + s1 + ch + k[i] + w[i]) & 0xffffffff;
      final s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (s0 + maj) & 0xffffffff;
      h = g; g = f; f = e; e = (d + temp1) & 0xffffffff;
      d = c; c = b; b = a; a = (temp1 + temp2) & 0xffffffff;
    }
    h0 = (h0 + a) & 0xffffffff; h1 = (h1 + b) & 0xffffffff;
    h2 = (h2 + c) & 0xffffffff; h3 = (h3 + d) & 0xffffffff;
    h4 = (h4 + e) & 0xffffffff; h5 = (h5 + f) & 0xffffffff;
    h6 = (h6 + g) & 0xffffffff; h7 = (h7 + h) & 0xffffffff;
  }
  final out = Uint8List(32);
  final outBd = ByteData.view(out.buffer);
  outBd.setUint32(0, h0, Endian.big); outBd.setUint32(4, h1, Endian.big);
  outBd.setUint32(8, h2, Endian.big); outBd.setUint32(12, h3, Endian.big);
  outBd.setUint32(16, h4, Endian.big); outBd.setUint32(20, h5, Endian.big);
  outBd.setUint32(24, h6, Endian.big); outBd.setUint32(28, h7, Endian.big);
  return out;
}
