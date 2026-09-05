# Isora design system

<!-- impeccable:design-schema 1 -->

## Direction

Isora is a topology console for local compute: machines, images, storage and host capabilities are presented as a calm connected system rather than a pile of generic dashboard cards. The interface borrows the exactness of virtualization diagrams and Windows 11 workstation tools, without turning into a terminal costume.

## Platform expression

- Windows 11 is the primary high-craft surface: system palette and accent, restrained depth, native window behavior, clear separate-guest-window controls and compact technical detail.
- Linux inherits the same information architecture but uses flatter surfaces and exposes libvirt/KVM-specific state.
- Layout responds to available window width; platform checks select behavior and vocabulary, never arbitrary device names.

## Materials and color

- Backgrounds are layered workstation planes: window, navigation rail, work surface and elevated transient surface.
- A single accent connects selected navigation, active topology nodes, focus and progress. Auto uses the host system highlight; manual presets are allowed.
- Status colors are semantic and always paired with text or iconography.
- Dark and light themes are equal first-class modes. System is the default.
- Borders separate adjacent planes; shadows are reserved for floating dialogs, menus and operation overlays.

## Typography

- Use the platform UI family for controls and operational copy. Technical identifiers, hashes, paths and measurements may use the platform monospace family.
- Page titles are compact and decisive; hierarchy comes from weight and spacing, not all-caps labels.
- Numeric resource values use tabular figures.

## Composition

- Persistent left navigation at desktop widths, compact rail when the window narrows.
- Main views use a list/detail topology: the selected machine is the anchor, related resources and actions sit around that context.
- Equal card grids are avoided. Surfaces group one task or one state with clear internal alignment.
- Advanced parameters progressively disclose below the primary workflow.

## Components and states

- Controls share a 40 px baseline and a visible 2 px focus treatment derived from the accent.
- Buttons name concrete actions. Destructive actions use danger treatment and explicit object copy.
- Empty, loading, disconnected, unsupported and error states remain navigable and explain recovery.
- Operation progress is a single anchored status surface, not multiple spinners.

## Motion

- One authored transition: machine detail and operation state settle into place with short exponential ease-out.
- Hover and focus respond within 120–180 ms. No perpetual ambient motion except a determinate/indeterminate operation indicator.
- Reduced motion removes spatial transitions and keeps immediate state changes.

## Windows 11 details

- Auto accent comes from the active `QPalette::Highlight` color.
- System theme follows `QStyleHints::colorScheme`.
- Guest display is a separately branded Isora window; windowed, borderless and fullscreen modes are explicit per-machine settings.
- GPU controls distinguish host-process preference on Windows from DRM render-node and PRIME offload on Linux.
- Window geometry and maximized state persist across normal restarts.

## Accessibility

- Keyboard operation and visible focus on every interactive control.
- Body text contrast at least 4.5:1, large text at least 3:1.
- No status is color-only; controls retain useful labels and tooltips.
- UI remains usable with OS scaling and reduced motion.
