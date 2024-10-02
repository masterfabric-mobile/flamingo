import 'dart:async';

// Importing necessary packages for logic and error handling
import 'package:flamingo_logic/src/logic_watcher.dart';
import 'package:flamingo_logic/src/modify.dart';
import 'package:flamingo_logic/src/progression.dart';
import 'package:logger/logger.dart';
import 'package:meta/meta.dart';

part 'actioner.dart'; // Importing actioner related functionality
part 'logic_core_base.dart'; // Importing base logic core functionality

/// An abstract class representing the core logic that handles events and state management.
abstract class LogicCore<EventCore, StateCore> extends LogicCoreBase<StateCore>
    implements LogicEventChain<EventCore> {
  /// Creates an instance of LogicCore with the initial state.
  LogicCore(StateCore initStateCore) : super(initStateCore);

  /// A static watcher for monitoring logic core events.
  static LogicCoreWatcher watcher = _FineLogicCoreWatcher();
  
  /// A logger instance for logging errors and events.
  static Logger logger = Logger(); // Initialize logger

  /// A static event modifier function for transforming event streams.
  static EventModifyer<dynamic> modifyer = (eventsCore, finder) {
    return eventsCore
        .map(finder) // Apply the finder to the event stream
        .transform<dynamic>(const _OnFinderStreamModifyer<dynamic>()); // Transform the stream
  };

  // Stream controller for broadcasting core events
  final _coreEventStreamController = StreamController<EventCore>.broadcast();
  
  // List of active stream subscriptions
  final _streamSubscriptions = <StreamSubscription<dynamic>>[];
  
  // List of controllers handling specific event types
  final _controllerList = <_Controller>[];
  
  // List of actioners for managing actions
  final _actioners = <_Actioner<dynamic>>[];
  
  // The event modifier function for this logic core
  final _eventCoreModifyer = LogicCore.modifyer;

  /// Adds an event core to the logic core.
  @override
  void add(EventCore eventCore) {
    // Assertion to ensure the event type is handled by at least one controller
    assert(() {
      final controllerExists = _controllerList.any((controller) => controller.isType(eventCore));
      if (!controllerExists) {
        final eventType = eventCore.runtimeType;
        throw StateError( 
          'LogicCore<$EventCore, $StateCore> does not handle events of type $eventType.',
        );
      }
      return true;
    }());
    
    try {
      onEvent(eventCore); // Process the event
      _coreEventStreamController.add(eventCore); // Broadcast the event
    } catch (error, stackTrace) {
      // Log any error encountered during the addition of the event
      logger.e('Error during adding event: $error,\nStackTrace: $stackTrace');
      onFailure(error, stackTrace); // Handle failure
      rethrow; // Rethrow the error after logging
    }
  }

  /// Processes an event core when it is added to the logic core.
  @protected
  @mustCallSuper
  void onEvent(EventCore eventCore) {
    try {
      _logicWatcher.onReceiveEventCore(this, eventCore); // Notify watcher of the received event
    } catch (error, stackTrace) {
      // Log any error encountered during event processing
      logger.e('Error during onEvent: $error,\nStackTrace: $stackTrace');
      throw error; // Re-throw the error after logging it
    }
  }

  /// A method that executes an action based on the current state.
  @visibleForTesting
  @override
  void action(StateCore state) => super.action(state);

  /// Registers an event controller for handling events of type E.
  void on<E extends EventCore>(
    EventController<E, StateCore> eventController, { // Event controller function
    EventModifyer<E>? modifyer, // Optional event modifier function
  }) {
    // Assertion to ensure the event type is not already handled by another controller
    assert(() {
      final controllerExists = _controllerList.any((controller) => controller.type == E);
      if (controllerExists) {
        throw StateError(
          'LogicCore<$EventCore, $StateCore> already handles events of type $E.',
        );
      }
      _controllerList.add(_Controller(isType: (dynamic e) => e is E, type: E)); // Add controller
      return true;
    }());

    // Create a subscription for the event stream
    final subscription = (modifyer ?? _eventCoreModifyer)(
      _coreEventStreamController.stream.where((eventCore) => eventCore is E).cast<E>(), // Filter events
      (dynamic eventCore) { // Finder function for event processing
        void onAction(StateCore stateCore) {
          if (isEnded) return; // Check if the logic core has ended
          if (this.stateCore == stateCore && _actioned) return; // Avoid duplicate actions
          
          // Notify progression watcher
          onProgression(
            Progression(
              currentStateCore: this.stateCore, // Current state
              eventCore: eventCore as E, // The event being processed
              nextStateCore: stateCore, // The next state
            ),
          );
          action(stateCore); // Execute the action for the new state
        }

        final actioner = _Actioner(onAction); // Create an actioner for managing actions
        final controller = StreamController<E>.broadcast(
          sync: true,
          onCancel: actioner.cancel, // Cancel actioner on stream cancellation
        );

        /// Handles the event processing asynchronously.
        Future<void> handleEvent() async {
          void onEnd() {
            actioner.complete(); // Complete the actioner
            _actioners.remove(actioner); // Remove from actioners list
            if (!controller.isClosed) controller.close(); // Close the controller if not closed
          }

          try {
            _actioners.add(actioner); // Add actioner to the list
            await eventController(eventCore as E, actioner); // Execute the event controller
          } catch (error, stackTrace) {
            // Log any error encountered during event handling
            logger.e('Error during handling event: $error,\nStackTrace: $stackTrace');
            onFailure(error, stackTrace); // Handle failure
            rethrow; // Rethrow the error after logging
          } finally {
            onEnd(); // Ensure the end cleanup happens
          }
        }

        handleEvent(); // Invoke the event handling function
        return controller.stream; // Return the controller's stream
      },
    ).listen(null); // Listen to the subscription
    _streamSubscriptions.add(subscription); // Add subscription to the list
  }

  /// Notifies the watcher about a state progression.
  @protected
  @mustCallSuper
  void onProgression(Progression<EventCore, StateCore> progression) {
    _logicWatcher.onProgression(this, progression); // Notify watcher of the progression
  }

  /// Cleans up resources and ends the logic core operation.
  @mustCallSuper
  @override
  Future<void> end() async {
    await _coreEventStreamController.close(); // Close the core event stream
    for (final actioner in _actioners) {
      actioner.cancel(); // Cancel all actioners
    }
    await Future.wait<void>(_actioners.map((e) => e.future)); // Wait for actioners to complete
    await Future.wait<void>(_streamSubscriptions.map((s) => s.cancel())); // Cancel all subscriptions
    return super.end(); // Call super to complete the end process
  }
}

/// A controller for managing event types.
class _Controller {
  const _Controller({required this.isType, required this.type});
  
  final bool Function(dynamic value) isType; // Function to check if a value is of the specified type
  final Type type; // The type of event this controller manages
}

/// A specific implementation of a logic core watcher.
class _FineLogicCoreWatcher extends LogicCoreWatcher {
  const _FineLogicCoreWatcher();
}

/// A transformer for modifying streams of events based on a finder function.
class _OnFinderStreamModifyer<T> extends StreamTransformerBase<Stream<T>, T> {
  const _OnFinderStreamModifyer();

  /// Binds the inner stream to the outer stream and manages subscriptions.
  @override
  Stream<T> bind(Stream<Stream<T>> stream) {
    final controller = StreamController<T>.broadcast(sync: true);

    controller.onListen = () {
      final subscriptions = <StreamSubscription<dynamic>>[];

      // Listen to the outer stream
      final outerSubscription = stream.listen(
        (subs) {
          // Listen to the inner stream
          final subscription = subs.listen(
            controller.add, // Add events to the controller
            onError: controller.addError, // Forward errors to the controller
          );

          // Handle completion of the inner stream
          subscription.onDone(() {
            subscriptions.remove(subscription);
            if (subscriptions.isEmpty) controller.close(); // Close the controller if no active subscriptions
          });

          subscriptions.add(subscription); // Add to subscriptions
        },
        onError: controller.addError, // Forward errors from outer stream
      );

      // Handle completion of the outer stream
      outerSubscription.onDone(() {
        subscriptions.remove(outerSubscription);
        if (subscriptions.isEmpty) controller.close(); // Close the controller if no active subscriptions
      });

      subscriptions.add(outerSubscription); // Add outer subscription to list

      // Handle controller cancellation
      controller.onCancel = () {
        if (subscriptions.isEmpty) return null; // If no subscriptions, do nothing
        final cancels = [for (final s in subscriptions) s.cancel()]; // Cancel all subscriptions
        return Future.wait(cancels).then((_) {}); // Wait for cancellations to complete
      };
    };

    return controller.stream; // Return the controller's stream
  }
}

/// An abstract class representing a chain of logic events.
abstract class LogicEventChain<EventCore extends Object?> implements ErrorChain {
  /// Adds an event core to the logic event chain.
  void add(EventCore eventCore);
}

/// Type definition for an event controller that handles an event and performs an action.
typedef EventController<EventCore, StateCore> = FutureOr<void> Function(
  EventCore eventCore, // The event core to be handled
  Actioner<StateCore> action, // The action to perform based on the event
);

/// Type definition for a function that finds events in a stream.
typedef EventFinderCore<EventCore> = Stream<EventCore> Function(EventCore eventCore);

/// Type definition for a modifier function that transforms event streams.
typedef EventModifyer<EventCore> = Stream<EventCore> Function(
  Stream<EventCore> eventsCore, // Input stream of events
  EventFinderCore<EventCore> finder, // Function to find events
);
