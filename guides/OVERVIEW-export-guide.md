# OVERVIEW.md Export Guide

## Export Options

### Option 1: Pandoc (Recommended for Editable PDF)
**Tools needed**: Pandoc (markdown to PDF converter) + wkhtmltopdf (with CSS support)

**Steps**:
```bash
# Install Pandoc (macOS: brew install pandoc, Linux: apt install pandoc)
# Install wkhtmltopdf for better CSS handling (optional but recommended)

# Convert Markdown to PDF with styling
pandoc docs/OVERVIEW.md \
  -f markdown \
  -t pdf \
  -o docs/OVERVIEW-export.pdf \
  --pdf-engine=wkhtmltopdf \
  -V margin-top=20mm \
  -V margin-bottom=20mm \
  -V margin-left=15mm \
  -V margin-right=15mm \
  --css=docs/export-style.css

# OR without wkhtmltopdf (uses pdflatex/xelatex):
pandoc docs/OVERVIEW.md \
  -f markdown \
  -t pdf \
  -o docs/OVERVIEW-export.pdf \
  --template=docs/template.tex
```

**Editability**: Pandoc-generated PDFs can be edited using:
- Adobe Acrobat DC (full editing)
- Google Docs (upload PDF, convert to Docs, edit, export back to PDF)
- MS Word (import PDF, edit, export to PDF)
- Affinity PDF Editor (lightweight, native PDF editing)

### Option 2: HTML → PDF (Better Control)
**Tools needed**: Pandoc + wkhtmltopdf OR any web browser with print-to-PDF

**Steps**:
```bash
# Generate HTML first
pandoc docs/OVERVIEW.md \
  -f markdown \
  -t html \
  -o docs/OVERVIEW-export.html \
  --css=docs/export-style.css \
  --include-in-header=docs/export-header.html \
  --standalone

# Then print to PDF using browser or tool
# Browser: Open HTML, Cmd+P / Ctrl+P → Print to PDF (maintains formatting)
# OR use wkhtmltopdf:
wkhtmltopdf docs/OVERVIEW-export.html docs/OVERVIEW-export.pdf
```

**Editability**: HTML-to-PDF via browser preserves better formatting and is more easily editable in downstream tools.

### Option 3: Google Docs + Export
**Steps**:
1. Copy full markdown content (docs/OVERVIEW.md)
2. Paste into Google Docs
3. Format manually (headings, bold, colors, images)
4. File → Download → PDF Document
5. Share link for real-time collaboration/editing

**Editability**: Full editability in Google Docs; always shareable; cloud-based; can revert to any version.

**Recommendation for you**: Use Option 2 (HTML → PDF via browser) or Option 3 (Google Docs export) for best editability post-export.

---

## HTML Export Configuration

Create a stylesheet `docs/export-style.css`:
```css
body {
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  line-height: 1.6;
  color: #1e293b;
  margin: 0;
  padding: 20px;
  background: white;
}

h1 {
  color: #0369a1;
  font-size: 2em;
  margin-bottom: 10px;
  border-bottom: 3px solid #0369a1;
  padding-bottom: 10px;
}

h2 {
  color: #0c4a6e;
  font-size: 1.5em;
  margin-top: 20px;
  margin-bottom: 10px;
}

h3 {
  color: #334155;
  font-size: 1.2em;
  margin-top: 15px;
}

ul, ol {
  margin-left: 20px;
}

li {
  margin-bottom: 5px;
}

code {
  background: #f1f5f9;
  padding: 2px 6px;
  border-radius: 3px;
  font-family: 'Monaco', 'Courier New', monospace;
  font-size: 0.9em;
}

blockquote {
  border-left: 4px solid #0369a1;
  margin-left: 0;
  padding-left: 15px;
  color: #475569;
  font-style: italic;
}

strong {
  color: #0c4a6e;
  font-weight: 600;
}

em {
  font-style: italic;
  color: #64748b;
}

table {
  border-collapse: collapse;
  margin: 15px 0;
  width: 100%;
}

th, td {
  border: 1px solid #cbd5e1;
  padding: 10px;
  text-align: left;
}

th {
  background: #f1f5f9;
  font-weight: 600;
}

@media print {
  body {
    padding: 0;
  }
  
  h1, h2 {
    page-break-after: avoid;
  }
  
  h1 {
    page-break-before: always;
  }
  
  li {
    page-break-inside: avoid;
  }
}
```

---

## Finalization Strategy (Immutable PDF)

Once the PDF is finalized for external sharing:

### 1. **Lock PDF for Editing** (prevent accidental changes)
```bash
# Using qpdf (install: brew install qpdf or apt install qpdf)
qpdf --encrypt owner-password user-password 40 -- \
  docs/OVERVIEW-export.pdf docs/OVERVIEW-export-locked.pdf

# This requires the owner password to enable/disable editing
```

### 2. **Add Version & Date Footer**
Use Pandoc's metadata to auto-insert:
```bash
pandoc docs/OVERVIEW.md \
  -f markdown \
  -t html \
  -o docs/OVERVIEW-export.html \
  --include-in-header='<meta name="date" content="2025-12-26">' \
  --include-after-body='<footer>Contest Schedule Platform — Feature Overview v1.0 (Dec 26, 2025). Locked for distribution.</footer>'
```

### 3. **Digital Signature** (optional, for compliance)
Use PDF signing tools (e.g., `openssl` + PDF libraries) to cryptographically sign:
```bash
# Requires certificate; sign with private key for authenticity
# Tool: gs (GhostScript) + PDFtk or similar
```

### 4. **Checksum/Hash** (verify integrity)
Generate SHA-256 hash for distribution:
```bash
sha256sum docs/OVERVIEW-export.pdf > docs/OVERVIEW-export.pdf.sha256
```

---

## Recommended Workflow for You

1. **Review markdown** (docs/OVERVIEW.md)
2. **Generate HTML**: `pandoc docs/OVERVIEW.md -t html -o /tmp/overview.html --css=docs/export-style.css`
3. **Open in browser**, print to PDF → `OVERVIEW-export.pdf`
4. **Test editability**:
   - Open in Google Docs (upload PDF)
   - Make a test edit (add note, highlight section)
   - Export back to PDF
5. **Finalize**:
   - Confirm all edits complete
   - Lock PDF (qpdf command above)
   - Add version footer
   - Generate checksum
6. **Distribute**: Share OVERVIEW-export.pdf with stakeholders

---

## Tools Summary

| Tool | Use Case | Editability |
|------|----------|-------------|
| Pandoc + wkhtmltopdf | PDF from Markdown | Good (use Acrobat/Google Docs to edit) |
| Browser print-to-PDF | HTML to PDF | Excellent (native browser, clean formatting) |
| Google Docs | Collaborative editing | Excellent (full editing + version history) |
| Affinity PDF | Native PDF editing | Excellent |
| qpdf | Lock PDF (prevent editing) | Controlled (owner password required) |

---

## Next Steps

1. Choose export method (recommend: HTML → browser print-to-PDF)
2. Test on sample section of OVERVIEW.md
3. Apply final styling (colors, fonts match contestgrid branding)
4. Review for readability and layout (page breaks, orphans/widows)
5. Lock and distribute once finalized

Let me know which format you prefer, and I can help set up the export pipeline!
