import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_android_pet_tracking_background_service/communication/android_communication.dart';
import 'package:flutter_android_pet_tracking_background_service/utils/AndroidCall.dart';
import 'package:flutter_android_pet_tracking_background_service/utils/LatLngWrapper.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const String METHOD_CHANNEL = "DeveloperGundaChannel";

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const methodChannel = const MethodChannel(METHOD_CHANNEL);
  bool isTrackingEnabled = false;
  bool isServiceBounded = false;
  List<LatLng> latLngList = [];
  final Set<Polyline> _polylines = {};
  AndroidCommunication androidCommunication = AndroidCommunication();

  GoogleMapController googleMapController;

  LatLng _center = const LatLng(45.521563, -122.677433);

  @override
  void initState() {
    super.initState();
    _setAndroidMethodCallHandler();
    _isServiceBound();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Background Service',
      home: Scaffold(
          body: !isServiceBounded
              ? CircularProgressIndicator()
              : getInitialWidget(context)),
      debugShowCheckedModeBanner: false,
    );
  }

  Center getInitialWidget(BuildContext context) {
    return Center(
      heightFactor: 50,
      child: Container(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              height: 500,
              child: GoogleMap(
                onMapCreated: _onMapCreated,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                initialCameraPosition:
                    CameraPosition(target: _center, zoom: 2.0),
                polylines: _polylines,
                compassEnabled: true,
              ),
            ),
            !isTrackingEnabled
                ? RaisedButton(
                    child: Text('Track my pet'),
                    onPressed: () {
                      _invokeServiceInAndroid();
                    },
                  )
                : RaisedButton(
                    child: Text('Stop tracking my pet'),
                    onPressed: () {
                      _stopServiceInAndroid();
                    },
                  )
          ],
        ),
      ),
    );
  }

  void _onMapCreated(GoogleMapController googleMapController) {
    this.googleMapController = googleMapController;
  }

  void _invokeServiceInAndroid() {
    androidCommunication.invokeServiceInAndroid().then((onValue) {
      setState(() {
        isTrackingEnabled = true;
      });
    });
  }

  void _stopServiceInAndroid() {
    androidCommunication.stopServiceInAndroid().then((onValue) {
      setState(() {
        isTrackingEnabled = false;
      });
    });
  }

  Future _isPetTrackingEnabled() async {
    if (Platform.isAndroid) {
      bool result = await methodChannel.invokeMethod("isPetTrackingEnabled");
      setState(() {
        isTrackingEnabled = result;
      });
      debugPrint("Pet Tracking Status - $isTrackingEnabled");
    }
  }

  Future _isServiceBound() async {
    if (Platform.isAndroid) {
      debugPrint("ServiceBound Called from init");
      bool result = await methodChannel.invokeMethod("serviceBound");
      debugPrint("Result from ServiceBound call - $result");
      setState(() {
        isServiceBounded = result;
        if (isServiceBounded) {
          _isPetTrackingEnabled();
        }
      });
      debugPrint("Pet Tracking Status - $isTrackingEnabled");
    }
  }

  Future<dynamic> _androidMethodCallHandler(MethodCall call) async {
    switch (call.method) {
      case AndroidCall.PATH_LOCATION:
        var pathLocation = jsonDecode(call.arguments);
        LatLng latLng = LatLngWrapper.fromAndroidJson(pathLocation);
        latLngList.add(latLng);
        if (latLngList.isNotEmpty) {
          setState(() {
            if (latLngList.length > 2) {
              var bounds = LatLngBounds(
                  southwest: latLngList.first, northeast: latLngList.last);
              var cameraUpdate = CameraUpdate.newLatLngBounds(bounds, 25.0);
              googleMapController.animateCamera(cameraUpdate);
            }
            _polylines.add(Polyline(
              polylineId: PolylineId(latLngList.first.toString()),
              visible: true,
              points: latLngList,
              color: Colors.green,
              width: 2,
            ));
            _center = latLngList.last;
          });
        }
        debugPrint("Wrapper here --> $latLng");
        break;
    }
  }

  void _setAndroidMethodCallHandler() {
    methodChannel.setMethodCallHandler(_androidMethodCallHandler);
  }
}
