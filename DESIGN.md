# Isora design system

<!-- impeccable:design-schema 1 -->

## Direction

Isora is a topology console for local compute: machines, images, storage and host capabilities are presented as a calm connected system rather than a pile of generic dashboard cards. The interface follows Material You and Material 3 while retaining the density and precision expected from a desktop virtualization tool.

## Platform expression

- Arch Linux is the primary high-craft surface, with native Qt Quick behavior and explicit libvirt/KVM state.
- The preserved Windows backend inherits the same QML information architecture and keeps clear separate-guest-window controls.
- Layout responds to available window width; platform checks select behavior and vocabulary, never arbitrary device names.

## Materials and color

- Backgrounds use Material 3 dark surface containers: window, navigation rail, work surface and elevated transient surface.
- A single accent connects selected navigation, active topology nodes, focus and progress. The default seed color is `#9FE0B4`; manual presets remain available.
- Status colors are semantic and always paired with text or iconography.
- Material 3 Dark is the application color scheme.
- Tonal elevation separates planes; outlines are reserved for boundaries, focus and selected states.

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

## Platform details

- Qt Quick/QML is the only user-interface layer; C++ exposes application and virtualization services to QML.
- The Qt Quick Controls Material style supplies native control behavior beneath Isora's Material 3 components.
- Guest display is a separately branded Isora window; windowed, borderless and fullscreen modes are explicit per-machine settings.
- GPU controls distinguish host-process preference on Windows from DRM render-node and PRIME offload on Linux.
- Window geometry and maximized state persist across normal restarts.

## Accessibility

- Keyboard operation and visible focus on every interactive control.
- Body text contrast at least 4.5:1, large text at least 3:1.
- No status is color-only; controls retain useful labels and tooltips.
- UI remains usable with OS scaling and reduced motion.
