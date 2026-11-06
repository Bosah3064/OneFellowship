// ==============================================================================
// ONEFELLOWSHIP - FIREBASE SERVICE INITIALIZER
// ==============================================================================

import { CONFIG } from '../config.js';

let appInstance = null;
let authInstance = null;
let firestoreInstance = null;

export function getFirebaseConfig() {
  // Allow user to override via localStorage or window if needed
  try {
    const saved = localStorage.getItem('ONEFELLOWSHIP_FIREBASE_CONFIG');
    if (saved) return JSON.parse(saved);
  } catch (_) {}

  return window.__FIREBASE_CONFIG__ || CONFIG.FIREBASE_CONFIG;
}

export function initFirebase() {
  if (!window.firebase) {
    throw new Error('Firebase SDK scripts not loaded on window.');
  }

  if (!appInstance) {
    const config = getFirebaseConfig();
    try {
      if (!window.firebase.apps.length) {
        appInstance = window.firebase.initializeApp(config);
      } else {
        appInstance = window.firebase.app();
      }
      authInstance = window.firebase.auth();
      firestoreInstance = window.firebase.firestore();
    } catch (err) {
      console.warn('Firebase initialization warning:', err);
    }
  }

  return {
    app: appInstance,
    auth: authInstance,
    db: firestoreInstance
  };
}

export function getAuth() {
  if (!authInstance) initFirebase();
  return authInstance;
}

export function getFirestore() {
  if (!firestoreInstance) initFirebase();
  return firestoreInstance;
}

export function handleFirebaseError(error, defaultMsg = 'An error occurred.') {
  if (!error) return defaultMsg;
  console.error('[Firebase Error]:', error);

  const code = error.code || '';
  switch (code) {
    case 'auth/invalid-email':
      return 'The email address is invalid.';
    case 'auth/user-disabled':
      return 'This user account has been disabled.';
    case 'auth/user-not-found':
      return 'No account found with this email.';
    case 'auth/wrong-password':
    case 'auth/invalid-credential':
      return 'Incorrect password or credentials.';
    case 'auth/email-already-in-use':
      return 'An account already exists with this email.';
    case 'auth/weak-password':
      return 'Password should be at least 6 characters.';
    case 'auth/network-request-failed':
      return 'Network connection failed. Please check your internet.';
    case 'permission-denied':
      return 'Access denied. You do not have permission for this action.';
    default:
      return error.message || defaultMsg;
  }
}

