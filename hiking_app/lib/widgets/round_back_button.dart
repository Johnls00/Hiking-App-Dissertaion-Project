import 'package:flutter/material.dart';

class RoundBackButton extends StatelessWidget {
  const RoundBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const SizedBox(width: 10),
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: () async {
              if (onPressed != null) {
                onPressed!();
              } else if (Navigator.canPop(context)) {
                Navigator.maybePop(context);
              }
            },
            customBorder: const CircleBorder(),
            child: Ink(
              width: 49,
              height: 49,
              decoration: const ShapeDecoration(
                color: Color.fromRGBO(221, 221, 221, 1),
                shape: CircleBorder(),
              ),
              child: const Icon(Icons.arrow_back),
            ),
          ),
        ),
      ],
    );
  }
}