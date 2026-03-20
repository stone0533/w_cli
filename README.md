# w_cli

A command-line tool for Flutter projects, including API code generation and app building.

## Features

- **API Code Generation**: Automatically generate API-related code from client.dart
- **Flutter App Building**: Build Flutter apps for Android (APK/AAB) and iOS (IPA)
- **Project Creation**: Create Flutter projects with custom structure
- **Dependency Management**: Install and remove dependencies
- **Code Generation**: Generate locales and models
- **Project Cleaning**: Clean Flutter project build files
- **Project Opening**: Open Flutter project in IDEs and file managers

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

# Initialize project structure
ww init

# Generate API code
ww generate api

# Build Flutter app
ww build apk
ww build aab
ww build ios

# Update w_cli to latest version
ww update

# Clean Flutter app
ww clean

# Open Flutter project
ww open ios
ww open android
ww open build
```

### API Code Generation

```bash
# Generate API code
ww generate api

# Generate with debug mode
ww generate api --debug
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

# Build multiple platforms
ww build apk aab

# Build all platforms in UAT mode with clean
ww build apk aab ios --uat --clean
```

### Dependency Management

```bash
# Install dependencies
ww install http path

# Remove dependencies
ww remove http
```

### Code Generation

```bash
# Generate locales
ww generate locales assets/locales

# Generate model
ww generate model on home with assets/models/user.json
```

### Project Cleaning

```bash
# Clean Flutter project
ww clean

# Clean specific platform
ww clean android
ww clean ios
ww clean all

# Clean with lock files
ww clean --lock

# Clean iOS Pods
ww clean ios --pod
```

### Project Opening

```bash
# Open iOS project in Xcode
ww open ios

# Open Android project in Android Studio
ww open android

# Open build directory in file manager
ww open build
```

## Project Structure

```
w_cli/
├── bin/
│   └── w_cli.dart            # Main entry point
├── lib/
│   ├── w_cli.dart            # Command handlers
│   └── sh/
│       ├── api_gen.sh        # API code generation script
│       ├── build.sh          # Flutter app building script
│       ├── clean.sh          # Flutter app cleaning script
│       ├── open.sh           # Flutter project opening script
│       └── setup_project.sh  # Project initialization script
├── pubspec.yaml              # Project configuration
├── README.md                 # This file
├── CHANGELOG.md              # Version change log
└── LICENSE                   # License file
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT
