pragma Singleton
import QtQuick

QtObject {
    readonly property color window: "#101411"
    readonly property color sidebar: "#181D19"
    readonly property color surface: "#1C211D"
    readonly property color surfaceRaised: "#262B27"
    readonly property color surfaceHover: "#313632"
    readonly property color border: "#3F4941"
    readonly property color borderStrong: "#89938B"
    readonly property color text: "#E1E3DE"
    readonly property color textSecondary: "#C0C9C0"
    readonly property color textMuted: "#89938B"
    readonly property color accent: Appearance.accent
    readonly property color accentHover: Qt.lighter(accent, 1.08)
    readonly property color accentText: accentLuminance(accent) > 0.58 ? "#00391F" : "#FFFFFF"
    readonly property color accentSubtle: Qt.rgba(accent.r, accent.g, accent.b, 0.22)
    readonly property color accentBorder: Qt.rgba(accent.r, accent.g, accent.b, 0.72)
    readonly property color success: "#9FE0B4"
    readonly property color successSurface: "#1E5033"
    readonly property color successBorder: "#82C497"
    readonly property color warning: "#E9C349"
    readonly property color danger: "#FFB4AB"
    readonly property color dangerSurface: "#690005"
    readonly property color dangerHover: "#8C1D18"
    readonly property color dangerBorder: "#FFB4AB"
    readonly property color dangerText: "#FFDAD6"
    readonly property int controlHeight: 40
    readonly property int radiusSmall: 12
    readonly property int radiusControl: 20
    readonly property int radiusCard: 20
    readonly property int pageMargin: 32

    function accentLuminance(value) {
        function linear(channel) {
            return channel <= 0.03928 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(value.r) + 0.7152 * linear(value.g) + 0.0722 * linear(value.b)
    }
}
