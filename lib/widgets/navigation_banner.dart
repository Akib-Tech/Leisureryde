import 'package:flutter/material.dart';
import 'package:leisureryde/services/directions_service.dart';

/// Full-width navigation banner shown at the top of the screen during an
/// active trip. Mirrors Uber's turn-instruction card: large maneuver arrow
/// on the left, distance to turn in bold, instruction text below.
class NavigationBanner extends StatelessWidget {
  final RouteStep? step;
  final int distanceMeters;

  /// The first upcoming step that has an actual maneuver (turn/uturn/etc).
  /// When [step] is a straight/head step with no maneuver, this is used for
  /// the direction icon and instruction text instead.
  final RouteStep? upcomingTurnStep;

  const NavigationBanner({
    super.key,
    required this.step,
    required this.distanceMeters,
    this.upcomingTurnStep,
  });

  @override
  Widget build(BuildContext context) {
    if (step == null) return const SizedBox.shrink();

    // Use the upcoming turn step for icon + instruction when the current step
    // is a straight/head step (maneuver == null); otherwise use current step.
    final displayStep = (step!.maneuver == null && upcomingTurnStep != null)
        ? upcomingTurnStep!
        : step!;

    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      color: const Color(0xFF1A237E),
      padding: EdgeInsets.fromLTRB(20, topPad + 10, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Maneuver icon — shows the next actual turn direction
          Icon(
            _maneuverIcon(displayStep.maneuver),
            color: Colors.white,
            size: 52,
          ),
          const SizedBox(width: 18),
          // Distance + instruction
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatDistance(distanceMeters),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  displayStep.instruction,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _maneuverIcon(String? maneuver) {
    switch (maneuver) {
      case 'turn-left':
      case 'turn-sharp-left':
      case 'turn-slight-left':
        return Icons.turn_left;
      case 'turn-right':
      case 'turn-sharp-right':
      case 'turn-slight-right':
        return Icons.turn_right;
      case 'uturn-left':
        return Icons.u_turn_left;
      case 'uturn-right':
        return Icons.u_turn_right;
      case 'fork-left':
      case 'ramp-left':
      case 'keep-left':
        return Icons.fork_left;
      case 'fork-right':
      case 'ramp-right':
      case 'keep-right':
        return Icons.fork_right;
      case 'merge':
        return Icons.merge_type;
      case 'roundabout-left':
      case 'roundabout-right':
        return Icons.loop;
      default:
        return Icons.arrow_upward;
    }
  }

  static String _formatDistance(int meters) {
    if (meters <= 0) return '';
    final miles = meters * 0.000621371;
    if (miles >= 0.1) return '${miles.toStringAsFixed(1)} mi';
    return '${miles.toStringAsFixed(2)} mi';
  }
}
