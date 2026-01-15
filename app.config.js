export default {
  expo: {
    name: 'Web TÜFE Mobile',
    slug: 'webtufe-mobile',
    version: '1.0.21',
    orientation: 'portrait',
    icon: './assets/icon.png',
    userInterfaceStyle: 'light',
    splash: {
      image: './assets/splash.png',
      resizeMode: 'contain',
      backgroundColor: '#ffffff',
    },
    assetBundlePatterns: ['**/*'],
    ios: {
      supportsTablet: true,
      bundleIdentifier: 'com.webtufe.mobile',
    },
    android: {
      adaptiveIcon: {
        foregroundImage: './assets/adaptive-icon.png',
        backgroundColor: '#ffffff',
      },
      package: 'com.webtufe.mobile',
    },
    web: {
      favicon: './assets/favicon.png',
      bundler: 'metro',
    },
    updates: {
      enabled: false, // OTA kapalı; repo içindeki CSV'ler gömülü bundle ile okunacak
    },
    extra: {
      eas: {
        projectId: '1563fcb5-b2a9-4a6b-b0b2-e7f9dfbd8328',
      },
    },
  },
};

