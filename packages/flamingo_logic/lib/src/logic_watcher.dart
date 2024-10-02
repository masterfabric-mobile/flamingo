import 'package:flamingo_logic/src/logic_core.dart';
import 'package:meta/meta.dart';
import 'package:flamingo_logic/src/modify.dart';
import 'package:flamingo_logic/src/progression.dart';

/// This is an abstract class named LogicCoreWatcher.
/// It helps in watching the core logic events and actions.
abstract class LogicCoreWatcher {
  // Constructor for LogicCoreWatcher
  const LogicCoreWatcher();

  /// This method is called when the logic core is initialized.
  /// It's like when a toy is taken out of the box and ready to play.
  @protected
  @mustCallSuper
  void onInitialization(LogicCoreBase<dynamic> logicCore) {}

  /// This method is called when the logic core receives an event.
  /// Think of it like when your toy gets a new command to follow.
  @protected
  @mustCallSuper
  void onReceiveEventCore(LogicCore<dynamic, dynamic> logicCore, Object? eventCore) {}

  /// This method is called when there is a modification.
  /// Imagine when you change something about your toy, like its color or shape.
  @protected
  @mustCallSuper
  void onModification(LogicCoreBase<dynamic> logicCore, Modify<dynamic> modification) {}

  /// This method is called when a progression occurs.
  /// It’s like when your toy goes from one action to another, like moving from standing to walking.
  @protected
  @mustCallSuper
  void onProgression(
    LogicCore<dynamic, dynamic> logicCore,
    Progression<dynamic, dynamic> progression,
  ) {}

  /// This method is called when there is a failure.
  /// Think of it as when your toy gets stuck and needs help.
  @protected
  @mustCallSuper
  void onFailure(LogicCoreBase<dynamic> logicCore, Object error, StackTrace stackTrace) {}

  /// This method is called when the logic core is completed.
  /// It’s like when you finish playing with your toy and put it back in the box.
  @protected
  @mustCallSuper
  void onCompletion(LogicCoreBase<dynamic> logicCore) {}
}