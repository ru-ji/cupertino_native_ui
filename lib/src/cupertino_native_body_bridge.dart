import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Carries state between the host app and a scaffold body — the only way they
/// *can* talk.
///
/// Each body runs in its own FlutterEngine, so in its own isolate. Isolates
/// share no memory: a Riverpod `ProviderContainer`, a BLoC, a `ValueNotifier`,
/// a `BuildContext` — none of it reaches across. Objects cannot be passed,
/// only **data**.
///
/// So the pattern is mirroring, not sharing. In the host, watch whatever your
/// state manager already holds and publish a serializable snapshot; in the
/// body, read that snapshot and send actions back.
///
/// ```dart
/// // Host: mirror the providers the bodies care about.
/// ref.listen(cartProvider, (_, cart) {
///   CupertinoNativeBodyBridge.publish({'count': cart.count, 'total': cart.total});
/// });
/// CupertinoNativeBodyBridge.onAction = (action, payload) {
///   if (action == 'addItem') ref.read(cartProvider.notifier).add(payload! as String);
/// };
///
/// // Body: read the mirror, send intent back.
/// ValueListenableBuilder(
///   valueListenable: CupertinoNativeBodyBridge.state,
///   builder: (context, state, _) => Text('${state['count']} items'),
/// );
/// CupertinoNativeBodyBridge.send('addItem', 'sku-42');
/// ```
///
/// Everything crossing must survive `StandardMessageCodec`: null, bool, num,
/// String, Uint8List, List and Map of those. Serialize your own types.
///
/// **The cheaper answer is often to not cross at all.** A body that is mostly
/// system controls can be a `CupertinoNativePageScaffold.nativeBody` instead —
/// that runs no engine, so it lives in the host isolate and your existing
/// state management works untouched.
abstract final class CupertinoNativeBodyBridge {
  /// The scaffold platform view's channel, on the host side. Assigned by
  /// `CupertinoNativePageScaffold` when its view is created.
  static MethodChannel? hostChannel;

  static const _bodyChannel = MethodChannel(
    'cupertino_widgets/scaffold_body',
  );

  static final ValueNotifier<Map<String, Object?>> _state =
      ValueNotifier<Map<String, Object?>>(const {});

  /// The last snapshot published by the host. Read this from a body.
  ///
  /// Empty until the host publishes — a body that boots mid-session has
  /// missed whatever came before, so publish on a change *and* whenever a
  /// body asks (see [requestState]).
  static ValueListenable<Map<String, Object?>> get state => _state;

  /// Called in the host when a body sends an action.
  static void Function(String action, Object? payload)? onAction;

  /// Host → every body. Replaces the previous snapshot; bodies see it on
  /// [state].
  static Future<void> publish(Map<String, Object?> snapshot) async {
    // No scaffold mounted yet, or none at all: nothing to publish to.
    await hostChannel?.invokeMethod<void>('publishBodyState', snapshot);
  }

  /// Body → host. [payload] must be codec-serializable.
  static Future<void> send(String action, [Object? payload]) async {
    await _bodyChannel.invokeMethod<void>('sendBodyAction', {
      'action': action,
      'payload': payload,
    });
  }

  /// Body → host: "send me the current snapshot". Delivered as the action
  /// `'__requestState'`, which the host answers by calling [publish] again.
  /// Call it once when a body starts so it isn't blank until the next change.
  static Future<void> requestState() => send('__requestState');

  /// Wired by `CupertinoNativePageScaffold.maybeRun` in a body isolate.
  static void handleHostState(Object? arguments) {
    if (arguments is Map) {
      _state.value = Map<String, Object?>.from(arguments);
    }
  }

  /// Wired by `CupertinoNativePageScaffold` in the host isolate.
  static void handleBodyAction(Object? arguments) {
    if (arguments is Map) {
      onAction?.call(
        arguments['action'] as String? ?? '',
        arguments['payload'],
      );
    }
  }
}
