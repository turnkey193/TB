# Design System Strategy: Construction Editorial

## 1. Overview & Creative North Star
**Creative North Star: The Industrial Architect**
This design system moves away from the "generic SaaS dashboard" look toward a high-end, editorial experience tailored for construction management. We avoid the flimsy, cluttered appearance of traditional tools by adopting a philosophy of **Industrial Brutalism**. 

The system prioritizes authoritative typography, heavy-weight visual anchors, and a sophisticated layering of monochromatic surfaces. By utilizing intentional asymmetry—such as oversized numerical displays paired with tight, technical labels—we create a UI that feels as solid and reliable as the projects "Mr. Turnkey" manages. It is a digital manifestation of blueprints and structural steel: precise, heavy, and built to last.

---

## 2. Colors
Our palette is rooted in high-contrast functionality. The interaction between the "Caution Yellow" (`primary_container`: #f9b91b) and the "Deep Iron" (`on_surface`: #1c1b1b) provides instant visual hierarchy.

*   **The "No-Line" Rule:** To achieve a premium, custom feel, **1px solid borders are strictly prohibited for sectioning.** We define zones through background shifts. A `surface_container_low` sidebar should sit directly against a `surface` main content area. Contrast, not lines, creates the structure.
*   **Surface Hierarchy & Nesting:** Treat the dashboard as a physical workbench.
    *   **Level 0 (Base):** `surface` (#fcf9f8) for the overall background.
    *   **Level 1 (Zones):** `surface_container_low` (#f6f3f2) for large navigation or grouping areas.
    *   **Level 2 (Active Objects):** `surface_container_lowest` (#ffffff) for primary data cards to make them "pop" against the lower-tier background.
*   **The Glass & Gradient Rule:** For "Overlays" or floating status panels, use semi-transparent `surface` colors with a 20px backdrop-blur. To add "soul" to CTA elements, apply a subtle linear gradient from `primary` (#7b5900) to `primary_container` (#f9b91b) at a 135-degree angle.
*   **Signature Textures:** Use the `primary_fixed` (#ffdea4) for subtle background washes in data-heavy sections to reduce eye strain while maintaining brand presence.

---

## 3. Typography
We utilize a high-contrast pairing: **Space Grotesk** for technical, industrial strength and **Manrope** for modern, legible utility.

*   **Display & Headlines (Space Grotesk):** These are our "Structural Beams." Use `display-lg` for project totals or critical KPIs. The aggressive, geometric nature of Space Grotesk mirrors the industrial logo and conveys authority.
*   **Body & Titles (Manrope):** Our "Interiors." Manrope provides a clean, neutral balance to the expressive headlines. It ensures that complex construction logs and line items remain highly readable at any scale.
*   **The Editorial Scale:** Don't be afraid of extreme scale. A `display-sm` KPI value next to a `label-sm` unit descriptor (e.g., "1,240 SQFT") creates a signature, high-end look that standard dashboards avoid.

---

## 4. Elevation & Depth
In this design system, depth is a function of light and material, not digital "drop shadows."

*   **The Layering Principle:** Depth is achieved by stacking. A `surface_container_highest` (#e5e2e1) element appearing over a `surface` background creates an immediate perception of height without a single pixel of shadow.
*   **Ambient Shadows:** Where floating is required (modals, dropdowns), use a "Structural Shadow": `on_surface` color at 6% opacity, with a 32px blur and 16px Y-offset. It should feel like an ambient occlusion shadow in an architectural render, not a glow.
*   **The Ghost Border Fallback:** If a border is required for accessibility in input fields, use `outline_variant` (#d4c4ac) at **20% opacity**. It should be felt rather than seen.
*   **Industrial Corners:** Use the `DEFAULT` (0.25rem) or `md` (0.375rem) roundedness for most components to maintain a "machined" look. Reserve `full` only for status pips and `xl` for large-scale hero containers.

---

## 5. Components

### Buttons
*   **Primary:** Solid `primary_container` (#f9b91b) with `on_primary_fixed` (#261900) text. Bold, heavy, and impossible to miss.
*   **Secondary:** `surface_container_highest` background with `on_surface` text. No border.
*   **Tertiary:** Ghost style. No background, `primary` text, shifts to a subtle `surface_variant` on hover.

### Input Fields & Controls
*   **Text Inputs:** Use a "Fill-only" style. `surface_container_high` (#eae7e7) background with a thick 2pt bottom-border in `primary` that only appears on focus.
*   **Checkboxes & Radios:** Sharp `sm` (0.125rem) corners for checkboxes to match the industrial vibe. Use `primary` for the active state.

### Cards & Data Objects
*   **Rule of Zero Lines:** Cards must never use dividers. Separate header, body, and footer content using the **Spacing Scale** (vertical padding) or by nesting a `surface_container` inside a `surface_container_low` parent.
*   **Status Indicators:** Use the "Screw-Head" pattern. Small, circular pips using `error`, `primary_container`, or `tertiary` to indicate status, paired with `label-md` uppercase text for a technical, blueprint-like feel.

### Additional Components: The "Timeline Gantry"
A custom component for construction progress. Use a thick, vertical `outline_variant` track with `primary` "blocks" representing completed phases. This visualizes the project's "skeleton" as it's being built.

---

## 6. Do's and Don'ts

### Do
*   **Do** use asymmetrical layouts (e.g., a wide 8-column main view and a narrow 4-column detail rail).
*   **Do** lean into the "Caution Yellow" for primary actions and critical alerts.
*   **Do** use `letter-spacing: -0.02em` on Space Grotesk headlines for a tighter, more professional "editorial" look.
*   **Do** use background tonal shifts to separate "Navigation" from "Content."

### Don't
*   **Don't** use 1px black or grey borders. It breaks the premium "industrial" illusion.
*   **Don't** use generic blue for links. Use `primary` (#7b5900) or `tertiary` (#4c616c).
*   **Don't** use heavy shadows on cards. Let the surface color do the work.
*   **Don't** clutter the view. If a piece of data isn't critical, hide it behind a "Technical Details" accordion using `surface_container_low`.