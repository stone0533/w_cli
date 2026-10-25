import 'dart:convert';
import 'dart:io';

/// 发布前一致性检查。
///
///   dart run tool/release_check.dart            # 离线检查（CI 每次跑）
///   dart run tool/release_check.dart --strict   # 额外要求工作区干净（真正发布前）
///   dart run tool/release_check.dart --online   # 额外对比 pub.dev 上的最新版本
///
/// 检查项：
/// - `pubspec.yaml` 有 version，且 `lib/src/version.dart` 与之一致
/// - `CHANGELOG.md` 有 `## <version>` 段；若有未折叠的 `## Unreleased` 条目则提醒
/// - README 不硬编码版本号
/// - `--strict`：工作区干净、无未跟踪文件
/// - `--online`：对比 pub.dev 的 latest，报「仓库领先 / 落后」
/// - 版本段含 Breaking/Removed 但没有升 major 时提醒（semver）
Future<void> main(List<String> args) async {
  if (args.contains('-h') || args.contains('--help')) {
    stdout.writeln(
      '用法: dart run tool/release_check.dart [--strict] [--online]',
    );
    return;
  }
  final strict = args.contains('--strict');
  final online = args.contains('--online');

  var errors = 0;
  var warns = 0;

  void section(String title) => stdout.writeln('\n== $title');
  void ok(String message) => stdout.writeln('  ✓ $message');
  void warn(String message) {
    stdout.writeln('  ! $message');
    warns++;
  }

  void fail(String message) {
    stdout.writeln('  ✗ $message');
    errors++;
  }

  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('找不到 pubspec.yaml（请在仓库根目录运行）');
    exit(2);
  }
  final pubspecText = pubspec.readAsStringSync();
  final name = _regExp(r'^name:\s*(\S+)', pubspecText);
  final version = _regExp(r'^version:\s*(\S+)', pubspecText);

  section('版本');
  if (name == null || version == null) {
    fail('pubspec.yaml 缺 name 或 version');
    exit(1);
  }
  ok('$name $version');

  final versionDart = File('lib/src/version.dart');
  if (!versionDart.existsSync()) {
    fail('缺 lib/src/version.dart（跑 dart run tool/generate_version.dart）');
  } else {
    final declared = _regExp(
      r"const String version = '([^']+)'",
      versionDart.readAsStringSync(),
    );
    if (declared == version) {
      ok('version.dart 与 pubspec 一致');
    } else {
      fail(
        'version.dart 是 $declared，pubspec 是 $version（跑 tool/generate_version.dart）',
      );
    }
  }

  section('CHANGELOG');
  final changelog = File('CHANGELOG.md');
  if (!changelog.existsSync()) {
    fail('缺 CHANGELOG.md');
  } else {
    final text = changelog.readAsStringSync();
    final heading = RegExp(
      r'^##\s+' + RegExp.escape(version) + r'\s*$',
      multiLine: true,
    );
    if (heading.hasMatch(text)) {
      ok('有 ## $version 段');
    } else {
      fail('CHANGELOG 里没有 ## $version 段');
    }

    if (_unreleasedHasEntries(text)) {
      warn('CHANGELOG 还有未折叠的 ## Unreleased 条目（发版时应并入 $version）');
    } else {
      ok('没有未折叠的 Unreleased 条目');
    }

    if (_sectionHasBreaking(text, version)) {
      final major = int.tryParse(version.split('.').first) ?? 0;
      final rest = version.split('.').skip(1).join('.');
      if (major != 0 && rest != '0.0') {
        warn(
          '$version 的条目含 Breaking/Removed，但版本不是 major（严格 semver 应为 ${major + 1}.0.0）',
        );
      }
    }
  }

  section('README');
  final readme = File('README.md');
  if (!readme.existsSync()) {
    fail('缺 README.md');
  } else {
    final hardcoded = RegExp(
      r'当前\s*`?\d+\.\d+\.\d+`?',
    ).allMatches(readme.readAsStringSync());
    if (hardcoded.isEmpty) {
      ok('未硬编码版本号');
    } else {
      fail('README 里硬编码了版本号（${hardcoded.length} 处），以 pubspec / pub.dev 为准');
    }
  }

  if (strict) {
    section('工作区（--strict）');
    final tracked = Process.runSync('git', ['status', '--porcelain']);
    if (tracked.exitCode != 0) {
      warn('不是 git 仓库或 git 不可用，跳过工作区检查');
    } else {
      final dirty = (tracked.stdout as String).trim();
      if (dirty.isEmpty) {
        ok('已跟踪文件无未提交改动');
      } else {
        fail('有未提交改动：发布请从干净提交开始');
      }
      final untracked = Process.runSync('git', [
        'ls-files',
        '--others',
        '--exclude-standard',
      ]);
      final untrackedOut = (untracked.stdout as String).trim();
      if (untrackedOut.isEmpty) {
        ok('无未跟踪文件');
      } else {
        fail('存在未跟踪文件：${untrackedOut.split('\n').take(3).join(' ')}');
      }
    }
  }

  if (online) {
    section('pub.dev（--online）');
    final published = await _publishedVersion(name);
    if (published == null) {
      warn('取不到 pub.dev 上的版本（网络或包不存在），跳过比对');
    } else if (published == version) {
      ok('$name $version 已发布');
    } else if (_compare(version, published) > 0) {
      fail('仓库 $version > pub.dev $published —— 待发布');
    } else {
      fail('仓库 $version < pub.dev $published —— 仓库落后于线上');
    }
  }

  stdout.writeln('');
  if (errors > 0) {
    stderr.writeln('检查失败：$errors 项错误，$warns 条提醒');
    exit(1);
  }
  stdout.writeln('检查通过（$warns 条提醒）');
}

String? _regExp(String pattern, String input) =>
    RegExp(pattern, multiLine: true).firstMatch(input)?.group(1);

/// `## Unreleased` 段里还有 `- ` 条目
bool _unreleasedHasEntries(String changelog) {
  var inside = false;
  for (final line in changelog.split('\n')) {
    if (line.startsWith('## ')) {
      if (inside) {
        return false;
      }
      inside = line.trim() == '## Unreleased';
      continue;
    }
    if (inside && line.startsWith('- ')) {
      return true;
    }
  }
  return false;
}

/// 指定版本的段落里是否提到 Breaking / Removed
bool _sectionHasBreaking(String changelog, String version) {
  var inside = false;
  for (final line in changelog.split('\n')) {
    if (line.startsWith('## ')) {
      if (inside) {
        return false;
      }
      inside = line.trim() == '## $version';
      continue;
    }
    if (inside &&
        (line.contains('### Breaking') ||
            line.contains('### Removed') ||
            line.toLowerCase().contains('breaking'))) {
      return true;
    }
  }
  return false;
}

Future<String?> _publishedVersion(String name) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.getUrl(
      Uri.parse('https://pub.dev/api/packages/$name'),
    );
    final response = await request.close().timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      return null;
    }
    final body = await response.transform(utf8.decoder).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final latest = data['latest'] as Map<String, dynamic>?;
    return latest?['version'] as String?;
  } on Exception {
    return null;
  } finally {
    client.close(force: true);
  }
}

int _compare(String a, String b) {
  final left = a.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final right = b.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  for (var i = 0; i < 3; i++) {
    final l = i < left.length ? left[i] : 0;
    final r = i < right.length ? right[i] : 0;
    if (l != r) {
      return l - r;
    }
  }
  return 0;
}
