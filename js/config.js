// ==============================================================================
// ONEFELLOWSHIP - CONFIGURATION & FIREBASE SETTINGS
// ==============================================================================

export const CONFIG = {
  APP_NAME: 'OneFellowship',
  APP_TAGLINE: 'Together We Stand',
  
  // Package Identifiers
  PACKAGE_NAME_ANDROID: 'org.onefellowship.app',
  BUNDLE_ID_IOS: 'org.onefellowship.app',
  WEB_APP_ID: 'onefellowship-app',

  // Firebase Web Configuration
  // Paste your Firebase project configuration here from the Firebase Console:
  // Firebase Console -> Project Settings -> General -> Your apps -> Web app -> SDK setup and configuration
  FIREBASE_CONFIG: {
    apiKey: "AIzaSyB40K7B18XcsetxDuDTgvF5KoHrE264fIo",
    authDomain: "onefellowship-1c792.firebaseapp.com",
    projectId: "onefellowship-1c792",
    storageBucket: "onefellowship-1c792.firebasestorage.app",
    messagingSenderId: "612773099202",
    appId: "1:612773099202:android:4f77f66ca552c4fd256d5b"
  },

  DEFAULT_PASSWORD: '12345678',
  REGISTRATION_FEE: 600,
  DEFAULT_MONTHLY_SAVING: 200,
  ADMIN_ROLES: ['admin', 'treasury', 'chairperson', 'vice_chairperson'],

  // App Theme Colors (CSS Variables)
  BRAND_COLORS: {
    primary: '#0B4FBB',
    primaryDark: '#0A2D6B',
    secondary: '#FFC107',
    skyBlue: '#29B6F6',
    success: '#28A745',
    danger: '#E53935',
    warning: '#FB8C00',
    textPrimary: '#263238',
    textSecondary: '#757575',
    background: '#F5F7FA',
    surface: '#FFFFFF'
  },

  CARD_TEMPLATES: [
    {
      id: 'fellowship_royal',
      name: 'OneFellowship Royal',
      tag: 'brand',
      bg: 'linear-gradient(135deg, #0A2D6B 0%, #0B4FBB 50%, #29B6F6 100%)',
      text: '#ffffff',
      accent: '#FFC107'
    },
    {
      id: 'fellowship_gold',
      name: 'Fellowship Gold',
      tag: 'gold',
      bg: 'linear-gradient(135deg, #0B4FBB 0%, #0A2D6B 60%, #FFC107 100%)',
      text: '#ffffff',
      accent: '#ffe082'
    },
    {
      id: 'sky_fellowship',
      name: 'Sky Blue Horizon',
      tag: 'sky',
      bg: 'linear-gradient(135deg, #0284c7 0%, #29B6F6 50%, #0B4FBB 100%)',
      text: '#ffffff',
      accent: '#ffffff'
    },
    {
      id: 'prestige_navy',
      name: 'Prestige Navy',
      tag: 'dark',
      bg: 'linear-gradient(135deg, #0A2D6B 0%, #1e293b 50%, #0f172a 100%)',
      text: '#ffffff',
      accent: '#94a3b8'
    },
    {
      id: 'amber_glory',
      name: 'Amber Sun',
      tag: 'gold',
      bg: 'linear-gradient(135deg, #b45309 0%, #f59e0b 50%, #FFC107 100%)',
      text: '#ffffff',
      accent: '#fffbeb'
    },
    {
      id: 'executive_emerald',
      name: 'Executive Emerald',
      tag: 'emerald',
      bg: 'linear-gradient(135deg, #065f46 0%, #059669 50%, #28A745 100%)',
      text: '#ffffff',
      accent: '#a7f3d0'
    }
  ]
};
