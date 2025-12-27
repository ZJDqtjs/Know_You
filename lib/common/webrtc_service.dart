import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
             break;
          case 'session_status':
             if (payload['status'] == 'active') {
               onMessage?.call({'type': 'session-accepted', 'data': payload});
               if (!_readySent) {
                 // Give the peer time to join WebSocket before sending ready to avoid "target not connected"
                 Future.delayed(const Duration(seconds: 1), () {
                   if (!_readySent && _channel != null) {
                     _sendSignalingMessage('ready', {});
                     _readySent = true;
                   }
                 });
               }
             } else if (payload['status'] == 'rejected') {
               _setState(WebRTCConnectionState.failed);
               onMessage?.call({'type': 'session-rejected'});
               close();
             } else if (payload['status'] == 'closed') {
               close();
             }
             break;
          case 'ready':
             if (_isInitiator) {
               await _createPeerConnection();
               await _createOffer();
             }
             break;
          case 'offer':
             if (!_isInitiator) {
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
             print('[WebRTC] Server error: $message');
             onError?.call(message);
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

    // Add local tracks if needed (Sharer)
    // For now, I'll skip implementation of screen capture start here, as it usually requires platform specific code or flutter_webrtc plugins.
    // The user said "functionality is complete" in source, I need to replicate it.
    // If I am Sharer, I need to capture screen.
    if (!_isInitiator) {
       // Logic to start screen capture
       // In flutter_webrtc, navigator.mediaDevices.getDisplayMedia
    } else {
       // Initiator is recvonly.
       // Add transceiver for video recvonly
       await _peerConnection!.addTransceiver(
         kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
         init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
       );
    }
  }

  Future<void> startScreenShare() async {
    if (_isInitiator) return;
    
    try {
      final mediaConstraints = <String, dynamic>{
        'audio': false,
        'video': true
      };
      
      _localStream = await navigator.mediaDevices.getDisplayMedia(mediaConstraints);
      _localStream!.getTracks().forEach((track) {
        _peerConnection?.addTrack(track, _localStream!);
      });
    } catch (e) {
      print('[WebRTC] Start screen share error: $e');
      rethrow;
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
      if (_peerConnection == null) {
        await _createPeerConnection();
        // If sharer, start screen share now or ensure it's ready
        if (_localStream == null) {
             // Request screen share permission and start
             await startScreenShare();
        }
      }
      
      String sdp = payload['sdp'];
      String type = payload['type'];
      
      await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, type));
      
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      
      _sendSignalingMessage('answer', {
        'type': answer.type,
        'sdp': answer.sdp,
      });
    } catch (e) {
       print('[WebRTC] Handle offer error: $e');
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
      _channel!.sink.add(msg);
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
    _stopHeartbeat();
    _channel?.sink.close();
    _channel = null;
    
    _localStream?.dispose();
    _localStream = null;
    
    _peerConnection?.close();
    _peerConnection = null;
    
    _sessionId = null;
    _readySent = false;
    _remoteStream = null;
    
    _setState(WebRTCConnectionState.closed);
  }
}
