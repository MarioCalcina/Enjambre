import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'flutter_libtransmission_bindings_generated.dart';

const String _libName = 'flutter_libtransmission';

/// For very short-lived functions, it is fine to call them on the main isolate.
/// They will block the Dart execution while running the native function, so
/// only do this for native functions which are guaranteed to be short-lived.
void initSession(String configDir) =>
    _bindings.init_session(configDir.toNativeUtf8().cast<Char>());

void closeSession() => _bindings.close_session();

void saveSettings() => _bindings.save_settings();

void resetSettings() => _bindings.reset_settings();

/// Sends a request to transmission and completes with its response.
///
/// Submitting never blocks, so a slow request (`torrent-add` from an url can
/// take up to 120s) does not hold back the others. Requests still go through a
/// helper isolate, because transmission runs its synchronous rpc methods on the
/// calling thread.
Future<String> requestAsync(String json) async {
  final SendPort helperIsolateSendPort = await _helperIsolateSendPort;
  final int requestId = _nextTransmissionRequestId++;
  final Completer<String> completer = Completer<String>();
  _requestRequests[requestId] = completer;
  final _TransmissionRequest request =
      _TransmissionRequest(requestId, json, _responseCallback.nativeFunction);
  helperIsolateSendPort.send(request);
  return completer.future;
}

/// The dynamic library in which the symbols for [FlutterLibtransmissionBindings] can be found.
final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final FlutterLibtransmissionBindings _bindings =
    FlutterLibtransmissionBindings(_dylib);

/// Completes the request the response belongs to.
void _onResponse(int requestId, Pointer<Char> json) {
  final String result = json.cast<Utf8>().toDartString();
  _bindings.free_response(json);
  _requestRequests.remove(requestId)?.complete(result);
}

/// A listener callback can be invoked from any thread, and runs [_onResponse]
/// on the isolate that created it. Never closed: that would drop the responses
/// of any request still in flight.
final NativeCallable<response_callbackFunction> _responseCallback =
    NativeCallable<response_callbackFunction>.listener(_onResponse);

/// A request to send to transmission.
///
/// Typically sent from one isolate to another.
class _TransmissionRequest {
  final int id;
  final String json;
  final response_callback callback;

  const _TransmissionRequest(this.id, this.json, this.callback);
}

/// Counter to identify [_TransmissionRequest]s and their responses.
int _nextTransmissionRequestId = 0;

/// Mapping from [_TransmissionRequest] `id`s to the completers corresponding to the correct future of the pending request.
final Map<int, Completer<String>> _requestRequests = <int, Completer<String>>{};

/// The SendPort belonging to the helper isolate.
Future<SendPort> _helperIsolateSendPort = () async {
  // The helper isolate is going to send us back a SendPort, which we want to
  // wait for.
  final Completer<SendPort> completer = Completer<SendPort>();

  // Receive port on the main isolate to receive the port to send messages on.
  // Responses do not go through here, [_responseCallback] delivers them.
  final ReceivePort receivePort = ReceivePort()
    ..listen((dynamic data) {
      if (data is SendPort) {
        // The helper isolate sent us the port on which we can sent it requests.
        completer.complete(data);
        return;
      }
      throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
    });

  // Start the helper isolate.
  await Isolate.spawn((SendPort sendPort) async {
    final ReceivePort helperReceivePort = ReceivePort()
      ..listen((dynamic data) {
        // On the helper isolate listen to requests and submit them.
        if (data is _TransmissionRequest) {
          final Pointer<Utf8> json = data.json.toNativeUtf8();
          try {
            _bindings.request_async(data.id, json.cast<Char>(), data.callback);
          } finally {
            // request_async parsed the json, the buffer can go.
            malloc.free(json);
          }
          return;
        }
        throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
      });

    // Send the port to the main isolate on which we can receive requests.
    sendPort.send(helperReceivePort.sendPort);
  }, receivePort.sendPort);

  // Wait until the helper isolate has sent us back the SendPort on which we
  // can start sending requests.
  return completer.future;
}();
