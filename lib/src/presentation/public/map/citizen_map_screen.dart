import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../report/report_form_sheet.dart';

class CitizenMapScreen extends StatefulWidget {
  const CitizenMapScreen({
    super.key,
    this.initialCameraPosition = const CameraPosition(
      target: LatLng(0, 0),
      zoom: 21,
    ),
    this.onLocationSelected,
  });

  final CameraPosition initialCameraPosition;
  final ValueChanged<LatLng>? onLocationSelected;

  @override
  State<CitizenMapScreen> createState() => _CitizenMapScreenState();
}

class _CitizenMapScreenState extends State<CitizenMapScreen> {
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    //1.- Guardamos la posición inicial para mostrar un marcador desde el arranque.
    _selectedLocation = widget.initialCameraPosition.target;
  }

  void _handleMapTap(LatLng position) {
    //2.- Actualizamos el marcador y notificamos a las capas superiores cuando se selecciona una ubicación.
    setState(() {
      _selectedLocation = position;
    });
    widget.onLocationSelected?.call(position);
  }

  void _handleConfirmLocation() {
    final LatLng confirmedLocation =
        _selectedLocation ?? widget.initialCameraPosition.target;
    //3.- Disparamos el callback final y mostramos el formulario de reporte en un bottom sheet.
    widget.onLocationSelected?.call(confirmedLocation);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ReportFormSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    //4.- Renderizamos el mapa de Google y el botón de confirmación de la ubicación.
    return Scaffold(
      appBar: AppBar(title: const Text('Selecciona la ubicación')),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GoogleMap(
                  initialCameraPosition: widget.initialCameraPosition,
                  minMaxZoomPreference: const MinMaxZoomPreference(0, 21),
                  myLocationButtonEnabled: false,
                  myLocationEnabled: false,
                  zoomControlsEnabled: false,
                  onTap: _handleMapTap,
                  markers: {
                    if (_selectedLocation != null)
                      Marker(
                        markerId: const MarkerId('selected_location'),
                        position: _selectedLocation!,
                      ),
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _handleConfirmLocation,
              icon: const Icon(Icons.check_circle_outline),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Confirmar ubicación'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
