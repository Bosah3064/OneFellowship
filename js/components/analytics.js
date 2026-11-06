// ==============================================================================
// ONEFELLOWSHIP - ANALYTICS CHART COMPONENT
// ==============================================================================

import { CONFIG } from '../config.js';

export const AnalyticsComponent = {
  /**
   * Render monthly payments SVG bar chart
   */
  renderChart(containerEl, payments = []) {
    if (!containerEl) return;

    const helpers = window.bulkPaymentHelpers;
    const monthlyData = helpers && typeof helpers.buildMonthlyPaymentAnalytics === 'function'
      ? helpers.buildMonthlyPaymentAnalytics(payments)
      : [];

    if (monthlyData.length === 0) {
      containerEl.innerHTML = `
        <div style="text-align: center; color: var(--text-secondary); padding: 30px;">
          <i class="fa-solid fa-chart-simple" style="font-size: 2rem; color: #cbd5e1; margin-bottom: 8px;"></i>
          <p style="font-size: 0.9rem;">No monthly contribution records to graph yet.</p>
        </div>
      `;
      return;
    }

    const maxAmount = Math.max(...monthlyData.map(d => d.amount), 500);
    const height = 180;
    const barWidth = 36;
    const gap = 20;
    const chartWidth = Math.max(340, monthlyData.length * (barWidth + gap) + 40);

    const bars = monthlyData.map((d, index) => {
      const barHeight = Math.max(8, (d.amount / maxAmount) * (height - 50));
      const x = 30 + index * (barWidth + gap);
      const y = height - barHeight - 28;

      return `
        <g class="chart-bar-group" tabindex="0">
          <rect x="${x}" y="${y}" width="${barWidth}" height="${barHeight}" rx="6" 
                fill="url(#primaryGradient)" filter="drop-shadow(0 2px 4px rgba(11, 79, 187, 0.2))">
            <title>${d.label}: KES ${d.amount.toLocaleString()} (${d.count} payments)</title>
          </rect>
          <text x="${x + barWidth / 2}" y="${y - 6}" text-anchor="middle" font-size="11" font-weight="700" fill="#0A2D6B">
            ${d.amount > 999 ? (d.amount / 1000).toFixed(1) + 'k' : d.amount}
          </text>
          <text x="${x + barWidth / 2}" y="${height - 10}" text-anchor="middle" font-size="10" font-weight="500" fill="#757575">
            ${d.label.split(' ')[0]}
          </text>
        </g>
      `;
    }).join('');

    containerEl.innerHTML = `
      <div style="overflow-x: auto; width: 100%; padding-bottom: 8px;">
        <svg viewBox="0 0 ${chartWidth} ${height}" style="width: 100%; min-width: ${chartWidth}px; height: ${height}px;">
          <defs>
            <linearGradient id="primaryGradient" x1="0%" y1="0%" x2="0%" y2="100%">
              <stop offset="0%" stop-color="#29B6F6" />
              <stop offset="100%" stop-color="#0B4FBB" />
            </linearGradient>
          </defs>
          <!-- Base line -->
          <line x1="10" y1="${height - 24}" x2="${chartWidth - 10}" y2="${height - 24}" stroke="#e2e8f0" stroke-width="1.5" />
          ${bars}
        </svg>
      </div>
    `;
  },

  /**
   * Render adjustments and advances summary badges
   */
  renderAdjustmentsAndAdvances(containerEl, payments = []) {
    if (!containerEl) return;

    const helpers = window.bulkPaymentHelpers;
    const summary = helpers && typeof helpers.summarizeAdjustmentsAndAdvances === 'function'
      ? helpers.summarizeAdjustmentsAndAdvances(payments)
      : { adjustmentRecords: [], advanceRecords: [] };

    const adjustmentsTotal = summary.adjustmentRecords.reduce((s, p) => s + (Number(p.amount) || 0), 0);
    const advancesTotal = summary.advanceRecords.reduce((s, p) => s + (Number(p.amount) || 0), 0);

    containerEl.innerHTML = `
      <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-top: 14px;">
        <div style="background: #fff7ed; border: 1px solid #ffedd5; border-radius: 10px; padding: 12px; text-align: center;">
          <small style="color: #c2410c; font-weight: 700; text-transform: uppercase; font-size: 0.72rem; letter-spacing: 0.5px;">Pending Adjustments</small>
          <h5 style="color: #9a3412; font-size: 1.15rem; font-weight: 800; margin-top: 2px;">KES ${adjustmentsTotal.toLocaleString()}</h5>
          <span style="font-size: 0.75rem; color: #757575;">${summary.adjustmentRecords.length} record(s)</span>
        </div>
        <div style="background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 10px; padding: 12px; text-align: center;">
          <small style="color: #15803d; font-weight: 700; text-transform: uppercase; font-size: 0.72rem; letter-spacing: 0.5px;">Paid Out Advances</small>
          <h5 style="color: #166534; font-size: 1.15rem; font-weight: 800; margin-top: 2px;">KES ${advancesTotal.toLocaleString()}</h5>
          <span style="font-size: 0.75rem; color: #757575;">${summary.advanceRecords.length} payout(s)</span>
        </div>
      </div>
    `;
  }
};
