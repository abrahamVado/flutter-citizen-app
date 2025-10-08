import 'dart:typed_data';

import 'package:citizen_reports_flutter/src/presentation/public/map/citizen_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

class _FakeGoogleMapsFlutterPlatform extends GoogleMapsFlutterPlatform {
  CameraPosition? lastCameraPosition;

  @override
  Future<void> init(int mapId) async {}

  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) {
    lastCameraPosition = widgetConfiguration.initialCameraPosition;
    onPlatformViewCreated(creationId);
    return const SizedBox();
  }

  @override
  Future<void> updateMapConfiguration(
    MapConfiguration configuration, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateMarkers(
    MarkerUpdates markerUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updatePolygons(
    PolygonUpdates polygonUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updatePolylines(
    PolylineUpdates polylineUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateCircles(
    CircleUpdates circleUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateTileOverlays({
    required Set<TileOverlay> newTileOverlays,
    required int mapId,
  }) async {}

  @override
  Future<void> clearTileCache(
    TileOverlayId tileOverlayId, {
    required int mapId,
  }) async {}

  @override
  Future<void> animateCamera(
    CameraUpdate cameraUpdate, {
    required int mapId,
  }) async {}

  @override
  Future<void> moveCamera(
    CameraUpdate cameraUpdate, {
    required int mapId,
  }) async {}

  @override
  Future<void> setMapStyle(
    String? mapStyle, {
    required int mapId,
  }) async {}

  @override
  Future<LatLngBounds> getVisibleRegion({
    required int mapId,
  }) async {
    return const LatLngBounds(
      southwest: LatLng(0, 0),
      northeast: LatLng(0, 0),
    );
  }

  @override
  Future<ScreenCoordinate> getScreenCoordinate(
    LatLng latLng, {
    required int mapId,
  }) async {
    return const ScreenCoordinate(x: 0, y: 0);
  }

  @override
  Future<LatLng> getLatLng(
    ScreenCoordinate screenCoordinate, {
    required int mapId,
  }) async {
    return const LatLng(0, 0);
  }

  @override
  Future<void> showMarkerInfoWindow(
    MarkerId markerId, {
    required int mapId,
  }) async {}

  @override
  Future<void> hideMarkerInfoWindow(
    MarkerId markerId, {
    required int mapId,
  }) async {}

  @override
  Future<bool> isMarkerInfoWindowShown(
    MarkerId markerId, {
    required int mapId,
  }) async {
    return false;
  }

  @override
  Future<double> getZoomLevel({
    required int mapId,
  }) async {
    return lastCameraPosition?.zoom ?? 0;
  }

  @override
  Future<Uint8List?> takeSnapshot({
    required int mapId,
  }) async {
    return null;
  }

  @override
  Stream<CameraMoveStartedEvent> onCameraMoveStarted({required int mapId}) {
    return const Stream<CameraMoveStartedEvent>.empty();
  }

  @override
  Stream<CameraMoveEvent> onCameraMove({required int mapId}) {
    return const Stream<CameraMoveEvent>.empty();
  }

  @override
  Stream<CameraIdleEvent> onCameraIdle({required int mapId}) {
    return const Stream<CameraIdleEvent>.empty();
  }

  @override
  Stream<MarkerTapEvent> onMarkerTap({required int mapId}) {
    return const Stream<MarkerTapEvent>.empty();
  }

  @override
  Stream<MarkerDragStartEvent> onMarkerDragStart({required int mapId}) {
    return const Stream<MarkerDragStartEvent>.empty();
  }

  @override
  Stream<MarkerDragEvent> onMarkerDrag({required int mapId}) {
    return const Stream<MarkerDragEvent>.empty();
  }

  @override
  Stream<MarkerDragEndEvent> onMarkerDragEnd({required int mapId}) {
    return const Stream<MarkerDragEndEvent>.empty();
  }

  @override
  Stream<InfoWindowTapEvent> onInfoWindowTap({required int mapId}) {
    return const Stream<InfoWindowTapEvent>.empty();
  }

  @override
  Stream<PolylineTapEvent> onPolylineTap({required int mapId}) {
    return const Stream<PolylineTapEvent>.empty();
  }

  @override
  Stream<PolygonTapEvent> onPolygonTap({required int mapId}) {
    return const Stream<PolygonTapEvent>.empty();
  }

  @override
  Stream<CircleTapEvent> onCircleTap({required int mapId}) {
    return const Stream<CircleTapEvent>.empty();
  }

  @override
  Stream<MapTapEvent> onTap({required int mapId}) {
    return const Stream<MapTapEvent>.empty();
  }

  @override
  Stream<MapLongPressEvent> onLongPress({required int mapId}) {
    return const Stream<MapLongPressEvent>.empty();
  }

  @override
  void dispose({required int mapId}) {}

  @override
  void enableDebugInspection() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeGoogleMapsFlutterPlatform fakePlatform;

  setUp(() {
    fakePlatform = _FakeGoogleMapsFlutterPlatform();
    GoogleMapsFlutterPlatform.instance = fakePlatform;
  });

  testWidgets('renders GoogleMap with maximum zoom', (tester) async {
    const initialCameraPosition = CameraPosition(
      target: LatLng(10, 10),
      zoom: 21,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: CitizenMapScreen(
          initialCameraPosition: initialCameraPosition,
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(GoogleMap), findsOneWidget);
    expect(fakePlatform.lastCameraPosition, isNotNull);
    expect(fakePlatform.lastCameraPosition!.zoom, equals(21));
  });
}
