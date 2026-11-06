// ==============================================================================
// ONEFELLOWSHIP - FIREBASE MEMBER SERVICE
// ==============================================================================

import { getFirestore, handleFirebaseError } from './firebase.js';

export const CANONICAL_FIELDS = [
  { key: 'phone', label: 'Phone Number', icon: 'fa-phone', isMemberField: true },
  { key: 'date_of_birth', label: 'Date of Birth', icon: 'fa-cake-candles', aliases: ['dob', 'birth_date'] },
  { key: 'gender', label: 'Gender', icon: 'fa-venus-mars' },
  { key: 'marital_status', label: 'Marital Status', icon: 'fa-heart', aliases: ['marital'] },
  { key: 'national_id_number', label: 'National ID Number', icon: 'fa-id-card', aliases: ['id_number', 'national_id', 'id number'] },
  { key: 'occupation', label: 'Occupation / Profession', icon: 'fa-briefcase', aliases: ['profession', 'job'] },
  { key: 'branch', label: 'Branch / Chapter', icon: 'fa-building', aliases: ['location'] },
  { key: 'next_of_kin_full_name', label: 'Next of Kin Name', icon: 'fa-people-arrows', aliases: ['nok_name', 'next_of_kin', 'kin_name'] },
  { key: 'next_of_kin_phone_number', label: 'Next of Kin Phone', icon: 'fa-phone-volume', aliases: ['nok_phone', 'kin_phone'] },
  { key: 'next_of_kin_national_id_number', label: 'Next of Kin ID', icon: 'fa-address-card', aliases: ['nok_id'] },
  { key: 'relationship_to_you', label: 'Relationship to Next of Kin', icon: 'fa-handshake', aliases: ['relationship', 'nok_relation'] }
];

export function resolveFieldValue(formDetails, fieldKey) {
  if (!formDetails || typeof formDetails !== 'object') return '';
  if (formDetails[fieldKey] !== undefined && formDetails[fieldKey] !== null && String(formDetails[fieldKey]).trim() !== '') {
    return formDetails[fieldKey];
  }

  // Check aliases
  const canonical = CANONICAL_FIELDS.find(f => f.key === fieldKey);
  if (canonical && canonical.aliases) {
    for (const alias of canonical.aliases) {
      if (formDetails[alias] !== undefined && formDetails[alias] !== null && String(formDetails[alias]).trim() !== '') {
        return formDetails[alias];
      }
    }
  }

  // Case-insensitive lookup
  const target = fieldKey.toLowerCase().replace(/_/g, ' ');
  for (const [k, v] of Object.entries(formDetails)) {
    if (k.toLowerCase().replace(/_/g, ' ') === target && v) return v;
  }

  return '';
}

export function checkProfileCompleteness(member) {
  const missing = [];
  const fd = member.form_details || {};

  if (!member.phone || String(member.phone).trim() === '') missing.push('Phone Number');

  CANONICAL_FIELDS.forEach(field => {
    if (field.isMemberField) return;
    const val = resolveFieldValue(fd, field.key);
    if (!val || String(val).trim() === '') {
      missing.push(field.label);
    }
  });

  return missing;
}

export const MemberService = {
  /**
   * Fetch member record by ID from Firestore
   */
  async getMemberById(id) {
    const db = getFirestore();
    try {
      const doc = await db.collection('members').doc(id).get();
      if (!doc.exists) {
        throw new Error('Member profile document not found.');
      }
      return { id: doc.id, ...doc.data() };
    } catch (error) {
      throw new Error(handleFirebaseError(error, 'Could not fetch member profile.'));
    }
  },

  /**
   * Fetch all members from Firestore
   */
  async getAllMembers() {
    const db = getFirestore();
    try {
      const snapshot = await db.collection('members').get();
      const list = [];
      snapshot.forEach(doc => {
        list.push({ id: doc.id, ...doc.data() });
      });

      // Sort by full_name ascending
      return list.sort((a, b) => (a.full_name || '').localeCompare(b.full_name || ''));
    } catch (error) {
      throw new Error(handleFirebaseError(error, 'Could not fetch members list.'));
    }
  },

  /**
   * Get total member count from Firestore
   */
  async getMemberCount() {
    const db = getFirestore();
    try {
      const snapshot = await db.collection('members').get();
      return snapshot.size;
    } catch (_) {
      return 0;
    }
  },

  /**
   * Create a member document manually (Admin)
   */
  async createMember({ fullName, email, phone, role = 'member', idNumber, branch }) {
    const db = getFirestore();
    try {
      const formDetails = {};
      if (idNumber) formDetails.national_id_number = idNumber;
      if (branch) formDetails.branch = branch;

      const newDocRef = db.collection('members').doc();
      const memberDoc = {
        id: newDocRef.id,
        full_name: fullName.trim(),
        email: email.trim(),
        phone: phone ? phone.trim() : null,
        role: role || 'member',
        status: 'active',
        form_details: formDetails,
        join_date: new Date().toISOString(),
        created_at: new Date().toISOString(),
        needs_password_reset: true
      };

      await newDocRef.set(memberDoc);
      return newDocRef.id;
    } catch (error) {
      throw new Error(handleFirebaseError(error, 'Failed to create member.'));
    }
  },

  /**
   * Update member document
   */
  async updateMember(memberId, updates) {
    const db = getFirestore();
    try {
      const docRef = db.collection('members').doc(memberId);
      await docRef.set({
        ...updates,
        updated_at: new Date().toISOString()
      }, { merge: true });

      const updated = await docRef.get();
      return { id: updated.id, ...updated.data() };
    } catch (error) {
      throw new Error(handleFirebaseError(error, 'Failed to update member.'));
    }
  },

  /**
   * Get dynamic custom profile schema (from Google Forms uploads)
   */
  async getFormSchema() {
    const db = getFirestore();
    try {
      const doc = await db.collection('form_schema').doc('config').get();
      if (doc.exists && Array.isArray(doc.data().fields)) {
        return doc.data().fields;
      }
    } catch (_) {}
    return [];
  },

  /**
   * Save dynamic custom profile schema
   */
  async saveFormSchema(fields) {
    const db = getFirestore();
    try {
      await db.collection('form_schema').doc('config').set({
        fields,
        updated_at: new Date().toISOString()
      }, { merge: true });
      return true;
    } catch (error) {
      throw new Error(handleFirebaseError(error, 'Could not save form schema.'));
    }
  }
};
