import 'package:flutter/material.dart';

class TkLogo extends StatelessWidget {
  const TkLogo({super.key, this.size = 44, this.showLabel = true});

  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Teman Kereta',
      image: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.22),
            child: Image.asset(
              'assets/branding/tk_icon.png',
              width: size,
              height: size,
              fit: BoxFit.contain,
            ),
          ),
          if (showLabel) ...<Widget>[
            const SizedBox(width: 12),
            Text(
              'Teman Kereta',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ],
      ),
    );
  }
}
