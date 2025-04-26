import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class UrlUtils {
  // Map of domain patterns to their respective icons
  static final Map<String, IconData> _domainIcons = {
    // Social Media
    'github.com': FontAwesomeIcons.github,
    'twitter.com': FontAwesomeIcons.twitter,
    'x.com': FontAwesomeIcons.twitter,
    'facebook.com': FontAwesomeIcons.facebook,
    'instagram.com': FontAwesomeIcons.instagram,
    'linkedin.com': FontAwesomeIcons.linkedin,
    'reddit.com': FontAwesomeIcons.reddit,
    'pinterest.com': FontAwesomeIcons.pinterest,
    'snapchat.com': FontAwesomeIcons.snapchat,
    'tiktok.com': FontAwesomeIcons.tiktok,
    'discord.com': FontAwesomeIcons.discord,
    'slack.com': FontAwesomeIcons.slack,
    'telegram.org': FontAwesomeIcons.telegram,
    'whatsapp.com': FontAwesomeIcons.whatsapp,
    
    // Video Platforms
    'youtube.com': FontAwesomeIcons.youtube,
    'youtu.be': FontAwesomeIcons.youtube,
    'vimeo.com': FontAwesomeIcons.vimeo,
    'twitch.tv': FontAwesomeIcons.twitch,
    'dailymotion.com': FontAwesomeIcons.video,
    
    // Shopping
    'amazon.com': FontAwesomeIcons.amazon,
    'amazon.': FontAwesomeIcons.amazon, // For regional Amazon sites
    'flipkart.com': FontAwesomeIcons.cartShopping,
    'ebay.com': FontAwesomeIcons.shoppingBag,
    'etsy.com': FontAwesomeIcons.store,
    'walmart.com': FontAwesomeIcons.shoppingCart,
    'alibaba.com': FontAwesomeIcons.shopify,
    'aliexpress.com': FontAwesomeIcons.shoppingBag,
    'shopify.com': FontAwesomeIcons.shopify,
    
    // Tech & Development
    'stackoverflow.com': FontAwesomeIcons.stackOverflow,
    'medium.com': FontAwesomeIcons.medium,
    'dev.to': FontAwesomeIcons.dev,
    'gitlab.com': FontAwesomeIcons.gitlab,
    'bitbucket.org': FontAwesomeIcons.bitbucket,
    'codepen.io': FontAwesomeIcons.codepen,
    'jsfiddle.net': FontAwesomeIcons.js,
    'stackoverflow.com': FontAwesomeIcons.stackOverflow,
    'npmjs.com': FontAwesomeIcons.npm,
    'netlify.app': FontAwesomeIcons.server,
    'vercel.app': FontAwesomeIcons.server,
    'heroku.com': FontAwesomeIcons.server,
    'firebase.com': FontAwesomeIcons.fire,
    'azure.com': FontAwesomeIcons.microsoft,
    'aws.amazon.com': FontAwesomeIcons.aws,
    
    // Productivity
    'notion.so': FontAwesomeIcons.noteSticky,
    'airtable.com': FontAwesomeIcons.table,
    'trello.com': FontAwesomeIcons.trello,
    'asana.com': FontAwesomeIcons.listCheck,
    'todoist.com': FontAwesomeIcons.listCheck,
    'evernote.com': FontAwesomeIcons.noteSticky,
    'dropbox.com': FontAwesomeIcons.dropbox,
    'drive.google.com': FontAwesomeIcons.googleDrive,
    'docs.google.com': FontAwesomeIcons.fileLines,
    'sheets.google.com': FontAwesomeIcons.tableList,
    
    // Education
    'coursera.org': FontAwesomeIcons.graduationCap,
    'udemy.com': FontAwesomeIcons.graduationCap,
    'edx.org': FontAwesomeIcons.graduationCap,
    'khanacademy.org': FontAwesomeIcons.school,
    'udacity.com': FontAwesomeIcons.graduationCap,
    'pluralsight.com': FontAwesomeIcons.p,
    
    // News & Information
    'medium.com': FontAwesomeIcons.medium,
    'cnn.com': FontAwesomeIcons.newspaper,
    'bbc.com': FontAwesomeIcons.b,
    'nytimes.com': FontAwesomeIcons.newspaper,
    'wikipedia.org': FontAwesomeIcons.wikipediaW,
    
    // Entertainment
    'spotify.com': FontAwesomeIcons.spotify,
    'netflix.com': FontAwesomeIcons.n,
    'apple.com/music': FontAwesomeIcons.music,
    'soundcloud.com': FontAwesomeIcons.soundcloud,
    'bandcamp.com': FontAwesomeIcons.bandcamp,
    
    // Travel
    'airbnb.com': FontAwesomeIcons.airbnb,
    'booking.com': FontAwesomeIcons.bed,
    'expedia.com': FontAwesomeIcons.plane,
    
    // Health & Fitness
    'strava.com': FontAwesomeIcons.personRunning,
    'fitbit.com': FontAwesomeIcons.heartPulse,
    'myfitnesspal.com': FontAwesomeIcons.dumbbell,
    
    // Other Major Platforms
    'wordpress.com': FontAwesomeIcons.wordpress,
    'squarespace.com': FontAwesomeIcons.squarespace,
    'wix.com': FontAwesomeIcons.w,
    'behance.net': FontAwesomeIcons.behance,
    'dribbble.com': FontAwesomeIcons.dribbble,
    'figma.com': FontAwesomeIcons.figma,
  };

  // Get icon for URL
  static IconData getIconForUrl(String url) {
    try {
      final uri = Uri.parse(url.toLowerCase());
      final host = uri.host;
      
      // Check for exact matches
      if (_domainIcons.containsKey(host)) {
        return _domainIcons[host]!;
      }
      
      // Check for partial matches
      for (final domain in _domainIcons.keys) {
        if (host.contains(domain)) {
          return _domainIcons[domain]!;
        }
      }
      
      // Check by TLD and common patterns
      if (host.endsWith('.netlify.app')) return FontAwesomeIcons.server;
      if (host.endsWith('.vercel.app')) return FontAwesomeIcons.server;
      if (host.endsWith('.github.io')) return FontAwesomeIcons.github;
      if (host.endsWith('.gitlab.io')) return FontAwesomeIcons.gitlab;
      if (host.endsWith('.herokuapp.com')) return FontAwesomeIcons.server;
      if (host.endsWith('.firebaseapp.com')) return FontAwesomeIcons.fire;
      if (host.endsWith('.web.app')) return FontAwesomeIcons.fire;
      if (host.endsWith('.appspot.com')) return FontAwesomeIcons.google;
      
      // Generic icons by TLD
      if (host.endsWith('.edu')) return FontAwesomeIcons.graduationCap;
      if (host.endsWith('.gov')) return FontAwesomeIcons.landmark;
      if (host.endsWith('.org')) return FontAwesomeIcons.building;
      if (host.endsWith('.io')) return FontAwesomeIcons.code;
      if (host.endsWith('.dev')) return FontAwesomeIcons.code;
      
      // Default icon
      return FontAwesomeIcons.link;
    } catch (e) {
      return FontAwesomeIcons.link;
    }
  }
  
  // Get clean domain name
  static String getDomainFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      // Remove 'www.' if present
      return host.startsWith('www.') ? host.substring(4) : host;
    } catch (e) {
      return url;
    }
  }

  static String sanitizeUrl(String url) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return 'https://$url';
    }
    return url;
  }
}
