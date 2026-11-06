// ==============================================================================
// ONEFELLOWSHIP - FIREBASE NOTIFICATION SERVICE
// ==============================================================================

import { getFirestore, handleFirebaseError } from './firebase.js';

export const NotificationService = {
  /**
   * Fetch in-app notifications for member or broadcast ('all') from Firestore
   */
  async getNotifications(memberId) {
    const db = getFirestore();
    try {
      const list = [];

      // Query broadcasts
      const broadcastSnap = await db.collection('notifications')
        .where('recipient', '==', 'all')
        .get();

      broadcastSnap.forEach(doc => {
        list.push({ id: doc.id, ...doc.data() });
      });

      // Query direct notifications if memberId provided
      if (memberId) {
        const directSnap = await db.collection('notifications')
          .where('recipient', '==', memberId)
          .get();

        directSnap.forEach(doc => {
          list.push({ id: doc.id, ...doc.data() });
        });
      }

      // Sort by created_at descending
      return list.sort((a, b) => new Date(b.created_at || 0) - new Date(a.created_at || 0));
    } catch (err) {
      console.warn('Could not load notifications:', err);
      return [];
    }
  },

  /**
   * Send notification via Firestore (Admin)
   */
  async sendNotification({ recipient, title, type = 'info', message, createdBy = 'Admin' }) {
    const db = getFirestore();
    const payload = {
      recipient,
      title: title.trim(),
      type,
      message: message.trim(),
      created_by: createdBy,
      created_at: new Date().toISOString()
    };

    try {
      const docRef = await db.collection('notifications').add(payload);
      return { id: docRef.id, ...payload };
    } catch (error) {
      throw new Error(handleFirebaseError(error, 'Failed to send notification.'));
    }
  }
};
