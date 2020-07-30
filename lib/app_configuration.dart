library app_configuration;

import 'dart:async';
import 'dart:convert';

import 'package:cloud_logger/cloud_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart' as Foundation;
import 'package:shared_preferences/shared_preferences.dart';

/// App configuration contains configurations map to setup for all other services
class AppConfiguration {
  /// Configurations map for the app
  Map<String, dynamic> configurations = new Map();

  /// Logger instance to share across services
  Logger logger;

  /// Shared preferences to save data https://pub.dev/packages/shared_preferences
  SharedPreferences prefs;

  /// Azure monitor logger output
  AzureMonitorOutput _azureOutput;

  /// All global variable and configs are setup here
  ///
  /// `asset` the json file in assets folder
  ///
  /// `configs` other configs to setup
  Future<void> initialize({String asset, Map<String, dynamic> configs}) async {
    if (asset?.isNotEmpty == true) {
      await appendAsset(asset);
    }

    if (configs != null) {
      append(configs);
    }

    prefs = await SharedPreferences.getInstance();
    var outputs = List<LogOutput>();
    _azureOutput = AzureMonitorOutput(configurations);
    if (Foundation.kReleaseMode) {
      // log to cloud on release
      outputs.add(_azureOutput);

      // In some case, we need to print the console in release as well (e.g. checking log on web release).
      // Let's set `devReleaseMode = true` to turn on the console log
      if (configurations['devReleaseMode'] == true) {
        outputs.add(ConsoleOutput());
      }
    } else {
      // log to console on debug
      outputs.add(ConsoleOutput());
    }

    logger = Logger(
        printer: Foundation.kReleaseMode ? CloudPrinter() : PrettyPrinter(),
        output: MultipleOutput(outputs));
  }

  /// Send all the cached logs into azure monitor
  Future<void> sendLogsToAzure() async {
    await _azureOutput.sendAllLogs();
  }

  /// Add new configurations into current
  void append(Map<String, dynamic> configs) {
    configurations.addAll(configs);
  }

  /// Add new configurations from json asset file into current
  Future<void> appendAsset(String asset) async {
    String data = await rootBundle.loadString(asset);
    var jsonResult = json.decode(data);
    append(jsonResult);
  }

  /// Record a flutter
  Future<void> recordFlutterError(FlutterErrorDetails details) async {
    logger?.wtf('runZoned error ${details.exception}', details.exception,
        details.stack);
  }

  /// Execute a function in [runZoned] and handle error logging
  ///
  /// [runZoned]:(https://api.flutter.dev/flutter/dart-async/runZoned.html)
  void executeInZoned(Function func) {
    runZoned(() {
      func();
    }, onError: (e, stackTrace) {
      logger?.wtf('runZoned error $e', e, stackTrace);
    });
  }
}
