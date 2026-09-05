pragma Singleton
import QtQuick

QtObject {
    readonly property bool dark: Appearance.dark
    readonly property color window: dark ? "#1B1C1F" : "#F8F9FD"
    readonly property color sidebar: dark ? "#1F2023" : "#F0F2F7"
    readonly property color surface: dark ? "#1F2023" : "#F0F2F7"
    readonly property color surfaceRaised: dark ? "#25262A" : "#E9EBF0"
    readonly property color surfaceHover: dark ? "#2C2D31" : "#E1E3E8"
    readonly property color border: dark ? "#44474D" : "#C3C7CF"
    readonly property color borderStrong: dark ? "#8C9199" : "#73777F"
    readonly property color text: dark ? "#E3E2E6" : "#191C20"
    readonly property color textSecondary: dark ? "#C2C7CF" : "#42474E"
    readonly property color textMuted: dark ? "#8C9199" : "#73777F"
    readonly property color accent: Appearance.accent
    readonly property color accentHover: dark ? Qt.lighter(accent, 1.14) : Qt.darker(accent, 1.12)
    readonly property color accentText: accentLuminance(accent) > 0.58 ? "#111820" : "#FFFFFF"
    readonly property color accentSubtle: dark ? Qt.rgba(accent.r, accent.g, accent.b, 0.18)
                                               : Qt.rgba(accent.r, accent.g, accent.b, 0.12)
    readonly property color accentBorder: dark ? Qt.rgba(accent.r, accent.g, accent.b, 0.52)
                                               : Qt.rgba(accent.r, accent.g, accent.b, 0.42)
    readonly property color success: dark ? "#86D2A5" : "#2F7650"
    readonly property color successSurface: dark ? "#263A30" : "#E4F3E9"
    readonly property color successBorder: dark ? "#375947" : "#9AC9AE"
    readonly property color warning: dark ? "#EFBD73" : "#9A6400"
    readonly property color danger: dark ? "#FFB4AB" : "#BA1A1A"
    readonly property color dangerSurface: dark ? "#4A2828" : "#FFDAD6"
    readonly property color dangerHover: dark ? "#633333" : "#F9C9C5"
    readonly property color dangerBorder: dark ? "#8C4B48" : "#E6A19B"
    readonly property color dangerText: dark ? "#FFDAD6" : "#93000A"
    readonly property int controlHeight: 40
    readonly property int radiusSmall: 9
    readonly property int radiusControl: 12
    readonly property int radiusCard: 16
    readonly property int pageMargin: 30

    function accentLuminance(value) {
        function linear(channel) {
            return channel <= 0.03928 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(value.r) + 0.7152 * linear(value.g) + 0.0722 * linear(value.b)
    }
}
