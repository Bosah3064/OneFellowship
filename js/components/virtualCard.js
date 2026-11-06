// ==============================================================================
// ONEFELLOWSHIP - VIRTUAL MEMBERSHIP CARD COMPONENT
// ==============================================================================

import { CONFIG } from '../config.js';

let selectedTemplateId = 'fellowship_royal';
let cardBalancesVisible = true;

export const VirtualCardComponent = {
  /**
   * Render virtual card into a container element
   */
  render(containerEl, member, payments = []) {
    if (!containerEl) return;

    const currentTemplate = CONFIG.CARD_TEMPLATES.find(t => t.id === selectedTemplateId) || CONFIG.CARD_TEMPLATES[0];

    const paidTotal = payments
      .filter(p => (p.status || '').toLowerCase() === 'paid')
      .reduce((sum, p) => sum + (Number(p.amount) || 0), 0);

    const outstanding = payments
      .filter(p => (p.status || '').toLowerCase() !== 'paid')
      .reduce((sum, p) => sum + (Number(p.amount) || 0), 0);

    const cardNumber = (member.member_number || member.id || '102938475612').toString();
    const cleanNumbers = cardNumber.replace(/[^a-zA-Z0-9]/g, '').slice(-8).padStart(8, '0');
    const formattedCardNumber = `•••• •••• ${cleanNumbers.slice(0, 4)} ${cleanNumbers.slice(4)}`;

    const joinDate = member.join_date ? new Date(member.join_date) : new Date();
    const memberSince = joinDate.toLocaleDateString('en-GB', { month: 'short', year: 'numeric' });

    containerEl.innerHTML = `
      <div class="virtual-card" id="onefellowship-virtual-card" style="background: ${currentTemplate.bg}; color: ${currentTemplate.text};">
        <!-- TOP: Chip, NFC & OneFellowship Brand -->
        <div class="card-top">
          <div style="display:flex; align-items:center; gap:12px;">
            <div class="card-chip"></div>
            <div class="nfc-icon" title="Contactless Member Card">
              <span></span><span></span><span></span>
            </div>
          </div>
          <div style="display:flex; align-items:center; gap:10px;">
            <div style="text-align:right;">
              <div style="font-size:0.65rem; opacity:0.8; letter-spacing:1px; text-transform:uppercase;">Official Membership</div>
              <div style="font-weight:800; font-size:0.95rem; letter-spacing:1.5px; color:#ffffff;">ONEFELLOWSHIP</div>
              <div style="font-size:0.6rem; color:${currentTemplate.accent || '#FFC107'}; font-weight:700;">TOGETHER WE STAND</div>
            </div>
            <img src="assets/logo.png" alt="OneFellowship Emblem" style="width:38px; height:38px; border-radius:8px; background:rgba(255,255,255,0.2); padding:3px; object-fit:contain;" />
          </div>
        </div>

        <!-- CARD NUMBER -->
        <div class="card-number">${formattedCardNumber}</div>

        <!-- CARD HOLDER & DATES -->
        <div style="display:flex; justify-content:space-between; align-items:flex-end;">
          <div style="flex:1;">
            <div class="card-meta">Card Holder</div>
            <div class="card-name">${member.full_name || 'Member'}</div>
          </div>
          <div style="text-align:center; padding: 0 10px;">
            <div class="card-meta">Valid Thru</div>
            <div style="font-weight:700; font-size:0.88rem; letter-spacing:1px;">12/29</div>
          </div>
          <div style="text-align:center;">
            <div class="card-meta">Member Since</div>
            <div style="font-weight:600; font-size:0.82rem;">${memberSince}</div>
          </div>
          <div class="holo-sticker" style="margin-left:14px;" title="OneFellowship Security Hologram"></div>
        </div>

        <!-- BALANCE BAR -->
        <div class="card-balance-box">
          <div>
            <div style="font-size:0.7rem; opacity:0.8; display:flex; align-items:center; gap:6px;">
              Total Paid
              <i class="fa-solid ${cardBalancesVisible ? 'fa-eye' : 'fa-eye-slash'}" id="btn-toggle-balances" style="cursor:pointer;" title="Toggle balance visibility"></i>
            </div>
            <div style="font-weight:800; font-size:1.05rem;">
              KES ${cardBalancesVisible ? paidTotal.toLocaleString() : '••••'}
            </div>
          </div>
          <div style="text-align:right;">
            <div style="font-size:0.7rem; opacity:0.8;">Outstanding</div>
            <div style="font-weight:800; font-size:1.05rem; color: ${outstanding > 0 ? '#ffcdd2' : '#c8e6c9'};">
              KES ${cardBalancesVisible ? outstanding.toLocaleString() : '••••'}
            </div>
          </div>
        </div>
      </div>
    `;

    // Eye toggle event
    const eyeBtn = document.getElementById('btn-toggle-balances');
    if (eyeBtn) {
      eyeBtn.onclick = (e) => {
        e.stopPropagation();
        cardBalancesVisible = !cardBalancesVisible;
        this.render(containerEl, member, payments);
      };
    }
  },

  /**
   * Render theme selectors
   */
  renderThemeControls(containerEl, onThemeChange) {
    if (!containerEl) return;

    containerEl.innerHTML = `
      <div style="margin-top: 14px;">
        <label style="font-size:0.82rem; color:var(--text-secondary); margin-bottom:8px;">Choose Card Theme:</label>
        <div class="card-templates-strip">
          ${CONFIG.CARD_TEMPLATES.map(tpl => `
            <div class="template-thumb ${tpl.id === selectedTemplateId ? 'selected' : ''}" 
                 data-id="${tpl.id}" title="${tpl.name}">
              <div class="template-preview" style="background: ${tpl.bg};"></div>
            </div>
          `).join('')}
        </div>
      </div>
    `;

    containerEl.querySelectorAll('.template-thumb').forEach(thumb => {
      thumb.onclick = () => {
        selectedTemplateId = thumb.dataset.id;
        containerEl.querySelectorAll('.template-thumb').forEach(t => t.classList.remove('selected'));
        thumb.classList.add('selected');
        if (typeof onThemeChange === 'function') {
          onThemeChange(selectedTemplateId);
        }
      };
    });
  },

  /**
   * Download card as PNG
   */
  async exportPng(member) {
    const cardEl = document.getElementById('onefellowship-virtual-card');
    if (!cardEl || !window.html2canvas) return;

    try {
      const canvas = await window.html2canvas(cardEl, { scale: 3, backgroundColor: null });
      const dataUrl = canvas.toDataURL('image/png');
      const a = document.createElement('a');
      a.href = dataUrl;
      const cleanName = (member.full_name || 'OneFellowship_Card').replace(/\s+/g, '_');
      a.download = `${cleanName}_Card.png`;
      a.click();
    } catch (e) {
      console.error('PNG export error:', e);
    }
  },

  /**
   * Download card as PDF
   */
  async exportPdf(member) {
    const cardEl = document.getElementById('onefellowship-virtual-card');
    if (!cardEl || !window.html2canvas) return;

    try {
      const canvas = await window.html2canvas(cardEl, { scale: 3, backgroundColor: null });
      const imgData = canvas.toDataURL('image/png');

      const { jsPDF } = window.jspdf || {};
      if (jsPDF) {
        const doc = new jsPDF({ orientation: 'landscape', unit: 'mm', format: [85.6, 53.98] }); // Standard ID card size
        doc.addImage(imgData, 'PNG', 0, 0, 85.6, 53.98);
        const cleanName = (member.full_name || 'OneFellowship_Card').replace(/\s+/g, '_');
        doc.save(`${cleanName}_Card.pdf`);
      } else {
        // Fallback to PNG download
        this.exportPng(member);
      }
    } catch (e) {
      console.error('PDF export error:', e);
    }
  }
};
