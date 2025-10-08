import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../design/shadcn/components/shadcn_card.dart';

class AdminPrivateMapScreen extends StatelessWidget {
  const AdminPrivateMapScreen({
    super.key,
    WidgetBuilder? mapBuilder,
  }) : _mapBuilder = mapBuilder ?? AdminPrivateMapScreen.buildDefaultMap;

  final WidgetBuilder _mapBuilder;

  static Widget buildDefaultMap(BuildContext context) {
    //1.- Configuramos el mapa con un enfoque inicial en el centro de la ciudad.
    return const GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(19.4326, -99.1332),
        zoom: 12,
      ),
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      compassEnabled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    //1.- Organizamos la interfaz con encabezado descriptivo y mapa interactivo.
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mapa privado de incidencias',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Visualiza la distribución geográfica de los reportes en tiempo real.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ShadcnCard(
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: _mapBuilder(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
