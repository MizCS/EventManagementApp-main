# Testing in This Project

This directory contains unit and widget tests for the core functionality of the application. The tests are written using the [flutter_test](https://pub.dev/packages/flutter_test) package and are designed to ensure the reliability and correctness of the app's logic and models.

## Testing Methods

### 1. Unit Testing
Unit tests are used to verify the correctness of individual functions, classes, and models in isolation. These tests do not depend on the Flutter framework's UI components and are fast to execute.

- **Example:**
  - `test/auth/auth_test.dart` tests JWT token validation and decoding logic.
  - `test/models/event_test.dart` tests the `Event` model for correct property assignment, date validation, location bounds, tags, and JSON serialization.
  - `test/services/location_test.dart` tests location-related logic, such as coordinate validation and permission checks (mocked).

### 2. Widget Testing
Widget tests (also called component tests) verify the behavior and rendering of UI components. These tests use the Flutter testing framework to simulate user interactions and check widget output.

- **Example:**
  - `test/widget_test.dart` ensures that the main app widget (`MyApp`) renders without crashing and that the widget tree contains a `MaterialApp`.

### 3. Integration Testing
Integration tests verify manually that different parts of the application work together correctly. These tests simulate real user interactions and test the app as a whole, including network requests, database interactions, and UI flows.

- **Example:**
  - Testing the complete authentication flow, including login, token storage, and protected route access.
  - Testing the event creation and listing flow, ensuring that events are correctly saved and displayed.

### 4. End-to-End (E2E) Testing
E2E tests simulate real user scenarios from start to finish, often using tools like [Flutter Driver](https://docs.flutter.dev/testing/integration-tests) or [Codemagic](https://codemagic.io/). These tests are useful for validating the app's behavior in a production-like environment.

- **Example:**
  - Testing the entire user journey, from registration to event creation, and verification of data persistence.

## TO-DO:

### 5. Performance Testing
Performance tests measure the app's responsiveness, load times, and resource usage. These tests help identify bottlenecks and ensure the app performs well under various conditions.

- **Example:**
  - Measuring the time taken to load and render a list of events.
  - Testing the app's performance under low network conditions.

### 6. Accessibility Testing
Accessibility tests ensure that the app is usable by people with disabilities. These tests check for proper labeling, contrast, and navigation.

- **Example:**
  - Verifying that all interactive elements are properly labeled and accessible via screen readers.

## How the Tests Work

- **Authentication Tests:**
  - Validate JWT tokens for expiration and correct user ID extraction by dynamically generating tokens with appropriate payloads.
- **Event Model Tests:**
  - Check that event objects are created with the correct data, validate event dates (future/past), ensure location coordinates are within valid bounds, verify tags, and test JSON serialization/deserialization.
- **Location Services Tests:**
  - Validate latitude and longitude values, and mock permission checks to ensure the logic handles different permission states.
- **Widget Test:**
  - Confirms that the app's main widget builds successfully and the widget tree is as expected.

## Running the Tests

To run all tests, use the following command in the project root:

```sh
flutter test
```

This will execute all tests in the `test/` directory and report the results.

---

For more information on writing tests in Flutter, see the [Flutter testing documentation](https://docs.flutter.dev/testing/overview). 