import 'package:flamingo_logic/src/modify.dart'; // Importing the Modify class from the flamingo_logic package
import 'package:meta/meta.dart'; // Importing the meta package for annotations like @immutable
// Importing the logger package for logging errors

@immutable // This annotation indicates that instances of this class cannot change after being created
class Progression<EventCore, StateCore> extends Modify<StateCore> {
  // Constructor for the Progression class
  const Progression({
    required StateCore currentStateCore, // The current state, required parameter
    required this.eventCore, // The event that triggers the state change, required parameter
    required StateCore nextStateCore, // The next state after the event, required parameter
  }) : super(currentStateCore: currentStateCore, nextStateCore: nextStateCore);

  final EventCore eventCore; // Field to store the event

  // Overriding the equality operator (==) to compare two Progression instances
  @override
  bool operator ==(Object other) {
    try {
      // Check if the other object is identical to this instance
      return identical(this, other) ||
          // Check if the other object is a Progression instance with the same properties
          other is Progression<EventCore, StateCore> &&
              runtimeType == other.runtimeType &&
              currentStateCore == other.currentStateCore &&
              eventCore == other.eventCore &&
              nextStateCore == other.nextStateCore;
    } catch (e, stackTrace) {
      // If an error occurs, log the error message and stack trace
      logger.e('Error during equality check: $e,\nStackTrace: $stackTrace');
      return false; // Return false if there was an error
    }
  }

  // Overriding the hashCode getter for generating a hash code for the object
  @override
  int get hashCode {
    // Combine the hash codes of currentStateCore, eventCore, and nextStateCore
    return currentStateCore.hashCode ^
        eventCore.hashCode ^
        nextStateCore.hashCode;
  }

  // Overriding the toString method to provide a string representation of the object
  @override
  String toString() {
    try {
      // Return a formatted string representing the Progression instance
      return '''Progression { currentStateCore: $currentStateCore, eventCore: $eventCore, nextStateCore: $nextStateCore }''';
    } catch (e, stackTrace) {
      // If an error occurs, log the error message and stack trace
      logger.e('Error during string representation: $e,\nStackTrace: $stackTrace');
      // Return a string representation with an error indication
      return 'Progression { currentStateCore: $currentStateCore, eventCore: [ERROR], nextStateCore: $nextStateCore }';
    }
  }
}