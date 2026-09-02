#!/usr/bin/env dart
/**
 * Branch Coverage Enforcer for Flutter/Dart
 *
 * Enforces coverage requirements (mirrored from Python agent):
 * - Line coverage: Pragmatic targets (50-80% based on code criticality)
 * - Branch coverage: Strict 100% for all new/changed code
 *
 * Philosophy: Every decision path should be tested. If a branch exists in your code,
 * there's a reason - test both outcomes!
 */

import 'dart:io';
import 'dart:convert';

// Line coverage thresholds by path pattern (pragmatic)
final lineCoverageRules = [
  CoverageRule('*/payment*', 80, 'Payment Module (Critical)'),
  CoverageRule('*/payout*', 80, 'Payout Module (Critical)'),
  CoverageRule('*/wallet*', 80, 'Wallet Module (Critical)'),
  CoverageRule('*/calculator*', 80, 'Calculator Module (Critical)'),
  CoverageRule('*/services/*', 70, 'Service Layer'),
  CoverageRule('*/flow*', 70, 'Flow Logic'),
  CoverageRule('*/models/*', 60, 'Models'),
  CoverageRule('*/pages/*', 60, 'UI Pages'),
  CoverageRule('*/views/*', 60, 'Views'),
  CoverageRule('*/widgets/*', 50, 'Widgets'),
  CoverageRule('*/providers/*', 70, 'State Management'),
];

// Branch coverage: STRICT 100% for changed code
const branchCoverageTarget = 100;
const branchCoverageTolerance = 0; // No tolerance - all branches must be tested

// Files to exclude
final excludePatterns = [
  '**/main.dart',
  '**/*_generated.dart',
  '**/*.g.dart',
  '**/*.freezed.dart',
  '**/constants/*',
];

class CoverageRule {
  final String pattern;
  final int threshold;
  final String description;

  CoverageRule(this.pattern, this.threshold, this.description);

  bool matches(String filePath) {
    final pattern = this.pattern.replaceAll('*', '.*');
    return RegExp(pattern).hasMatch(filePath);
  }
}

class CoverageStats {
  final String filename;
  int linesFound = 0;
  int linesHit = 0;
  int branchesFound = 0;
  int branchesHit = 0;

  CoverageStats(this.filename);

  double get lineCoverage => linesFound > 0 ? (linesHit / linesFound * 100) : 100.0;
  double get branchCoverage => branchesFound > 0 ? (branchesHit / branchesFound * 100) : 100.0;
  int get missingBranches => branchesFound - branchesHit;
}

Future<Map<String, CoverageStats>> parseLcovFile(String lcovFile) async {
  final coverage = <String, CoverageStats>{};
  final lines = await File(lcovFile).readAsLines();

  CoverageStats? current;

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      // Source file
      final filename = line.substring(3);
      current = CoverageStats(filename);
      coverage[filename] = current;
    } else if (line.startsWith('LF:')) {
      // Lines found
      current?.linesFound = int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      // Lines hit
      current?.linesHit = int.parse(line.substring(3));
    } else if (line.startsWith('BRF:')) {
      // Branches found
      current?.branchesFound = int.parse(line.substring(4));
    } else if (line.startsWith('BRH:')) {
      // Branches hit
      current?.branchesHit = int.parse(line.substring(4));
    }
  }

  return coverage;
}

bool shouldExclude(String filePath) {
  for (final pattern in excludePatterns) {
    final regexPattern = pattern.replaceAll('**/', '').replaceAll('*', '.*');
    if (RegExp(regexPattern).hasMatch(filePath)) {
      return true;
    }
  }
  return false;
}

(int, String) getLineThreshold(String filePath) {
  for (final rule in lineCoverageRules) {
    if (rule.matches(filePath)) {
      return (rule.threshold, rule.description);
    }
  }
  return (50, 'Default');
}

Future<List<String>> getChangedFiles() async {
  try {
    final result = await Process.run(
      'git',
      ['diff', 'origin/main', '--name-only'],
    );

    if (result.exitCode == 0) {
      final files = (result.stdout as String)
          .split('\n')
          .where((f) => f.startsWith('lib/'))
          .toList();
      return files;
    }
  } catch (e) {
    print('⚠️  Could not get changed files from git. Checking all files.');
  }
  return [];
}

Future<bool> checkCoverage(Map<String, CoverageStats> coverageData, List<String> changedFiles) async {
  print('=' * 80);
  print('📊 Coverage Analysis Report');
  print('=' * 80);
  print('');
  print('Strategy:');
  print('  • Line Coverage: Pragmatic targets (50-80% based on code type)');
  print('  • Branch Coverage: Strict 100% for all new/changed code');
  print('');

  var allPassed = true;
  final lineFailures = <(String, CoverageStats, int, String)>[];
  final branchFailures = <(String, CoverageStats)>[];

  final changedFileSet = Set<String>.from(changedFiles);

  print('🔍 Changed Files (Strict Branch Coverage):');
  print('-' * 80);

  var hasChangedFiles = false;

  for (final entry in coverageData.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
    final filePath = entry.key;
    final stats = entry.value;

    if (shouldExclude(filePath)) continue;

    // Check if this is a changed file
    final isChanged = changedFiles.any((cf) => filePath.endsWith(cf));

    if (!isChanged) continue;

    hasChangedFiles = true;

    final (lineThreshold, category) = getLineThreshold(filePath);
    final linePassed = stats.lineCoverage >= lineThreshold;
    final branchPassed = stats.branchCoverage >= branchCoverageTarget;

    // Status symbols
    final lineStatus = linePassed ? '✅' : '❌';
    final branchStatus = branchPassed ? '✅' : '❌';

    final fileShort = filePath.replaceFirst('lib/', '');

    print('');
    print('  $fileShort');
    print('    Category: $category');
    print('    $lineStatus Line Coverage:   ${stats.lineCoverage.toStringAsFixed(2)}% (target: $lineThreshold%)');
    print('    $branchStatus Branch Coverage: ${stats.branchCoverage.toStringAsFixed(2)}% (target: $branchCoverageTarget%)');

    if (stats.branchesFound > 0) {
      stdout.write('       Branches: ${stats.branchesHit}/${stats.branchesFound} covered');
      if (stats.missingBranches > 0) {
        print(' (${stats.missingBranches} missing) ⚠️');
      } else {
        print(' ✅');
      }
    }

    if (!linePassed) {
      allPassed = false;
      lineFailures.add((filePath, stats, lineThreshold, category));
    }

    if (!branchPassed && stats.branchesFound > 0) {
      allPassed = false;
      branchFailures.add((filePath, stats));
    }
  }

  if (!hasChangedFiles) {
    print('  No changed files detected. Showing all files...');
    print('');
  }

  // Print other files summary
  print('');
  print('📋 Other Files (Existing Code):');
  print('-' * 80);

  var otherFilesChecked = 0;
  for (final entry in coverageData.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
    final filePath = entry.key;
    final stats = entry.value;

    if (shouldExclude(filePath)) continue;

    final isChanged = changedFiles.any((cf) => filePath.endsWith(cf));
    if (isChanged) continue;

    otherFilesChecked++;
    if (otherFilesChecked <= 5) {
      // Show first 5
      final fileShort = filePath.split('/').last;
      final line = '  ${fileShort.padRight(40)} Line: ${stats.lineCoverage.toStringAsFixed(1).padLeft(5)}%  Branch: ${stats.branchCoverage.toStringAsFixed(1).padLeft(5)}%';
      print(line);
    }
  }

  if (otherFilesChecked > 5) {
    print('  ... and ${otherFilesChecked - 5} more files');
  }

  // Summary
  print('');
  print('=' * 80);
  print('📈 Summary');
  print('=' * 80);

  if (lineFailures.isNotEmpty) {
    print('');
    print('❌ Line Coverage Failures (${lineFailures.length}):');
    for (final (filePath, stats, threshold, category) in lineFailures) {
      final gap = threshold - stats.lineCoverage;
      final fileName = filePath.split('/').last;
      print('  • $fileName');
      print('    ${stats.lineCoverage.toStringAsFixed(1)}% coverage (need $threshold%, gap: ${gap.toStringAsFixed(1)}%)');
    }
  }

  if (branchFailures.isNotEmpty) {
    print('');
    print('❌ Branch Coverage Failures (${branchFailures.length}):');
    print('   All branches in changed code MUST be tested!');
    print('');
    for (final (filePath, stats) in branchFailures) {
      final fileName = filePath.split('/').last;
      print('  • $fileName');
      print('    ${stats.branchesHit}/${stats.branchesFound} branches covered (${stats.branchCoverage.toStringAsFixed(1)}%)');
      print('    Missing: ${stats.missingBranches} branch(es)');
      print('');
    }
  }

  if (allPassed) {
    print('');
    print('✅ All coverage requirements met!');
    print('   • Line coverage meets targets for changed files');
    print('   • 100% branch coverage achieved for changed files');
    return true;
  } else {
    print('');
    print('💡 How to fix:');
    if (branchFailures.isNotEmpty) {
      print('   • Review each if/else and ensure both paths are tested');
      print('   • Check loops - test when they execute and when they don\'t');
      print('   • Test exception handlers (try/catch blocks)');
      print('   • Use \'make coverage-report\' to see which branches are missing');
    }
    if (lineFailures.isNotEmpty) {
      print('   • Add tests for the missing lines in critical code');
    }
    print('');
    return false;
  }
}

Future<void> main() async {
  const coverageFile = 'coverage/lcov.info';

  if (!await File(coverageFile).exists()) {
    print('❌ Coverage file not found: $coverageFile');
    print('Run: make test-cov');
    exit(1);
  }

  print('🔍 Analyzing coverage with strict branch requirements...');
  print('');

  final coverageData = await parseLcovFile(coverageFile);
  final changedFiles = await getChangedFiles();

  if (changedFiles.isEmpty) {
    print('⚠️  No changed files detected. Checking all files.');
  }

  final passed = await checkCoverage(coverageData, changedFiles);

  exit(passed ? 0 : 1);
}
