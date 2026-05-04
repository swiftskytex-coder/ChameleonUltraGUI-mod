import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:chameleonultragui/main.dart';
import 'package:chameleonultragui/database/key_database.dart';
import 'package:chameleonultragui/models/key_record.dart';
import 'package:chameleonultragui/helpers/general.dart';
import 'package:chameleonultragui/helpers/definitions.dart';
import 'package:chameleonultragui/connector/serial_abstract.dart';
import 'package:geolocator/geolocator.dart';

class AddressesPage extends StatefulWidget {
  const AddressesPage({super.key});

  @override
  AddressesPageState createState() => AddressesPageState();
}

class AddressesPageState extends State<AddressesPage> {
  final KeyDatabase _db = KeyDatabase();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  Position? _currentPosition;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled')),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Location permissions are permanently denied')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadKeyToSlot(KeyRecord key) async {
    var appState = context.read<ChameleonGUIState>();
    if (!appState.connector!.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device not connected')),
      );
      return;
    }

    try {
      await appState.communicator!.setActiveSlot(0);

      await appState.communicator!.setSlotTagType(0, key.tag);

      await appState.communicator!.setSlotData(
        0,
        hexToBytes(key.uid),
        key.tag,
      );

      await appState.communicator!.setSlotEnable(0, true, true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loaded: ${key.address}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading key: $e')),
        );
      }
    }
  }

  Future<void> _exportDatabase() async {
    try {
      String json = await _db.exportToJson();
      final directory = await getApplicationDocumentsDirectory();
      String path = '${directory.path}/keys_export_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File(path);
      await file.writeAsString(json);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported to: $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    }
  }

  Future<void> _importDatabase() async {
    try {
      var appState = context.read<ChameleonGUIState>();
      var cards = appState.sharedPreferencesProvider.getCards();

      if (cards.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No saved cards to import')),
        );
        return;
      }

      int count = 0;
      for (var card in cards) {
        var keyRecord = KeyRecord(
          uid: card.uid,
          sak: card.sak,
          atqa: card.atqa,
          name: card.name,
          address: card.name,
          entrance: 1,
          tag: card.tag,
          data: card.data,
          ats: card.ats,
          signature: card.extraData.ultralightSignature,
          version: card.extraData.ultralightVersion,
        );
        await _db.insertKey(keyRecord);
        count++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported $count keys')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e')),
        );
      }
    }
  }

  Future<void> _clearDatabase() async {
    bool confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all keys?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await _db.clearAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database cleared')),
        );
        setState(() {});
      }
    }
  }

@override
  Widget build(BuildContext context) {
    var appState = context.watch<ChameleonGUIState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Addresses'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'export') {
                _exportDatabase();
              } else if (value == 'import') {
                _importDatabase();
              } else if (value == 'clear') {
                _clearDatabase();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.upload_file),
                  title: Text('Export JSON'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Import JSON'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.delete_forever),
                  title: Text('Clear all'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: 'Get current location',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search address...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          if (_currentPosition != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on),
                  const SizedBox(width: 8),
                  Text(
                    'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, Lon: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                  ),
                ],
              ),
            ),
          Expanded(
            child: FutureBuilder<List<KeyRecord>>(
              future: _searchQuery.isEmpty
                  ? _db.getAllKeys()
                  : _db.searchKeys(_searchQuery),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                List<KeyRecord> keys = snapshot.data ?? [];

                if (keys.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.home_work,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'No addresses found',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text('Scan a card and add it with address'),
                      ],
                    ),
                  );
                }

                if (_currentPosition != null) {
                  keys.sort((a, b) {
                    double? distA = a.distanceTo(
                        _currentPosition!.latitude, _currentPosition!.longitude);
                    double? distB = b.distanceTo(
                        _currentPosition!.latitude, _currentPosition!.longitude);
                    if (distA == null && distB == null) return 0;
                    if (distA == null) return 1;
                    if (distB == null) return -1;
                    return distA.compareTo(distB);
                  });
                }

                return ListView.builder(
                  itemCount: keys.length,
                  itemBuilder: (context, index) {
                    KeyRecord key = keys[index];
                    double? distance = _currentPosition != null
                        ? key.distanceTo(_currentPosition!.latitude,
                            _currentPosition!.longitude)
                        : null;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text('${key.entrance}'),
                        ),
                        title: Text(key.address),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('UID: ${key.uid}'),
                            if (distance != null)
                              Text(
                                '${(distance / 1000).toStringAsFixed(1)} km',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        trailing: appState.connector!.connected
                            ? IconButton(
                                icon: const Icon(Icons.upload),
                                onPressed: () => _loadKeyToSlot(key),
                                tooltip: 'Load to slot 1',
                              )
                            : null,
                        onTap: () {
                          _showKeyDetails(key);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        tooltip: 'Add from saved cards',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showKeyDetails(KeyRecord key) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(key.address),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Entrance: ${key.entrance}'),
            Text('UID: ${key.uid}'),
            Text('Tag Type: ${key.tag.name}'),
            if (key.lat != null && key.lon != null)
              Text('GPS: ${key.lat}, ${key.lon}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAddDialog() async {
    var appState = context.read<ChameleonGUIState>();
    var cards = appState.sharedPreferencesProvider.getCards();

    if (cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved cards')),
      );
      return;
    }

    String? selectedCard = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Card'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: cards.length,
            itemBuilder: (context, index) {
              var card = cards[index];
              return ListTile(
                title: Text(card.name),
                subtitle: Text(card.uid),
                onTap: () => Navigator.pop(context, card.uid),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedCard == null) return;

    _showAddressDialog(selectedCard);
  }

  void _showAddressDialog(String uid) {
    final addressController = TextEditingController();
    int entrance = 1;
    double? lat = _currentPosition?.latitude;
    double? lon = _currentPosition?.longitude;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Address'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  hintText: 'Street, House',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Entrance: '),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: entrance,
                    items: List.generate(20, (i) => i + 1)
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text('$e'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        entrance = value ?? 1;
                      });
                    },
                  ),
                ],
              ),
              if (lat != null && lon != null) ...[
                const SizedBox(height: 8),
                Text(
                  'GPS: $lat, $lon',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (addressController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter address')),
                  );
                  return;
                }

                var appState = context.read<ChameleonGUIState>();
                var cards = appState.sharedPreferencesProvider.getCards();
                var card = cards.firstWhere((c) => c.uid == uid);

                var keyRecord = KeyRecord(
                  uid: uid,
                  sak: card.sak,
                  atqa: card.atqa,
                  name: card.name,
                  address: addressController.text,
                  entrance: entrance,
                  lat: lat,
                  lon: lon,
                  tag: card.tag,
                  data: card.data,
                  ats: card.ats,
                  signature: card.extraData.ultralightSignature,
                  version: card.extraData.ultralightVersion,
                );

                await _db.insertKey(keyRecord);

                if (mounted) {
                  Navigator.pop(context);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Address added')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}