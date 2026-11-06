// ==============================================================================
// ONEFELLOWSHIP - FIREBASE PAYMENT SERVICE
// ==============================================================================

import { getFirestore, handleFirebaseError } from './firebase.js';

export const PaymentService = {
  /**
   * Fetch payments for a specific member from Firestore
   */
  async getPaymentsByMember(memberId) {
    const db = getFirestore();
    try {
      const snapshot = await db.collection('payments')
        .where('member_id', '==', memberId)
        .get();

      const list = [];
      snapshot.forEach(doc => {
        list.push({ id: doc.id, ...doc.data() });
      });

      // Sort by payment_date descending
      return list.sort((a, b) => new Date(b.payment_date || 0) - new Date(a.payment_date || 0));
    } catch (error) {
      throw new Error(handleFirebaseError(error, 'Could not fetch member payments.'));
    }
  },

  /**
   * Fetch all payments in the system from Firestore (Admin)
   */
  async getAllPayments() {
    const db = getFirestore();
    try {
      const snapshot = await db.collection('payments').get();
      const list = [];
      snapshot.forEach(doc => {
        list.push({ id: doc.id, ...doc.data() });
      });

      // Sort by payment_date descending
      return list.sort((a, b) => new Date(b.payment_date || 0) - new Date(a.payment_date || 0));
    } catch (error) {
      throw new Error(handleFirebaseError(error, 'Could not fetch payments directory.'));
    }
  },

  /**
   * Add a single payment to Firestore
   */
  async addPayment(paymentData) {
    const db = getFirestore();
    try {
      const docRef = await db.collection('payments').add({
        ...paymentData,
        created_at: new Date().toISOString()
      });
      const created = await docRef.get();
      return { id: docRef.id, ...created.data() };
    } catch (error) {
      throw new Error(handleFirebaseError(error, 'Could not save payment.'));
    }
  },

  /**
   * Add bulk payments for selected members using Firestore Batch Write
   */
  async addBulkPayments(members, payload) {
    const helpers = window.bulkPaymentHelpers;
    if (!helpers) {
      throw new Error('Bulk payment helpers are not loaded.');
    }

    const validationErrors = helpers.validateBulkPaymentSelection(payload);
    if (validationErrors.length > 0) {
      throw new Error(validationErrors.join(' '));
    }

    const rows = helpers.buildBulkPaymentRows(members, payload);
    if (!rows || rows.length === 0) {
      throw new Error('No valid member payment rows generated.');
    }

    const db = getFirestore();
    try {
      const batch = db.batch();
      const results = [];

      rows.forEach(row => {
        const docRef = db.collection('payments').doc();
        const data = {
          ...row,
          created_at: new Date().toISOString()
        };
        batch.set(docRef, data);
        results.push({ id: docRef.id, ...data });
      });

      await batch.commit();
      return results;
    } catch (error) {
      throw new Error(handleFirebaseError(error, 'Bulk payment batch write failed.'));
    }
  },

  /**
   * Update payment record in Firestore
   */
  async updatePayment(paymentId, updates) {
    const db = getFirestore();
    try {
      const docRef = db.collection('payments').doc(paymentId);
      await docRef.set({
        ...updates,
        updated_at: new Date().toISOString()
      }, { merge: true });

      const updated = await docRef.get();
      return { id: updated.id, ...updated.data() };
    } catch (error) {
      throw new Error(handleFirebaseError(error, 'Could not update payment record.'));
    }
  },

  /**
   * Delete payment record from Firestore
   */
  async deletePayment(paymentId) {
    const db = getFirestore();
    try {
      await db.collection('payments').doc(paymentId).delete();
      return true;
    } catch (error) {
      throw new Error(handleFirebaseError(error, 'Could not delete payment record.'));
    }
  },

  /**
   * Compute member KPI stats from payments list
   */
  calculateMemberStats(payments = []) {
    let totalSavings = 0;
    let paidOutSavings = 0;
    let isRegistered = false;
    let pendingCount = 0;

    payments.forEach(p => {
      const status = (p.status || '').toLowerCase().trim();
      const type = (p.payment_type || '').toLowerCase().trim();
      const payoutStatus = (p.payout_status || '').toLowerCase().trim();
      const amount = Number(p.amount) || 0;

      if (status === 'paid') {
        if (type === 'registration') {
          isRegistered = true;
        } else {
          if (payoutStatus === 'paid_out') {
            paidOutSavings += amount;
          } else {
            totalSavings += amount;
          }
        }
      } else if (status === 'pending' || status === 'overdue') {
        pendingCount += 1;
      }
    });

    return {
      totalSavings,
      paidOutSavings,
      isRegistered,
      pendingCount
    };
  },

  /**
   * Compute admin dashboard aggregates
   */
  calculateAdminStats(payments = [], members = []) {
    let totalCollected = 0;
    let totalPaidOut = 0;
    let totalPendingAmount = 0;
    let activeMembersCount = 0;

    members.forEach(m => {
      if (m.status === 'active' || m.status === 'approved') {
        activeMembersCount += 1;
      }
    });

    payments.forEach(p => {
      const status = (p.status || '').toLowerCase().trim();
      const payoutStatus = (p.payout_status || '').toLowerCase().trim();
      const amount = Number(p.amount) || 0;

      if (status === 'paid') {
        if (payoutStatus === 'paid_out') {
          totalPaidOut += amount;
        } else {
          totalCollected += amount;
        }
      } else if (status === 'pending' || status === 'overdue') {
        totalPendingAmount += amount;
      }
    });

    return {
      totalMembers: members.length,
      activeMembers: activeMembersCount,
      totalCollected,
      totalPaidOut,
      totalPendingAmount
    };
  }
};
