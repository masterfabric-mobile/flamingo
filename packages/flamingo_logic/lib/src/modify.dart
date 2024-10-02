import 'package:meta/meta.dart'; // Importing the meta package for the @immutable annotation.
import 'package:logger/logger.dart'; // Importing the logger package for logging errors.

// Creating a Logger instance for logging messages.
final logger = Logger();

/// A class that represents a state modification between a current state and a next state.
@immutable // This annotation indicates that instances of this class are immutable.
class Modify<StateCore> {
  /// Creates an instance of Modify with the given current and next states.
  const Modify({required this.currentStateCore, required this.nextStateCore});
  
  /// The current state before modification.
  final StateCore currentStateCore;
  
  /// The next state after modification.
  final StateCore nextStateCore;

  /// Overriding the equality operator to compare two Modify instances.
  @override
  bool operator ==(Object other) {
    try {
      // Check if both references point to the same instance.
      if (identical(this, other)) return true;

      // Check if the other object is of the same type.
      if (other is! Modify<StateCore>) return false;

      // Ensure the runtime types are the same.
      if (runtimeType != other.runtimeType) return false;

      // Compare current states for equality.
      return currentStateCore == other.currentStateCore &&
          nextStateCore == other.nextStateCore; // Compare next states for equality.
    } catch (e, stackTrace) {
      // Log any unexpected errors that occur during the equality check.
      logger.e('Error during equality check: $e,\nStackTrace: $stackTrace');
      return false; // Return false if an error occurs.
    }
  }

  /// Overriding the hashCode getter to provide a unique hash code based on the states.
  @override
  int get hashCode {
    try {
      // Combining the hash codes of both states.
      return currentStateCore.hashCode ^ nextStateCore.hashCode;
    } catch (e, stackTrace) {
      // Log any unexpected errors that occur while computing hashCode.
      logger.e('Error during hash code calculation: $e\nStackTrace: $stackTrace');
      return 0; // Return 0 as a default hash code if an error occurs.
    }
  }

  /// Overriding the toString method to provide a string representation of the Modify instance.
  @override
  String toString() {
    try {
      // Returns a descriptive string of the object.
      return 'Modify { currentState: $currentStateCore, nextState: $nextStateCore }';
    } catch (e, stackTrace) {
      // Log any unexpected errors that occur during string conversion.
      logger.e('Error during string conversion: $e\nStackTrace: $stackTrace');
      return 'Modify { currentState: <error>, nextState: <error> }'; // Return an error indication.
    }
  }
}