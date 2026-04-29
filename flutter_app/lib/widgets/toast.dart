import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ToastStyle { static const info = 0, success = 1, warning = 2, error = 3; }

class ToastMessage {
  final String message;
  final int style;
  final Duration duration;
  const ToastMessage(this.message, {this.style = ToastStyle.info, this.duration = const Duration(seconds: 3)});
}

class ToastController extends ValueNotifier<ToastMessage?> {
  ToastController() : super(null);

  void show(String message, {int style = ToastStyle.info}) {
    value = ToastMessage(message, style: style);
    Future.delayed(value!.duration, () {
      if (value?.message == message) value = null;
    });
  }
}

final toastController = ToastController();

void showToast(String message, {int style = ToastStyle.info}) =>
    toastController.show(message, style: style);

class ToastOverlay extends StatelessWidget {
  final Widget child;
  const ToastOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        ValueListenableBuilder<ToastMessage?>(
          valueListenable: toastController,
          builder: (context, toast, _) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => SlideTransition(
              position: Tween(begin: const Offset(0, 0.2), end: Offset.zero).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: toast == null
                ? const SizedBox.shrink()
                : Align(
                    key: ValueKey(toast.message),
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      child: _ToastChip(toast: toast),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ToastChip extends StatelessWidget {
  final ToastMessage toast;
  const _ToastChip({required this.toast});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (toast.style) {
      ToastStyle.success => (Colors.green, Icons.check_circle_rounded),
      ToastStyle.warning => (Colors.orange, Icons.warning_rounded),
      ToastStyle.error   => (Colors.red, Icons.error_rounded),
      _                  => (Colors.grey.shade800, Icons.info_rounded),
    };
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Flexible(child: Text(toast.message, style: const TextStyle(color: Colors.white, fontSize: 14))),
          ],
        ),
      ),
    );
  }
}
