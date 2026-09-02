#!/usr/bin/env dart
/**
 * Unit Test Agent V2.1 for Flutter/Dart - Brownfield-Safe Test Generation
 *
 * This agent mirrors the Python unit test agent philosophy and adds critical
 * brownfield safety features to prevent regression issues.
 *
 * KEY FEATURES:
 * 1. Analyzes Dart modules (enums, extensions, classes, functions)
 * 2. Detects: factory constructors, static methods, conditional logic
 * 3. Generates comprehensive unit tests using AAA pattern + builder pattern
 * 4. **BROWNFIELD SAFETY**: Runs existing tests before overwriting
 * 5. **REGRESSION PREVENTION**: Fails if existing tests break
 * 6. Compatible with all AI IDEs (Claude Code, Cursor, Windsurf, etc.)
 *
 * BROWNFIELD WORKFLOW (V2.1+):
 * - Greenfield (no existing tests): Generates autonomously ✅
 * - Brownfield (existing tests):
 *   1. Runs existing tests first
 *   2. If FAIL → STOPS and warns developer (prevents regression)
 *   3. If PASS → Asks for confirmation before overwriting
 *
 * COVERAGE PHILOSOPHY (from Python agent):
 * - ✅ 100% Branch Coverage (NON-NEGOTIABLE) - Every if/else/try/catch must be tested
 * - 📊 Pragmatic Line Coverage based on criticality:
 *   * Critical modules (payment, wallet): 80%
 *   * Business logic (services): 70%
 *   * UI/Pages: 60%
 *   * Models: 60%
 *   * Widgets: 50%
 * - Fewer, comprehensive tests over many small tests
 *
 * Usage:
 *   dart scripts/unit_test_agent.dart lib/services/payment_service.dart
 *   dart scripts/unit_test_agent.dart lib/models/  # All files in directory
 *
 * AI IDE Compatibility:
 *   ✅ Claude Code (Anthropic)
 *   ✅ Cursor (Anysphere)
 *   ✅ Windsurf (Codeium)
 *   ✅ GitHub Copilot
 *   ✅ Any IDE with Dart runtime
 */

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

class DartModuleAnalyzer {
  final String modulePath;
  final String moduleContent;

  DartModuleAnalyzer(this.modulePath) : moduleContent = File(modulePath).readAsStringSync();

  Map<String, dynamic> analyze() {
    return {
      'classes': _extractClasses(),
      'enums': _extractEnums(),
      'extensions': _extractExtensions(),
      'functions': _extractFunctions(),
      'imports': _extractImports(),
      'module_path': modulePath,
      'module_name': path.basenameWithoutExtension(modulePath),
      'module_content': moduleContent,
    };
  }

  List<Map<String, dynamic>> _extractClasses() {
    final classes = <Map<String, dynamic>>[];
    final classRegex = RegExp(r'class\s+(\w+)(?:\s+extends\s+(\w+))?(?:\s+with\s+[\w,\s]+)?(?:\s+implements\s+[\w,\s]+)?\s*{', multiLine: true);

    for (final match in classRegex.allMatches(moduleContent)) {
      final className = match.group(1)!;
      final baseClass = match.group(2);

      // Extract methods for this class
      final methods = _extractMethodsForClass(className, match.start);

      classes.add({
        'name': className,
        'methods': methods,
        'bases': baseClass != null ? [baseClass] : [],
        'line_number': _getLineNumber(match.start),
      });
    }

    return classes;
  }

  List<Map<String, dynamic>> _extractEnums() {
    final enums = <Map<String, dynamic>>[];
    final enumRegex = RegExp(r'enum\s+(\w+)\s*{([^}]+)}', multiLine: true);

    for (final match in enumRegex.allMatches(moduleContent)) {
      final enumName = match.group(1)!;
      final enumBody = match.group(2)!;

      // Extract enum values
      final values = <String>[];
      final valueRegex = RegExp(r'(\w+)(?:,|;|\s|$)');
      for (final valueMatch in valueRegex.allMatches(enumBody)) {
        final value = valueMatch.group(1)!;
        if (value.isNotEmpty && !value.startsWith('_')) {
          values.add(value);
        }
      }

      enums.add({
        'name': enumName,
        'values': values,
        'line_number': _getLineNumber(match.start),
      });
    }

    return enums;
  }

  List<Map<String, dynamic>> _extractExtensions() {
    final extensions = <Map<String, dynamic>>[];
    final extensionRegex = RegExp(r'extension\s+(\w+)\s+on\s+(\w+)\s*{', multiLine: true);

    for (final match in extensionRegex.allMatches(moduleContent)) {
      final extensionName = match.group(1)!;
      final targetType = match.group(2)!;

      // Extract extension methods and getters
      final methods = _extractExtensionMembers(extensionName, match.start);

      extensions.add({
        'name': extensionName,
        'target_type': targetType,
        'methods': methods,
        'line_number': _getLineNumber(match.start),
      });
    }

    return extensions;
  }

  List<Map<String, dynamic>> _extractExtensionMembers(String extensionName, int extensionStart) {
    final members = <Map<String, dynamic>>[];

    // Find extension body
    final extensionBodyStart = moduleContent.indexOf('{', extensionStart);
    final extensionBodyEnd = _findMatchingBrace(extensionBodyStart);
    final extensionBody = moduleContent.substring(extensionBodyStart, extensionBodyEnd);

    // Extract static methods
    final staticMethodRegex = RegExp(r'static\s+(?:Future<\w+>|FutureOr<\w+>|\w+)\s+(\w+)\s*\([^)]*\)(?:\s+async)?\s*{', multiLine: true);
    for (final match in staticMethodRegex.allMatches(extensionBody)) {
      final methodName = match.group(1)!;
      if (methodName.startsWith('_')) continue;

      final branches = _countBranchesInText(extensionBody.substring(match.start));
      members.add({
        'name': methodName,
        'is_static': true,
        'is_getter': false,
        'branches': branches,
        'line_number': _getLineNumber(extensionBodyStart + match.start),
      });
    }

    // Extract getters
    final getterRegex = RegExp(r'(?:Future<\w+>|FutureOr<\w+>|\w+)\s+get\s+(\w+)\s*{', multiLine: true);
    for (final match in getterRegex.allMatches(extensionBody)) {
      final getterName = match.group(1)!;
      if (getterName.startsWith('_')) continue;

      final branches = _countBranchesInText(extensionBody.substring(match.start));
      members.add({
        'name': getterName,
        'is_static': false,
        'is_getter': true,
        'branches': branches,
        'line_number': _getLineNumber(extensionBodyStart + match.start),
      });
    }

    // Extract regular methods
    final methodRegex = RegExp(r'(?:Future<\w+>|FutureOr<\w+>|\w+)\s+(\w+)\s*\([^)]*\)(?:\s+async)?\s*{', multiLine: true);
    for (final match in methodRegex.allMatches(extensionBody)) {
      final methodName = match.group(1)!;
      if (methodName.startsWith('_') || methodName == 'get') continue;

      // Skip if already found as static method
      if (members.any((m) => m['name'] == methodName && m['is_static'] == true)) continue;

      final branches = _countBranchesInText(extensionBody.substring(match.start));
      members.add({
        'name': methodName,
        'is_static': false,
        'is_getter': false,
        'branches': branches,
        'line_number': _getLineNumber(extensionBodyStart + match.start),
      });
    }

    return members;
  }

  List<Map<String, dynamic>> _extractMethodsForClass(String className, int classStart) {
    final methods = <Map<String, dynamic>>[];

    // Find class body
    final classBodyStart = moduleContent.indexOf('{', classStart);
    final classBodyEnd = _findMatchingBrace(classBodyStart);
    final classBody = moduleContent.substring(classBodyStart, classBodyEnd);

    // 1. Extract factory constructors (e.g., factory ClassName.fromJson)
    final factoryRegex = RegExp(r'factory\s+\w+\.(\w+)\s*\([^)]*\)(?:\s+async)?\s*{', multiLine: true);
    for (final match in factoryRegex.allMatches(classBody)) {
      final factoryName = match.group(1)!;
      if (factoryName.startsWith('_')) continue;

      // Find the factory method body to count branches
      final factoryBodyStart = classBodyStart + match.end - 1;
      final factoryBodyEnd = _findMatchingBrace(factoryBodyStart);
      final factoryBody = moduleContent.substring(factoryBodyStart, factoryBodyEnd);

      methods.add({
        'name': factoryName,
        'is_factory': true,
        'is_static': false,
        'is_async': classBody.substring(match.start, match.end).contains('async'),
        'branches': _countBranchesInText(factoryBody),
        'line_number': _getLineNumber(classBodyStart + match.start),
      });
    }

    // 2. Extract static methods
    final staticMethodRegex = RegExp(r'static\s+(?:Future<[^>]+>|FutureOr<[^>]+>|\w+(?:<[^>]+>)?)\s+(\w+)\s*\([^)]*\)(?:\s+async)?\s*{', multiLine: true);
    for (final match in staticMethodRegex.allMatches(classBody)) {
      final methodName = match.group(1)!;
      if (methodName.startsWith('_')) continue;

      // Find method body to count branches
      final methodBodyStart = classBodyStart + match.end - 1;
      final methodBodyEnd = _findMatchingBrace(methodBodyStart);
      final methodBody = moduleContent.substring(methodBodyStart, methodBodyEnd);

      methods.add({
        'name': methodName,
        'is_factory': false,
        'is_static': true,
        'is_async': classBody.substring(match.start, match.end).contains('async'),
        'branches': _countBranchesInText(methodBody),
        'line_number': _getLineNumber(classBodyStart + match.start),
      });
    }

    // 3. Extract regular instance methods (both sync and async)
    final methodRegex = RegExp(r'(?:Future<[^>]+>|FutureOr<[^>]+>|\w+(?:<[^>]+>)?)\s+(\w+)\s*\([^)]*\)(?:\s+async)?\s*{', multiLine: true);

    for (final match in methodRegex.allMatches(classBody)) {
      final methodName = match.group(1)!;

      // Skip constructors, private methods, and already-detected methods
      if (methodName == className || methodName.startsWith('_')) continue;

      // Skip if already detected as factory or static
      if (methods.any((m) => m['name'] == methodName)) continue;

      // Skip if this is part of a factory or static declaration
      final beforeMatch = classBody.substring(0, match.start);
      if (beforeMatch.trimRight().endsWith('factory') || beforeMatch.trimRight().endsWith('static')) {
        continue;
      }

      // Find method body to count branches
      final methodBodyStart = classBodyStart + match.end - 1;
      final methodBodyEnd = _findMatchingBrace(methodBodyStart);
      final methodBody = moduleContent.substring(methodBodyStart, methodBodyEnd);

      methods.add({
        'name': methodName,
        'is_factory': false,
        'is_static': false,
        'is_async': classBody.substring(match.start, match.end).contains('async'),
        'branches': _countBranchesInText(methodBody),
        'line_number': _getLineNumber(classBodyStart + match.start),
      });
    }

    return methods;
  }

  List<Map<String, dynamic>> _extractFunctions() {
    final functions = <Map<String, dynamic>>[];

    // Top-level functions (not in classes)
    final functionRegex = RegExp(
      r'^(?:Future<\w+>|FutureOr<\w+>|\w+)\s+(\w+)\s*\([^)]*\)(?:\s+async)?\s*{',
      multiLine: true
    );

    for (final match in functionRegex.allMatches(moduleContent)) {
      final functionName = match.group(1)!;

      // Skip if it's inside a class (basic heuristic)
      if (_isInsideClass(match.start)) continue;

      // Skip private functions
      if (functionName.startsWith('_')) continue;

      final branches = _countBranches(match.start);
      final isAsync = moduleContent.substring(match.start, match.end).contains('async');

      functions.add({
        'name': functionName,
        'branches': branches,
        'is_async': isAsync,
        'line_number': _getLineNumber(match.start),
      });
    }

    return functions;
  }

  List<String> _extractImports() {
    final imports = <String>[];
    // Match: import 'package:foo/bar.dart'; or import "package:foo/bar.dart";
    final importRegex = RegExp(r'''import\s+['"]([^'"]+)['"];?''');

    for (final match in importRegex.allMatches(moduleContent)) {
      imports.add(match.group(1)!);
    }

    return imports;
  }

  int _countBranches(int start) {
    // Find function body
    final bodyStart = moduleContent.indexOf('{', start);
    final bodyEnd = _findMatchingBrace(bodyStart);
    final body = moduleContent.substring(bodyStart, bodyEnd);

    return _countBranchesInText(body);
  }

  int _countBranchesInText(String text) {
    // Count if/else, try/catch, switch cases
    final ifCount = 'if '.allMatches(text).length;
    final elseCount = 'else'.allMatches(text).length;
    final tryCount = 'try '.allMatches(text).length;
    final catchCount = 'catch'.allMatches(text).length;
    final switchCount = 'switch '.allMatches(text).length;

    // Count case statements in switch
    final caseCount = RegExp(r'case\s+').allMatches(text).length;
    final defaultCount = RegExp(r'default\s*:').allMatches(text).length;

    // Count ternary operators (? :) - common in factories
    final ternaryCount = RegExp(r'\?[^:]*:').allMatches(text).length;

    // Count null-aware operators (?? - provides default value)
    final nullCoalesceCount = RegExp(r'\?\?').allMatches(text).length;

    // Count null-check conditionals (var != null ? ... : ...)
    final nullCheckCount = RegExp(r'!=\s*null').allMatches(text).length;

    // Total branches is sum of all decision points
    return ifCount + elseCount + tryCount + catchCount + switchCount + caseCount + defaultCount + ternaryCount + nullCoalesceCount + nullCheckCount;
  }

  bool _isInsideClass(int position) {
    // Simple heuristic: check if we're between 'class' and its closing brace
    final beforePos = moduleContent.substring(0, position);
    final classCount = 'class '.allMatches(beforePos).length;
    final openBraces = '{'.allMatches(beforePos).length;
    final closeBraces = '}'.allMatches(beforePos).length;

    return openBraces > closeBraces && classCount > 0;
  }

  int _findMatchingBrace(int openBracePos) {
    var count = 1;
    var pos = openBracePos + 1;

    while (pos < moduleContent.length && count > 0) {
      if (moduleContent[pos] == '{') count++;
      if (moduleContent[pos] == '}') count--;
      pos++;
    }

    return pos;
  }

  int _getLineNumber(int position) {
    return moduleContent.substring(0, position).split('\n').length;
  }
}

class FlutterTestGenerator {
  final Map<String, dynamic> analysis;

  FlutterTestGenerator(this.analysis);

  Map<String, String> generate() {
    return {
      'test_file': _generateTestFile(),
      'builder_file': _generateBuilderFile(),
    };
  }

  String _generateTestFile() {
    final moduleName = analysis['module_name'];
    final modulePath = analysis['module_path'];
    final coverageTarget = _getCoverageTarget(modulePath);
    final importPath = _getImportPath(modulePath);

    final imports = _generateTestImports(importPath);
    final testGroups = _generateTestGroups();

    return '''
/**
 * Unit tests for $modulePath
 *
 * COVERAGE REQUIREMENTS (mirrored from Python agent philosophy):
 * - ✅ **Branch Coverage: 100% (REQUIRED)** - Every if/else/try/catch must be tested
 * - 📊 **Line Coverage: $coverageTarget** - Based on code criticality
 *
 * Testing Philosophy (from repository standards):
 * - 100% branch coverage (strict requirement)
 * - Pragmatic line coverage based on module type
 * - Fewer, comprehensive tests over many small tests
 * - Test all branches: if/else, try/catch, conditional operators
 *
 * All tests follow:
 * - AAA pattern (Arrange-Act-Assert)
 * - Builder pattern for test data
 * - Mock external dependencies (DB, APIs, etc.)
 * - group() for organizing related tests
 *
 * CRITICAL REQUIREMENTS:
 * 1. 100% branch coverage is NON-NEGOTIABLE - test both paths of every if/else
 * 2. Test exception handling - both success and error paths
 * 3. Test edge cases - null values, empty collections, boundary conditions
 * 4. Mock all external dependencies - no real DB/API calls
 *
 * Next steps:
 * 1. Fill in TODO comments with specific test logic
 * 2. Add matchers to verify expected behavior for EACH branch
 * 3. Mock external dependencies (database, API clients, etc.)
 * 4. Run `flutter test` to verify all tests pass
 * 5. Run `flutter test --coverage` to verify 100% branch coverage
 */

$imports

void main() {
$testGroups
}
''';
  }

  String _getCoverageTarget(String modulePath) {
    final pathLower = modulePath.toLowerCase();

    // Critical modules (80%)
    if (pathLower.contains('payment') ||
        pathLower.contains('payout') ||
        pathLower.contains('wallet') ||
        pathLower.contains('calculator')) {
      return '80% (Critical - handles money)';
    }

    // Business logic (70%)
    if (pathLower.contains('service') || pathLower.contains('flow')) {
      return '70% (Important - business logic)';
    }

    // Pages/UI (60%)
    if (pathLower.contains('page') || pathLower.contains('screen')) {
      return '60% (UI layer - interaction + validation)';
    }

    // Models (60%)
    if (pathLower.contains('model')) {
      return '60% (Models - business logic only)';
    }

    // Widgets (50%)
    if (pathLower.contains('widget')) {
      return '50% (Widgets - core logic only)';
    }

    // Default
    return '70% (Standard module)';
  }

  String _getImportPath(String modulePath) {
    // Convert file path to package import
    // lib/services/payment_service.dart -> package:snabbit_runner/services/payment_service.dart
    final libIndex = modulePath.indexOf('lib/');
    if (libIndex != -1) {
      return modulePath.substring(libIndex + 4); // Remove 'lib/'
    }
    return modulePath;
  }

  String _generateTestImports(String importPath) {
    final moduleName = analysis['module_name'];
    final classes = analysis['classes'] as List;
    final enums = analysis['enums'] as List? ?? [];
    final extensions = analysis['extensions'] as List? ?? [];
    final functions = analysis['functions'] as List;

    final imports = <String>[
      "import 'package:flutter_test/flutter_test.dart';",
    ];

    // Check if mocking is needed (classes with instance methods, not just enums/extensions)
    final needsMocking = classes.any((c) =>
      (c['methods'] as List).any((m) =>
        !(m['is_static'] ?? false) && !(m['is_factory'] ?? false)
      )
    );

    final hasStaticMethods = classes.any((c) =>
      (c['methods'] as List).any((m) => m['is_static'] == true)
    );

    if (needsMocking || hasStaticMethods) {
      imports.add("// import 'package:mockito/mockito.dart';");
      imports.add("// import 'package:mockito/annotations.dart';");
      if (hasStaticMethods) {
        imports.add("// NOTE: Static methods using singletons (HttpService(), GlobalState()) are hard to mock.");
        imports.add("// Consider refactoring to use dependency injection or write integration tests.");
      }
    }

    // Check if async tests needed
    final hasAsync = functions.any((f) => f['is_async'] == true) ||
                     classes.any((c) => (c['methods'] as List).any((m) => m['is_async'] == true));

    if (hasAsync) {
      imports.add("// NOTE: Most Flutter tests handle async automatically");
    }

    // Import module under test
    imports.add("import 'package:snabbit_runner/$importPath';");

    // Import builders only for classes (not for enums/extensions)
    if (classes.isNotEmpty && enums.isEmpty && extensions.isEmpty) {
      imports.add("import '${moduleName}_builder.dart';");
    }

    return imports.join('\n');
  }

  String _generateTestGroups() {
    final groups = <String>[];

    // Generate test groups for enums
    for (final enumData in (analysis['enums'] as List? ?? [])) {
      groups.add(_generateEnumTestGroup(enumData));
    }

    // Generate test groups for extensions
    for (final ext in (analysis['extensions'] as List? ?? [])) {
      groups.add(_generateExtensionTestGroup(ext));
    }

    // Generate test groups for classes
    for (final cls in (analysis['classes'] as List? ?? [])) {
      groups.add(_generateClassTestGroup(cls));
    }

    // Generate test groups for functions
    for (final func in (analysis['functions'] as List? ?? [])) {
      groups.add(_generateFunctionTestGroup(func));
    }

    return groups.join('\n\n');
  }

  String _generateEnumTestGroup(Map<String, dynamic> enumData) {
    final enumName = enumData['name'];
    final values = enumData['values'] as List<dynamic>;

    return '''
  group('$enumName', () {
    test('has all expected values', () {
      // Arrange & Act
      final values = $enumName.values;

      // Assert
      expect(values.length, equals(${values.length}));
      ${values.map((v) => "expect(values, contains($enumName.$v));").join('\n      ')}
    });
  });''';
  }

  String _generateExtensionTestGroup(Map<String, dynamic> ext) {
    final extensionName = ext['name'];
    final targetType = ext['target_type'];
    final members = ext['methods'] as List;

    final testCases = <String>[];

    for (final member in members) {
      testCases.add(_generateExtensionMemberTest(targetType, member));
    }

    return '''
  group('$extensionName', () {
${testCases.join('\n\n')}
  });''';
  }

  String _generateExtensionMemberTest(String targetType, Map<String, dynamic> member) {
    final memberName = member['name'];
    final isStatic = member['is_static'] ?? false;
    final isGetter = member['is_getter'] ?? false;
    final branches = member['branches'] ?? 0;

    if (isStatic) {
      // Static method - test all branches based on switch cases
      return '''
    group('$memberName (static)', () {
      test('handles valid input correctly', () {
        // Arrange
        // TODO: Add valid input parameter

        // Act
        final result = ${targetType}Extension.$memberName(/* TODO: params */);

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      });

      test('handles invalid/edge case input', () {
        // Arrange
        // TODO: Add edge case parameter

        // Act
        final result = ${targetType}Extension.$memberName(/* TODO: params */);

        // Assert
        // TODO: Assert edge case behavior (e.g., null, default value)
      });
    });''';
    } else if (isGetter) {
      // Getter - generate tests for each enum value if this is an enum extension
      return '''
    group('$memberName (getter)', () {
      test('returns expected value for each case', () {
        // Arrange & Act & Assert
        ${targetType == 'ContestRankEnum' || targetType.contains('Enum') ? '''
        for (final value in $targetType.values) {
          final result = value.$memberName;
          expect(result, isNotNull);
          // TODO: Add specific assertions for each enum value
        }''' : '''
        // TODO: Test getter with various instances
        final instance = $targetType.${memberName.toLowerCase()}; // Example
        final result = instance.$memberName;
        expect(result, isNotNull);'''}
      });
    });''';
    } else {
      // Regular extension method
      return '''
    test('$memberName returns expected result', () {
      // Arrange
      // TODO: Create instance of $targetType

      // Act
      // final result = instance.$memberName();

      // Assert
      // TODO: Add assertions
    });''';
    }
  }

  String _generateClassTestGroup(Map<String, dynamic> cls) {
    final className = cls['name'];
    final methods = cls['methods'] as List;

    final testCases = <String>[];

    for (final method in methods) {
      testCases.add(_generateMethodTest(className, method));
    }

    return '''
  group('$className', () {
${testCases.join('\n\n')}
  });''';
  }

  String _generateMethodTest(String className, Map<String, dynamic> method) {
    final methodName = method['name'];
    final isAsync = method['is_async'] ?? false;
    final isFactory = method['is_factory'] ?? false;
    final isStatic = method['is_static'] ?? false;
    final branches = method['branches'] ?? 0;
    final builderName = '${className}Builder';

    // Factory constructor tests (e.g., fromJson)
    if (isFactory) {
      return '''
    group('$methodName (factory)', () {
      test('creates instance from valid JSON', () {
        // Arrange
        final json = ${builderName}.defaultJson();

        // Act
        final result = $className.$methodName(json);

        // Assert
        expect(result, isNotNull);
        expect(result, isA<$className>());
        // TODO: Add specific field assertions
      });

      test('handles null values in JSON gracefully', () {
        // Arrange - test null handling branches
        final json = ${builderName}.jsonWith(/* TODO: set nulls */);

        // Act
        final result = $className.$methodName(json);

        // Assert
        expect(result, isNotNull);
        // TODO: Assert null fields are handled correctly
      });${branches > 2 ? '''

      test('handles invalid JSON data', () {
        // Arrange - test error/edge case branches
        final json = ${builderName}.invalidJson();

        // Act
        final result = $className.$methodName(json);

        // Assert
        // TODO: Assert how invalid data is handled
      });''' : ''}
    });''';
    }

    // Static method tests
    if (isStatic) {
      return '''
    group('$methodName (static)', () {
      test('returns expected result for valid input', () ${isAsync ? 'async' : ''} {
        // Arrange
        // TODO: Add valid input parameters
        // NOTE: If this method uses singletons (HttpService(), GlobalState(), etc.),
        // consider refactoring to use dependency injection or mark as integration test.

        // Act
        final result = ${isAsync ? 'await ' : ''}$className.$methodName(/* TODO: params */);

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');${branches > 0 ? '''

      test('handles error/edge cases correctly', () ${isAsync ? 'async' : ''} {
        // Arrange - test branch coverage
        // TODO: Add edge case parameters

        // Act
        final result = ${isAsync ? 'await ' : ''}$className.$methodName(/* TODO: params */);

        // Assert
        // TODO: Assert edge case behavior (branches: $branches)
      }, skip: 'TODO: Set up mocks for external dependencies');''' : ''}
    });''';
    }

    // Regular instance method tests
    return '''
    test('$methodName returns expected result for valid inputs', () ${isAsync ? 'async' : ''} {
      // Arrange
      final instance = $builderName().build();
      // TODO: Add test parameters if needed

      // Act
      final result = ${isAsync ? 'await ' : ''}instance.$methodName();

      // Assert
      expect(result, isNotNull);
      // TODO: Add specific assertions for expected behavior
    });

    test('$methodName handles edge cases correctly', () ${isAsync ? 'async' : ''} {
      // Arrange - set up edge case scenario
      final instance = $builderName().asEdgeCase().build();

      // Act
      final result = ${isAsync ? 'await ' : ''}instance.$methodName();

      // Assert
      // TODO: Assert edge case behavior
      // IMPORTANT: This test must cover a specific branch!
    });''';
  }

  String _generateFunctionTestGroup(Map<String, dynamic> func) {
    final funcName = func['name'];
    final isAsync = func['is_async'] ?? false;
    final branches = func['branches'] ?? 0;

    final testCases = <String>[];

    // Happy path test
    testCases.add(_generateFunctionHappyPathTest(funcName, isAsync));

    // Branch tests
    if (branches > 0) {
      testCases.add(_generateFunctionBranchTest(funcName, isAsync));
    }

    // Error test
    testCases.add(_generateFunctionErrorTest(funcName, isAsync));

    return '''
  group('$funcName', () {
${testCases.join('\n\n')}
  });''';
  }

  String _generateFunctionHappyPathTest(String funcName, bool isAsync) {
    return '''
    test('returns correct value when valid inputs provided', () ${isAsync ? 'async' : ''} {
      // Arrange
      // TODO: Set up test parameters

      // Act
      final result = ${isAsync ? 'await ' : ''}$funcName(/* TODO: params */);

      // Assert
      expect(result, isNotNull);
      // TODO: Add specific assertions
    });''';
  }

  String _generateFunctionBranchTest(String funcName, bool isAsync) {
    return '''
    test('handles edge case conditions correctly', () ${isAsync ? 'async' : ''} {
      // Arrange - set up conditions to trigger specific branch
      // IMPORTANT: This must test a different code path (if/else branch)
      // TODO: Set up edge case parameters

      // Act
      final result = ${isAsync ? 'await ' : ''}$funcName(/* TODO: edge case params */);

      // Assert
      // TODO: Assert branch-specific behavior
    });''';
  }

  String _generateFunctionErrorTest(String funcName, bool isAsync) {
    return '''
    test('handles errors and null values gracefully', () ${isAsync ? 'async' : ''} {
      // Arrange - set up error scenario
      // TODO: Set up parameters that should trigger error handling

      // Act & Assert
      expect(
        () ${isAsync ? 'async ' : ''}=> ${isAsync ? 'await ' : ''}$funcName(/* TODO: invalid params */),
        throwsA(isA<Exception>()), // TODO: Specify exception type
      );
    });''';
  }

  String _generateBuilderFile() {
    final classes = analysis['classes'] as List;
    if (classes.isEmpty) return '';

    final moduleName = analysis['module_name'];
    final importPath = _getImportPath(analysis['module_path']);
    final builders = <String>[];

    for (final cls in classes) {
      builders.add(_generateBuilder(cls));
    }

    return '''
/**
 * Builder classes for $moduleName test data.
 *
 * This file contains two types of builders (following Python agent pattern):
 * 1. Entity Builders - For constructing domain objects/entities
 * 2. Parameter Builders - For constructing test input data (configs, maps)
 *
 * The builder pattern makes test input-output relationships crystal clear:
 * - Input: Built with fluent API showing exactly what's being tested
 * - Output: Assertions verify expected behavior based on input
 *
 * Example:
 *   // Clear input construction
 *   final config = BonusConfigBuilder()
 *       .withCriticalDates(['2025-12-25'])
 *       .build();
 *
 *   // Clear expected output
 *   expect(getDayCategory(date, config), DayCategory.critical);
 *
 * Benefits:
 * - Maintainable: Change structure? Update builder once
 * - Readable: Fluent API makes test intent clear
 * - Reusable: Share builders across test files
 *
 * Generated by Flutter Unit Test Agent
 */

import 'package:snabbit_runner/$importPath';

${builders.join('\n\n')}
''';
  }

  String _generateBuilder(Map<String, dynamic> cls) {
    final className = cls['name'];

    return '''
class ${className}Builder {
  // TODO: Add fields matching $className constructor

  ${className}Builder();

  $className build() {
    // TODO: Construct $className instance with test data
    return $className(
      // TODO: Add constructor parameters
    );
  }

  // Fluent builder methods
  // TODO: Add with* methods for each field
  // Example:
  // ${className}Builder withFieldName(Type value) {
  //   _fieldName = value;
  //   return this;
  // }

  // Scenario methods (following Python agent pattern)
  ${className}Builder asHighValue() {
    // TODO: Set up high-value scenario
    return this;
  }

  ${className}Builder asLowValue() {
    // TODO: Set up low-value scenario
    return this;
  }

  ${className}Builder asEdgeCase() {
    // TODO: Set up edge case scenario (nulls, empty collections, etc.)
    return this;
  }
}''';
  }
}

class FlutterUnitTestAgent {
  final String modulePath;

  FlutterUnitTestAgent(this.modulePath);

  void run() {
    print('🤖 Flutter Unit Test Agent V2.1 (Brownfield-Safe)');
    print('=' * 80);
    print('Target: $modulePath');
    print('');

    // Step 0: BROWNFIELD SAFETY CHECK
    final testDir = _getTestDirectory(modulePath);
    final moduleName = path.basenameWithoutExtension(modulePath);
    final testFile = path.join(testDir, '${moduleName}_test.dart');
    final builderFile = path.join(testDir, '${moduleName}_builder.dart');

    final isExistingTest = File(testFile).existsSync();

    if (isExistingTest) {
      print('⚠️  BROWNFIELD DETECTED: Existing tests found');
      print('   Test file: $testFile');
      print('');
      print('🧪 Running existing tests to check for breaking changes...');
      print('');

      final existingTestResult = _runTestsWithResult(testFile);

      if (existingTestResult != 0) {
        print('');
        print('❌ EXISTING TESTS ARE FAILING!');
        print('=' * 80);
        print('');
        print('   Your code changes broke existing tests. This indicates:');
        print('   1. A breaking change that may cause regressions');
        print('   2. Tests need to be updated for intentional API changes');
        print('');
        print('   ⚠️  STOPPING to prevent accidental test overwrites.');
        print('');
        print('   What to do:');
        print('   1. Review the failing tests above');
        print('   2. Fix your code to pass existing tests, OR');
        print('   3. If breaking change is intentional, manually update tests');
        print('   4. Delete the test file if you want to regenerate from scratch');
        print('');
        print('   The purpose of unit tests is to prevent regression issues.');
        print('   Please address the failing tests before proceeding.');
        print('');
        exit(1);
      }

      print('');
      print('✅ Existing tests PASSED!');
      print('');
      print('   Your code changes are backward compatible.');
      print('   Do you want to regenerate test scaffolds?');
      print('');
      print('   WARNING: This will OVERWRITE existing tests!');
      print('');
      stdout.write('   Continue? (y/N): ');
      final input = stdin.readLineSync()?.toLowerCase() ?? 'n';

      if (input != 'y' && input != 'yes') {
        print('');
        print('❌ Aborted. Existing tests preserved.');
        print('   To add new tests, manually edit: $testFile');
        print('');
        exit(0);
      }

      print('');
      print('⚠️  Proceeding with regeneration (existing tests will be overwritten)...');
      print('');
    }

    // Step 1: Analyze
    print('📊 Step 1: Analyzing module...');
    final analyzer = DartModuleAnalyzer(modulePath);
    final analysis = analyzer.analyze();

    final enumCount = (analysis['enums'] as List? ?? []).length;
    final extCount = (analysis['extensions'] as List? ?? []).length;
    final classCount = (analysis['classes'] as List? ?? []).length;
    final funcCount = (analysis['functions'] as List? ?? []).length;

    print('   Found: $enumCount enums, $extCount extensions, $classCount classes, $funcCount functions');

    // Print details if any enums or extensions found
    if (enumCount > 0) {
      for (final enumData in (analysis['enums'] as List)) {
        final members = (enumData['methods'] as List? ?? []).length;
        print('   - Enum: ${enumData['name']} (${(enumData['values'] as List).length} values)');
      }
    }
    if (extCount > 0) {
      for (final ext in (analysis['extensions'] as List)) {
        final members = (ext['methods'] as List).length;
        print('   - Extension: ${ext['name']} on ${ext['target_type']} ($members members)');
      }
    }
    print('');

    // Step 2: Generate
    print('✍️  Step 2: Generating tests...');
    final generator = FlutterTestGenerator(analysis);
    final files = generator.generate();

    print('   Test file: $testFile');
    if (files['builder_file']!.isNotEmpty) {
      print('   Builder file: $builderFile');
    }
    print('');

    // Step 3: Write files
    print('💾 Step 3: Writing test files...');
    Directory(testDir).createSync(recursive: true);

    File(testFile).writeAsStringSync(files['test_file']!);
    print('   ✅ Created $testFile');

    if (files['builder_file']!.isNotEmpty) {
      File(builderFile).writeAsStringSync(files['builder_file']!);
      print('   ✅ Created $builderFile');
    }
    print('');

    // Step 4: Run tests
    print('🧪 Step 4: Running tests...');
    _runTests(testFile);
    print('');

    print('✅ Done! Review the generated tests and fill in TODOs.');
    print('   Next: flutter test $testFile');
    print('   Coverage: flutter test --coverage');
  }

  String _getTestDirectory(String modulePath) {
    // lib/services/payment_service.dart -> test/unit/services/
    final libIndex = modulePath.indexOf('lib/');
    if (libIndex != -1) {
      final relativePath = modulePath.substring(libIndex + 4);
      final dir = path.dirname(relativePath);
      return path.join('test', 'unit', dir);
    }
    return 'test/unit';
  }

  void _runTests(String testFile) {
    final result = Process.runSync('flutter', ['test', testFile]);
    print(result.stdout);
    if (result.exitCode != 0) {
      print(result.stderr);
      print('⚠️  Tests need fixes. Please review and update.');
    }
  }

  int _runTestsWithResult(String testFile) {
    final result = Process.runSync('flutter', ['test', testFile]);
    print(result.stdout);
    if (result.exitCode != 0) {
      print(result.stderr);
    }
    return result.exitCode;
  }
}

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart scripts/unit_test_agent.dart <module_path>');
    print('Example: dart scripts/unit_test_agent.dart lib/services/payment_service.dart');
    exit(1);
  }

  final modulePath = args[0];
  if (!File(modulePath).existsSync()) {
    print('❌ Error: $modulePath not found');
    exit(1);
  }

  final agent = FlutterUnitTestAgent(modulePath);
  agent.run();
}
