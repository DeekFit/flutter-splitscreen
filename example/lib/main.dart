import 'package:flutter/material.dart';
import 'package:split_screen/split_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(home: const SensorDemo());
}

class SensorDemo extends StatefulWidget {
  const SensorDemo({super.key});
  @override
  State<SensorDemo> createState() => _SensorDemoState();
}

class _SensorDemoState extends State<SensorDemo> {
  late final Future<bool> _capability = DualScreenInfo.hasHingeAngleSensor;
  late final Stream<double> _angles = DualScreenInfo.hingeAngleEvents;
  @override
  Widget build(BuildContext context) => TwoPane(
    panePriority: MediaQuery.sizeOf(context).width >= 600
        ? TwoPanePriority.both
        : TwoPanePriority.start,
    startPane: Scaffold(
      appBar: AppBar(title: const Text('Hinge Angle Sensor')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<bool>(
              future: _capability,
              builder: (context, value) => Text(
                value.hasError
                    ? 'Sensor error: ${value.error}'
                    : 'Hinge angle sensor exists: ${value.data ?? "waiting"}',
              ),
            ),
            StreamBuilder<double>(
              stream: _angles,
              builder: (context, value) => Text(
                value.hasError
                    ? 'Angle error: ${value.error}'
                    : 'Hinge angle is: ${value.data?.toStringAsFixed(2) ?? "waiting"}',
              ),
            ),
          ],
        ),
      ),
    ),
    endPane: const Material(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Second pane: visible on wide screens or across an active fold.',
          ),
        ),
      ),
    ),
  );
}
