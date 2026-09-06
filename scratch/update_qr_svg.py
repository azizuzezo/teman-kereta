import os

screenshots_dir = r"c:\Projet\Teman Kereta\landing_page\assets\screenshots"

# Clean, professional QR Code SVG
qr_svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 220" width="220" height="220" style="background:#ffffff; border-radius:16px;">
  <!-- Finder Pattern 1 (Top Left) -->
  <rect x="20" y="20" width="56" height="56" rx="8" fill="#0f172a"/>
  <rect x="28" y="28" width="40" height="40" rx="6" fill="#ffffff"/>
  <rect x="36" y="36" width="24" height="24" rx="4" fill="#2563eb"/>

  <!-- Finder Pattern 2 (Top Right) -->
  <rect x="144" y="20" width="56" height="56" rx="8" fill="#0f172a"/>
  <rect x="152" y="28" width="40" height="40" rx="6" fill="#ffffff"/>
  <rect x="160" y="36" width="24" height="24" rx="4" fill="#2563eb"/>

  <!-- Finder Pattern 3 (Bottom Left) -->
  <rect x="20" y="144" width="56" height="56" rx="8" fill="#0f172a"/>
  <rect x="28" y="152" width="40" height="40" rx="6" fill="#ffffff"/>
  <rect x="36" y="160" width="24" height="24" rx="4" fill="#2563eb"/>

  <!-- Data Matrix Dots / Modules -->
  <g fill="#0f172a">
    <rect x="88" y="24" width="10" height="10" rx="2"/>
    <rect x="104" y="24" width="10" height="10" rx="2"/>
    <rect x="120" y="24" width="10" height="10" rx="2"/>
    
    <rect x="88" y="40" width="10" height="10" rx="2"/>
    <rect x="120" y="40" width="10" height="10" rx="2"/>
    
    <rect x="88" y="56" width="10" height="10" rx="2"/>
    <rect x="104" y="56" width="10" height="10" rx="2"/>
    
    <rect x="24" y="88" width="10" height="10" rx="2"/>
    <rect x="40" y="88" width="10" height="10" rx="2"/>
    <rect x="56" y="88" width="10" height="10" rx="2"/>
    <rect x="72" y="88" width="10" height="10" rx="2"/>
    <rect x="88" y="88" width="10" height="10" rx="2"/>
    <rect x="120" y="88" width="10" height="10" rx="2"/>
    <rect x="144" y="88" width="10" height="10" rx="2"/>
    <rect x="160" y="88" width="10" height="10" rx="2"/>
    <rect x="184" y="88" width="10" height="10" rx="2"/>

    <rect x="24" y="104" width="10" height="10" rx="2"/>
    <rect x="56" y="104" width="10" height="10" rx="2"/>
    <rect x="72" y="104" width="10" height="10" rx="2"/>
    <rect x="136" y="104" width="10" height="10" rx="2"/>
    <rect x="152" y="104" width="10" height="10" rx="2"/>
    <rect x="184" y="104" width="10" height="10" rx="2"/>

    <rect x="24" y="120" width="10" height="10" rx="2"/>
    <rect x="40" y="120" width="10" height="10" rx="2"/>
    <rect x="72" y="120" width="10" height="10" rx="2"/>
    <rect x="88" y="120" width="10" height="10" rx="2"/>
    <rect x="104" y="120" width="10" height="10" rx="2"/>
    <rect x="136" y="120" width="10" height="10" rx="2"/>
    <rect x="168" y="120" width="10" height="10" rx="2"/>

    <rect x="88" y="144" width="10" height="10" rx="2"/>
    <rect x="104" y="144" width="10" height="10" rx="2"/>
    <rect x="136" y="144" width="10" height="10" rx="2"/>
    <rect x="160" y="144" width="10" height="10" rx="2"/>
    <rect x="184" y="144" width="10" height="10" rx="2"/>

    <rect x="88" y="160" width="10" height="10" rx="2"/>
    <rect x="120" y="160" width="10" height="10" rx="2"/>
    <rect x="144" y="160" width="10" height="10" rx="2"/>
    <rect x="160" y="160" width="10" height="10" rx="2"/>

    <rect x="88" y="176" width="10" height="10" rx="2"/>
    <rect x="104" y="176" width="10" height="10" rx="2"/>
    <rect x="120" y="176" width="10" height="10" rx="2"/>
    <rect x="152" y="176" width="10" height="10" rx="2"/>
    <rect x="184" y="176" width="10" height="10" rx="2"/>
  </g>
  
  <!-- Subtle center logo badge -->
  <circle cx="110" cy="110" r="18" fill="#ffffff" stroke="#e2e8f0" stroke-width="2"/>
  <circle cx="110" cy="110" r="14" fill="#2563eb"/>
  <text x="110" y="114" text-anchor="middle" fill="#ffffff" font-size="9.5" font-weight="800">TK</text>
</svg>"""

with open(os.path.join(screenshots_dir, "qr-code.svg"), "w", encoding="utf-8") as f:
  f.write(qr_svg)

print("qr-code.svg updated successfully!")

