import 'package:flutter/material.dart';

class RoundBackButton extends StatelessWidget {
  const RoundBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(width: 10),
        Ink(
          decoration: const ShapeDecoration(
            color: Color.fromRGBO(221, 221, 221, 1),
            shape: CircleBorder(),
          ),
          child: IconButton(
            onPressed: () {
              print("Popping back to: ${ModalRoute.of(context)?.settings.name}"); 
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back),
          ),
        ),
      ],
    );
  }
}
