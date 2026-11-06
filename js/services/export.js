// ==============================================================================
// ONEFELLOWSHIP - EXPORT SERVICE (EXCEL, WORD, PDF)
// ==============================================================================

import { CONFIG } from '../config.js';
import { resolveFieldValue } from './members.js';

export const ExportService = {
  /**
   * Export all members to Excel (.xlsx)
   */
  exportToExcel(members = [], schema = []) {
    if (!window.XLSX) {
      throw new Error('SheetJS (XLSX) library is not loaded.');
    }

    const rows = members.map(m => {
      const row = {
        'Full Name': m.full_name || '',
        'Email Address': m.email || '',
        'Phone Number': m.phone || '',
        'Role': (m.role || 'member').toUpperCase(),
        'Status': (m.status || 'active').toUpperCase(),
        'Join Date': m.join_date ? new Date(m.join_date).toLocaleDateString('en-GB') : ''
      };

      const fd = m.form_details || {};
      if (schema && schema.length > 0) {
        schema.forEach(field => {
          if (field.key === 'phone') return;
          const val = resolveFieldValue(fd, field.key);
          row[field.label] = val || '';
        });
      } else {
        // Flatten extra keys
        Object.entries(fd).forEach(([k, v]) => {
          if (v && typeof v !== 'object') {
            const pretty = k.replace(/_/g, ' ').toUpperCase();
            row[pretty] = v;
          }
        });
      }

      return row;
    });

    const worksheet = window.XLSX.utils.json_to_sheet(rows);
    const workbook = window.XLSX.utils.book_new();
    window.XLSX.utils.book_append_sheet(workbook, worksheet, 'Members');
    window.XLSX.writeFile(workbook, `OneFellowship_Members_${new Date().toISOString().slice(0, 10)}.xlsx`);
  },

  /**
   * Export all members to a high-quality printable PDF view
   */
  exportToPdf(members = [], schema = []) {
    const printWindow = window.open('', '_blank');
    if (!printWindow) {
      throw new Error('Pop-up was blocked. Please allow pop-ups to view PDF.');
    }

    const rowsHtml = members.map((m, index) => {
      const fd = m.form_details || {};
      const idNum = resolveFieldValue(fd, 'national_id_number') || '—';
      const branch = resolveFieldValue(fd, 'branch') || '—';
      const joinDate = m.join_date ? new Date(m.join_date).toLocaleDateString('en-GB') : '—';

      return `
        <tr>
          <td>${index + 1}</td>
          <td><strong>${m.full_name || '—'}</strong></td>
          <td>${m.email || '—'}</td>
          <td>${m.phone || '—'}</td>
          <td>${idNum}</td>
          <td>${branch}</td>
          <td><span class="badge">${(m.role || 'member').toUpperCase()}</span></td>
          <td><span class="badge ${m.status === 'active' ? 'badge-active' : ''}">${(m.status || 'active').toUpperCase()}</span></td>
          <td>${joinDate}</td>
        </tr>
      `;
    }).join('');

    const html = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title>OneFellowship — Members Directory</title>
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; padding: 30px; color: #263238; }
          .header { display: flex; align-items: center; justify-content: space-between; border-bottom: 2px solid #0B4FBB; padding-bottom: 16px; margin-bottom: 20px; }
          .brand { display: flex; align-items: center; gap: 14px; }
          .brand img { width: 56px; height: 56px; object-fit: contain; }
          .brand h1 { margin: 0; font-size: 1.5rem; color: #0A2D6B; }
          .brand p { margin: 2px 0 0; color: #FB8C00; font-weight: 600; font-size: 0.85rem; letter-spacing: 0.5px; }
          .meta { text-align: right; font-size: 0.85rem; color: #757575; }
          table { width: 100%; border-collapse: collapse; margin-top: 15px; font-size: 0.85rem; }
          th { background: #0B4FBB; color: #ffffff; text-align: left; padding: 10px 12px; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.5px; }
          td { padding: 9px 12px; border-bottom: 1px solid #e2e8f0; }
          tr:nth-child(even) { background: #f8fafc; }
          .badge { display: inline-block; padding: 2px 8px; border-radius: 9999px; font-size: 0.7rem; font-weight: 700; background: #e2e8f0; color: #475569; }
          .badge-active { background: #dcfce7; color: #166534; }
          .footer { margin-top: 30px; text-align: center; font-size: 0.8rem; color: #757575; border-top: 1px solid #e2e8f0; padding-top: 15px; }
          @media print {
            .no-print { display: none; }
            body { padding: 0; }
          }
        </style>
      </head>
      <body>
        <div class="no-print" style="margin-bottom: 20px; display:flex; justify-content:flex-end;">
          <button onclick="window.print()" style="padding: 10px 20px; background: #0B4FBB; color: white; border: none; border-radius: 8px; font-weight: 600; cursor: pointer;">
            Print / Save to PDF
          </button>
        </div>
        <div class="header">
          <div class="brand">
            <img src="assets/logo.png" alt="OneFellowship Logo">
            <div>
              <h1>OneFellowship</h1>
              <p>Together We Stand</p>
            </div>
          </div>
          <div class="meta">
            <div><strong>Members Directory</strong></div>
            <div>Total Members: ${members.length}</div>
            <div>Generated: ${new Date().toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })}</div>
          </div>
        </div>

        <table>
          <thead>
            <tr>
              <th>#</th>
              <th>Full Name</th>
              <th>Email</th>
              <th>Phone</th>
              <th>National ID</th>
              <th>Branch</th>
              <th>Role</th>
              <th>Status</th>
              <th>Joined</th>
            </tr>
          </thead>
          <tbody>
            ${rowsHtml}
          </tbody>
        </table>

        <div class="footer">
          &copy; ${new Date().getFullYear()} OneFellowship. Together We Stand. All rights reserved.
        </div>
      </body>
      </html>
    `;

    printWindow.document.write(html);
    printWindow.document.close();
  },

  /**
   * Export all members to Microsoft Word (.docx)
   */
  async exportToWord(members = [], schema = []) {
    if (!window.docx) {
      await new Promise((resolve, reject) => {
        const s = document.createElement('script');
        s.src = 'https://unpkg.com/docx@8.2.3/build/index.umd.js';
        s.onload = resolve;
        s.onerror = () => reject(new Error('Failed to load Word export library.'));
        document.head.appendChild(s);
      });
    }

    const { Document, Packer, Paragraph, TextRun, HeadingLevel, Table, TableRow, TableCell, WidthType, AlignmentType } = window.docx;

    const tableRows = [
      new TableRow({
        children: [
          new TableCell({ children: [new Paragraph({ children: [new TextRun({ text: "Name", bold: true })] })] }),
          new TableCell({ children: [new Paragraph({ children: [new TextRun({ text: "Email", bold: true })] })] }),
          new TableCell({ children: [new Paragraph({ children: [new TextRun({ text: "Phone", bold: true })] })] }),
          new TableCell({ children: [new Paragraph({ children: [new TextRun({ text: "Role", bold: true })] })] }),
          new TableCell({ children: [new Paragraph({ children: [new TextRun({ text: "Status", bold: true })] })] }),
        ]
      })
    ];

    members.forEach(m => {
      tableRows.push(
        new TableRow({
          children: [
            new TableCell({ children: [new Paragraph(m.full_name || '—')] }),
            new TableCell({ children: [new Paragraph(m.email || '—')] }),
            new TableCell({ children: [new Paragraph(m.phone || '—')] }),
            new TableCell({ children: [new Paragraph((m.role || 'member').toUpperCase())] }),
            new TableCell({ children: [new Paragraph((m.status || 'active').toUpperCase())] }),
          ]
        })
      );
    });

    const doc = new Document({
      sections: [{
        children: [
          new Paragraph({
            text: "OneFellowship — Members Directory",
            heading: HeadingLevel.TITLE,
            alignment: AlignmentType.CENTER
          }),
          new Paragraph({
            children: [
              new TextRun({ text: "Together We Stand | Generated on " + new Date().toLocaleDateString(), italics: true })
            ],
            alignment: AlignmentType.CENTER
          }),
          new Paragraph({ text: "" }),
          new Table({
            rows: tableRows,
            width: { size: 100, type: WidthType.PERCENTAGE }
          })
        ]
      }]
    });

    const blob = await Packer.toBlob(doc);
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = `OneFellowship_Members_${new Date().toISOString().slice(0, 10)}.docx`;
    link.click();
  }
};
