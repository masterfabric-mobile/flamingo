part of 'logic_core.dart'; // Indicates that this file is part of 'logic_core.dart'

/// An abstract class that serves as the base for logic cores.
abstract class LogicCoreBase<StateCore>
    implements
        StateCoreBroadcastleSource<StateCore>,
        Actiontable<StateCore>,
        ErrorChain {
  /// Creates an instance of LogicCoreBase with the initial state.
  LogicCoreBase(this._stateCore) {
    _logicWatcher.onInitialization(this); // Notify the watcher on initialization
  }

  /// A watcher instance for monitoring logic core events.
  final _logicWatcher = LogicCore.watcher;

  /// A broadcast stream controller for state changes.
  late final _stateController = StreamController<StateCore>.broadcast();

  /// The current state of the logic core.
  StateCore _stateCore;

  /// A flag indicating whether an action has been performed.
  bool _actioned = false;

  /// The current state of the logic core.
  @override
  StateCore get stateCore => _stateCore;

  /// The stream of state changes.
  @override
  Stream<StateCore> get streamCore => _stateController.stream;

  /// Indicates whether the logic core has ended.
  @override
  bool get isEnded => _stateController.isClosed;

  /// Performs an action based on the given state, actioning the new state.
  @protected
  @visibleForTesting
  @override
  void action(StateCore stateCore) {
    try {
      // Check if the logic core has ended and cannot accept new actions
      if (isEnded) {
        throw StateError('Cannot action fresh state cores after calling end');
      }

      // Avoid duplicate actions for the same state
      if (stateCore == _stateCore && _actioned) return;

      // Notify of the state modification
      onModify(Modify<StateCore>(
          currentStateCore: this.stateCore, nextStateCore: stateCore));

      // Update the current state and action it through the stream
      _stateCore = stateCore;
      _stateController.add(_stateCore);
      _actioned = true; // Mark the action as performed
    } catch (error, stackTrace) {
      // Handle failure by logging the error
      onFailure(error, stackTrace);
      rethrow; // Rethrow the error after handling
    }
  }

  /// Notifies the watcher about a modification of the state.
  @protected
  @mustCallSuper
  void onModify(Modify<StateCore> modify) {
    _logicWatcher.onModification(this, modify); // Notify watcher of modification
  }

  /// Adds an error to the logic core's error chain.
  @protected
  @mustCallSuper
  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    onFailure(error, stackTrace ?? StackTrace.current); // Handle failure with the provided error
  }

  /// Handles failure scenarios and notifies the watcher.
  @protected
  @mustCallSuper
  void onFailure(Object error, StackTrace stackTrace) {
    _logicWatcher.onFailure(this, error, stackTrace); // Notify watcher of failure
  }

  /// Cleans up resources and ends the logic core operation.
  @mustCallSuper
  @override
  Future<void> end() async {
    _logicWatcher.onCompletion(this); // Notify watcher of completion
    await _stateController.close(); // Close the state controller
  }
}

/// An abstract class that defines a broadcastable stream of state.
abstract class Broadcastable<StateCore extends Object?> {
  /// A stream that actions the current state.
  Stream<StateCore> get streamCore; // Abstract getter for the core state stream
}

/// An abstract class that provides the current state and implements Broadcastable.
abstract class StateCoreBroadcastable<StateCore>
    implements Broadcastable<StateCore> {
  /// The current state of the stream.
  StateCore get stateCore; // Abstract getter for the current state
}

/// An abstract class that represents a source of broadcastable states.
abstract class StateCoreBroadcastleSource<StateCore>
    implements StateCoreBroadcastable<StateCore>, Endable {}

/// An interface representing an entity that can be ended.
abstract class Endable {
  /// Ends the current process or stream, performing necessary cleanup.
  FutureOr<void> end();

  /// Indicates whether the object has ended its process.
  bool get isEnded; // Abstract getter for checking if the entity has ended
}

/// An interface for entities that can perform actions based on a state.
abstract class Actiontable<StateCore extends Object?> {
  /// Performs an action based on the given state.
  void action(StateCore stateCore); // Abstract method for actioning state actions
}

/// An interface for handling errors in a chain of processes.
abstract class ErrorChain implements Endable {
  /// Adds an error to the chain with an optional stack trace.
  void addError(Object error, [StackTrace? stackTrace]); // Abstract method for adding errors
}