# Coverage Strategy for Flutter/Dart

This document defines our pragmatic testing philosophy, mirrored from the backend Python repository.

## TL;DR - The Golden Rules

1. **✅ 100% Branch Coverage is NON-NEGOTIABLE** for all new/changed code
2. **📊 Pragmatic Line Coverage** (50-80%) based on code criticality
3. **🎯 Fewer, comprehensive tests** over many small tests
4. **🔍 Focus on business logic**, not boilerplate

## Philosophy

Our testing approach balances:
- **Strictness where it matters** (branch coverage)
- **Pragmatism where it helps** (line coverage)
- **Developer productivity** (don't test trivial code)

### Why 100% Branch Coverage?

**Every decision path in your code should be tested.** If you wrote an `if/else`, there's a reason - test both outcomes!

```dart
// This has 2 branches - test both!
if (user.isVerified) {
  return processPayment();  // ← Test this
} else {
  return showVerificationError();  // ← And test this
}
```

**Branch coverage** ensures you test:
- Both sides of every `if/else`
- All `case` statements in a `switch`
- Both success and exception paths in `try/catch`
- All logical operators (`&&`, `||`)

## Coverage Targets by Module Type

### Critical Modules (80% line coverage)
**Money, payments, calculations - test thoroughly!**

| Module Type | Pattern | Line Coverage | Why |
|------------|---------|---------------|-----|
| Payment | `*/payment*` | 80% | Handles money |
| Payout | `*/payout*` | 80% | Handles money |
| Wallet | `*/wallet*` | 80% | Handles money |
| Calculator | `*/calculator*` | 80% | Business calculations |

### Important Modules (70% line coverage)
**Core business logic**

| Module Type | Pattern | Line Coverage | Why |
|------------|---------|---------------|-----|
| Services | `*/services/*` | 70% | Business logic layer |
| Providers | `*/providers/*` | 70% | State management |
| Flows | `*/flow*` | 70% | Multi-step business processes |

### Standard Modules (60% line coverage)
**UI and data layer**

| Module Type | Pattern | Line Coverage | Why |
|------------|---------|---------------|-----|
| Pages | `*/pages/*` | 60% | UI logic + validation |
| Views | `*/views/*` | 60% | UI components |
| Models | `*/models/*` | 60% | Data models with business logic |

### Lower Priority (50% line coverage)
**Simple components**

| Module Type | Pattern | Line Coverage | Why |
|------------|---------|---------------|-----|
| Widgets | `*/widgets/*` | 50% | Reusable UI components |
| Constants | `*/constants/*` | 0% | No logic to test |

## What to Test

### ✅ Always Test
- **Business logic** - Calculations, validations, transformations
- **Decision points** - Every `if/else`, `switch/case`, ternary operator
- **Error handling** - Try/catch blocks, error states
- **Edge cases** - Null values, empty lists, boundary conditions
- **State changes** - Provider updates, model mutations
- **API interactions** - Mock HTTP calls, test responses

### ❌ Don't Waste Time Testing
- **Simple getters/setters** - No logic = no test needed
- **Constants** - They don't change
- **Generated code** - `*.g.dart`, `*.freezed.dart` files
- **Main.dart** - App initialization (test manually)
- **UI layout code** - Use widget tests/golden tests instead

## Testing Patterns

### 1. AAA Pattern (Arrange-Act-Assert)

```dart
test('calculates bonus correctly for weekday', () {
  // Arrange - Set up test data
  final calculator = BonusCalculator();
  final delivery = DeliveryBuilder()
      .withDate(DateTime(2025, 11, 25))  // Monday
      .build();

  // Act - Execute the code
  final bonus = calculator.calculateBonus(delivery);

  // Assert - Verify the result
  expect(bonus, equals(50.0));
});
```

### 2. Builder Pattern for Test Data

**Why?** Makes tests maintainable and readable.

```dart
// ❌ BAD - Hard to read, hard to maintain
final delivery = Delivery(
  id: 1,
  date: DateTime(2025, 11, 25),
  amount: 100,
  distance: 5.0,
  isUrgent: false,
  customer: Customer(id: 1, name: 'Test', verified: true),
  // ... 10 more fields
);

// ✅ GOOD - Clear, maintainable
final delivery = DeliveryBuilder()
    .withDate(DateTime(2025, 11, 25))
    .asUrgent()
    .build();
```

### 3. Test All Branches

```dart
group('processPayment', () {
  test('processes payment when user is verified', () {
    // Test the TRUE branch
    final user = UserBuilder().withVerified(true).build();
    final result = processPayment(user);
    expect(result.isSuccess, isTrue);
  });

  test('rejects payment when user is not verified', () {
    // Test the FALSE branch
    final user = UserBuilder().withVerified(false).build();
    expect(
      () => processPayment(user),
      throwsA(isA<VerificationException>()),
    );
  });
});
```

### 4. Mock External Dependencies

```dart
@GenerateMocks([HttpClient, Database])
void main() {
  late MockHttpClient mockHttp;
  late PaymentService service;

  setUp(() {
    mockHttp = MockHttpClient();
    service = PaymentService(mockHttp);
  });

  test('fetches payment status from API', () async {
    // Arrange - Mock the HTTP call
    when(mockHttp.get(any)).thenAnswer((_) async =>
      Response('{"status": "completed"}', 200));

    // Act
    final status = await service.getPaymentStatus('123');

    // Assert
    expect(status, equals('completed'));
    verify(mockHttp.get(any)).called(1);
  });
});
```

## Running Tests

### Quick Commands

```bash
make test              # Run all tests
make test-unit         # Run unit tests only
make test-cov          # Generate coverage report
make test-my-changes   # Coverage for YOUR changes only ⭐
make coverage-check    # Enforce coverage requirements before commit
```

### Workflow

```bash
# 1. Write your code
vim lib/services/payment_service.dart

# 2. Generate test skeleton (optional)
make generate-test FILE=lib/services/payment_service.dart

# 3. Write tests
vim test/unit/services/payment_service_test.dart

# 4. Run tests
make test

# 5. Check coverage (only your changes)
make test-my-changes

# 6. Before committing
make coverage-check

# 7. If coverage fails, add more tests and repeat
```

## Coverage Enforcement

### Pre-commit Checklist

Before creating a PR, run:

```bash
make coverage-check
```

This will:
1. Run all tests
2. Generate coverage report
3. Check if your changes meet requirements:
   - ✅ 100% branch coverage for changed code
   - 📊 Line coverage targets for changed files

### What Happens on Failure?

```bash
❌ Branch Coverage Failures (2):
   All branches in changed code MUST be tested!

  • payment_calculator.dart
    5/7 branches covered (71.4%)
    Missing: 2 branch(es)

💡 How to fix:
   • Review each if/else and ensure both paths are tested
   • Use 'make coverage-report' to see which branches are missing
```

## Test Organization

```
test/
├── unit/                    # Unit tests (isolated logic)
│   ├── services/
│   │   ├── payment_service_test.dart
│   │   └── payment_service_builder.dart
│   ├── models/
│   ├── providers/
│   └── utils/
├── widget/                  # Widget tests (UI components)
│   └── widgets/
└── integration/             # Integration tests (e2e)
    └── flows/
```

### Naming Conventions

- Test files: `{module_name}_test.dart`
- Builder files: `{module_name}_builder.dart`
- Test classes: `group('{ClassName/FunctionName}', () { })`
- Test names: Descriptive sentences
  - ✅ `'calculates bonus correctly for critical day'`
  - ❌ `'test1'`

## Examples

### Example 1: Service with Business Logic

```dart
// lib/services/bonus_calculator.dart
class BonusCalculator {
  double calculateBonus(Delivery delivery) {
    if (delivery.date.weekday == DateTime.sunday) {
      return delivery.amount * 0.5;  // 50% bonus
    } else if (delivery.isUrgent) {
      return delivery.amount * 0.3;  // 30% bonus
    }
    return 0;
  }
}

// test/unit/services/bonus_calculator_test.dart
void main() {
  group('BonusCalculator', () {
    late BonusCalculator calculator;

    setUp(() {
      calculator = BonusCalculator();
    });

    test('returns 50% bonus for Sunday deliveries', () {
      // Branch 1: Sunday
      final delivery = DeliveryBuilder()
          .withDate(DateTime(2025, 11, 30))  // Sunday
          .build();

      final bonus = calculator.calculateBonus(delivery);

      expect(bonus, equals(50.0));  // 50% of 100
    });

    test('returns 30% bonus for urgent deliveries on weekdays', () {
      // Branch 2: Urgent on weekday
      final delivery = DeliveryBuilder()
          .withDate(DateTime(2025, 11, 25))  // Monday
          .asUrgent()
          .build();

      final bonus = calculator.calculateBonus(delivery);

      expect(bonus, equals(30.0));  // 30% of 100
    });

    test('returns zero bonus for normal weekday deliveries', () {
      // Branch 3: Normal weekday
      final delivery = DeliveryBuilder()
          .withDate(DateTime(2025, 11, 25))  // Monday
          .build();

      final bonus = calculator.calculateBonus(delivery);

      expect(bonus, equals(0.0));
    });
  });
}

// test/unit/services/bonus_calculator_builder.dart
class DeliveryBuilder {
  DateTime _date = DateTime.now();
  double _amount = 100.0;
  bool _isUrgent = false;

  DeliveryBuilder withDate(DateTime date) {
    _date = date;
    return this;
  }

  DeliveryBuilder asUrgent() {
    _isUrgent = true;
    return this;
  }

  Delivery build() => Delivery(
    date: _date,
    amount: _amount,
    isUrgent: _isUrgent,
  );
}
```

### Example 2: Testing Error Handling

```dart
test('throws exception when amount is negative', () {
  final delivery = DeliveryBuilder()
      .withAmount(-100)
      .build();

  expect(
    () => calculator.calculateBonus(delivery),
    throwsA(isA<InvalidAmountException>()),
  );
});
```

## Tools

### Make Commands Reference

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `make test` | Run all tests | During development |
| `make test-unit` | Run unit tests only | Faster feedback loop |
| `make test-cov` | Generate full coverage | Weekly/before big PRs |
| `make test-my-changes` | Coverage for your changes | Before every commit |
| `make coverage-check` | Enforce standards | Before creating PR |
| `make coverage-report` | Open HTML report | Deep dive into coverage |

### Test Agent

Generate test skeletons automatically:

```bash
# Generate tests for a file
make generate-test FILE=lib/services/payment_service.dart

# Or directly
dart scripts/unit_test_agent.dart lib/services/payment_service.dart
```

This creates:
- `test/unit/services/payment_service_test.dart` - Test skeleton
- `test/unit/services/payment_service_builder.dart` - Builder classes

Then fill in the TODOs with actual test logic!

## FAQ

**Q: Do I really need 100% branch coverage?**
A: Yes, for new/changed code. If you wrote an if/else, test both paths.

**Q: What about trivial getters?**
A: Skip them. Focus on business logic.

**Q: My coverage is 99.9%, can I merge?**
A: No. That 0.1% is probably an untested error path. Test it.

**Q: How do I see which branches are missing?**
A: Run `make coverage-report` and open the HTML report.

**Q: Can I exclude a file from coverage?**
A: Yes, if it's generated code (*.g.dart) or pure constants. Edit `scripts/check_branch_coverage.dart`.

**Q: Tests are slow, can I skip them?**
A: Never. Use `make test-fast` for parallel execution.

## Maintenance

- **Weekly**: Review coverage trends
- **Monthly**: Update coverage rules if needed
- **Per PR**: Enforce 100% branch coverage for changes

---

**Remember**: Good tests are **fast**, **focused**, and **comprehensive**. Test the behavior, not the implementation.

For questions or suggestions, reach out to the team!
