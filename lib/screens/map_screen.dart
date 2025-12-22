import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';
import '../services/app_state.dart';
import '../models/models.dart';
import '../widgets/impact_card.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionStream;
  LatLng? _currentPosition;
  bool _locationError = false;
  bool _isLoadingTrees = false;

  @override
  void initState() { super.initState(); _initLocation(); }

  @override
  void dispose() { _positionStream?.cancel(); super.dispose(); }

  Future<void> _initLocation() async {
    final status = await Permission.location.request();
    if (!mounted) return;
    final appState = context.read<AppState>();
    appState.setLocationGranted(status.isGranted);
    if (status.isGranted) {
      try {
        final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        if (!mounted) return;
        setState(() { _currentPosition = LatLng(position.latitude, position.longitude); _locationError = false; });
        appState.setLocation(position.latitude, position.longitude);
        _loadNearbyTrees();
        _positionStream = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 20)).listen((Position p) {
          if (!mounted) return;
          setState(() => _currentPosition = LatLng(p.latitude, p.longitude));
          appState.setLocation(p.latitude, p.longitude);
        });
      } catch (e) { if (!mounted) return; setState(() => _locationError = true); }
    } else { setState(() => _locationError = true); }
  }

  Future<void> _loadNearbyTrees() async {
    if (_currentPosition == null) return;
    setState(() => _isLoadingTrees = true);
    final appState = context.read<AppState>();
    await appState.loadNearbyTrees();
    await appState.loadNearbyTasks();
    if (mounted) setState(() => _isLoadingTrees = false);
  }

  void _showTreeInfo(NearbyTreeModel tree) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textLight.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Row(children: [
            Container(width: 60, height: 60, decoration: BoxDecoration(color: AppColors.softGreen, borderRadius: BorderRadius.circular(16)), child: const Center(child: Text('🌳', style: TextStyle(fontSize: 32)))),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Daraxt #${tree.treeId}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              const SizedBox(height: 4),
              Text('Masofa: ${tree.distanceMeters.toStringAsFixed(0)} m', style: const TextStyle(fontSize: 14, color: AppColors.textMedium)),
            ])),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _InfoChip(icon: Icons.gps_fixed, label: 'Aniqlik', value: '${(tree.confidence * 100).toStringAsFixed(1)}%')),
            const SizedBox(width: 12),
            Expanded(child: _InfoChip(icon: Icons.straighten, label: 'Masofa', value: '${tree.distanceMeters.toStringAsFixed(0)} m')),
          ]),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, appState, child) {
      return Scaffold(
        body: Stack(children: [
          if (_currentPosition != null)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: _currentPosition!, initialZoom: 15, interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate)),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.greenify.app'),
                CircleLayer(circles: [CircleMarker(point: _currentPosition!, radius: 2000, useRadiusInMeter: true, color: AppColors.primaryGreen.withOpacity(0.08), borderColor: AppColors.primaryGreen.withOpacity(0.4), borderStrokeWidth: 2)]),
                MarkerLayer(markers: appState.nearbyTrees.map((tree) => Marker(
                  point: LatLng(tree.centroidLat, tree.centroidLon), width: 40, height: 40,
                  child: GestureDetector(onTap: () => _showTreeInfo(tree), child: Container(decoration: BoxDecoration(color: AppColors.primaryGreen, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: AppColors.primaryGreen.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)]), child: const Center(child: Text('🌳', style: TextStyle(fontSize: 18))))),
                )).toList()),
                MarkerLayer(markers: [Marker(point: _currentPosition!, width: 50, height: 50, child: Container(decoration: BoxDecoration(color: AppColors.accentBlue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: [BoxShadow(color: AppColors.accentBlue.withOpacity(0.4), blurRadius: 12, spreadRadius: 2)]), child: const Icon(Icons.person, color: Colors.white, size: 24)))]),
              ],
            )
          else Container(color: AppColors.softGreen, child: Center(child: _locationError ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.location_off, size: 64, color: AppColors.textLight), const SizedBox(height: 16), const Text('Joylashuvni aniqlab bo\'lmadi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textMedium)), const SizedBox(height: 24), ElevatedButton.icon(onPressed: _initLocation, icon: const Icon(Icons.refresh), label: const Text('Qayta urinish'))]) : const CircularProgressIndicator(color: AppColors.primaryGreen))),
          Positioned(top: 0, left: 0, right: 0, child: Container(height: MediaQuery.of(context).padding.top + 60, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0)])))),
          SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Salom, ${appState.userName.split(' ').first}! 👋', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              Text('Umumiy daraxtlar: ${appState.globalTotalTrees}', style: const TextStyle(fontSize: 14, color: AppColors.textMedium)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AppColors.cardShadow), child: Row(mainAxisSize: MainAxisSize.min, children: [const Text('🌳', style: TextStyle(fontSize: 16)), const SizedBox(width: 6), Text('${appState.nearbyTrees.length} ta', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark))])),
          ])).animate().fadeIn(duration: 400.ms)),
          Positioned(left: 16, right: 16, bottom: 16, child: const ImpactCard().animate().slideY(begin: 0.5, end: 0, delay: 300.ms)),
          if (_isLoadingTrees) Positioned(top: MediaQuery.of(context).padding.top + 80, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AppColors.cardShadow), child: const Row(mainAxisSize: MainAxisSize.min, children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen)), SizedBox(width: 8), Text('Yuklanmoqda...', style: TextStyle(fontSize: 13))])))),
          Positioned(right: 16, bottom: 180, child: FloatingActionButton.small(heroTag: 'refresh', backgroundColor: Colors.white, onPressed: _loadNearbyTrees, child: const Icon(Icons.refresh, color: AppColors.primaryGreen))),
          Positioned(right: 16, bottom: 130, child: FloatingActionButton.small(heroTag: 'location', backgroundColor: Colors.white, onPressed: () { if (_currentPosition != null) _mapController.move(_currentPosition!, 15); }, child: const Icon(Icons.my_location, color: AppColors.accentBlue))),
        ]),
      );
    });
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon; final String label, value;
  const _InfoChip({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.softGreen, borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(icon, size: 20, color: AppColors.primaryGreen), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMedium)), Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark))])]));
  }
}
