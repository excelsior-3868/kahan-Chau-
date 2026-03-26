import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

import 'package:family_locator/core/constants/supabase_constants.dart';

class BackgroundServiceInstance {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    /// OPTIONAL: only for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'location_service_channel', // id
      'Location Service', // title
      description: 'This channel is used for tracking location in background.', // description
      importance: Importance.low, // importance must be at least low to show notification
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'location_service_channel',
        initialNotificationTitle: 'Location Sharing Active',
        initialNotificationContent: 'Updating your location every 10 minutes',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // 1. Initialize Supabase for the background isolate
  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
  );

  final client = Supabase.instance.client;

  // 2. Set up periodic timer (10 minutes = 600 seconds)
  Timer.periodic(const Duration(minutes: 10), (timer) async {
    if (service is AndroidServiceInstance) {
      if (!(await service.isForegroundService())) {
        return;
      }
    }

    try {
      // 3. Fetch current location
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );

      // 4. Update Supabase
      final user = client.auth.currentUser;
      if (user != null) {
        final userId = user.id;

        // Update master table
        await client.from('users').update({
          'last_location': {
            'lat': position.latitude,
            'lng': position.longitude,
          },
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);

        // Update groups locations
        final groupsResponse = await client.from('group_members').select('group_id').eq('user_id', userId);
        final List<dynamic> groups = groupsResponse as List<dynamic>;
        
        if (groups.isNotEmpty) {
          final List<Map<String, dynamic>> upserts = groups.map((g) {
            return {
              'user_id': userId,
              'group_id': g['group_id'],
              'lat': position.latitude,
              'lng': position.longitude,
              'status': 'background', // Indicate it's a background update
              'timestamp': DateTime.now().toIso8601String(),
            };
          }).toList();

          await client.from('locations').upsert(upserts);
        }

        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "Location Updated",
            content: "Last update at ${DateTime.now().hour}:${DateTime.now().minute}",
          );
        }
      }
    } catch (e) {
      debugPrint("Background Location Error: $e");
    }
  });
}
