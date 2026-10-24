pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services
import M3Shapes

StyledWindow {
    id: root

    // request metadata (written by the launcher)
    // request metadata (written by the launcher)
    readonly property var req: reqStore ? JSON.parse(reqStore.text() || "{}") : ({})
    readonly property string title: req.title ?? "Passphrase required"
    readonly property string message: req.message ?? ""
    readonly property string prompt: req.prompt ?? "Enter passphrase"
    readonly property string error: req.error ?? ""
    readonly property string okLabel: req.okLabel ?? ""
    readonly property string cancelLabel: req.cancelLabel ?? ""
    readonly property int timeout: req.timeout ?? 0
    // characters are never shown; the flag is reserved for future plain preview
    readonly property bool masked: req.masked ?? true

    readonly property real centerScale: Math.max(0.8, Math.min(1, root.height / 1440))

    property string buffer: ""
    property int secondsLeft: timeout
    property Socket conn
    property bool didQuit: false

    function respond(status: string, pass: string): void {
        if (root.didQuit)
            return; // never answer twice (e.g. submit racing a timeout)
        root.didQuit = true;
        const payload = pass === undefined ? status : `${status} ${Qt.btoa(pass)}`;
        // NOTE: on this Qt build Qt.btoa() encodes the string as UTF-8 (it does
        // NOT match the Web API's Latin-1), and the launcher decodes with plain
        // `base64 -d`, so non-ASCII passphrases round-trip intact. Do NOT wrap
        // with unescape(encodeURIComponent(...)) — that would double-encode.
        if (conn) {
            conn.write(payload);
            conn.flush();
        }
        closeAnim.start();
        quitTimer.start();
    }

    readonly property list<int> shapeQueue: {
        const shapes = [MaterialShape.Slanted, MaterialShape.Arch, MaterialShape.Fan, MaterialShape.Arrow, MaterialShape.SemiCircle, MaterialShape.Triangle, MaterialShape.Diamond, MaterialShape.ClamShell, MaterialShape.Pentagon, MaterialShape.Gem, MaterialShape.Sunny, MaterialShape.VerySunny, MaterialShape.Cookie4Sided, MaterialShape.Ghostish, MaterialShape.SoftBurst];
        for (let i = shapes.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [shapes[i], shapes[j]] = [shapes[j], shapes[i]];
        }
        return shapes;
    }

    name: "prompt"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    screen: Quickshell.screens[0]

    visible: true
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    onSecondsLeftChanged: {
        if (root.timeout > 0 && root.secondsLeft <= 0)
            root.respond("TIMEOUT");
    }

    Component.onCompleted: {
        if (!Quickshell.env("AEP_DIR")) {
            console.warn("aetherprompt: AEP_DIR is not set — run via the aetherprompt CLI");
            Qt.quit();
            return;
        }
        openAnim.start();
        passwordRect.forceActiveFocus();
        countdown.visible = root.timeout > 0;
        if (root.timeout > 0)
            countdownTimer.start();
    }

    Timer {
        id: quitTimer

        interval: 400 // let socket bytes drain before exiting
        onTriggered: Qt.quit()
    }

    function submit(): void {
        if (root.buffer.length === 0)
            return;
        respond("PASS", root.buffer);
        root.buffer = "";
    }

    function cancel(): void {
        respond("CANCEL");
    }

    Timer {
        id: countdownTimer

        interval: 1000
        running: false
        repeat: true
        onTriggered: root.secondsLeft--
    }

    FileView {
        id: reqStore

        path: `${Quickshell.env("AEP_DIR")}/req.json`
    }

    // the launcher connects here and reads the result; the passphrase lives
    // only in kernel socket buffers, never on disk
    SocketServer {
        id: respServer

        active: true
        path: `${Quickshell.env("AEP_DIR")}/pass.sock`
        handler: Socket {
            onConnectedChanged: {
                if (connected) {
                    root.conn = this;
                    disconnectTimer.start();
                }
            }
            parser: SplitParser {
                onRead: msg => {} // nothing to accept from the caller
            }
        }
    }

    Timer {
        id: disconnectTimer
        // if the caller never connects there is nobody to answer — give up
        interval: 20000
        onTriggered: {
            if (!root.conn)
                Qt.quit();
        }
    }

    ParallelAnimation {
        id: openAnim

        SequentialAnimation {
            ParallelAnimation {
                Anim {
                    target: dialogContainer
                    property: "opacity"
                    to: 1
                    duration: Tokens.anim.durations.small
                }
                Anim {
                    target: dialogContainer
                    property: "scale"
                    to: 1
                    type: Anim.Emphasized
                    duration: 400
                }
            }
            PropertyAction {
                target: dialogContainer
                property: "isExpanded"
                value: true
            }
            ParallelAnimation {
                Anim {
                    target: lockIcon
                    property: "scale"
                    to: 0
                    type: Anim.Emphasized
                    duration: 400
                }
                Anim {
                    type: Anim.DefaultEffects
                    target: lockIcon
                    property: "opacity"
                    to: 0
                    duration: 250
                }
                Anim {
                    type: Anim.DefaultEffects
                    target: dialogContent
                    property: "opacity"
                    to: 1
                    duration: 500
                }
                Anim {
                    target: dialogContent
                    property: "scale"
                    to: 1
                    type: Anim.Emphasized
                    duration: 500
                }
                Anim {
                    target: dialogBg
                    property: "radius"
                    to: Tokens.rounding.large
                    duration: 500
                }
            }
        }
    }

    SequentialAnimation {
        id: closeAnim

        ParallelAnimation {
            PropertyAction {
                target: dialogContainer
                property: "isExpanded"
                value: false
            }
            Anim {
                target: dialogBg
                property: "radius"
                to: dialogContainer.initialRadius
            }
            Anim {
                target: dialogContent
                property: "scale"
                to: 0
            }
            Anim {
                target: dialogContent
                property: "opacity"
                to: 0
                type: Anim.StandardSmall
            }
            Anim {
                target: lockIcon
                property: "opacity"
                to: 1
                type: Anim.StandardLarge
            }
            Anim {
                target: lockIcon
                property: "scale"
                to: 1
                type: Anim.StandardLarge
            }

            SequentialAnimation {
                PauseAnimation {
                    duration: Tokens.anim.durations.small
                }
                Anim {
                    target: dialogContainer
                    property: "opacity"
                    to: 0
                    type: Anim.Standard
                }
                PropertyAction {
                    target: dialogContainer
                    property: "scale"
                    value: 0
                }
            }
            PauseAnimation {
                duration: 600
            }
            PropertyAction {
                target: root
                property: "visible"
                value: false
            }
        }
    }

    MouseArea {
        anchors.fill: parent
    }

    Item {
        id: dialogContainer

        property bool isExpanded: false

        readonly property int centerWidth: (Tokens.sizes?.lock?.centerWidth ?? 420) * root.centerScale
        readonly property int passwordMaxWidth: centerWidth * 0.8

        readonly property int iconSize: lockIcon.implicitHeight + (root.screen ? Tokens.padding.large * 4 : 0)
        readonly property int initialRadius: root.screen ? iconSize / 4 * Tokens.rounding.scale : 0

        property int targetWidth: Math.max(420, passwordMaxWidth + Tokens.padding.extraLarge * 2)
        property int targetHeight: dialogContent.implicitHeight + Tokens.padding.large * 2

        anchors.centerIn: parent
        implicitWidth: isExpanded ? targetWidth : iconSize
        implicitHeight: isExpanded ? targetHeight : iconSize
        scale: 0

        Behavior on implicitWidth {
            Anim {
                type: Anim.Emphasized
                duration: 500
            }
        }
        Behavior on implicitHeight {
            Anim {
                type: Anim.Emphasized
                duration: 500
            }
        }

        StyledRect {
            id: dialogBg

            anchors.fill: parent
            radius: dialogContainer.initialRadius
            color: Colours.layer(Colours.palette.m3surface, 0)

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurMax: 15
                shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.7)
            }
        }

        MaterialIcon {
            id: lockIcon

            anchors.centerIn: parent
            text: "shield_person"
            fill: 1
            fontStyle: Tokens.font.icon.builders.extraLarge.scale(2).weight(Font.Medium).build()
            color: Colours.palette.m3secondary
        }

        ColumnLayout {
            id: dialogContent

            width: dialogContainer.targetWidth - Tokens.padding.large * 2
            anchors.centerIn: parent

            opacity: 0
            scale: 0
            spacing: Tokens.spacing.large

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: titleLayout.implicitHeight + Tokens.padding.large * 2
                color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                radius: Tokens.rounding.large

                ColumnLayout {
                    id: titleLayout
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.small

                    StyledText {
                        Layout.fillWidth: true
                        text: root.title
                        font: Tokens.font.title.builders.large.weight(Font.Medium).build()
                        color: Colours.palette.m3onSurface
                        horizontalAlignment: Text.AlignHCenter
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.message.length > 0
                        text: root.message
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.error.length > 0
                text: root.error
                font: Tokens.font.body.small
                color: Colours.palette.m3error
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            StyledRect {
                id: passwordRect
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: Math.min(dialogContainer.passwordMaxWidth, emptyPlaceholder.width + iconWrapper.implicitWidth + enterButton.implicitWidth + passwordInputLayout.spacing * 2 + Tokens.padding.medium * 2)
                implicitHeight: passwordInputLayout.implicitHeight + Tokens.padding.small
                color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                radius: Tokens.rounding.full

                focus: true

                Behavior on implicitWidth {
                    Anim {}
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onClicked: passwordRect.forceActiveFocus()
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                        root.submit();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Backspace) {
                        root.buffer = root.buffer.slice(0, -1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        root.cancel();
                        event.accepted = true;
                    } else if (event.text.length > 0) {
                        root.buffer += event.text;
                        event.accepted = true;
                    }
                }

                RowLayout {
                    id: passwordInputLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.extraSmall
                    spacing: Tokens.spacing.medium

                    Item {
                        id: iconWrapper
                        Layout.fillHeight: true
                        implicitWidth: height

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "lock"
                            color: Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.builders.medium.scale(root.centerScale).build()
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        StyledText {
                            id: emptyPlaceholder

                            anchors.centerIn: parent
                            text: root.prompt
                            color: Colours.palette.m3outline
                            font: Tokens.font.body.builders.medium.scale(0.9).width(110).build()
                            opacity: root.buffer ? 0 : 1

                            Behavior on opacity {
                                Anim {
                                    type: Anim.DefaultEffects
                                }
                            }
                        }

                        ListView {
                            id: charList

                            readonly property int fullWidth: {
                                let w = (count - 1) * spacing;
                                for (let i = 0; i < count; i++)
                                    w += ((itemAtIndex(i) as CharItem)?.nonAnimWidthScale ?? 1) * implicitHeight;
                                return w + implicitHeight;
                            }

                            function bindImWidth(): void {
                                imWidthBehavior.enabled = false;
                                implicitWidth = Qt.binding(() => fullWidth);
                                imWidthBehavior.enabled = true;
                            }

                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: implicitWidth > parent.width ? -(implicitWidth - parent.width) / 2 : 0

                            implicitWidth: fullWidth
                            implicitHeight: Tokens.font.body.medium.pointSize

                            orientation: Qt.Horizontal
                            spacing: Tokens.spacing.extraSmall
                            interactive: false

                            model: ScriptModel {
                                values: root.buffer.split("")
                            }

                            delegate: CharItem {}

                            Behavior on implicitWidth {
                                id: imWidthBehavior
                                Anim {}
                            }
                        }
                    }

                    Item {
                        id: enterButton

                        implicitWidth: implicitHeight
                        implicitHeight: {
                            const h = enterIcon.implicitHeight + Tokens.padding.extraSmall * 2;
                            return h % 2 === 0 ? h : h + 1;
                        }

                        MaterialShape {
                            anchors.fill: parent
                            color: root.buffer ? Colours.palette.m3primary : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
                            shape: root.buffer ? MaterialShape.Arrow : MaterialShape.Circle
                            scale: !root.buffer ? 1 : enterMouse.pressed ? 0.6 : enterMouse.containsMouse ? 0.8 : 0.7
                            rotation: 90

                            Behavior on scale {
                                Anim {
                                    type: Anim.FastSpatial
                                }
                            }
                            Behavior on color {
                                CAnim {}
                            }

                            MouseArea {
                                id: enterMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: root.buffer ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.submit()
                            }
                        }

                        MaterialIcon {
                            id: enterIcon

                            anchors.centerIn: parent
                            text: "arrow_forward"
                            color: Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.builders.medium.scale(root.centerScale * 1.2).build()
                            opacity: root.buffer ? 0 : 1

                            Behavior on opacity {
                                Anim {
                                    type: Anim.DefaultEffects
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                StyledText {
                    id: cancelButton

                    visible: root.cancelLabel.length > 0
                    text: root.cancelLabel
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Tokens.padding.small
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        StyledRect {
                            anchors.fill: parent
                            radius: Tokens.rounding.full
                            color: parent.containsMouse ? Colours.layer(Colours.palette.m3surfaceContainerHigh, 1) : "transparent"
                        }

                        onClicked: root.cancel()
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    id: countdown

                    text: qsTr("%1s").arg(root.secondsLeft)
                    font: Tokens.font.body.small
                    color: Colours.palette.m3outline
                    visible: false
                }

                Item {
                    Layout.fillWidth: root.cancelLabel.length === 0
                }
            }
        }
    }

    component CharItem: Item {
        id: char

        required property int index
        property real nonAnimWidthScale: 1

        implicitHeight: charList.implicitHeight

        ListView.onRemove: {
            initAnim.stop();
            removeAnim.start();
        }

        MaterialShape {
            id: charShape

            anchors.centerIn: parent
            implicitSize: charList.implicitHeight * 1.5
            shape: root.shapeQueue[char.index % root.shapeQueue.length] ?? MaterialShape.Circle
            color: Colours.palette.m3onSurface

            Behavior on color {
                CAnim {}
            }

            SequentialAnimation {
                id: initAnim

                running: true

                ParallelAnimation {
                    Anim {
                        target: charShape
                        property: "opacity"
                        from: 0
                        to: 1
                        type: Anim.DefaultEffects
                    }
                    Anim {
                        target: charShape
                        property: "scale"
                        from: 0
                        to: 1
                        type: Anim.FastSpatial
                    }
                    Anim {
                        target: char
                        property: "implicitWidth"
                        from: charList.implicitHeight
                        to: charList.implicitHeight * 1.3
                        type: Anim.DefaultEffects
                    }
                    PropertyAction {
                        target: char
                        property: "nonAnimWidthScale"
                        value: 1.5
                    }
                }
                PauseAnimation {
                    duration: 180 * Tokens.anim.durations.scale
                }
                PropertyAction {
                    target: charShape
                    property: "shape"
                    value: MaterialShape.Circle
                }
                ParallelAnimation {
                    Anim {
                        target: charShape
                        property: "scale"
                        to: 2 / 3
                        type: Anim.FastSpatial
                    }
                    Anim {
                        target: char
                        property: "implicitWidth"
                        to: charList.implicitHeight
                        type: Anim.DefaultEffects
                    }
                    PropertyAction {
                        target: char
                        property: "nonAnimWidthScale"
                        value: 1
                    }
                }
            }

            SequentialAnimation {
                id: removeAnim

                PropertyAction {
                    target: char
                    property: "ListView.delayRemove"
                    value: true
                }
                ParallelAnimation {
                    Anim {
                        type: Anim.DefaultEffects
                        target: charShape
                        property: "opacity"
                        to: 0
                    }
                    Anim {
                        target: charShape
                        property: "scale"
                        to: 0.5
                    }
                }
                PropertyAction {
                    target: char
                    property: "ListView.delayRemove"
                    value: false
                }
            }
        }
    }
}
