part of 'logic_core.dart';
// Creating a Logger instance for logging messages.
final logger = Logger();

// Actioner is an abstract class that defines an interface for managing state actions.
abstract class Actioner<StateCore> {
  // Method to listen to each action in the stream.
  // It processes data coming from the stream and provides error handling callbacks.
  Future<void> onEachAction<T>(
    Stream<T> streamCore, {
    required void Function(T data) onData, // Function to handle data from the stream.
    void Function(Object error, StackTrace stackTrace)? onError, // Optional function to handle errors.
  });

  // Method to handle each action in the stream, transforming the data into a state.
  Future<void> forEachAction<T>(
    Stream<T> streamCore, {
    required StateCore Function(T data) onData, // Function to transform stream data into state.
    StateCore Function(Object error, StackTrace stackTrace)? onError, // Optional function to handle errors.
  });

  // Getter to check if the action has ended.
  bool get isEnd;

  // Method to call the provided action with the current state.
  void call(StateCore stateCore);
}

// Private class implementing the Actioner interface.
class _Actioner<StateCore> implements Actioner<StateCore> {
  // Constructor that accepts a function to execute with the current state.
  _Actioner(this._action);

  final void Function(StateCore stateCore) _action; // The action function to execute.
  final _completer = Completer<void>(); // Completer to manage the completion state of the action.
  final _disposables = <FutureOr<void> Function()>[]; // List to hold disposable resources.

  var _isEnded = false; // Flag to track if the action has ended.
  var _isCompleted = false; // Flag to track if the action has been completed.

  @override
  Future<void> onEachAction<T>(
    Stream<T> streamCore, {
    required void Function(T data) onData,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    final completer = Completer<void>(); // Completer for this specific stream action.
    StreamSubscription<T>? subs; // Stream subscription variable to manage the listener.

    try {
      // Listening to the stream and defining the actions for data, done, and error cases.
      subs = streamCore.listen(
        onData, // On receiving data, execute the onData function.
        onDone: completer.complete, // When the stream is done, complete the completer.
        onError: (error, stackTrace) {
          // Handle errors by either calling the provided onError or logging the error.
          if (onError != null) {
            onError(error, stackTrace); // Call the user-defined error handler.
          } else {
            // Log the error using the logger package.
            logger.e('Error occurred: $error\nStackTrace:$stackTrace');
            completer.completeError(error, stackTrace); // Complete with error if no handler is provided.
          }
        },
        cancelOnError: onError == null, // Cancel subscription on error if no error handler is provided.
      );

      _disposables.add(subs.cancel); // Add the subscription cancellation to disposables list.
      await Future.any([future, completer.future]); // Wait for either the completer or the main future to complete.
    } catch (e, stackTrace) {
      // Catch any unexpected errors during stream processing.
      logger.e('Unexpected error occurred: $e\nStackTrace:$stackTrace'); // Log the caught exception.
    } finally {
      // Cleanup: Cancel the subscription and remove from disposables.
      if (subs != null) {
        await subs.cancel(); // Cancel the subscription to free resources.
        _disposables.remove(subs.cancel); // Remove the cancellation function from disposables.
      }
    }
  }

  @override
  Future<void> forEachAction<T>(
    Stream<T> streamCore, {
    required StateCore Function(T data) onData,
    StateCore Function(Object error, StackTrace stackTrace)? onError,
  }) {
    // Call onEachAction with a transformed onData function and error handler.
    return onEachAction<T>(
      streamCore,
      onData: (data) {
        try {
          // Call the provided onData function and pass the transformed data to the state management call.
          call(onData(data));
        } catch (e, stackTrace) {
          // Catch any errors from the onData processing.
          logger.e('Error in onData processing: $e\nStackTrace: $stackTrace'); // Log the caught exception.
        }
      },
      onError: onError != null
          ? (Object error, StackTrace stackTrace) {
              // Handle errors using the provided onError function.
              try {
                call(onError(error, stackTrace)); // Call user-defined error handler.
              } catch (e, stackTrace) {
                // Catch any errors from the error handler.
                logger.e('Error in error handler: $e\nStackTrace: $stackTrace'); // Log the caught exception.
              }
            }
          : null, // No error handler provided.
    );
  }

  @override
  void call(StateCore stateCore) {
    assert(
      !_isCompleted,
      'Cannot call action after completed', // Ensure the action is not completed before calling.
    );
    if (!_isEnded) _action(stateCore); // Call the action with the current state if not ended.
  }

  @override
  bool get isEnd => _isEnded || _isCompleted; // Return true if the action has ended or completed.

  // Method to cancel the ongoing action.
  void cancel() {
    if (isEnd) return; // Do nothing if the action has already ended.
    _isEnded = true; // Mark the action as ended.
    _end(); // Call the cleanup method to release resources.
  }

  // Method to complete the ongoing action.
  void complete() {
    if (isEnd) return; // Do nothing if the action has already ended.
    assert(
      _disposables.isEmpty,
      'Cannot complete action while streamCore is active', // Ensure no active stream before completing.
    );
    _isCompleted = true; // Mark the action as completed.
    _end(); // Call the cleanup method to release resources.
  }

  // Private method to clean up and dispose of resources.
  void _end() {
    for (final disposable in _disposables) {
      disposable.call(); // Call each disposable function to clean up resources.
    }
    _disposables.clear(); // Clear the disposables list.
    if (!_completer.isCompleted) _completer.complete(); // Complete the main completer if not already done.
  }

  Future<void> get future => _completer.future; // Expose the main completer's future for awaiting.
}