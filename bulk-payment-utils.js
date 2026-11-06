(function (root, factory) {
  const api = factory();
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = api;
  }
  root.bulkPaymentHelpers = api;
})(typeof window !== 'undefined' ? window : globalThis, function () {
  function filterBulkPaymentEligibleMembers(members) {
    return (members || []).filter((member) => {
      const role = (member.role || '').toString().trim().toLowerCase();
      return role === '' || role === 'member';
    });
  }

  function buildBulkPaymentRows(members, payload) {
    const selectedIds = Array.isArray(payload.selectedIds) ? payload.selectedIds : [];
    const amount = Number(payload.amount);
    const amountValue = Number.isFinite(amount) && amount > 0 ? amount : 0;

    return members
      .filter((member) => selectedIds.includes(member.id))
      .map((member) => ({
        member_id: member.id,
        member_name: member.full_name,
        amount: amountValue,
        month: payload.month,
        payment_date: payload.paymentDate,
        status: payload.status,
        payment_type: payload.paymentType,
        payout_status: payload.payoutStatus,
        reference: payload.reference || null,
        added_by: payload.addedBy || 'admin'
      }));
  }

  function validateBulkPaymentSelection(payload) {
  const errors = [];
  const selectedIds = Array.isArray(payload.selectedIds) ? payload.selectedIds : [];

  if (!selectedIds.length) {
    errors.push('Select at least one member.');
  }

  if (!payload.amount || Number(payload.amount) <= 0) {
    errors.push('Enter a payment amount.');
  }

  if (!payload.month) {
    errors.push('Select a month.');
  }

  if (!payload.paymentDate) {
    errors.push('Select a payment date.');
  }

    return errors;
  }

  function normalizePaymentMonth(payment) {
    if (payment && payment.month) {
      return payment.month;
    }

    if (payment && payment.payment_date) {
      const parsedDate = new Date(payment.payment_date);
      if (!Number.isNaN(parsedDate.getTime())) {
        return `${parsedDate.toLocaleString('en', { month: 'short' })} ${parsedDate.getFullYear()}`;
      }
    }

    return 'Unknown';
  }

  function buildMonthlyPaymentAnalytics(payments) {
    const buckets = {};

    (payments || []).forEach((payment) => {
      const monthLabel = normalizePaymentMonth(payment);
      const amount = Number(payment.amount) || 0;
      if (!buckets[monthLabel]) {
        buckets[monthLabel] = { label: monthLabel, amount: 0, count: 0 };
      }
      buckets[monthLabel].amount += amount;
      buckets[monthLabel].count += 1;
    });

    return Object.values(buckets).sort((left, right) => left.label.localeCompare(right.label));
  }

  function summarizeAdjustmentsAndAdvances(payments) {
    const adjustmentRecords = (payments || []).filter((payment) => {
      const status = (payment.status || '').toString().trim().toLowerCase();
      return status === 'pending' || status === 'overdue';
    });

    const advanceRecords = (payments || []).filter((payment) => {
      const payoutStatus = (payment.payout_status || '').toString().trim().toLowerCase();
      return payoutStatus === 'paid_out';
    });

    return {
      adjustmentCount: adjustmentRecords.length,
      adjustmentAmount: adjustmentRecords.reduce((sum, payment) => sum + (Number(payment.amount) || 0), 0),
      advanceCount: advanceRecords.length,
      advanceAmount: advanceRecords.reduce((sum, payment) => sum + (Number(payment.amount) || 0), 0)
    };
  }

  return {
    buildBulkPaymentRows,
    validateBulkPaymentSelection,
    filterBulkPaymentEligibleMembers,
    buildMonthlyPaymentAnalytics,
    summarizeAdjustmentsAndAdvances
  };
});
