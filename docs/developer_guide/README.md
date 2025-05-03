# Developer Guide

This developer guide provides technical documentation for developers who want to understand or contribute to the Numerical Analysis App codebase.

## Table of Contents

1. [Project Structure](#project-structure)
2. [Architecture](#architecture)
3. [State Management](#state-management)
4. [Adding New Methods](#adding-new-methods)
5. [UI Components](#ui-components)
6. [Testing](#testing)

## Project Structure

The project follows a standard Flutter application structure with some custom organization:

```
lib/
├── main.dart              # Application entry point
├── models/                # Data models and numerical method implementations
├── screens/               # UI screens for each method and functionality
├── widgets/               # Reusable UI components
├── providers/             # State management
├── util/                  # Utility functions
└── methods/               # Method-specific utilities
```

## Architecture

The application follows a clean architecture approach with separation of concerns:

1. **UI Layer** (screens and widgets): Handles user interaction and display.
2. **Business Logic Layer** (models): Contains the core numerical algorithm implementations.
3. **Data Layer** (providers): Manages state and persistence.

## State Management

The app uses Flutter Riverpod for state management. Key providers include:

- `themeProvider`: Manages the app's theme state (light/dark mode).
- Method-specific providers for managing method inputs and calculation states.

## Adding New Methods

To add a new numerical method to the application:

1. Create a new implementation in the `models/` directory.
2. Add the method details to the `numerical_method.dart` list.
3. Create input and solution screen implementations in the `screens/` directory.
4. Update the chapter screen to include the new method.

Each numerical method should implement:
- Core algorithm logic
- Step-by-step solution tracking
- Debugging information generation

## UI Components

The app uses several custom UI components:

- `method_card`: Cards for displaying method options
- `function_graph`: Component for rendering function graphs

## Testing

Unit tests are located in the `test/` directory. To run tests:

```bash
flutter test
```

When adding new features, please ensure appropriate test coverage is maintained. 