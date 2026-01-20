import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'http.dart';
import 'api.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WebRTCConnectionState {
  idle,
  connecting,
  connected,
  failed,
  closed
}

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  String? _sessionId;
  WebSocketChannel? _channel;
  WebRTCConnectionState _state = WebRTCConnectionState.idle;
  bool _isInitiator = false;
  bool _readySent = false;
  
  Timer? _heartbeatTimer;
  int _missedHeartbeats = 0;
  
  // Callbacks
  Function(WebRTCConnectionState)? onStateChange;
  Function(MediaStream)? onRemoteStream;
  Function(dynamic)? onError;
  Function(dynamic)? onMessage;
  Function(dynamic)? onControlCommand;

  static final List<Map<String, dynamic>> _iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
    {'urls': 'stun:stun.cloudflare.com:3478'},
    {'urls': 'stun:stun.xten.net'},
  ];

  WebRTCConnectionState get state => _state;
  String? get sessionId => _sessionId;
  MediaStream? get remoteStream => _remoteStream;
  MediaStream? get localStream => _localStream;

  void _setState(WebRTCConnectionState newState) {
    if (_state != newState) {
      print('[WebRTC] State change: $_state -> $newState');
      _state = newState;
      onStateChange?.call(newState);
    }
  }

  Future<void> initAsViewer(int targetUserId) async {
    _isInitiator = true;
    _readySent = false;
    print('[WebRTC] Initializing as VIEWER (initiator), _isInitiator=$_isInitiator');
    try {
      final res = await Api.screen.createSession(targetUserId);
      _sessionId = res['sessionId'] ?? res['id']; // Adjust based on actual API response
      if (_sessionId == null) throw Exception('Failed to create session');
      await _connectWebSocket();
    } catch (e) {
      print('[WebRTC] Init viewer error: $e');
      onError?.call(e);
      _setState(WebRTCConnectionState.failed);
    }
  }

  Future<void> initAsSharer(String sessionId) async {
    _isInitiator = false;
    _sessionId = sessionId;
    _readySent = false;
    print('[WebRTC] Initializing as SHARER (target), _isInitiator=$_isInitiator, sessionId=$sessionId');
    try {
       await _connectWebSocket();
    } catch (e) {
      print('[WebRTC] Init sharer error: $e');
      onError?.call(e);
      _setState(WebRTCConnectionState.failed);
    }
  }

  Future<void> _connectWebSocket() async {
    _setState(WebRTCConnectionState.connecting);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_access_token');
    
    if (token == null) {
      throw Exception('No access token');
    }

    // Replace http/https with ws/wss
    String wsBaseUrl = HttpService.baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
    final url = '$wsBaseUrl/screen/$_sessionId/stream?token=$token';
    
    print('[WebRTC] Connecting to WebSocket: $url');
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      
      _channel!.stream.listen((message) {
        _onWebSocketMessage(message);
      }, onDone: () {
        print('[WebRTC] WebSocket closed');
        _stopHeartbeat();
        if (_state != WebRTCConnectionState.closed) {
           _closeInternal();
        }
      }, onError: (error) {
        print('[WebRTC] WebSocket error: $error');
        onError?.call(error);
      });

      _startHeartbeat();
    } catch (e) {
      print('[WebRTC] WebSocket connection failed: $e');
      rethrow;
    }
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_state != WebRTCConnectionState.closed) {
        _sendSignalingMessage('ping', {});
        _missedHeartbeats++;
        if (_missedHeartbeats >= 3) {
          print('[WebRTC] Heartbeat timeout');
          close();
        }
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _missedHeartbeats = 0;
  }

  void _onWebSocketMessage(dynamic data) async {
    // Reset heartbeat
    _missedHeartbeats = 0;
    
    try {
      if (data is String) {
        final message = jsonDecode(data);
        final type = message['type'];
        final payload = message['payload'] ?? message['data']; // payload or data depending on message type

        print('[WebRTC] Received: $type');

        switch (type) {
          case 'connected':
             // Backend currently仅向控制端推送 session_status:active。
             // 为保证握手，目标端在连接建立后也主动发送 ready。
             if (!_isInitiator && !_readySent) {
               print('[WebRTC] Target sending ready after connected');
               _sendSignalingMessage('ready', {});
               _readySent = true;
             }
             break;
          case 'session_status':
             final status = payload['status'];
             print('[WebRTC] Session status: $status, _isInitiator=$_isInitiator, _readySent=$_readySent');
             
             if (status == 'active') {
               onMessage?.call({'type': 'session-accepted', 'data': payload});
               
               // Target (sharer) sends ready after accepting
               print('[WebRTC] Checking ready conditions: _readySent=$_readySent, _isInitiator=$_isInitiator');
               if (!_readySent && !_isInitiator) {
                 print('[WebRTC] Target sending ready signal');
                 _sendSignalingMessage('ready', {});
                 _readySent = true;
               } else {
                 print('[WebRTC] NOT sending ready: _readySent=$_readySent, _isInitiator=$_isInitiator');
               }
             } else if (status == 'rejected') {
               _setState(WebRTCConnectionState.failed);
               onMessage?.call({'type': 'session-rejected'});
               close();
             } else if (payload['status'] == 'closed') {
               close();
             }
             break;
          case 'ready':
             print('[WebRTC] Received ready signal, _isInitiator=$_isInitiator, _readySent=$_readySent');
             // Initiator creates offer when target is ready
             if (_isInitiator && !_readySent) {
               print('[WebRTC] Initiator creating peer connection and offer');
               _readySent = true;
               await _createPeerConnection();
               await _createOffer();
             } else {
               print('[WebRTC] NOT creating offer: _isInitiator=$_isInitiator, _readySent=$_readySent');
             }
             break;
          case 'offer':
             print('[WebRTC] Received offer from initiator');
             // Target creates peer connection when receiving offer
             if (!_isInitiator) {
               // Don't create peer connection here - let _handleOffer do it
               // so that screen share can be started first
               await _handleOffer(payload);
             }
             break;
          case 'answer':
             if (_isInitiator) {
               await _handleAnswer(payload);
             }
             break;
          case 'ice-candidate':
             await _handleIceCandidate(payload);
             break;
          case 'control':
             if (!_isInitiator) {
               onControlCommand?.call(payload);
             }
             break;
          case 'pong':
             break;
          case 'peer-left':
          case 'peer_disconnected':
             close();
             break;
          case 'error':
             final errorMsg = message['error'] ?? message['message'] ?? 'Unknown error';
             print('[WebRTC] Server error: $errorMsg');
             
             // Don't immediately fail on "Peer target not connected" - they might still be connecting
             if (errorMsg.toString().contains('not connected')) {
               print('[WebRTC] Target not connected yet, waiting...');
             } else {
               onError?.call(message);
               _setState(WebRTCConnectionState.failed);
             }
             break;
        }
      }
    } catch (e) {
      print('[WebRTC] Parse message error: $e');
    }
  }

  Future<void> _createPeerConnection() async {
    if (_peerConnection != null) return;

    final config = {
      'iceServers': _iceServers,
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': _isInitiator ? 'max-bundle' : 'balanced',
      'rtcpMuxPolicy': _isInitiator ? 'require' : 'negotiate',
    };

    _peerConnection = await createPeerConnection(config);

    _peerConnection!.onIceCandidate = (candidate) {
      _sendSignalingMessage('ice-candidate', {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _peerConnection!.onIceConnectionState = (state) {
      print('[WebRTC] ICE state: $state');
    };

    _peerConnection!.onConnectionState = (state) {
      print('[WebRTC] Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _setState(WebRTCConnectionState.connected);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
                 state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _setState(WebRTCConnectionState.failed);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _setState(WebRTCConnectionState.closed);
      }
    };

    _peerConnection!.onTrack = (event) {
      print('[WebRTC] OnTrack');
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        onRemoteStream?.call(_remoteStream!);
      }
    };

    // Attach local tracks for sharer if already available
    if (!_isInitiator && _localStream != null) {
      for (var track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
      print('[WebRTC] Added ${_localStream!.getTracks().length} local tracks to peer connection');
    } else {
       // Initiator is recvonly.
       // Add transceiver for video recvonly
       await _peerConnection!.addTransceiver(
         kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
         init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
       );
    }
  }

  // Flag to track if foreground service is running
  static bool _foregroundServiceStarted = false;
  static const _foregroundServiceChannel = MethodChannel('com.example.know_you/foreground_service');
  
  Future<void> startScreenShare() async {
    if (_isInitiator) return;
    
    try {
      // On Android 10+, we need to start a foreground service before screen capture
      if (Platform.isAndroid) {
        await _startForegroundService();
      }
      
      // Prefer display media for screen sharing; fallback to camera if unavailable
      try {
        _localStream = await navigator.mediaDevices.getDisplayMedia({
          'audio': false,
          'video': {
            'frameRate': 15,
            'width': {'ideal': 1280},
            'height': {'ideal': 720},
          }
        });
        print('[WebRTC] getDisplayMedia success');
      } catch (e) {
        print('[WebRTC] getDisplayMedia failed, fallback to getUserMedia: $e');
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': false,
          'video': {
            'mandatory': {
              'minWidth': '640',
              'minHeight': '480',
              'minFrameRate': '15',
            },
            'facingMode': 'environment',
            'optional': [],
          }
        });
      }
      
      // Note: tracks will be added to peer connection in _createPeerConnection()
      // when _localStream is available
      
      print('[WebRTC] Screen share started with ${_localStream!.getTracks().length} tracks');
    } catch (e) {
      print('[WebRTC] Start screen share error: $e');
      // Stop foreground service on error
      if (Platform.isAndroid) {
        await _stopForegroundService();
      }
      rethrow;
    }
  }
  
  Future<void> _startForegroundService() async {
    if (_foregroundServiceStarted) return;
    
    try {
      await _foregroundServiceChannel.invokeMethod('startForegroundService');
      _foregroundServiceStarted = true;
      print('[WebRTC] Foreground service started');
    } catch (e) {
      print('[WebRTC] Failed to start foreground service: $e');
      // Continue anyway - might work on older Android versions
    }
  }
  
  Future<void> _stopForegroundService() async {
    if (!_foregroundServiceStarted) return;
    
    try {
      await _foregroundServiceChannel.invokeMethod('stopForegroundService');
      _foregroundServiceStarted = false;
      print('[WebRTC] Foreground service stopped');
    } catch (e) {
      print('[WebRTC] Failed to stop foreground service: $e');
    }
  }

  Future<void> _createOffer() async {
    try {
      RTCSessionDescription offer = await _peerConnection!.createOffer({
        'offerToReceiveVideo': true,
        'offerToReceiveAudio': false,
      });
      
      // Fix SDP for recvonly if initiator
      if (_isInitiator) {
         String sdp = offer.sdp ?? '';
         sdp = sdp.replaceAll('a=sendrecv', 'a=recvonly');
         sdp = sdp.replaceAll('a=sendonly', 'a=recvonly');
         offer = RTCSessionDescription(sdp, offer.type);
      }

      await _peerConnection!.setLocalDescription(offer);
      
      _sendSignalingMessage('offer', {
        'type': offer.type,
        'sdp': offer.sdp,
      });
    } catch (e) {
      print('[WebRTC] Create offer error: $e');
    }
  }

  Future<void> _handleOffer(dynamic payload) async {
    try {
      // Target needs local stream before creating peer connection
      if (_peerConnection == null) {
        // Start screen share BEFORE creating peer connection
        if (!_isInitiator && _localStream == null) {
           print('[WebRTC] Starting screen share before creating peer connection');
           await startScreenShare();
        }
        
        await _createPeerConnection();
      }
      
      String sdp = payload['sdp'];
      String type = payload['type'];
      
      print('[WebRTC] Setting remote description');
      await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, type));
      
      print('[WebRTC] Creating answer');
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      
      print('[WebRTC] Sending answer');
      _sendSignalingMessage('answer', {
        'type': answer.type,
        'sdp': answer.sdp,
      });
    } catch (e) {
       print('[WebRTC] Handle offer error: $e');
       onError?.call(e);
    }
  }

  Future<void> _handleAnswer(dynamic payload) async {
    try {
      String sdp = payload['sdp'];
      String type = payload['type'];
      await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, type));
    } catch (e) {
      print('[WebRTC] Handle answer error: $e');
    }
  }

  Future<void> _handleIceCandidate(dynamic payload) async {
    try {
      if (_peerConnection != null) {
        await _peerConnection!.addCandidate(RTCIceCandidate(
          payload['candidate'],
          payload['sdpMid'],
          payload['sdpMLineIndex'],
        ));
      }
    } catch (e) {
      print('[WebRTC] Handle ICE error: $e');
    }
  }

  void _sendSignalingMessage(String type, dynamic payload) {
    if (_channel != null) {
      final msg = jsonEncode({
        'type': type,
        'payload': payload
      });
      print('[WebRTC] Sending message: type=$type, payload=$payload');
      _channel!.sink.add(msg);
    } else {
      print('[WebRTC] ERROR: Cannot send $type message, WebSocket channel is null');
    }
  }

  void sendControlCommand(String command, dynamic payload) {
    _sendSignalingMessage('control', {
      'command': command,
      'payload': payload ?? {}
    });
  }

  Future<void> close() async {
    if (_sessionId != null) {
      try {
        await Api.screen.close(_sessionId!);
      } catch (e) {
        // ignore
      }
    }
    _closeInternal();
  }

  void _closeInternal() {
    print('[WebRTC] Closing internal resources');
    _stopHeartbeat();
    
    // Close WebSocket
    try {
      _channel?.sink.close();
    } catch (e) {
      print('[WebRTC] Error closing WebSocket: $e');
    }
    _channel = null;
    
    // Dispose local stream
    try {
      _localStream?.getTracks().forEach((track) {
        track.stop();
      });
      _localStream?.dispose();
    } catch (e) {
      print('[WebRTC] Error disposing local stream: $e');
    }
    _localStream = null;
    
    // Close peer connection
    try {
      _peerConnection?.close();
    } catch (e) {
      print('[WebRTC] Error closing peer connection: $e');
    }
    _peerConnection = null;
    
    // Stop foreground service on Android
    if (Platform.isAndroid) {
      _stopForegroundService();
    }
    
    // Reset all state
    _sessionId = null;
    _readySent = false;
    _remoteStream = null;
    
    _setState(WebRTCConnectionState.closed);
  }
  
  /// Reset the service to idle state for reuse
  void reset() {
    print('[WebRTC] Resetting service to idle state');
    _closeInternal();
    _state = WebRTCConnectionState.idle;
  }
}
