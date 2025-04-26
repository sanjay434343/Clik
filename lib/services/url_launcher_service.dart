import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class UrlLauncherService {
  static Future<bool> launchURL(String urlString, {BuildContext? context}) async {
    try {
      final url = Uri.parse(urlString);
      
      // Try launching in external browser first for web links
      if (!urlString.contains('facebook.com') && 
          !urlString.contains('youtube.com')) {
        if (await canLaunchUrl(url)) {
          return await launchUrl(
            url,
            mode: LaunchMode.externalApplication,
            webOnlyWindowName: '_blank',
          );
        }
      }

      // Special handling for known URLs
      if (urlString.contains('facebook.com')) {
        if (Platform.isAndroid) {
          final fbUrl = 'fb://facewebmodal/f?href=$urlString';
          if (await canLaunchUrl(Uri.parse(fbUrl))) {
            return await launchUrl(Uri.parse(fbUrl));
          }
        } else if (Platform.isIOS) {
          final fbUrl = 'fb://';
          if (await canLaunchUrl(Uri.parse(fbUrl))) {
            return await launchUrl(url);
          }
        }
      }

      // Try different launch modes in sequence
      for (final mode in [
        LaunchMode.externalApplication,
        LaunchMode.platformDefault,
        LaunchMode.externalNonBrowserApplication,
      ]) {
        try {
          final launched = await launchUrl(url, mode: mode);
          if (launched) return true;
        } catch (_) {
          continue;
        }
      }

      // If all modes fail, try basic launch
      return await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }
}
