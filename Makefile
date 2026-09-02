.PHONY: test test-unit test-cov test-my-changes coverage-report coverage-check help setup install run

help:
	@echo "Available commands:"
	@echo ""
	@echo "🧪 Running Tests:"
	@echo "  make test                - Run all tests (clean output)"
	@echo "  make test-unit           - Run unit tests only"
	@echo "  make test-watch          - Run tests in watch mode"
	@echo "  make test-fast           - Run tests with concurrency"
	@echo ""
	@echo "📊 Coverage Reports:"
	@echo "  make test-cov            - Run tests + generate coverage report"
	@echo "  make coverage-report     - Open HTML coverage report in browser"
	@echo "  make test-my-changes     - ⭐ Coverage for YOUR changes only (recommended for PRs)"
	@echo "  make coverage-check      - 🎯 Enforce coverage requirements (run before commit)"
	@echo ""
	@echo "🔧 Setup & Development:"
	@echo "  make setup               - 🚀 One-time setup (install deps + get packages)"
	@echo "  make install             - Install all Flutter dependencies"
	@echo "  make run                 - Run the app on connected device/emulator"
	@echo "  make run-release         - Run app in release mode"
	@echo "  make build               - Build APK"
	@echo ""
	@echo "🧹 Cleanup:"
	@echo "  make clean               - Clean build artifacts"
	@echo "  make clean-all           - Deep clean (including pub cache)"

setup: install
	@echo ""
	@echo "✅ Setup complete! You can now run:"
	@echo "   make run    - Start the app"
	@echo "   make test   - Run tests"

install:
	@echo "📦 Installing Flutter dependencies..."
	flutter pub get
	@echo "✅ Dependencies installed!"

check-flutter:
	@command -v flutter >/dev/null 2>&1 || \
	 (echo "❌ ERROR: Flutter not found!" && \
	  echo "" && \
	  echo "Please install Flutter:" && \
	  echo "  https://docs.flutter.dev/get-started/install" && \
	  echo "" && \
	  exit 1)

run: check-flutter
	@echo "🚀 Running app on connected device..."
	flutter run

run-release: check-flutter
	@echo "🚀 Running app in release mode..."
	flutter run --release

build: check-flutter
	@echo "🔨 Building APK..."
	flutter build apk

test: check-flutter
	@echo "🧪 Running tests..."
	flutter test

test-unit: check-flutter
	@echo "🧪 Running unit tests only..."
	flutter test test/unit/

test-watch: check-flutter
	@echo "👀 Running tests in watch mode..."
	flutter test --watch

test-fast: check-flutter
	@echo "⚡ Running tests with concurrency..."
	flutter test --concurrency=4

test-cov: check-flutter
	@echo "📊 Running tests with coverage..."
	flutter test --coverage
	@echo ""
	@echo "✅ Coverage report generated!"
	@echo "   Coverage file: coverage/lcov.info"
	@echo "   Run 'make coverage-report' to generate HTML and open in browser"

test-my-changes: check-flutter
	@echo "🔍 Running tests with coverage..."
	@flutter test --coverage
	@echo ""
	@echo "📊 Coverage for YOUR changed lines (vs main branch):"
	@echo "    This shows coverage ONLY for the specific lines you modified!"
	@echo ""
	@command -v lcov >/dev/null 2>&1 && \
	 genhtml coverage/lcov.info -o coverage/html && \
	 echo "✅ Coverage HTML generated at coverage/html/index.html" || \
	 (echo "⚠️  lcov not found. Install with:" && \
	  echo "  brew install lcov  # macOS" && \
	  echo "  sudo apt-get install lcov  # Linux")
	@echo ""
	@echo "💡 Tip: Run 'make coverage-check' to enforce coverage requirements"

coverage-report: check-flutter
	@echo "🌐 Generating HTML coverage report..."
	@command -v lcov >/dev/null 2>&1 && \
	 (genhtml coverage/lcov.info -o coverage/html && \
	  open coverage/html/index.html || xdg-open coverage/html/index.html || \
	  echo "Please open coverage/html/index.html manually") || \
	 (echo "⚠️  lcov not found. Install with:" && \
	  echo "  brew install lcov  # macOS" && \
	  echo "  sudo apt-get install lcov  # Linux")

coverage-check: check-flutter
	@echo "🎯 Enforcing Coverage Standards"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Strategy: Pragmatic line coverage + Strict 100% branch coverage"
	@echo "  • Line Coverage: 50-80% based on code criticality"
	@echo "  • Branch Coverage: 100% for all new/changed code (REQUIRED)"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "Running tests with coverage..."
	@flutter test --coverage
	@echo ""
	@dart scripts/check_branch_coverage.dart

clean:
	@echo "🧹 Cleaning build artifacts..."
	flutter clean
	rm -rf coverage/
	@echo "✅ Clean complete!"

clean-all: clean
	@echo "🧹 Deep cleaning (including pub cache)..."
	rm -rf .dart_tool/
	rm -rf .packages
	rm -rf pubspec.lock
	@echo "✅ Deep clean complete! Run 'make setup' to reinstall."

# Helper commands for test generation
generate-test:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make generate-test FILE=lib/path/to/file.dart"; \
		exit 1; \
	fi
	@echo "🤖 Generating tests for $(FILE)..."
	dart scripts/unit_test_agent.dart $(FILE)

# Code quality
analyze:
	@echo "🔍 Running static analysis..."
	flutter analyze

format:
	@echo "✨ Formatting code..."
	dart format lib/ test/

format-check:
	@echo "🔍 Checking code formatting..."
	dart format --output=none --set-exit-if-changed lib/ test/
