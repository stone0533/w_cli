# w_cli

A command-line tool for Flutter projects, including API code generation and app building.

## Features

- **API Code Generation**: Automatically generate API-related code from client.dart
- **Flutter App Building**: Build Flutter apps for Android (APK/AAB) and iOS (IPA)
- **Project Creation**: Create Flutter projects with custom structure
- **Dependency Management**: Install and remove dependencies
- **Code Generation**: Generate locales and models

## Installation

### Method 1: Global Installation

```bash
dart pub global activate --source=path /path/to/w_cli
```

### Method 2: Build from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/w_cli.git
   cd w_cli
   ```

2. Build the executable:
   ```bash
   dart compile exe bin/w_cli.dart -o w
   ```

3. Add to system path:
   ```bash
   # macOS/Linux
   sudo mv w /usr/local/bin/
   
   # Windows (run as administrator)
   move w C:\Windows\System32\
   ```

## Usage

### Basic Commands

```bash
# Show help
w --help

# Show version
w --version

# Create a new Flutter project
w create project my_app

# Initialize project structure
w init

# Generate API code
w generate api

# Build Flutter app
w build apk
w build aab
w build ios

# Update w_cli to latest version
w update
```

### API Code Generation

```bash
# Generate API code
w generate api

# Generate with debug mode
w generate api --debug
```

### Flutter App Building

```bash
# Build APK in production mode
w build apk

# Build AAB in production mode
w build aab

# Build iOS in production mode
w build ios

# Build in UAT mode
w build apk -uat

# Increment version and build
w build apk --increment

# Clear build directory and build
w build apk -clear
```

### Dependency Management

```bash
# Install dependencies
w install http path

# Remove dependencies
w remove http
```

### Code Generation

```bash
# Generate locales
w generate locales assets/locales

# Generate model
w generate model on home with assets/models/user.json
```

## Project Structure

```
w_cli/
├── bin/
│   └── w_cli.dart            # Main entry point
├── lib/
│   ├── w.dart                # Command handlers
│   ├── w_cli.dart            # Command handlers
│   └── sh/
│       ├── api_gen.sh        # API code generation script
│       ├── build.sh          # Flutter app building script
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
