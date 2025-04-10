import 'package:flutter/material.dart';

class NiftLogo extends StatelessWidget {
  final double size;
  final Color? color;

  const NiftLogo({
    Key? key,
    this.size = 24.0,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      color: color,
    );
  }
} 