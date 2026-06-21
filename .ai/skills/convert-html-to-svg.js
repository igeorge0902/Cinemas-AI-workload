const fs = require("fs");

const inputFile = process.argv[2];
const outputFile = process.argv[3] || "output.svg";

if (!inputFile) {
    console.error("Usage: node convert-html-to-svg.js input.html [output.svg]");
    process.exit(1);
}

// Read only to capture title and prove input linkage.
const html = fs.readFileSync(inputFile, "utf8");
const titleMatch = html.match(/<title>([^<]+)<\/title>/i);
const pageTitle = titleMatch ? titleMatch[1].trim() : "PEMS OpenAPI Contract Viewer";

const W = 1400;
const H = 980;

function rect(x, y, w, h, fill, stroke = "#d1d5db", rx = 8) {
    return `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${rx}" fill="${fill}" stroke="${stroke}" />`;
}
function text(x, y, value, size = 14, color = "#1f2937", weight = "normal") {
    const safe = String(value)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;");
    return `<text x="${x}" y="${y}" font-family="Helvetica,Arial,sans-serif" font-size="${size}" fill="${color}" font-weight="${weight}">${safe}</text>`;
}
function line(x1, y1, x2, y2, color = "#d1d5db") {
    return `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${color}" />`;
}

const svg = `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  <rect x="0" y="0" width="${W}" height="${H}" fill="#f5f7fa"/>
  
  <!-- Header -->
  ${rect(20, 16, W - 40, 54, "#001f4d", "#001f4d")}
  ${text(36, 49, pageTitle, 20, "#ffffff", "bold")}
  ${text(W - 380, 49, "Badges: Env | Spec | Token | Refresh", 12, "#e5e7eb")}

  <!-- Main columns -->
  ${rect(20, 84, 680, 280, "#ffffff")}
  ${text(36, 112, "Environment & Token", 16, "#001f4d", "bold")}
  ${line(32, 124, 688, 124)}
  ${rect(36, 138, 140, 34, "#f9fafb")}
  ${text(44, 160, "Environment", 12, "#4b5563")}
  ${rect(184, 138, 140, 34, "#f9fafb")}
  ${text(192, 160, "Realm", 12, "#4b5563")}
  ${rect(332, 138, 140, 34, "#f9fafb")}
  ${text(340, 160, "Client ID", 12, "#4b5563")}
  ${rect(480, 138, 100, 34, "#f9fafb")}
  ${text(488, 160, "Username", 12, "#4b5563")}
  ${rect(588, 138, 92, 34, "#f9fafb")}
  ${text(596, 160, "Password", 12, "#4b5563")}
  ${rect(36, 186, 120, 32, "#001f4d", "#001f4d")}
  ${text(66, 207, "Get Token", 12, "#ffffff", "bold")}
  ${rect(166, 186, 120, 32, "#ffffff", "#001f4d")}
  ${text(190, 207, "Apply Token", 12, "#001f4d", "bold")}
  ${rect(296, 186, 80, 32, "#b91c1c", "#b91c1c")}
  ${text(319, 207, "Clear", 12, "#ffffff", "bold")}
  ${rect(36, 232, 644, 112, "#ffffff")}
  ${text(44, 254, "Bearer Token Input (single-line field)", 12, "#4b5563")}

  ${rect(720, 84, 660, 280, "#ffffff")}
  ${text(736, 112, "DocSpace Refresh", 16, "#001f4d", "bold")}
  ${line(732, 124, 1368, 124)}
  ${text(736, 148, "Sources: [IADP] [OT] [TT]", 13, "#4b5563")}
  ${rect(736, 162, 130, 34, "#001f4d", "#001f4d")}
  ${text(752, 184, "Fetch & Refresh", 12, "#ffffff", "bold")}
  ${rect(736, 210, 620, 134, "#f9fafb")}
  ${text(748, 234, "Status / saved files / hints area", 12, "#4b5563")}

  ${rect(20, 378, 680, 180, "#ffffff")}
  ${text(36, 406, "Operation Statistics", 16, "#001f4d", "bold")}
  ${line(32, 418, 688, 418)}
  ${rect(36, 434, 200, 104, "#f9fafb")}
  ${text(46, 458, "Total", 12, "#4b5563")}
  ${rect(252, 434, 200, 104, "#f9fafb")}
  ${text(262, 458, "IADP / OT / TT", 12, "#4b5563")}
  ${rect(468, 434, 212, 104, "#f9fafb")}
  ${text(478, 458, "Methods", 12, "#4b5563")}

  ${rect(720, 378, 660, 180, "#ffffff")}
  ${text(736, 406, "Loaded Operations", 16, "#001f4d", "bold")}
  ${line(732, 418, 1368, 418)}
  ${rect(736, 434, 620, 104, "#f9fafb")}
  ${text(748, 458, "Operations table placeholder", 12, "#4b5563")}

  <!-- Swagger section -->
  ${rect(20, 572, W - 40, 388, "#ffffff")}
  ${text(36, 600, "Swagger Viewer", 16, "#001f4d", "bold")}
  ${line(32, 612, W - 32, 612)}
  ${rect(36, 626, 200, 34, "#001f4d", "#001f4d")}
  ${text(58, 648, "Authenticate Swagger", 12, "#ffffff", "bold")}
  ${rect(246, 626, 170, 34, "#ffffff", "#001f4d")}
  ${text(278, 648, "Relay Proxy: ON", 12, "#001f4d", "bold")}
  ${rect(36, 674, W - 72, 270, "#f9fafb", "#d1d5db")}
  ${text(56, 718, "Swagger UI Placeholder", 24, "#6b7280", "bold")}
  ${text(56, 746, "Live Swagger execution is intentionally not embedded in this SVG.", 14, "#6b7280")}
  ${text(56, 770, "Use view-specs.html in browser for interactive behavior.", 14, "#6b7280")}
</svg>
`;

fs.writeFileSync(outputFile, svg, "utf8");
console.log(`Created ${outputFile}`);
