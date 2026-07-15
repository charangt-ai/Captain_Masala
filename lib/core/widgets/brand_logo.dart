import 'package:flutter/material.dart';
import '../theme.dart';

class CaptainMasalaLogo extends StatelessWidget {
  final double size;
  final bool showTagline;
  final Color? color;

  const CaptainMasalaLogo({
    Key? key,
    this.size = 120,
    this.showTagline = true,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size, // New logo is perfectly square
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.15),
            child: Image.asset(
              'assets/images/logo.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: AppColors.primaryRed,
                  child: Center(
                    child: Text(
                      'Logo',
                      style: TextStyle(color: Colors.white, fontSize: size * 0.1),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (showTagline) ...[
          SizedBox(height: size * 0.1),
          Text(
            'Pure Spices... Perfect Taste!',
            style: TextStyle(
              fontSize: size * 0.09,
              fontStyle: FontStyle.italic,
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}
