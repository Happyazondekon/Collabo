import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../services/call_service.dart';
import '../services/conversation_service.dart';
import '../services/notification_service.dart';
import '../utils/app_theme.dart';
import '../config/app_secrets.dart';


final _ringtonePlayer = FlutterRingtonePlayer();

// ─── IncomingCallPage ─────────────────────────────────────────────────────────

/// Full-screen incoming call UI (accept / decline).
/// Navigated to from home_screen when a ringing call is detected.
class IncomingCallPage extends StatefulWidget {
  final String callId;
  final String callerName;
  final String? callerAvatar;
  final bool isVideo;
  final String? conversationId;

  const IncomingCallPage({
    super.key,
    required this.callId,
    required this.callerName,
    this.callerAvatar,
    required this.isVideo,
    this.conversationId,
  });

  @override
  State<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends State<IncomingCallPage> {
  StreamSubscription? _statusSub;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _ringtonePlayer.playRingtone(looping: true, volume: 1.0, asAlarm: true);
    // Auto-dismiss if the caller hangs up before the receiver answers.
    _statusSub = CallService.callStream(widget.callId).listen((snap) {
      final data = snap.data() as Map<String, dynamic>?;
      final status = data?['status'] as String?;
      if (status == 'ended' && !_dismissed && mounted) {
        _dismiss();
      }
    });
  }

  @override
  void dispose() {
    _ringtonePlayer.stop();
    _statusSub?.cancel();
    super.dispose();
  }

  void _dismiss() {
    if (_dismissed || !mounted) return;
    _dismissed = true;
    _ringtonePlayer.stop();
    // Log missed call: caller ended before receiver answered
    if (widget.conversationId != null) {
      ConversationService.sendCallMessage(
        widget.conversationId!,
        isVideo: widget.isVideo,
        missed: true,
      );
    }
    CollaboNotificationService().showMissedCall(
      callerName: widget.callerName,
      isVideo: widget.isVideo,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A0A1F), Color(0xFF3D0B5E), Color(0xFF1A0A1F)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              // Call type pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isVideo
                          ? Icons.videocam_rounded
                          : Icons.call_rounded,
                      color: Colors.white70,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.isVideo
                          ? 'Appel vidéo entrant'
                          : 'Appel audio entrant',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              // Pulsing avatar with expanding rings
              _RingAvatar(
                  avatarUrl: widget.callerAvatar, name: widget.callerName),
              const SizedBox(height: 28),
              Text(
                widget.callerName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Appel entrant…',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
              const Spacer(),
              // Action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 52),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CallActionBtn(
                      icon: Icons.call_end_rounded,
                      label: 'Refuser',
                      color: Colors.red.shade400,
                      onTap: () async {
                        _dismissed = true;
                        _ringtonePlayer.stop();
                        await CallService.setStatus(
                            widget.callId, 'declined');
                        // Log as missed call when explicitly declined
                        if (widget.conversationId != null) {
                          await ConversationService.sendCallMessage(
                            widget.conversationId!,
                            isVideo: widget.isVideo,
                            missed: true,
                          );
                        }
                        if (mounted) Navigator.of(context).pop();
                      },
                    ),
                    _CallActionBtn(
                      icon: widget.isVideo
                          ? Icons.videocam_rounded
                          : Icons.call_rounded,
                      label: 'Accepter',
                      color: Colors.green.shade500,
                      onTap: () {
                        _dismissed = true;
                        _ringtonePlayer.stop();
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => CallScreen(
                              callId: widget.callId,
                              isCaller: false,
                              isVideo: widget.isVideo,
                              partnerName: widget.callerName,
                              partnerAvatar: widget.callerAvatar,
                              conversationId: widget.conversationId,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 72),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── CallScreen ───────────────────────────────────────────────────────────────

enum _CallStatus { ringing, connecting, connected, ended }

/// Main call screen that manages the WebRTC peer connection lifecycle.
class CallScreen extends StatefulWidget {
  final String callId;
  final bool isCaller;
  final bool isVideo;
  final String partnerName;
  final String? partnerAvatar;
  final String? conversationId;

  const CallScreen({
    super.key,
    required this.callId,
    required this.isCaller,
    required this.isVideo,
    required this.partnerName,
    this.partnerAvatar,
    this.conversationId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  // WebRTC
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  // UI state
  _CallStatus _status = _CallStatus.ringing;
  bool _muted = false;
  bool _cameraOff = false;
  bool _speakerOn = true;
  bool _frontCamera = true;
  int _seconds = 0;
  bool _initialized = false;

  // ICE candidate buffering (prevents addCandidate before setRemoteDescription)
  bool _remoteDescSet = false;
  final List<RTCIceCandidate> _pendingCandidates = [];

  // Subscriptions
  Timer? _timer;
  Timer? _connectionTimer;
  Timer? _disconnectGraceTimer;
  Timer? _ringbackTimer;
  StreamSubscription? _callSub;
  StreamSubscription? _candidateSub;

  // Error / info banner
  String? _errorBanner;

  static const Map<String, dynamic> _rtcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.relay.metered.ca:80'},
      {
        'urls': 'turn:standard.relay.metered.ca:80',
        'username': turnUsername,
        'credential': turnCredential,
      },
      {
        'urls': 'turn:standard.relay.metered.ca:80?transport=tcp',
        'username': turnUsername,
        'credential': turnCredential,
      },
      {
        'urls': 'turn:standard.relay.metered.ca:443',
        'username': turnUsername,
        'credential': turnCredential,
      },
      {
        'urls': 'turns:standard.relay.metered.ca:443?transport=tcp',
        'username': turnUsername,
        'credential': turnCredential,
      },
    ],
    'iceCandidatePoolSize': 10,
  };

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _init();
  }

  Future<void> _init() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      final permOk = await _requestPermissions();
      await _getLocalStream();
      await _createPeerConnection();
      if (!mounted) return;
      setState(() => _initialized = true);
      if (!permOk) return;
      if (widget.isCaller) {
        await _createOffer();
      } else {
        await _createAnswer();
      }
      _listenRemoteCandidates();
    } catch (e) {
      if (mounted) {
        setState(() => _initialized = true);
        _showBanner('Une erreur inattendue est survenue. Désolé 😔');
        Future.delayed(
          const Duration(seconds: 3),
          () => _hangUp(notify: false),
        );
      }
    }
  }

  @override
  void dispose() {
    _ringtonePlayer.stop();
    _timer?.cancel();
    _connectionTimer?.cancel();
    _disconnectGraceTimer?.cancel();
    _ringbackTimer?.cancel();
    _callSub?.cancel();
    _candidateSub?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStream?.dispose();
    _remoteStream?.dispose();
    _pc?.dispose();
    super.dispose();
  }

  // ── ICE buffering ────────────────────────────────────────────────────────────

  Future<void> _applyRemoteDescription(RTCSessionDescription desc) async {
    await _pc!.setRemoteDescription(desc);
    _remoteDescSet = true;
    for (final c in _pendingCandidates) {
      await _pc?.addCandidate(c);
    }
    _pendingCandidates.clear();
  }

  // ── WebRTC setup ────────────────────────────────────────────────────────────

  Future<bool> _requestPermissions() async {
    final perms = widget.isVideo
        ? [Permission.camera, Permission.microphone]
        : [Permission.microphone];
    final results = await perms.request();
    final denied = results.values.any((s) =>
        s == PermissionStatus.denied ||
        s == PermissionStatus.permanentlyDenied);
    if (denied) {
      _showBanner(
        widget.isVideo
            ? 'Accès à la caméra ou au micro refusé. Vérifiez les paramètres de l\'application.'
            : 'Accès au micro refusé. Vérifiez les paramètres de l\'application.',
      );
      return false;
    }
    return true;
  }

  Future<void> _getLocalStream() async {
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': widget.isVideo
            ? {'facingMode': 'user', 'width': 640, 'height': 480}
            : false,
      });
      if (mounted) {
        _localRenderer.srcObject = _localStream;
        setState(() {});
      }
    } catch (_) {
      _showBanner(
        widget.isVideo
            ? 'Impossible d\'accéder à la caméra ou au micro. Vérifiez les permissions.'
            : 'Impossible d\'accéder au micro. Vérifiez les permissions.',
      );
    }
  }

  Future<void> _createPeerConnection() async {
    _pc = await createPeerConnection(_rtcConfig);

    // Add local tracks
    _localStream
        ?.getTracks()
        .forEach((t) => _pc?.addTrack(t, _localStream!));

    // Remote track handler
    _pc?.onTrack = (event) {
      if (event.streams.isNotEmpty && mounted) {
        setState(() {
          _remoteStream = event.streams[0];
          _remoteRenderer.srcObject = _remoteStream;
        });
      }
    };

    // Send local ICE candidates to Firestore
    _pc?.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        CallService.addCandidate(widget.callId, widget.isCaller, {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      }
    };

    // Connection state changes
    _pc?.onConnectionState = (state) {
      if (!mounted) return;
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _ringtonePlayer.stop();
        _connectionTimer?.cancel();
        _disconnectGraceTimer?.cancel();
        setState(() {
          _status = _CallStatus.connected;
          _errorBanner = null;
        });
        _startTimer();
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _showBanner('Connexion instable… Tentative de reconnexion en cours.');
        _disconnectGraceTimer?.cancel();
        _disconnectGraceTimer = Timer(const Duration(seconds: 8), () {
          if (mounted) {
            _showBanner('La connexion a été perdue. Désolé 😢');
            Future.delayed(
              const Duration(seconds: 2),
              () => _hangUp(notify: true),
            );
          }
        });
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _showBanner('La connexion a échoué. Désolé 😔');
        Future.delayed(
          const Duration(seconds: 2),
          () => _hangUp(notify: true),
        );
      }
    };
  }

  // ── Offer / Answer ──────────────────────────────────────────────────────────

  Future<void> _createOffer() async {
    if (_pc == null || !mounted) return;
    _ringtonePlayer.playRingtone(looping: true, volume: 0.5, asAlarm: true);
    setState(() => _status = _CallStatus.connecting);

    // Ringback : bip court toutes les 4 secondes
    void _doRingback() => _ringtonePlayer.playNotification(
        volume: 0.8, looping: false, asAlarm: true);
    _doRingback();
    _ringbackTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_status != _CallStatus.connected) _doRingback();
    });
    await Future.delayed(
        const Duration(milliseconds: 200)); // laisse le ring prendre le focus
    _ringtonePlayer.stop(); // coupe le playRingtone, ringback prend le relais
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    await CallService.setOffer(widget.callId, {
      'sdp': offer.sdp,
      'type': offer.type,
    });
    // Timeout si le partenaire ne répond pas dans les 45s
    _connectionTimer = Timer(const Duration(seconds: 45), () {
      if (mounted && _status != _CallStatus.connected) {
        _ringtonePlayer.stop();
        _showBanner('${widget.partnerName} ne répond pas. Désolé 😔');
        Future.delayed(const Duration(seconds: 2), () => _hangUp());
      }
    });
    // Listen for answer + remote hang-up
    _callSub =
        CallService.callStream(widget.callId).listen((snap) async {
      final data = snap.data() as Map<String, dynamic>?;
      if (data == null) return;
      final status = data['status'] as String?;
      if (status == 'declined') {
        _connectionTimer?.cancel();
        _ringtonePlayer.stop();
        _showBanner('${widget.partnerName} a refusé l\'appel.');
        Future.delayed(const Duration(seconds: 2), _endLocally);
        return;
      }
      if (status == 'ended') {
        _connectionTimer?.cancel();
        _endLocally();
        return;
      }
      if (data['answer'] != null &&
          _pc?.signalingState ==
              RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        final answer = RTCSessionDescription(
            data['answer']['sdp'], data['answer']['type']);
        await _applyRemoteDescription(answer);
      }
    });
  }

  Future<void> _createAnswer() async {
    if (_pc == null || !mounted) return;
    setState(() => _status = _CallStatus.connecting);

    // Wait for the offer to appear (handles race: caller may not have saved it yet)
    final completer = Completer<Map<String, dynamic>?>();
    StreamSubscription? waitSub;
    waitSub = CallService.callStream(widget.callId).listen((snap) {
      if (completer.isCompleted) return;
      final data = snap.data() as Map<String, dynamic>?;
      if (data?['offer'] != null) {
        completer.complete(data!['offer'] as Map<String, dynamic>);
      } else if (data?['status'] == 'ended' ||
          data?['status'] == 'cancelled') {
        completer.complete(null);
      }
    });

    final offerData = await completer.future
        .timeout(const Duration(seconds: 15), onTimeout: () => null);
    await waitSub.cancel();

    if (offerData == null || !mounted) {
      if (mounted) {
        _showBanner('L\'appel a été annulé avant la connexion.');
        Future.delayed(const Duration(seconds: 2), _endLocally);
      }
      return;
    }

    final offer =
        RTCSessionDescription(offerData['sdp'], offerData['type']);
    await _applyRemoteDescription(offer);
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    await CallService.setAnswer(widget.callId, {
      'sdp': answer.sdp,
      'type': answer.type,
    });
    await CallService.setStatus(widget.callId, 'ongoing');

    // Listen for remote hang-up
    _callSub =
        CallService.callStream(widget.callId).listen((snap) {
      final data = snap.data() as Map<String, dynamic>?;
      if (data?['status'] == 'ended') _endLocally();
    });
  }

  void _listenRemoteCandidates() {
    _candidateSub = CallService.remoteCandidatesStream(
      widget.callId,
      listenToCaller: !widget.isCaller,
    ).listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final candidate = RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          );
          if (_remoteDescSet) {
            _pc?.addCandidate(candidate);
          } else {
            _pendingCandidates.add(candidate);
          }
        }
      }
    });
  }

  // ── Timer ───────────────────────────────────────────────────────────────────

  void _startTimer() {
    _timer =
        Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  String get _timerLabel {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _hangUp({bool notify = true}) async {
    if (notify) await CallService.setStatus(widget.callId, 'ended');
    // Only the caller logs the call message to avoid duplication
    if (widget.isCaller && widget.conversationId != null) {
      final missed = _status != _CallStatus.connected;
      await ConversationService.sendCallMessage(
        widget.conversationId!,
        isVideo: widget.isVideo,
        missed: missed,
        duration: missed ? 0 : _seconds,
      );
    }
    _endLocally();
  }

  void _endLocally() {
    _ringtonePlayer.stop();
    _ringbackTimer?.cancel();
    _timer?.cancel();
    _callSub?.cancel();
    _candidateSub?.cancel();
    _localStream?.dispose();
    _remoteStream?.dispose();
    _pc?.close();
    if (mounted) {
      setState(() => _status = _CallStatus.ended);
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  void _toggleMute() {
    final wasMuted = _muted;
    _localStream?.getAudioTracks().forEach((t) => t.enabled = wasMuted);
    setState(() => _muted = !wasMuted);
  }

  void _toggleCamera() {
    final wasOff = _cameraOff;
    _localStream?.getVideoTracks().forEach((t) => t.enabled = wasOff);
    setState(() => _cameraOff = !wasOff);
  }

  Future<void> _switchCamera() async {
    final tracks = _localStream?.getVideoTracks();
    if (tracks != null && tracks.isNotEmpty) {
      await Helper.switchCamera(tracks[0]);
      setState(() => _frontCamera = !_frontCamera);
    }
  }

  void _toggleSpeaker() {
    final next = !_speakerOn;
    try {
      Helper.setSpeakerphoneOn(next);
    } catch (_) {}
    setState(() => _speakerOn = next);
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child: CircularProgressIndicator(color: Colors.white54)),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(),
          if (widget.isVideo &&
              _remoteStream != null &&
              _status == _CallStatus.connected)
            _buildLocalPreview(),
          _buildTopBar(),
          _buildControls(),
          if (_errorBanner != null) _buildErrorBanner(),
        ],
      ),
    );
  }

  // ── Banner ──────────────────────────────────────────────────────────────────

  void _showBanner(String message) {
    if (!mounted) return;
    setState(() => _errorBanner = message);
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _errorBanner == message) {
        setState(() => _errorBanner = null);
      }
    });
  }

  Widget _buildErrorBanner() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 20,
      right: 20,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xDD1A1A2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Colors.orangeAccent.withValues(alpha: 0.6)),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 12)
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.orangeAccent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _errorBanner!,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    // Connected video call: show remote stream full-screen
    if (widget.isVideo &&
        _remoteStream != null &&
        _status == _CallStatus.connected) {
      return RTCVideoView(
        _remoteRenderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    }
    // Audio call or connecting: dark background with avatar
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF1A0A1F),
            Color(0xFF3D0B5E),
            Color(0xFF1A0A1F),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PulsingAvatar(
              avatarUrl: widget.partnerAvatar,
              name: widget.partnerName,
            ),
            const SizedBox(height: 24),
            Text(
              widget.partnerName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              _statusLabel,
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  String get _statusLabel {
    switch (_status) {
      case _CallStatus.ringing:
        return widget.isCaller ? 'Appel en cours…' : 'Connexion…';
      case _CallStatus.connecting:
        return 'Connexion…';
      case _CallStatus.connected:
        return _timerLabel;
      case _CallStatus.ended:
        return 'Appel terminé';
    }
  }

  Widget _buildLocalPreview() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: GestureDetector(
        onTap: _switchCamera,
        child: Container(
          width: 100,
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 10)
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _cameraOff
                ? Container(
                    color: Colors.grey.shade900,
                    child: const Icon(Icons.videocam_off_rounded,
                        color: Colors.white38, size: 28),
                  )
                : RTCVideoView(
                    _localRenderer,
                    mirror: _frontCamera,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    if (_status != _CallStatus.connected || !widget.isVideo) {
      return const SizedBox.shrink();
    }
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Text(
                widget.partnerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  shadows: [
                    Shadow(blurRadius: 6, color: Colors.black54)
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _timerLabel,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_status == _CallStatus.ended)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text('Appel terminé',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 16)),
                ),
              if (_status != _CallStatus.ended) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CtrlBtn(
                      icon: _muted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      label: _muted ? 'Muet' : 'Micro',
                      onTap: _toggleMute,
                      active: _muted,
                    ),
                    if (widget.isVideo) ...[
                      _CtrlBtn(
                        icon: _cameraOff
                            ? Icons.videocam_off_rounded
                            : Icons.videocam_rounded,
                        label: 'Caméra',
                        onTap: _toggleCamera,
                        active: _cameraOff,
                      ),
                      _CtrlBtn(
                        icon: Icons.cameraswitch_rounded,
                        label: 'Retourner',
                        onTap: _switchCamera,
                      ),
                    ] else
                      _CtrlBtn(
                        icon: _speakerOn
                            ? Icons.volume_up_rounded
                            : Icons.hearing_rounded,
                        label: _speakerOn ? 'HP' : 'Oreille',
                        onTap: _toggleSpeaker,
                        active: !_speakerOn,
                      ),
                  ],
                ),
                const SizedBox(height: 32),
                // Hang-up button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    _hangUp();
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.red.shade500,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color:
                                Colors.red.withValues(alpha: 0.5),
                            blurRadius: 20,
                            spreadRadius: 2)
                      ],
                    ),
                    child: const Icon(Icons.call_end_rounded,
                        color: Colors.white, size: 32),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── _RingAvatar ──────────────────────────────────────────────────────────────

/// Avatar with expanding concentric ring animations (for incoming call).
class _RingAvatar extends StatefulWidget {
  final String? avatarUrl;
  final String name;

  const _RingAvatar({required this.avatarUrl, required this.name});

  @override
  State<_RingAvatar> createState() => _RingAvatarState();
}

class _RingAvatarState extends State<_RingAvatar>
    with TickerProviderStateMixin {
  final _controllers = <AnimationController>[];
  final _anims = <Animation<double>>[];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 3; i++) {
      final c = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2200));
      _controllers.add(c);
      _anims.add(Tween<double>(begin: 0, end: 1)
          .animate(CurvedAnimation(parent: c, curve: Curves.easeOut)));
      Future.delayed(Duration(milliseconds: i * 700), () {
        if (mounted) c.repeat();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (int i = 0; i < 3; i++)
            AnimatedBuilder(
              animation: _anims[i],
              builder: (_, __) {
                final v = _anims[i].value;
                return Opacity(
                  opacity: (1 - v).clamp(0, 1),
                  child: Container(
                    width: 100 + v * 90,
                    height: 100 + v * 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary
                            .withValues(alpha: 0.6),
                        width: 2,
                      ),
                    ),
                  ),
                );
              },
            ),
          CircleAvatar(
            radius: 62,
            backgroundColor:
                AppColors.primary.withValues(alpha: 0.3),
            backgroundImage: widget.avatarUrl != null
                ? NetworkImage(widget.avatarUrl!)
                : null,
            child: widget.avatarUrl == null
                ? Text(
                    widget.name.isNotEmpty
                        ? widget.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontSize: 48,
                        color: Colors.white,
                        fontWeight: FontWeight.w800),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

// ─── _PulsingAvatar ───────────────────────────────────────────────────────────

/// Gently pulsing avatar shown during audio calls or while connecting.
class _PulsingAvatar extends StatefulWidget {
  final String? avatarUrl;
  final String name;

  const _PulsingAvatar({required this.avatarUrl, required this.name});

  @override
  State<_PulsingAvatar> createState() => _PulsingAvatarState();
}

class _PulsingAvatarState extends State<_PulsingAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.96, end: 1.04).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _anim,
      child: CircleAvatar(
        radius: 72,
        backgroundColor:
            AppColors.primary.withValues(alpha: 0.3),
        backgroundImage: widget.avatarUrl != null
            ? NetworkImage(widget.avatarUrl!)
            : null,
        child: widget.avatarUrl == null
            ? Text(
                widget.name.isNotEmpty
                    ? widget.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    fontSize: 52,
                    color: Colors.white,
                    fontWeight: FontWeight.w800),
              )
            : null,
      ),
    );
  }
}

// ─── _CallActionBtn ───────────────────────────────────────────────────────────

class _CallActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CallActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    blurRadius: 22,
                    spreadRadius: 2)
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─── _CtrlBtn ─────────────────────────────────────────────────────────────────

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _CtrlBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.white24,
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                color: active ? Colors.black87 : Colors.white,
                size: 24),
          ),
          const SizedBox(height: 7),
          Text(label,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }
}
