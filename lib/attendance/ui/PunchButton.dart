import 'package:flutter/material.dart';

class PunchButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final VoidCallback onPressed;

  const PunchButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  State<PunchButton> createState() => _PunchButtonState();
}

class _PunchButtonState extends State<PunchButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _isPressed = true;
        });
      },
      onTapUp: (_) {
        setState(() {
          _isPressed = false;
        });
        if (!widget.isLoading) {
          widget.onPressed();
        }
      },
      onTapCancel: () {
        setState(() {
          _isPressed = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
        decoration: BoxDecoration(
          color: _isPressed ? widget.color.withOpacity(0.9) : widget.color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isPressed
              ? []
              : [
            BoxShadow(
              color: widget.color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: widget.isLoading
              ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(
                widget.icon,
                size: 24,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}