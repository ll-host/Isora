pragma Singleton
import QtQuick

QtObject {
    readonly property color window: "#101411"
    readonly property color sidebar: "#1C211E"
    readonly property color surface: "#181C1A"
    readonly property color surfaceRaised: "#272B28"
    readonly property color surfaceHover: "#313633"
    readonly property color border: "#3E4941"
    readonly property color borderStrong: "#87948B"
    readonly property color text: "#DEE4E0"
    readonly property color textSecondary: "#BDCAC0"
    readonly property color textMuted: "#87948B"
    readonly property color accent: "#96D5A9"
    readonly property color accentHover: Qt.lighter(accent, 1.08)
    readonly property color accentText: "#00391C"
    readonly property color accentSubtle: "#12512E"
    readonly property color accentBorder: "#96D5A9"
    readonly property color secondary: "#B7CBBD"
    readonly property color secondaryContainer: "#3A4B3F"
    readonly property color onSecondaryContainer: "#D3E8D8"
    readonly property color success: "#96D5A9"
    readonly property color successSurface: "#12512E"
    readonly property color successBorder: "#96D5A9"
    readonly property color warning: "#E9C349"
    readonly property color danger: "#F2B8B5"
    readonly property color dangerSurface: "#8C1D18"
    readonly property color dangerHover: "#8C1D18"
    readonly property color dangerBorder: "#FFB4AB"
    readonly property color dangerText: "#F9DEDC"
    readonly property int controlHeight: 56
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

    function contrastText(value) {
        return accentLuminance(value) > 0.179 ? "#07110A" : "#FFFFFF"
    }
}
