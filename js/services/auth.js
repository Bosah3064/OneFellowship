// ==============================================================================
// ONEFELLOWSHIP - FIREBASE AUTH SERVICE
// ==============================================================================

import { getAuth, getFirestore, handleFirebaseError } from './firebase.js';
import { CONFIG } from '../config.js';

export const AuthService = {
  /**
   * Log in user with email & password via Firebase Auth
   */
  async signIn(email, password) {
    const auth = getAuth();
    const db = getFirestore();
    try {
      const userCredential = await auth.signInWithEmailAndPassword(email.trim(), password);
      const user = userCredential.user;

      // Auto-provision Firestore document if missing
      if (user && db) {
        try {
          const docRef = db.collection('members').doc(user.uid);
          const docSnap = await docRef.get();
          if (!docSnap.exists) {
            const cleanEmail = (user.email || email).trim();
            const displayName = user.displayName || (cleanEmail ? cleanEmail.split('@')[0] : 'Member');
            await docRef.set({
              id: user.uid,
              full_name: displayName,
              email: cleanEmail,
              phone: user.phoneNumber || null,
              role: (cleanEmail === 'bosah3064@gmail.com' || cleanEmail === 'lame3064@gmail.com') ? 'admin' : 'member',
              status: 'active',
              form_details: {},
              join_date: new Date().toISOString(),
              created_at: new Date().toISOString(),
              needs_password_reset: false
            }, { merge: true });
          }
        } catch (dbErr) {
          console.warn('Auto-provisioning member doc warning:', dbErr);
        }
      }

      return user;
    } catch (error) {
      throw new Error(handleFirebaseError(error, 'Invalid email or password.'));
    }
  },

  /**
   * Register a new member via Firebase Auth & Firestore
   */
  async signUp({ email, password, fullName, phone, formDetails = {} }) {
    const auth = getAuth();
    const db = getFirestore();
    const cleanEmail = email.trim();

    try {
      const userCredential = await auth.createUserWithEmailAndPassword(
        cleanEmail,
        password || CONFIG.DEFAULT_PASSWORD
      );

      const user = userCredential.user;

      // Update user display name in Firebase Auth profile
      if (user.updateProfile) {
        await user.updateProfile({ displayName: fullName.trim() });
      }

      // Create member document in Firestore 'members' collection
      const memberDoc = {
        id: user.uid,
        full_name: fullName.trim(),
        email: cleanEmail,
        phone: phone ? phone.trim() : null,
        role: 'member',
        status: 'active',
        form_details: formDetails,
        join_date: new Date().toISOString(),
        created_at: new Date().toISOString(),
        needs_password_reset: password === CONFIG.DEFAULT_PASSWORD
      };

      await db.collection('members').doc(user.uid).set(memberDoc);
      return user;
    } catch (error) {
      throw new Error(handleFirebaseError(error, 'Failed to create member account.'));
    }
  },

  /**
   * Log out of Firebase
   */
  async signOut() {
    const auth = getAuth();
    await auth.signOut();
  },

  /**
   * Get active user session
   */
  async getSession() {
    const auth = getAuth();
    return new Promise((resolve) => {
      const unsubscribe = auth.onAuthStateChanged((user) => {
        unsubscribe();
        resolve(user ? { user } : null);
      });
    });
  },

  /**
   * Get currently signed-in user
   */
  getCurrentUser() {
    const auth = getAuth();
    return auth.currentUser;
  },

  /**
   * Update password for currently signed-in user
   */
  async updatePassword(newPassword) {
    const auth = getAuth();
    const user = auth.currentUser;
    if (!user) throw new Error('No active user signed in.');

    try {
      await user.updatePassword(newPassword);
      return true;
    } catch (error) {
      throw new Error(handleFirebaseError(error, 'Password update failed.'));
    }
  },

  /**
   * Send password reset email via Firebase Auth
   */
  async requestPasswordReset(email) {
    const auth = getAuth();
    try {
      await auth.sendPasswordResetEmail(email.trim());
      return true;
    } catch (error) {
      throw new Error(handleFirebaseError(error, 'Could not send reset email.'));
    }
  },

  /**
   * Admin reset password for member (flags document and triggers recovery)
   */
  async adminResetPassword(targetUserId, newPassword) {
    const db = getFirestore();
    try {
      await db.collection('members').doc(targetUserId).update({
        needs_password_reset: true,
        temp_password: newPassword,
        updated_at: new Date().toISOString()
      });
      return true;
    } catch (error) {
      throw new Error(handleFirebaseError(error, 'Admin password reset failed.'));
    }
  },

  /**
   * Subscribe to Firebase Auth state changes
   */
  onAuthStateChange(callback) {
    const auth = getAuth();
    const db = getFirestore();
    return auth.onAuthStateChanged(async (user) => {
      if (user && db) {
        try {
          const docRef = db.collection('members').doc(user.uid);
          const docSnap = await docRef.get();
          if (!docSnap.exists) {
            const cleanEmail = (user.email || '').trim();
            const displayName = user.displayName || (cleanEmail ? cleanEmail.split('@')[0] : 'Member');
            await docRef.set({
              id: user.uid,
              full_name: displayName,
              email: cleanEmail,
              phone: user.phoneNumber || null,
              role: (cleanEmail === 'bosah3064@gmail.com' || cleanEmail === 'lame3064@gmail.com') ? 'admin' : 'member',
              status: 'active',
              form_details: {},
              join_date: new Date().toISOString(),
              created_at: new Date().toISOString(),
              needs_password_reset: false
            }, { merge: true });
          }
        } catch (_) {}
      }
      callback(user ? 'SIGNED_IN' : 'SIGNED_OUT', user ? { user } : null);
    });
  }
};
