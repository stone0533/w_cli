# w_cli

A comprehensive command-line tool for Flutter projects, providing API code generation, app building, and project management utilities.

## Features

- **API Code Generation**: Automatically generate API-related code from `client.dart`
- **Flutter App Building**: Build Flutter apps for Android (APK/AAB) and iOS (IPA)
- **Project Creation**: Create Flutter projects with custom structure
- **Project Opening**: Open Flutter project in IDEs and file managers
- **Project Management**: Update Flutter project dependencies and configuration
- **Build Runner Execution**: Run `build_runner` with a simple command
- **Command Aliases**: Short aliases for all commands for faster usage
- **Default Behaviors**: Intelligent defaults for common commands
- **Cross-Platform**: Works on macOS, Linux, and Windows

## Installation

### Method 1: Global Installation

```bash
dart pub global activate w_cli
```

### Method 2: Local Development

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/w_cli.git
   cd w_cli
   ```

2. Activate from path:
   ```bash
   dart pub global activate --source=path .
   ```

## Usage

### Basic Commands

```bash
# Show help
ww --help

# Show version
ww --version

# Create a new Flutter project
ww create project my_app

# Using aliases
ww c p my_app

# Project creation automatically adds w_build directory to .gitignore

# Generate API code
ww api

# Build Flutter app
ww build apk
ww build aab
ww build ios

# Update w_cli to latest version
ww update

# Update Flutter project dependencies and configuration
ww project --update

# Open Flutter project
ww open ios
ww open android
ww open build
ww open root
```

### Command Aliases

```bash
# Main commands
ww create   → ww c
ww api      → ww a
ww update   → ww u
ww build    → ww b
ww project  → ww p
ww open     → ww o

# Subcommands
ww create project → ww create p
ww open ios       → ww open i
ww open android   → ww open a
ww open build     → ww open b
ww open root      → ww open r
```

### Default Behaviors

```bash
# Default to project creation
ww create     → ww create project
```

### Examples with Aliases

```bash
# Create a project using aliases
ww c p my_app

# Generate API code using aliases
ww a

# Build using aliases
ww b apk --uat

# Open using aliases
ww o i  # Open iOS project
ww o r  # Open root directory

# Update project using alias
ww p --update  # Update Flutter project dependencies and configuration
```

### API Code Generation

```bash
# Generate API code
ww api

# Generate with debug mode
ww api --debug

# Initialize API directory structure
ww api --init

# Generate model files from JSON
ww api --models

# Using aliases
ww a            # Generate API code
ww a --init     # Initialize API directory structure
ww a --models   # Generate model files from JSON
```

### Flutter App Building

```bash
# Build APK in production mode
ww build apk

# Build AAB in production mode
ww build aab

# Build iOS in production mode
ww build ios

# Build in UAT mode
ww build apk --uat

# Clear build directory and build
ww build apk --clean

# Open output directory after build
ww build apk --open

# Build multiple platforms
ww build apk aab

# Build all platforms in UAT mode with clean and open
ww build apk aab ios --uat --clean --open

# Using short aliases
ww b apk -u -o          # Build APK in UAT mode and open output directory
ww b apk aab -c -o      # Build APK and AAB with clean and open output directory
```



### Project Opening

```bash
# Open iOS project in Xcode
ww open ios

# Open Android project in Android Studio
ww open android

# Open build directory in file manager
ww open build

# Open root directory in file manager
ww open root
```

### Build Runner Execution

```bash
# Run build_runner build with delete-conflicting-outputs
ww common drbb

# Run with debug mode
ww common drbb --debug

# Using full path (if needed)
./lib/sh/common.sh drbb
```

### Project Management

```bash
# Update Flutter project dependencies and configuration
ww project --update

# Using alias
ww p --update
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT
