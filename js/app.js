// ==============================================================================
// ONEFELLOWSHIP - MAIN APPLICATION CONTROLLER (SPA)
// ==============================================================================

import { CONFIG } from './config.js';
import { AuthService } from './services/auth.js';
import { MemberService, checkProfileCompleteness, CANONICAL_FIELDS, resolveFieldValue } from './services/members.js';
import { PaymentService } from './services/payments.js';
import { NotificationService } from './services/notifications.js';
import { ExportService } from './services/export.js';
import { VirtualCardComponent } from './components/virtualCard.js';
import { AnalyticsComponent } from './components/analytics.js';
import { Toast } from './components/toast.js';

class App {
  constructor() {
    this.session = null;
    this.member = null;
    this.payments = [];
    this.allMembers = [];
    this.allPayments = [];
    this.notifications = [];
    this.formSchema = [];
    this.activeTab = 'dashboard';
    this.scannedImportMembers = [];
  }

  async init() {
    this.setupGlobalEvents();
    this.setupAuthForms();

    try {
      this.session = await AuthService.getSession();
      if (this.session && this.session.user) {
        await this.handleAuthenticated(this.session.user);
      } else {
        this.showAuthView();
      }
    } catch (err) {
      console.error('Session init error:', err);
      this.showAuthView();
    }

    // Listen for Supabase auth changes
    AuthService.onAuthStateChange(async (event, session) => {
      if (event === 'SIGNED_IN' && session) {
        this.session = session;
        await this.handleAuthenticated(session.user);
      } else if (event === 'SIGNED_OUT') {
        this.session = null;
        this.member = null;
        this.showAuthView();
      }
    });

    // Check hash for direct routing
    window.addEventListener('hashchange', () => this.handleHashChange());
  }

  // ============================================================================
  // AUTH VIEWS & TRANSITIONS
  // ============================================================================
  showAuthView(tab = 'login') {
    document.getElementById('view-app-shell').style.display = 'none';
    document.getElementById('view-auth').style.display = 'flex';
    this.switchAuthTab(tab);
  }

  switchAuthTab(tabName) {
    const tabs = ['login', 'register', 'reset'];
    tabs.forEach(t => {
      const container = document.getElementById(`auth-${t}-container`);
      const btn = document.getElementById(`tab-btn-${t}`);
      if (container) container.style.display = t === tabName ? 'block' : 'none';
      if (btn) btn.classList.toggle('active', t === tabName);
    });
  }

  async handleAuthenticated(user) {
    try {
      document.getElementById('view-auth').style.display = 'none';
      document.getElementById('view-app-shell').style.display = 'flex';

      // Load profile
      this.member = await MemberService.getMemberById(user.id);

      // Check if user has the default password "12345678" and prompt to change it
      if (this.member && this.member.needs_password_reset) {
        this.openForcePasswordModal();
      }

      this.updateUserInterface();
      await this.loadMemberData();

      const isAdmin = CONFIG.ADMIN_ROLES.includes(this.member?.role);
      const adminNavGroup = document.getElementById('sidebar-admin-group');
      if (adminNavGroup) {
        adminNavGroup.style.display = isAdmin ? 'block' : 'none';
      }

      // Restore tab from hash or default
      const hash = window.location.hash.replace('#', '');
      if (hash && document.getElementById(`tab-content-${hash}`)) {
        this.navigateTo(hash);
      } else {
        this.navigateTo('dashboard');
      }

      // If admin, preload admin data in background
      if (isAdmin) {
        this.loadAdminData();
      }

    } catch (err) {
      console.error('Error in handleAuthenticated:', err);
      Toast.error('Failed to load profile. Please sign in again.');
      this.showAuthView();
    }
  }

  updateUserInterface() {
    if (!this.member) return;

    const initials = (this.member.full_name || 'OF')
      .split(' ')
      .map(n => n[0])
      .join('')
      .toUpperCase()
      .slice(0, 2);

    // Update avatar and name across UI
    document.querySelectorAll('.user-avatar-text').forEach(el => el.textContent = initials);
    document.querySelectorAll('.user-display-name').forEach(el => el.textContent = this.member.full_name || 'Member');
    document.querySelectorAll('.user-display-email').forEach(el => el.textContent = this.member.email || '');

    const roleBadges = document.querySelectorAll('.user-display-role');
    const roleLabels = {
      admin: '🛡️ Admin',
      treasury: '💰 Treasury',
      chairperson: '👑 Chairperson',
      vice_chairperson: '⭐ Vice Chair',
      member: 'Member'
    };
    roleBadges.forEach(el => {
      el.textContent = roleLabels[this.member.role] || (this.member.role || 'Member').toUpperCase();
    });
  }

  async loadMemberData() {
    if (!this.member) return;

    // Load payments
    this.payments = await PaymentService.getPaymentsByMember(this.member.id);

    // Load notifications
    this.notifications = await NotificationService.getNotifications(this.member.id);
    this.renderNotificationsBadge();

    // Render dashboard components
    this.renderDashboardStats();
    this.renderProfileCompletenessAlert();
    this.renderProfileDetails();
    this.renderPaymentsTable();
    this.renderVirtualCard();
    this.renderAnalytics();
  }

  async loadAdminData() {
    try {
      this.allMembers = await MemberService.getAllMembers();
      this.allPayments = await PaymentService.getAllPayments();
      this.formSchema = await MemberService.getFormSchema();

      this.renderAdminOverview();
      this.renderAdminMembersTable();
      this.renderAdminPaymentsTable();
      this.populateBulkPaymentMembersList();
      this.populateMemberSelectDropdowns();
    } catch (err) {
      console.error('Error loading admin data:', err);
    }
  }

  // ============================================================================
  // NAVIGATION & TABS
  // ============================================================================
  navigateTo(tabId) {
    this.activeTab = tabId;
    window.location.hash = tabId;

    document.querySelectorAll('.view-section').forEach(el => el.classList.remove('active'));
    document.querySelectorAll('.nav-item').forEach(el => el.classList.remove('active'));

    const targetSection = document.getElementById(`tab-content-${tabId}`);
    const targetNavItem = document.querySelector(`[data-tab="${tabId}"]`);

    if (targetSection) targetSection.classList.add('active');
    if (targetNavItem) targetNavItem.classList.add('active');

    // Close mobile sidebar if open
    document.getElementById('app-sidebar').classList.remove('open');
  }

  handleHashChange() {
    const hash = window.location.hash.replace('#', '');
    if (hash && document.getElementById(`tab-content-${hash}`)) {
      this.navigateTo(hash);
    } else if (hash === 'register') {
      this.showAuthView('register');
    } else if (hash === 'login') {
      this.showAuthView('login');
    }
  }

  // ============================================================================
  // MEMBER DASHBOARD RENDERING
  // ============================================================================
  renderDashboardStats() {
    const stats = PaymentService.calculateMemberStats(this.payments);

    const elTotalSavings = document.getElementById('stat-total-savings');
    const elPaidOut = document.getElementById('stat-paid-out');
    const elRegStatus = document.getElementById('stat-reg-status');
    const elPending = document.getElementById('stat-pending-records');

    if (elTotalSavings) elTotalSavings.textContent = `KES ${stats.totalSavings.toLocaleString()}`;
    if (elPaidOut) elPaidOut.textContent = `KES ${stats.paidOutSavings.toLocaleString()}`;
    
    if (elRegStatus) {
      if (stats.isRegistered) {
        elRegStatus.innerHTML = '<span class="status-badge badge-active"><i class="fa-solid fa-circle-check"></i> Paid</span>';
      } else {
        elRegStatus.innerHTML = '<span class="status-badge badge-overdue"><i class="fa-solid fa-circle-xmark"></i> Unpaid</span>';
      }
    }

    if (elPending) elPending.textContent = stats.pendingCount;
  }

  renderProfileCompletenessAlert() {
    const alertBox = document.getElementById('profile-incomplete-alert');
    const missingList = document.getElementById('missing-fields-list');
    if (!alertBox || !missingList || !this.member) return;

    const missing = checkProfileCompleteness(this.member);
    if (missing.length > 0) {
      missingList.innerHTML = missing.map(m => `<li><strong>${m}</strong></li>`).join('');
      alertBox.style.display = 'flex';
    } else {
      alertBox.style.display = 'none';
    }
  }

  renderProfileDetails() {
    const container = document.getElementById('profile-fields-grid');
    if (!container || !this.member) return;

    const fd = this.member.form_details || {};
    const joinDate = this.member.join_date ? new Date(this.member.join_date).toLocaleDateString('en-GB') : '—';

    let html = `
      <div class="profile-field-tile">
        <i class="fa-solid fa-phone"></i>
        <div>
          <small>Phone Number</small>
          <p>${this.member.phone || 'Not provided'}</p>
        </div>
      </div>
      <div class="profile-field-tile">
        <i class="fa-solid fa-calendar"></i>
        <div>
          <small>Member Since</small>
          <p>${joinDate}</p>
        </div>
      </div>
    `;

    CANONICAL_FIELDS.forEach(f => {
      if (f.isMemberField) return;
      const val = resolveFieldValue(fd, f.key);
      if (val) {
        html += `
          <div class="profile-field-tile">
            <i class="fa-solid ${f.icon || 'fa-tag'}"></i>
            <div>
              <small>${f.label}</small>
              <p>${val}</p>
            </div>
          </div>
        `;
      }
    });

    container.innerHTML = html;
  }

  renderPaymentsTable() {
    const tbody = document.getElementById('member-payments-tbody');
    if (!tbody) return;

    if (this.payments.length === 0) {
      tbody.innerHTML = `
        <tr>
          <td colspan="5" class="empty-state">
            <i class="fa-solid fa-receipt"></i>
            <p>No payment records found yet.</p>
            <small>Your monthly contributions and receipts will appear here once recorded by the Treasury.</small>
          </td>
        </tr>
      `;
      return;
    }

    tbody.innerHTML = this.payments.map(p => {
      const status = (p.status || 'pending').toLowerCase();
      const statusBadge = status === 'paid' ? '<span class="status-badge badge-active"><i class="fa-solid fa-circle-check"></i> Paid</span>'
                        : status === 'pending' ? '<span class="status-badge badge-pending"><i class="fa-solid fa-clock"></i> Pending</span>'
                        : '<span class="status-badge badge-overdue"><i class="fa-solid fa-triangle-exclamation"></i> Overdue</span>';

      const typeLabel = p.payment_type === 'registration' ? 'Registration Fee'
                      : p.payout_status === 'paid_out' ? 'Paid Out Savings'
                      : 'Monthly Saving';

      const dateStr = p.payment_date ? new Date(p.payment_date).toLocaleDateString('en-GB') : '—';

      return `
        <tr>
          <td><strong>${p.month || '—'}</strong></td>
          <td>
            <div style="font-weight: 700;">KES ${(Number(p.amount) || 0).toLocaleString()}</div>
            <small style="color: var(--text-secondary); font-size: 0.75rem;">${typeLabel}</small>
          </td>
          <td>${dateStr}</td>
          <td>${statusBadge}</td>
          <td><code style="background: #edf2f7; padding: 2px 6px; border-radius: 4px; font-size: 0.85rem;">${p.reference || '—'}</code></td>
        </tr>
      `;
    }).join('');
  }

  renderVirtualCard() {
    const cardContainer = document.getElementById('virtual-card-container');
    const themeContainer = document.getElementById('virtual-card-theme-selector');
    if (!cardContainer || !this.member) return;

    VirtualCardComponent.render(cardContainer, this.member, this.payments);

    if (themeContainer) {
      VirtualCardComponent.renderThemeControls(themeContainer, () => {
        VirtualCardComponent.render(cardContainer, this.member, this.payments);
      });
    }

    const pngBtn = document.getElementById('btn-download-card-png');
    if (pngBtn) {
      pngBtn.onclick = () => VirtualCardComponent.exportPng(this.member);
    }

    const pdfBtn = document.getElementById('btn-download-card-pdf');
    if (pdfBtn) {
      pdfBtn.onclick = () => VirtualCardComponent.exportPdf(this.member);
    }
  }

  renderAnalytics() {
    const chartEl = document.getElementById('member-analytics-chart');
    const summaryEl = document.getElementById('member-analytics-summary');
    if (chartEl) AnalyticsComponent.renderChart(chartEl, this.payments);
    if (summaryEl) AnalyticsComponent.renderAdjustmentsAndAdvances(summaryEl, this.payments);
  }

  renderNotificationsBadge() {
    const badge = document.getElementById('header-notif-badge');
    const countEl = document.getElementById('notif-count');
    if (!badge) return;

    const count = this.notifications.length;
    if (count > 0) {
      badge.style.display = 'block';
      if (countEl) countEl.textContent = count;
    } else {
      badge.style.display = 'none';
      if (countEl) countEl.textContent = '0';
    }

    // Render list in modal/drawer
    const listEl = document.getElementById('notifications-list-container');
    if (listEl) {
      if (count === 0) {
        listEl.innerHTML = `
          <div class="empty-state" style="padding: 30px;">
            <i class="fa-solid fa-bell-slash"></i>
            <p>No notifications</p>
            <small>You're all caught up!</small>
          </div>
        `;
      } else {
        listEl.innerHTML = this.notifications.map(n => `
          <div style="padding: 14px; border-bottom: 1px solid var(--border-color); display: flex; gap: 12px; align-items: flex-start;">
            <i class="fa-solid fa-circle-info" style="color: var(--primary); margin-top: 3px;"></i>
            <div style="flex: 1;">
              <div style="display: flex; justify-content: space-between; align-items: baseline;">
                <h5 style="font-weight: 700; font-size: 0.92rem; color: var(--text-primary);">${n.title || 'Announcement'}</h5>
                <small style="color: var(--text-secondary); font-size: 0.72rem;">${new Date(n.created_at).toLocaleDateString()}</small>
              </div>
              <p style="font-size: 0.85rem; color: var(--text-primary); margin-top: 4px; line-height: 1.4;">${n.message}</p>
            </div>
          </div>
        `).join('');
      }
    }
  }

  // ============================================================================
  // ADMIN DASHBOARD RENDERING
  // ============================================================================
  renderAdminOverview() {
    const stats = PaymentService.calculateAdminStats(this.allPayments, this.allMembers);

    const elTotalMembers = document.getElementById('admin-stat-total-members');
    const elActiveMembers = document.getElementById('admin-stat-active-members');
    const elTotalCollected = document.getElementById('admin-stat-total-collected');
    const elTotalPending = document.getElementById('admin-stat-total-pending');

    if (elTotalMembers) elTotalMembers.textContent = stats.totalMembers;
    if (elActiveMembers) elActiveMembers.textContent = stats.activeMembers;
    if (elTotalCollected) elTotalCollected.textContent = `KES ${stats.totalCollected.toLocaleString()}`;
    if (elTotalPending) elTotalPending.textContent = `KES ${stats.totalPendingAmount.toLocaleString()}`;

    // Admin analytics chart
    const adminChartEl = document.getElementById('admin-analytics-chart');
    if (adminChartEl) {
      AnalyticsComponent.renderChart(adminChartEl, this.allPayments);
    }
  }

  renderAdminMembersTable() {
    const tbody = document.getElementById('admin-members-tbody');
    if (!tbody) return;

    const searchTerm = (document.getElementById('admin-member-search')?.value || '').toLowerCase().trim();
    const roleFilter = document.getElementById('admin-member-role-filter')?.value || 'all';
    const statusFilter = document.getElementById('admin-member-status-filter')?.value || 'all';

    const filtered = this.allMembers.filter(m => {
      const matchSearch = !searchTerm ||
        (m.full_name && m.full_name.toLowerCase().includes(searchTerm)) ||
        (m.email && m.email.toLowerCase().includes(searchTerm)) ||
        (m.phone && m.phone.toLowerCase().includes(searchTerm));

      const matchRole = roleFilter === 'all' || m.role === roleFilter;
      const matchStatus = statusFilter === 'all' || m.status === statusFilter;

      return matchSearch && matchRole && matchStatus;
    });

    if (filtered.length === 0) {
      tbody.innerHTML = `<tr><td colspan="7" class="empty-state"><p>No members match your criteria.</p></td></tr>`;
      return;
    }

    tbody.innerHTML = filtered.map(m => {
      const fd = m.form_details || {};
      const idNumber = resolveFieldValue(fd, 'national_id_number') || '—';
      const branch = resolveFieldValue(fd, 'branch') || '—';
      const statusBadge = m.status === 'active' || m.status === 'approved'
        ? '<span class="status-badge badge-active">Active</span>'
        : `<span class="status-badge badge-pending">${m.status || 'Inactive'}</span>`;

      return `
        <tr>
          <td>
            <strong>${m.full_name || '—'}</strong>
            <div style="font-size: 0.75rem; color: var(--text-secondary);">${m.email || '—'}</div>
          </td>
          <td>${m.phone || '—'}</td>
          <td>${idNumber}</td>
          <td>${branch}</td>
          <td><span class="status-badge badge-role">${(m.role || 'member').toUpperCase()}</span></td>
          <td>${statusBadge}</td>
          <td>
            <div style="display:flex; gap:6px;">
              <button class="btn btn-secondary btn-sm" onclick="app.openEditMemberModal('${m.id}')" title="Edit Member">
                <i class="fa-solid fa-pen-to-square"></i>
              </button>
              <button class="btn btn-secondary btn-sm" onclick="app.openResetMemberPasswordModal('${m.id}')" title="Force Password Reset">
                <i class="fa-solid fa-key"></i>
              </button>
            </div>
          </td>
        </tr>
      `;
    }).join('');
  }

  renderAdminPaymentsTable() {
    const tbody = document.getElementById('admin-payments-tbody');
    if (!tbody) return;

    const searchTerm = (document.getElementById('admin-payment-search')?.value || '').toLowerCase().trim();
    const memberFilter = document.getElementById('admin-payment-member-filter')?.value || 'all';

    const filtered = this.allPayments.filter(p => {
      const matchMember = memberFilter === 'all' || p.member_id === memberFilter;
      const matchSearch = !searchTerm ||
        (p.member_name && p.member_name.toLowerCase().includes(searchTerm)) ||
        (p.reference && p.reference.toLowerCase().includes(searchTerm)) ||
        (p.month && p.month.toLowerCase().includes(searchTerm));

      return matchMember && matchSearch;
    });

    if (filtered.length === 0) {
      tbody.innerHTML = `<tr><td colspan="7" class="empty-state"><p>No payment records found.</p></td></tr>`;
      return;
    }

    tbody.innerHTML = filtered.map(p => {
      const statusBadge = p.status === 'paid' ? '<span class="status-badge badge-active">Paid</span>'
                        : p.status === 'pending' ? '<span class="status-badge badge-pending">Pending</span>'
                        : '<span class="status-badge badge-overdue">Overdue</span>';

      return `
        <tr>
          <td><strong>${p.member_name || 'Member'}</strong></td>
          <td><strong>KES ${(Number(p.amount) || 0).toLocaleString()}</strong></td>
          <td>${p.month || '—'}</td>
          <td>${p.payment_date ? new Date(p.payment_date).toLocaleDateString('en-GB') : '—'}</td>
          <td>${statusBadge}</td>
          <td><code>${p.reference || '—'}</code></td>
          <td>
            <div style="display:flex; gap:6px;">
              <button class="btn btn-secondary btn-sm" onclick="app.openEditPaymentModal('${p.id}')" title="Edit Payment">
                <i class="fa-solid fa-pen-to-square"></i>
              </button>
              <button class="btn btn-danger btn-sm" onclick="app.deletePaymentRecord('${p.id}')" title="Delete Payment">
                <i class="fa-solid fa-trash"></i>
              </button>
            </div>
          </td>
        </tr>
      `;
    }).join('');
  }

  populateBulkPaymentMembersList() {
    const container = document.getElementById('bulk-payment-members-list');
    if (!container) return;

    // Filter members eligible for bulk payment (regular members)
    const helpers = window.bulkPaymentHelpers;
    const eligible = helpers && typeof helpers.filterBulkPaymentEligibleMembers === 'function'
      ? helpers.filterBulkPaymentEligibleMembers(this.allMembers)
      : this.allMembers;

    container.innerHTML = eligible.map(m => `
      <label style="display:flex; align-items:center; gap:10px; padding:8px 10px; border-radius:6px; cursor:pointer; background:#ffffff; margin-bottom:4px; border:1px solid #f1f5f9;">
        <input type="checkbox" class="bulk-member-checkbox" value="${m.id}" />
        <div style="flex:1;">
          <div style="font-weight:600; font-size:0.88rem;">${m.full_name}</div>
          <small style="color:var(--text-secondary);">${m.email}</small>
        </div>
      </label>
    `).join('');
  }

  populateMemberSelectDropdowns() {
    const selects = [
      document.getElementById('notif-target-member'),
      document.getElementById('admin-payment-member-filter'),
      document.getElementById('modal-reset-target-member')
    ];

    selects.forEach(select => {
      if (!select) return;
      const isFilter = select.id.includes('filter');
      const defaultOption = isFilter ? '<option value="all">All Members</option>' : '<option value="">— Select a member —</option>';
      select.innerHTML = defaultOption + this.allMembers.map(m => `
        <option value="${m.id}">${m.full_name} (${m.email})</option>
      `).join('');
    });
  }

  // ============================================================================
  // GLOBAL EVENTS & FORMS
  // ============================================================================
  setupGlobalEvents() {
    // Mobile sidebar toggle
    const toggleBtn = document.getElementById('mobile-sidebar-toggle');
    const sidebar = document.getElementById('app-sidebar');
    if (toggleBtn && sidebar) {
      toggleBtn.onclick = () => sidebar.classList.toggle('open');
    }

    // Sidebar navigation clicks
    document.querySelectorAll('[data-tab]').forEach(btn => {
      btn.onclick = () => this.navigateTo(btn.dataset.tab);
    });

    // Logout button
    document.querySelectorAll('.btn-logout-action').forEach(btn => {
      btn.onclick = async () => {
        try {
          await AuthService.signOut();
          Toast.info('Signed out successfully.');
        } catch (e) {
          console.error(e);
        }
      };
    });

    // Notifications modal open
    const notifBtn = document.getElementById('btn-header-notifications');
    if (notifBtn) {
      notifBtn.onclick = () => this.openModal('modal-notifications');
    }

    // Modal close buttons
    document.querySelectorAll('[data-modal-close]').forEach(btn => {
      btn.onclick = () => {
        const modal = btn.closest('.modal-overlay');
        if (modal) modal.classList.remove('active');
      };
    });

    // Password Eye Toggles
    document.querySelectorAll('.password-toggle-btn').forEach(btn => {
      btn.onclick = () => {
        const input = btn.parentElement.querySelector('input');
        if (!input) return;
        const isPass = input.type === 'password';
        input.type = isPass ? 'text' : 'password';
        btn.querySelector('i').className = isPass ? 'fa-solid fa-eye-slash' : 'fa-solid fa-eye';
      };
    });

    // Admin member search filter
    const searchMembers = document.getElementById('admin-member-search');
    if (searchMembers) {
      searchMembers.oninput = () => this.renderAdminMembersTable();
    }
    const roleFilter = document.getElementById('admin-member-role-filter');
    if (roleFilter) {
      roleFilter.onchange = () => this.renderAdminMembersTable();
    }
    const statusFilter = document.getElementById('admin-member-status-filter');
    if (statusFilter) {
      statusFilter.onchange = () => this.renderAdminMembersTable();
    }

    // Admin payments search filter
    const searchPayments = document.getElementById('admin-payment-search');
    if (searchPayments) {
      searchPayments.oninput = () => this.renderAdminPaymentsTable();
    }
    const paymentMemberFilter = document.getElementById('admin-payment-member-filter');
    if (paymentMemberFilter) {
      paymentMemberFilter.onchange = () => this.renderAdminPaymentsTable();
    }

    // Bulk payment "Select All" toggle
    const selectAllBtn = document.getElementById('btn-bulk-select-all');
    if (selectAllBtn) {
      selectAllBtn.onclick = () => {
        const checkboxes = document.querySelectorAll('.bulk-member-checkbox');
        const allChecked = Array.from(checkboxes).every(cb => cb.checked);
        checkboxes.forEach(cb => cb.checked = !allChecked);
        selectAllBtn.innerHTML = allChecked ? '<i class="fa-solid fa-check-double"></i> Select All' : '<i class="fa-solid fa-xmark"></i> Deselect All';
      };
    }

    // Bulk payment search filter
    const bulkSearch = document.getElementById('bulk-member-search-input');
    if (bulkSearch) {
      bulkSearch.oninput = (e) => {
        const query = e.target.value.toLowerCase().trim();
        document.querySelectorAll('#bulk-payment-members-list label').forEach(lbl => {
          lbl.style.display = lbl.textContent.toLowerCase().includes(query) ? 'flex' : 'none';
        });
      };
    }

    // Export Buttons
    const btnExpXlsx = document.getElementById('btn-export-excel');
    if (btnExpXlsx) btnExpXlsx.onclick = () => ExportService.exportToExcel(this.allMembers, this.formSchema);

    const btnExpPdf = document.getElementById('btn-export-pdf');
    if (btnExpPdf) btnExpPdf.onclick = () => ExportService.exportToPdf(this.allMembers, this.formSchema);

    const btnExpDocx = document.getElementById('btn-export-word');
    if (btnExpDocx) btnExpDocx.onclick = () => ExportService.exportToWord(this.allMembers, this.formSchema);

    // Google Forms bulk import scanner
    this.setupGoogleFormsImporter();
  }

  setupAuthForms() {
    // LOGIN FORM
    const formLogin = document.getElementById('form-login');
    if (formLogin) {
      formLogin.onsubmit = async (e) => {
        e.preventDefault();
        const email = document.getElementById('login-email').value;
        const password = document.getElementById('login-password').value;
        const btn = formLogin.querySelector('button[type="submit"]');

        btn.disabled = true;
        btn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Signing in...';

        try {
          await AuthService.signIn(email, password);
          Toast.success('Welcome back to OneFellowship!');
        } catch (err) {
          Toast.error(err.message || 'Login failed.');
        } finally {
          btn.disabled = false;
          btn.innerHTML = '<i class="fa-solid fa-right-to-bracket"></i> Sign In';
        }
      };
    }

    // REGISTRATION FORM
    const formRegister = document.getElementById('form-register');
    if (formRegister) {
      formRegister.onsubmit = async (e) => {
        e.preventDefault();
        const fullName = document.getElementById('reg-fullname').value;
        const email = document.getElementById('reg-email').value;
        const phone = document.getElementById('reg-phone').value;
        const password = document.getElementById('reg-password').value;

        const formDetails = {
          date_of_birth: document.getElementById('reg-dob')?.value || '',
          gender: document.getElementById('reg-gender')?.value || '',
          marital_status: document.getElementById('reg-marital')?.value || '',
          national_id_number: document.getElementById('reg-id-number')?.value || '',
          branch: document.getElementById('reg-branch')?.value || '',
          occupation: document.getElementById('reg-occupation')?.value || '',
          next_of_kin_full_name: document.getElementById('reg-nok-name')?.value || '',
          next_of_kin_phone_number: document.getElementById('reg-nok-phone')?.value || '',
          relationship_to_you: document.getElementById('reg-nok-relation')?.value || ''
        };

        const btn = formRegister.querySelector('button[type="submit"]');
        btn.disabled = true;
        btn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Registering...';

        try {
          await AuthService.signUp({
            email,
            password,
            fullName,
            phone,
            formDetails
          });
          Toast.success('Account created! Welcome to OneFellowship.');
        } catch (err) {
          Toast.error(err.message || 'Registration failed.');
        } finally {
          btn.disabled = false;
          btn.innerHTML = '<i class="fa-solid fa-user-plus"></i> Complete Registration';
        }
      };
    }

    // RESET PASSWORD REQUEST FORM
    const formResetReq = document.getElementById('form-forgot-password');
    if (formResetReq) {
      formResetReq.onsubmit = async (e) => {
        e.preventDefault();
        const email = document.getElementById('reset-req-email').value;
        try {
          await AuthService.requestPasswordReset(email);
          Toast.success('Password reset link sent to your email.');
          this.switchAuthTab('login');
        } catch (err) {
          Toast.error(err.message || 'Request failed.');
        }
      };
    }

    // FORCE CHANGE PASSWORD FORM
    const formForcePass = document.getElementById('form-force-password');
    if (formForcePass) {
      formForcePass.onsubmit = async (e) => {
        e.preventDefault();
        const newPass = document.getElementById('force-new-password').value;
        const confirmPass = document.getElementById('force-confirm-password').value;

        if (newPass !== confirmPass) {
          Toast.error('Passwords do not match.');
          return;
        }

        try {
          await AuthService.updatePassword(newPass);
          if (this.member) {
            await MemberService.updateMember(this.member.id, { needs_password_reset: false });
            this.member.needs_password_reset = false;
          }
          Toast.success('Password successfully secured.');
          this.closeModal('modal-force-password');
        } catch (err) {
          Toast.error(err.message || 'Password update failed.');
        }
      };
    }

    // EDIT PROFILE FORM
    const formEditProfile = document.getElementById('form-edit-profile');
    if (formEditProfile) {
      formEditProfile.onsubmit = async (e) => {
        e.preventDefault();
        if (!this.member) return;

        const phone = document.getElementById('edit-prof-phone').value;
        const updatedFormDetails = { ...(this.member.form_details || {}) };

        CANONICAL_FIELDS.forEach(f => {
          if (f.isMemberField) return;
          const input = document.getElementById(`edit-prof-${f.key}`);
          if (input) updatedFormDetails[f.key] = input.value.trim();
        });

        try {
          const updated = await MemberService.updateMember(this.member.id, {
            phone,
            form_details: updatedFormDetails
          });
          this.member = updated;
          Toast.success('Profile details updated!');
          this.renderProfileDetails();
          this.renderProfileCompletenessAlert();
          this.closeModal('modal-edit-profile');
        } catch (err) {
          Toast.error(err.message || 'Failed to update profile.');
        }
      };
    }

    // ADD PAYMENT FORM (ADMIN)
    const formAddPayment = document.getElementById('form-add-payment');
    if (formAddPayment) {
      formAddPayment.onsubmit = async (e) => {
        e.preventDefault();

        const checkboxes = document.querySelectorAll('.bulk-member-checkbox:checked');
        const selectedIds = Array.from(checkboxes).map(cb => cb.value);

        if (selectedIds.length === 0) {
          Toast.error('Please select at least one member.');
          return;
        }

        const payload = {
          selectedIds,
          amount: document.getElementById('pay-amount').value,
          month: document.getElementById('pay-month').value,
          paymentDate: document.getElementById('pay-date').value,
          paymentType: document.getElementById('pay-type').value,
          payoutStatus: document.getElementById('pay-payout-status').value,
          status: document.getElementById('pay-status').value,
          reference: document.getElementById('pay-reference').value,
          addedBy: this.member ? this.member.role : 'treasury'
        };

        const btn = formAddPayment.querySelector('button[type="submit"]');
        btn.disabled = true;
        btn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Saving...';

        try {
          await PaymentService.addBulkPayments(this.allMembers, payload);
          Toast.success(`Successfully recorded payments for ${selectedIds.length} member(s).`);
          formAddPayment.reset();
          await this.loadAdminData();
        } catch (err) {
          Toast.error(err.message || 'Payment recording failed.');
        } finally {
          btn.disabled = false;
          btn.innerHTML = '<i class="fa-solid fa-save"></i> Save Payment Records';
        }
      };
    }

    // BROADCAST NOTIFICATION FORM (ADMIN)
    const formNotif = document.getElementById('form-send-notification');
    if (formNotif) {
      formNotif.onsubmit = async (e) => {
        e.preventDefault();
        const recipient = document.getElementById('notif-target-member').value || 'all';
        const title = document.getElementById('notif-input-title').value;
        const type = document.getElementById('notif-input-type').value;
        const message = document.getElementById('notif-input-message').value;

        try {
          await NotificationService.sendNotification({
            recipient,
            title,
            type,
            message,
            createdBy: this.member ? this.member.full_name : 'Admin'
          });
          Toast.success('Notification broadcasted successfully!');
          formNotif.reset();
        } catch (err) {
          Toast.error(err.message || 'Failed to send notification.');
        }
      };
    }

    // CREATE MEMBER FORM (ADMIN)
    const formCreateMember = document.getElementById('form-create-member');
    if (formCreateMember) {
      formCreateMember.onsubmit = async (e) => {
        e.preventDefault();
        const fullName = document.getElementById('admin-new-name').value;
        const email = document.getElementById('admin-new-email').value;
        const phone = document.getElementById('admin-new-phone').value;
        const role = document.getElementById('admin-new-role').value;
        const idNumber = document.getElementById('admin-new-id').value;
        const branch = document.getElementById('admin-new-branch').value;

        try {
          await MemberService.createMember({
            fullName,
            email,
            phone,
            role,
            idNumber,
            branch
          });
          Toast.success(`Created member account for ${fullName}!`);
          formCreateMember.reset();
          this.closeModal('modal-add-member');
          await this.loadAdminData();
        } catch (err) {
          Toast.error(err.message || 'Failed to create member.');
        }
      };
    }

    // EDIT MEMBER FORM (ADMIN)
    const formAdminEditMember = document.getElementById('form-admin-edit-member');
    if (formAdminEditMember) {
      formAdminEditMember.onsubmit = async (e) => {
        e.preventDefault();
        const memberId = document.getElementById('admin-edit-member-id').value;
        if (!memberId) return;

        const target = this.allMembers.find(m => m.id === memberId);
        const formDetails = { ...(target?.form_details || {}) };

        formDetails.national_id_number = document.getElementById('admin-edit-id-number').value;
        formDetails.date_of_birth = document.getElementById('admin-edit-dob').value;
        formDetails.gender = document.getElementById('admin-edit-gender').value;
        formDetails.marital_status = document.getElementById('admin-edit-marital').value;
        formDetails.branch = document.getElementById('admin-edit-branch').value;
        formDetails.next_of_kin_full_name = document.getElementById('admin-edit-nok-name').value;
        formDetails.next_of_kin_phone_number = document.getElementById('admin-edit-nok-phone').value;

        const updates = {
          full_name: document.getElementById('admin-edit-fullname').value,
          email: document.getElementById('admin-edit-email').value,
          phone: document.getElementById('admin-edit-phone').value,
          role: document.getElementById('admin-edit-role').value,
          status: document.getElementById('admin-edit-status').value,
          form_details: formDetails
        };

        try {
          await MemberService.updateMember(memberId, updates);
          Toast.success('Member record updated!');
          this.closeModal('modal-admin-edit-member');
          await this.loadAdminData();
        } catch (err) {
          Toast.error(err.message || 'Failed to update member.');
        }
      };
    }

    // EDIT PAYMENT FORM (ADMIN)
    const formAdminEditPayment = document.getElementById('form-admin-edit-payment');
    if (formAdminEditPayment) {
      formAdminEditPayment.onsubmit = async (e) => {
        e.preventDefault();
        const paymentId = document.getElementById('admin-edit-payment-id').value;
        if (!paymentId) return;

        const updates = {
          amount: Number(document.getElementById('admin-edit-pay-amount').value),
          month: document.getElementById('admin-edit-pay-month').value,
          payment_date: document.getElementById('admin-edit-pay-date').value,
          status: document.getElementById('admin-edit-pay-status').value,
          payment_type: document.getElementById('admin-edit-pay-type').value,
          payout_status: document.getElementById('admin-edit-pay-payout-status').value,
          reference: document.getElementById('admin-edit-pay-reference').value
        };

        try {
          await PaymentService.updatePayment(paymentId, updates);
          Toast.success('Payment updated!');
          this.closeModal('modal-admin-edit-payment');
          await this.loadAdminData();
        } catch (err) {
          Toast.error(err.message || 'Failed to update payment.');
        }
      };
    }
  }

  setupGoogleFormsImporter() {
    const fileInput = document.getElementById('import-excel-file');
    const btnScan = document.getElementById('btn-scan-import-file');
    const previewContainer = document.getElementById('import-preview-container');
    const tbody = document.getElementById('import-preview-tbody');
    const btnExecute = document.getElementById('btn-execute-import');

    if (!btnScan || !fileInput) return;

    btnScan.onclick = () => {
      if (!fileInput.files || fileInput.files.length === 0) {
        Toast.error('Please select an Excel (.xlsx) or CSV file first.');
        return;
      }

      const file = fileInput.files[0];
      const reader = new FileReader();

      reader.onload = (e) => {
        try {
          if (!window.XLSX) throw new Error('XLSX library not loaded.');
          const data = new Uint8Array(e.target.result);
          const workbook = window.XLSX.read(data, { type: 'array' });
          const firstSheet = workbook.Sheets[workbook.SheetNames[0]];
          const json = window.XLSX.utils.sheet_to_json(firstSheet, { defval: '' });

          if (json.length === 0) {
            Toast.warning('The uploaded sheet contains no rows.');
            return;
          }

          // Scan rows and identify new members by email
          const existingEmails = new Set(this.allMembers.map(m => (m.email || '').toLowerCase().trim()));
          this.scannedImportMembers = [];

          json.forEach(row => {
            const findKey = (search) => {
              for (const [k, v] of Object.entries(row)) {
                if (k.toLowerCase().includes(search)) return v;
              }
              return '';
            };

            const fullName = findKey('name') || findKey('full name') || 'Member';
            const email = (findKey('email') || '').trim();
            const phone = (findKey('phone') || findKey('mobile') || findKey('contact') || '').trim();

            if (!email || existingEmails.has(email.toLowerCase())) {
              return; // skip existing or rows without email
            }

            // Put remaining columns into form_details
            const formDetails = {};
            Object.entries(row).forEach(([col, val]) => {
              const lower = col.toLowerCase();
              if (!lower.includes('email') && !lower.includes('name') && !lower.includes('phone') && !lower.includes('timestamp')) {
                formDetails[col] = val;
              }
            });

            this.scannedImportMembers.push({
              full_name: fullName,
              email,
              phone,
              form_details: formDetails
            });
          });

          if (this.scannedImportMembers.length === 0) {
            Toast.info('All members in this file already exist in the database.');
            previewContainer.style.display = 'none';
            return;
          }

          // Populate preview table
          tbody.innerHTML = this.scannedImportMembers.slice(0, 50).map(m => `
            <tr>
              <td><strong>${m.full_name}</strong></td>
              <td>${m.email}</td>
              <td>${m.phone || '—'}</td>
            </tr>
          `).join('');

          document.getElementById('import-new-count').textContent = this.scannedImportMembers.length;
          previewContainer.style.display = 'block';
          Toast.success(`Found ${this.scannedImportMembers.length} new member(s) to import!`);

        } catch (err) {
          Toast.error('File parsing error: ' + err.message);
        }
      };

      reader.readAsArrayBuffer(file);
    };

    if (btnExecute) {
      btnExecute.onclick = async () => {
        if (this.scannedImportMembers.length === 0) return;

        btnExecute.disabled = true;
        btnExecute.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Importing...';

        let imported = 0;
        for (const m of this.scannedImportMembers) {
          try {
            await MemberService.createMember({
              fullName: m.full_name,
              email: m.email,
              phone: m.phone,
              role: 'member'
            });
            imported++;
          } catch (e) {
            console.warn('Import item failed:', m.email, e);
          }
        }

        Toast.success(`Successfully imported ${imported} member(s)!`);
        btnExecute.disabled = false;
        btnExecute.innerHTML = '<i class="fa-solid fa-cloud-arrow-up"></i> Import All';
        previewContainer.style.display = 'none';
        fileInput.value = '';
        this.scannedImportMembers = [];
        await this.loadAdminData();
      };
    }
  }

  // ============================================================================
  // MODAL HELPERS
  // ============================================================================
  openModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) modal.classList.add('active');
  }

  closeModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) modal.classList.remove('active');
  }

  openForcePasswordModal() {
    this.openModal('modal-force-password');
  }

  openEditProfileModal() {
    if (!this.member) return;
    const phoneInput = document.getElementById('edit-prof-phone');
    if (phoneInput) phoneInput.value = this.member.phone || '';

    const fd = this.member.form_details || {};
    CANONICAL_FIELDS.forEach(f => {
      if (f.isMemberField) return;
      const input = document.getElementById(`edit-prof-${f.key}`);
      if (input) input.value = resolveFieldValue(fd, f.key) || '';
    });

    this.openModal('modal-edit-profile');
  }

  openEditMemberModal(memberId) {
    const member = this.allMembers.find(m => m.id === memberId);
    if (!member) return;

    document.getElementById('admin-edit-member-id').value = member.id;
    document.getElementById('admin-edit-fullname').value = member.full_name || '';
    document.getElementById('admin-edit-email').value = member.email || '';
    document.getElementById('admin-edit-phone').value = member.phone || '';
    document.getElementById('admin-edit-role').value = member.role || 'member';
    document.getElementById('admin-edit-status').value = member.status || 'active';

    const fd = member.form_details || {};
    document.getElementById('admin-edit-id-number').value = resolveFieldValue(fd, 'national_id_number') || '';
    document.getElementById('admin-edit-dob').value = resolveFieldValue(fd, 'date_of_birth') || '';
    document.getElementById('admin-edit-gender').value = resolveFieldValue(fd, 'gender') || '';
    document.getElementById('admin-edit-marital').value = resolveFieldValue(fd, 'marital_status') || '';
    document.getElementById('admin-edit-branch').value = resolveFieldValue(fd, 'branch') || '';
    document.getElementById('admin-edit-nok-name').value = resolveFieldValue(fd, 'next_of_kin_full_name') || '';
    document.getElementById('admin-edit-nok-phone').value = resolveFieldValue(fd, 'next_of_kin_phone_number') || '';

    this.openModal('modal-admin-edit-member');
  }

  openResetMemberPasswordModal(memberId) {
    const member = this.allMembers.find(m => m.id === memberId);
    if (!member) return;

    const select = document.getElementById('modal-reset-target-member');
    if (select) select.value = member.id;
    this.openModal('modal-admin-reset-password');
  }

  openEditPaymentModal(paymentId) {
    const payment = this.allPayments.find(p => p.id === paymentId) || this.payments.find(p => p.id === paymentId);
    if (!payment) return;

    document.getElementById('admin-edit-payment-id').value = payment.id;
    document.getElementById('admin-edit-pay-amount').value = payment.amount;
    document.getElementById('admin-edit-pay-month').value = payment.month;
    document.getElementById('admin-edit-pay-date').value = payment.payment_date ? payment.payment_date.slice(0, 10) : '';
    document.getElementById('admin-edit-pay-status').value = payment.status || 'paid';
    document.getElementById('admin-edit-pay-type').value = payment.payment_type || 'saving';
    document.getElementById('admin-edit-pay-payout-status').value = payment.payout_status || 'accumulating';
    document.getElementById('admin-edit-pay-reference').value = payment.reference || '';

    this.openModal('modal-admin-edit-payment');
  }

  async deletePaymentRecord(paymentId) {
    if (!confirm('Are you sure you want to delete this payment record? This action cannot be undone.')) {
      return;
    }

    try {
      await PaymentService.deletePayment(paymentId);
      Toast.success('Payment record deleted.');
      await this.loadAdminData();
      if (this.member) {
        this.payments = await PaymentService.getPaymentsByMember(this.member.id);
        this.renderPaymentsTable();
        this.renderDashboardStats();
      }
    } catch (err) {
      Toast.error(err.message || 'Failed to delete payment.');
    }
  }
}

// Instantiate and expose globally
window.app = new App();
document.addEventListener('DOMContentLoaded', () => {
  window.app.init();
});
