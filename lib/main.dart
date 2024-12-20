import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'src/locations.dart' as locations;
import 'dart:math' show cos, sqrt, asin;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green[700],
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Map<String, Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  GoogleMapController? mapController;
  locations.Office? selectedOffice;

  double calculateDistance(lat1, lon1, lat2, lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    var c = cos;
    var a = 0.5 - c((lat2 - lat1) * p)/2 + 
            c(lat1 * p) * c(lat2 * p) * 
            (1 - c((lon1 - lon2) * p))/2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  void _showDistances() async {
    final offices = (await locations.getGoogleOffices()).offices;
    double totalDistance = 0;
    List<LatLng> polylinePoints = [];
    List<Map<String, dynamic>> segmentInfo = [];

    // Clear existing polylines and markers
    setState(() {
      _polylines.clear();
      _markers.clear();
    });

    // Recreate faculty markers
    for (final office in offices) {
      _markers[office.name] = Marker(
        markerId: MarkerId(office.name),
        position: LatLng(office.lat, office.lng),
        infoWindow: InfoWindow(
          title: office.name,
          snippet: office.address,
          onTap: () => _showOfficeDetails(office),
        ),
        onTap: () => _showOfficeDetails(office),
      );
    }

    // Create segments between faculties
    for (int i = 0; i < offices.length - 1; i++) {
      var current = offices[i];
      var next = offices[i + 1];
      
      var currentLatLng = LatLng(current.lat, current.lng);
      var nextLatLng = LatLng(next.lat, next.lng);
      
      double distance = calculateDistance(
        current.lat, current.lng,
        next.lat, next.lng
      );
      totalDistance += distance;

      // Store segment information
      segmentInfo.add({
        'from': current.name,
        'to': next.name,
        'distance': distance,
        'points': [currentLatLng, nextLatLng],
      });
    }

    // Add polylines with individual segments
    for (int i = 0; i < segmentInfo.length; i++) {
      setState(() {
        _polylines.add(
          Polyline(
            polylineId: PolylineId('segment_$i'),
            points: segmentInfo[i]['points'] as List<LatLng>,
            color: Colors.blue,
            width: 5,
            patterns: [
              PatternItem.dash(20),
              PatternItem.gap(10),
            ],
            onTap: () {
              _showSegmentInfo(
                segmentInfo[i]['from'] as String,
                segmentInfo[i]['to'] as String,
                segmentInfo[i]['distance'] as double,
              );
            },
          ),
        );
      });
    }

    // Show total distance
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Total distance between all faculties: ${totalDistance.toStringAsFixed(2)} km',
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  void _showSegmentInfo(String from, String to, double distance) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Distance Information'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('From: $from'),
              const SizedBox(height: 8),
              Text('To: $to'),
              const SizedBox(height: 8),
              Text(
                'Distance: ${distance.toStringAsFixed(2)} km',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    mapController = controller;
    final googleOffices = await locations.getGoogleOffices();
    setState(() {
      _markers.clear();
      for (final office in googleOffices.offices) {
        final marker = Marker(
          markerId: MarkerId(office.name),
          position: LatLng(office.lat, office.lng),
          infoWindow: InfoWindow(
            title: office.name,
            snippet: office.address,
            onTap: () {
              setState(() {
                selectedOffice = office;
              });
              _showOfficeDetails(office);
            },
          ),
          onTap: () {
            setState(() {
              selectedOffice = office;
            });
            _showOfficeDetails(office);
          },
        );
        _markers[office.name] = marker;
      }
    });
  }

  void _showOfficeDetails(locations.Office office) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow the bottom sheet to be larger
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SingleChildScrollView( // Make content scrollable
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  office.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      office.image,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, size: 32),
                                SizedBox(height: 8),
                                Text('Failed to load image'),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  office.address,
                  style: const TextStyle(fontSize: 16),
                ),
                if (office.phone.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Phone: ${office.phone}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UPM Faculty Locations'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate),
            onPressed: _showDistances,
            tooltip: 'Show Distances',
          ),
        ],
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: const CameraPosition(
          target: LatLng(3.0064, 101.7199), // Centered on UPM
          zoom: 15,
        ),
        markers: _markers.values.toSet(),
        polylines: _polylines,
      ),
    );
  }
}