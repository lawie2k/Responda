import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// UIKit owns the selected tab and its stock Liquid Glass selection effect.
class RespondaIosTabBar extends StatefulWidget {
  const RespondaIosTabBar({
    required this.pageIndex,
    required this.labels,
    required this.tint,
    required this.callAccessibilityLabel,
    required this.onPageSelected,
    required this.onCall,
    super.key,
  });

  final int pageIndex;
  final List<String> labels;
  final Color tint;
  final String callAccessibilityLabel;
  final ValueChanged<int> onPageSelected;
  final VoidCallback onCall;

  @override
  State<RespondaIosTabBar> createState() => _RespondaIosTabBarState();
}

class _RespondaIosTabBarState extends State<RespondaIosTabBar> {
  MethodChannel? _channel;
  bool _visible = true;

  Map<String, Object> get _configuration => {
    'pageIndex': widget.pageIndex,
    'labels': widget.labels,
    'callAccessibilityLabel': widget.callAccessibilityLabel,
    'tint': widget.tint.toARGB32(),
    'visible': _visible,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = ModalRoute.isCurrentOf(context) ?? true;
    unawaited(_sync());
  }

  @override
  void didUpdateWidget(covariant RespondaIosTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    unawaited(_sync());
  }

  Future<void> _sync() async {
    try {
      await _channel?.invokeMethod<void>('update', _configuration);
    } on PlatformException {
      // The native view can disappear while a route is being disposed.
    } on MissingPluginException {
      // Ignore a late update after the platform view was removed.
    }
  }

  void _created(int id) {
    _channel = MethodChannel('responda/native-tab-bar/$id')
      ..setMethodCallHandler((call) async {
        if (!mounted) return;
        if (call.method == 'onCall') {
          widget.onCall();
        } else if (call.method == 'onPageSelected' && call.arguments is int) {
          final index = call.arguments as int;
          if (index >= 0 && index < 4) widget.onPageSelected(index);
        }
      });
    unawaited(_sync());
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 80,
    child: UiKitView(
      viewType: 'responda/native-tab-bar',
      creationParams: _configuration,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _created,
      gestureRecognizers: {
        Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
      },
    ),
  );
}
