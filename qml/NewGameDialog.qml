import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

Popup {
    id: root

    // Emitted when user clicks "Start"
    // mode: 0=Human vs Human, 1=Human vs Computer, 2=Computer vs Computer
    // playerColor: 0=White, 1=Black, 2=Random  (only meaningful for mode=1)
    // timeMsW/timeMsB: 0 = untimed, else milliseconds for that side
    // incMsW/incMsB:   increment in milliseconds per move for that side
    // fen:    empty string = standard starting position
    signal startGame(int mode, int playerColor, int timeMsW, int incMsW, int timeMsB, int incMsB, string fen, bool allowUndo, int eloWhite, int eloBlack)

    modal:       true
    focus:       true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    width:   400
    padding: 28

    background: Rectangle {
        color:        "#2a2a2a"
        radius:       10
        border.color: "#555"
        border.width: 1
    }

    // ── internal state ──────────────────────────────────────────────────────
    property int  selectedMode:   0  // 0=HvH, 1=HvC, 2=CvC
    property int  selectedColor:  0  // 0=White, 1=Black, 2=Random
    property int  selectedTime:   0  // index into timeOptions
    property bool customTime:     false
    property bool allowUndo:      true
    property bool limitStrength:       false
    property bool differentTime:       false
    property int  engineEloValue:      1500
    property bool limitStrengthWhite:  false
    property int  whiteEloValue:       1500
    property bool limitStrengthBlack:  false
    property int  blackEloValue:       1500
    property string blackEnginePath:   ""
    property string whiteEnginePath:   ""

    readonly property var timeOptions: [
        { label: "No clock",      timeMs:      0, incMs:     0 },
        { label: "1 + 0  Bullet", timeMs:  60000, incMs:     0 },
        { label: "2 + 1  Bullet", timeMs: 120000, incMs:  1000 },
        { label: "3 + 2  Blitz",  timeMs: 180000, incMs:  2000 },
        { label: "5 + 0  Blitz",  timeMs: 300000, incMs:     0 },
        { label: "10 + 0 Rapid",  timeMs: 600000, incMs:     0 },
        { label: "15 + 10 Rapid", timeMs: 900000, incMs: 10000 },
        { label: "Custom…",       timeMs:     -1, incMs:    -1 }
    ]

    ColumnLayout {
        id: col
        anchors { top: parent.top; left: parent.left; right: parent.right }
        spacing: 20

        // ── Title ─────────────────────────────────────────────────────────
        Text {
            text: "New Game"
            font.pixelSize: 20
            font.bold: true
            color: "white"
            Layout.alignment: Qt.AlignHCenter
        }

        // ── Game mode ─────────────────────────────────────────────────────
        ColumnLayout {
            spacing: 6
            Layout.fillWidth: true
            Text { text: "Game mode"; color: "#aaa"; font.pixelSize: 12 }
            RowLayout {
                spacing: 8
                Layout.fillWidth: true
                Repeater {
                    model: ["Human vs Human", "vs Computer", "Computer vs Computer"]
                    delegate: Rectangle {
                        required property int index
                        required property string modelData
                        Layout.fillWidth: true
                        height: 36
                        radius: 5
                        color: root.selectedMode === index ? "#4a8a4a" : (ma.containsMouse ? "#444" : "#363636")
                        border.color: root.selectedMode === index ? "#6ab46a" : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData
                            color: "white"
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            width: parent.width - 8
                        }
                        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectedMode = parent.index }
                    }
                }
            }
        }

        // ── Player color (only for HvC) ────────────────────────────────────
        ColumnLayout {
            spacing: 6
            Layout.fillWidth: true
            visible: root.selectedMode === 1
            Text { text: "Play as"; color: "#aaa"; font.pixelSize: 12 }
            RowLayout {
                spacing: 8
                Layout.fillWidth: true
                Repeater {
                    model: ["White", "Black", "Random"]
                    delegate: Rectangle {
                        required property int index
                        required property string modelData
                        Layout.fillWidth: true
                        height: 36
                        radius: 5
                        color: root.selectedColor === index ? "#4a8a4a" : (cma.containsMouse ? "#444" : "#363636")
                        border.color: root.selectedColor === index ? "#6ab46a" : "transparent"
                        Text { anchors.centerIn: parent; text: parent.modelData; color: "white"; font.pixelSize: 12 }
                        MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectedColor = parent.index }
                    }
                }
            }
        }

        // ── Engine strength (only when computer plays) ─────────────────────
        ColumnLayout {
            spacing: 8
            Layout.fillWidth: true
            visible: root.selectedMode !== 0

            Text { text: "Engine strength"; color: "#aaa"; font.pixelSize: 12 }

            // ── HvC: single elo control ──────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; spacing: 6
                visible: root.selectedMode === 1
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Text { text: "Limit Elo"; color: "#ccc"; font.pixelSize: 12 }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: 40; height: 22; radius: 11
                        color: root.limitStrength ? "#4a8a4a" : "#444"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Rectangle { width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter
                            x: root.limitStrength ? parent.width - 18 : 2; color: "white"
                            Behavior on x { NumberAnimation { duration: 120 } } }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.limitStrength = !root.limitStrength }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    visible: root.limitStrength
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Beginner"; color: "#777"; font.pixelSize: 10 }
                        Item { Layout.fillWidth: true }
                        Text { text: root.engineEloValue + " Elo"; color: "#6ab46a"; font.pixelSize: 12; font.bold: true }
                        Item { Layout.fillWidth: true }
                        Text { text: "Master"; color: "#777"; font.pixelSize: 10 }
                    }
                    Slider {
                        id: eloSlider
                        Layout.fillWidth: true
                        implicitHeight: 28
                        from: 1320; to: 3190; stepSize: 10
                        value: root.engineEloValue
                        onMoved: root.engineEloValue = Math.round(value / 10) * 10
                        background: Rectangle {
                            x: eloSlider.leftPadding; y: eloSlider.topPadding + eloSlider.availableHeight / 2 - height / 2
                            width: eloSlider.availableWidth; height: 4; radius: 2; color: "#444"
                            Rectangle { width: eloSlider.visualPosition * parent.width; height: parent.height; radius: 2; color: "#4a8a4a" }
                        }
                        handle: Rectangle {
                            x: eloSlider.leftPadding + eloSlider.visualPosition * (eloSlider.availableWidth - width)
                            y: eloSlider.topPadding + eloSlider.availableHeight / 2 - height / 2
                            width: 16; height: 16; radius: 8
                            color: eloSlider.pressed ? "#6ab46a" : "white"; border.color: "#4a8a4a"
                        }
                    }
                }
            }

            // ── CvC: white and black elo controls ────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; spacing: 8
                visible: root.selectedMode === 2

                // White Elo
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 6
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Rectangle { width: 10; height: 10; radius: 5; color: "white" }
                        Text { text: "White – Limit Elo"; color: "#ccc"; font.pixelSize: 12 }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            width: 40; height: 22; radius: 11
                            color: root.limitStrengthWhite ? "#4a8a4a" : "#444"
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Rectangle { width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter
                                x: root.limitStrengthWhite ? parent.width - 18 : 2; color: "white"
                                Behavior on x { NumberAnimation { duration: 120 } } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.limitStrengthWhite = !root.limitStrengthWhite }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 4
                        visible: root.limitStrengthWhite
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Beginner"; color: "#777"; font.pixelSize: 10 }
                            Item { Layout.fillWidth: true }
                            Text { text: root.whiteEloValue + " Elo"; color: "#6ab46a"; font.pixelSize: 12; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text { text: "Master"; color: "#777"; font.pixelSize: 10 }
                        }
                        Slider {
                            id: whiteEloSlider
                            Layout.fillWidth: true
                            implicitHeight: 28
                            from: 1320; to: 3190; stepSize: 10
                            value: root.whiteEloValue
                            onMoved: root.whiteEloValue = Math.round(value / 10) * 10
                            background: Rectangle {
                                x: whiteEloSlider.leftPadding; y: whiteEloSlider.topPadding + whiteEloSlider.availableHeight / 2 - height / 2
                                width: whiteEloSlider.availableWidth; height: 4; radius: 2; color: "#444"
                                Rectangle { width: whiteEloSlider.visualPosition * parent.width; height: parent.height; radius: 2; color: "#4a8a4a" }
                            }
                            handle: Rectangle {
                                x: whiteEloSlider.leftPadding + whiteEloSlider.visualPosition * (whiteEloSlider.availableWidth - width)
                                y: whiteEloSlider.topPadding + whiteEloSlider.availableHeight / 2 - height / 2
                                width: 16; height: 16; radius: 8
                                color: whiteEloSlider.pressed ? "#6ab46a" : "white"; border.color: "#4a8a4a"
                            }
                        }
                    }
                }

                // Black Elo
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 6
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Rectangle { width: 10; height: 10; radius: 5; color: "#555" }
                        Text { text: "Black – Limit Elo"; color: "#ccc"; font.pixelSize: 12 }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            width: 40; height: 22; radius: 11
                            color: root.limitStrengthBlack ? "#4a8a4a" : "#444"
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Rectangle { width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter
                                x: root.limitStrengthBlack ? parent.width - 18 : 2; color: "white"
                                Behavior on x { NumberAnimation { duration: 120 } } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.limitStrengthBlack = !root.limitStrengthBlack }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 4
                        visible: root.limitStrengthBlack
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Beginner"; color: "#777"; font.pixelSize: 10 }
                            Item { Layout.fillWidth: true }
                            Text { text: root.blackEloValue + " Elo"; color: "#6ab46a"; font.pixelSize: 12; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text { text: "Master"; color: "#777"; font.pixelSize: 10 }
                        }
                        Slider {
                            id: blackEloSlider
                            Layout.fillWidth: true
                            implicitHeight: 28
                            from: 1320; to: 3190; stepSize: 10
                            value: root.blackEloValue
                            onMoved: root.blackEloValue = Math.round(value / 10) * 10
                            background: Rectangle {
                                x: blackEloSlider.leftPadding; y: blackEloSlider.topPadding + blackEloSlider.availableHeight / 2 - height / 2
                                width: blackEloSlider.availableWidth; height: 4; radius: 2; color: "#444"
                                Rectangle { width: blackEloSlider.visualPosition * parent.width; height: parent.height; radius: 2; color: "#4a8a4a" }
                            }
                            handle: Rectangle {
                                x: blackEloSlider.leftPadding + blackEloSlider.visualPosition * (blackEloSlider.availableWidth - width)
                                y: blackEloSlider.topPadding + blackEloSlider.availableHeight / 2 - height / 2
                                width: 16; height: 16; radius: 8
                                color: blackEloSlider.pressed ? "#6ab46a" : "white"; border.color: "#4a8a4a"
                            }
                        }
                    }
                }

                // White engine binary (optional, CvC only)
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    Text { text: "White engine path (optional)"; color: "#aaa"; font.pixelSize: 11 }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 4
                        TextField {
                            id: whiteEnginePathField
                            Layout.fillWidth: true
                            placeholderText: "Leave empty to use engine from settings…"
                            text: root.whiteEnginePath
                            onTextChanged: root.whiteEnginePath = text
                            background: Rectangle {
                                color: whiteEnginePathField.text !== "" ? "#2a3a2a" : "#3a3a3a"
                                radius: 4
                                border.color: whiteEnginePathField.text !== "" ? "#6ab46a" : "#666"
                            }
                            color: "white"; placeholderTextColor: "#777"; font.pixelSize: 11
                            leftPadding: 8; rightPadding: 8
                        }
                        Button {
                            text: "Browse"; width: 70; height: whiteEnginePathField.height
                            onClicked: whiteEngineFileDlg.open()
                            background: Rectangle { color: parent.hovered ? "#4a4a4a" : "#3a3a3a"; radius: 4; border.color: "#666" }
                            contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 11 }
                        }
                    }
                }

                // Black engine binary (optional, CvC only)
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    Text { text: "Black engine path (optional)"; color: "#aaa"; font.pixelSize: 11 }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 4
                        TextField {
                            id: blackEnginePathField
                            Layout.fillWidth: true
                            placeholderText: "Leave empty to use same engine as white…"
                            text: root.blackEnginePath
                            onTextChanged: root.blackEnginePath = text
                            background: Rectangle {
                                color: blackEnginePathField.text !== "" ? "#2a3a2a" : "#3a3a3a"
                                radius: 4
                                border.color: blackEnginePathField.text !== "" ? "#6ab46a" : "#666"
                            }
                            color: "white"; placeholderTextColor: "#777"; font.pixelSize: 11
                            leftPadding: 8; rightPadding: 8
                        }
                        Button {
                            text: "Browse"; width: 70; height: blackEnginePathField.height
                            onClicked: blackEngineFileDlg.open()
                            background: Rectangle { color: parent.hovered ? "#4a4a4a" : "#3a3a3a"; radius: 4; border.color: "#666" }
                            contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 11 }
                        }
                    }
                }
            }
        }

        // ── Time control ───────────────────────────────────────────────────
        ColumnLayout {
            spacing: 6
            Layout.fillWidth: true
            Text { text: "Time control"; color: "#aaa"; font.pixelSize: 12 }

            Grid {
                columns: 4
                columnSpacing: 8
                rowSpacing: 8
                Layout.fillWidth: true
                enabled: !root.differentTime
                opacity: root.differentTime ? 0.35 : 1.0

                Repeater {
                    model: root.timeOptions
                    delegate: Rectangle {
                        required property int    index
                        required property var    modelData
                        width:  (col.width - 24) / 4
                        height: 36
                        radius: 5
                        color: (!root.differentTime && root.selectedTime === index) ? "#4a8a4a" : (tma.containsMouse ? "#444" : "#363636")
                        border.color: (!root.differentTime && root.selectedTime === index) ? "#6ab46a" : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData.label
                            color: "white"
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                            width: parent.width - 6
                            horizontalAlignment: Text.AlignHCenter
                        }
                        MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.differentTime  = false
                                        root.selectedTime   = parent.index
                                        root.customTime     = (parent.modelData.timeMs === -1)
                                    } }
                    }
                }
            }

            // Same-time custom inputs
            RowLayout {
                visible: root.customTime && !root.differentTime
                spacing: 8
                Layout.fillWidth: true

                Text { text: "Min:"; color: "#aaa"; font.pixelSize: 12 }
                TextField {
                    id: customMinutes
                    text: "10"
                    inputMethodHints: Qt.ImhDigitsOnly
                    width: 52
                    background: Rectangle { color: "#3a3a3a"; radius: 4; border.color: "#666" }
                    color: "white"
                    font.pixelSize: 13
                }
                Text { text: "Sec:"; color: "#aaa"; font.pixelSize: 12 }
                TextField {
                    id: customSeconds
                    text: "0"
                    inputMethodHints: Qt.ImhDigitsOnly
                    width: 52
                    background: Rectangle { color: "#3a3a3a"; radius: 4; border.color: "#666" }
                    color: "white"
                    font.pixelSize: 13
                }
                Text { text: "Inc:"; color: "#aaa"; font.pixelSize: 12 }
                TextField {
                    id: customInc
                    text: "0"
                    inputMethodHints: Qt.ImhDigitsOnly
                    width: 52
                    background: Rectangle { color: "#3a3a3a"; radius: 4; border.color: "#666" }
                    color: "white"
                    font.pixelSize: 13
                }
            }

            // Different time per side toggle
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text { text: "Different time per side"; color: "#ccc"; font.pixelSize: 12 }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 40; height: 22; radius: 11
                    color: root.differentTime ? "#4a8a4a" : "#444"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Rectangle { width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter
                        x: root.differentTime ? parent.width - 18 : 2; color: "white"
                        Behavior on x { NumberAnimation { duration: 120 } } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root.differentTime = !root.differentTime }
                }
            }

            // Per-side custom time inputs
            ColumnLayout {
                visible: root.differentTime
                Layout.fillWidth: true; spacing: 6

                // White
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    Rectangle { width: 10; height: 10; radius: 5; color: "white" }
                    Text { text: "White"; color: "#ccc"; font.pixelSize: 12; width: 36 }
                    Text { text: "Min:"; color: "#aaa"; font.pixelSize: 12 }
                    TextField {
                        id: wCustomMinutes; text: "10"; inputMethodHints: Qt.ImhDigitsOnly; width: 48
                        background: Rectangle { color: "#3a3a3a"; radius: 4; border.color: "#666" }
                        color: "white"; font.pixelSize: 13
                    }
                    Text { text: "Sec:"; color: "#aaa"; font.pixelSize: 12 }
                    TextField {
                        id: wCustomSeconds; text: "0"; inputMethodHints: Qt.ImhDigitsOnly; width: 48
                        background: Rectangle { color: "#3a3a3a"; radius: 4; border.color: "#666" }
                        color: "white"; font.pixelSize: 13
                    }
                    Text { text: "Inc:"; color: "#aaa"; font.pixelSize: 12 }
                    TextField {
                        id: wCustomInc; text: "0"; inputMethodHints: Qt.ImhDigitsOnly; width: 48
                        background: Rectangle { color: "#3a3a3a"; radius: 4; border.color: "#666" }
                        color: "white"; font.pixelSize: 13
                    }
                }

                // Black
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    Rectangle { width: 10; height: 10; radius: 5; color: "#555"; border.color: "#999"; border.width: 1 }
                    Text { text: "Black"; color: "#ccc"; font.pixelSize: 12; width: 36 }
                    Text { text: "Min:"; color: "#aaa"; font.pixelSize: 12 }
                    TextField {
                        id: bCustomMinutes; text: "10"; inputMethodHints: Qt.ImhDigitsOnly; width: 48
                        background: Rectangle { color: "#3a3a3a"; radius: 4; border.color: "#666" }
                        color: "white"; font.pixelSize: 13
                    }
                    Text { text: "Sec:"; color: "#aaa"; font.pixelSize: 12 }
                    TextField {
                        id: bCustomSeconds; text: "0"; inputMethodHints: Qt.ImhDigitsOnly; width: 48
                        background: Rectangle { color: "#3a3a3a"; radius: 4; border.color: "#666" }
                        color: "white"; font.pixelSize: 13
                    }
                    Text { text: "Inc:"; color: "#aaa"; font.pixelSize: 12 }
                    TextField {
                        id: bCustomInc; text: "0"; inputMethodHints: Qt.ImhDigitsOnly; width: 48
                        background: Rectangle { color: "#3a3a3a"; radius: 4; border.color: "#666" }
                        color: "white"; font.pixelSize: 13
                    }
                }
            }
        }

        // ── Starting position (FEN) ────────────────────────────────────────
        ColumnLayout {
            spacing: 6
            Layout.fillWidth: true

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Starting position"; color: "#aaa"; font.pixelSize: 12; Layout.fillWidth: true }
                Text {
                    text: "Standard"
                    color: fenField.text.trim() === "" ? "#6ab46a" : "#666"
                    font.pixelSize: 11
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fenField.text = ""
                    }
                }
            }
            TextField {
                id: fenField
                placeholderText: "Paste FEN to set a custom position…"
                Layout.fillWidth: true
                background: Rectangle {
                    color: fenField.text.trim() !== "" ? "#2a3a2a" : "#3a3a3a"
                    radius: 4
                    border.color: fenField.text.trim() !== "" ? "#6ab46a" : "#666"
                }
                color: "white"
                placeholderTextColor: "#777"
                font.pixelSize: 11
                leftPadding: 8; rightPadding: 8
            }
        }

        // ── Options row (allow undo) ────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text { text: "Allow take back"; color: "#aaa"; font.pixelSize: 12; Layout.fillWidth: true }
            Rectangle {
                id: undoToggle
                width: 40; height: 22; radius: 11
                color: root.allowUndo ? "#4a8a4a" : "#444"
                Behavior on color { ColorAnimation { duration: 120 } }
                Rectangle {
                    width: 16; height: 16; radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.allowUndo ? parent.width - 18 : 2
                    color: "white"
                    Behavior on x { NumberAnimation { duration: 120 } }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.allowUndo = !root.allowUndo
                }
            }
        }

        // ── Buttons ────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Button {
                text: "Cancel"
                Layout.fillWidth: true
                onClicked: root.close()
                background: Rectangle { color: parent.hovered ? "#555" : "#3a3a3a"; radius: 4; border.color: "#666" }
                contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 13 }
            }
            Button {
                text: "Start"
                Layout.fillWidth: true
                onClicked: {
                    let wMs = 0, bMs = 0, wInc = 0, bInc = 0
                    if (root.differentTime) {
                        wMs  = (parseInt(wCustomMinutes.text) || 0) * 60000
                               + (parseInt(wCustomSeconds.text) || 0) * 1000
                        if (wMs === 0) wMs = 600000
                        wInc = (parseInt(wCustomInc.text) || 0) * 1000
                        bMs  = (parseInt(bCustomMinutes.text) || 0) * 60000
                               + (parseInt(bCustomSeconds.text) || 0) * 1000
                        if (bMs === 0) bMs = 600000
                        bInc = (parseInt(bCustomInc.text) || 0) * 1000
                    } else if (root.selectedTime > 0) {
                        const opt = root.timeOptions[root.selectedTime]
                        if (opt.timeMs === -1) {
                            wMs = bMs = (parseInt(customMinutes.text) || 0) * 60000
                                      + (parseInt(customSeconds.text) || 0) * 1000
                            if (wMs === 0) wMs = bMs = 600000
                            wInc = bInc = (parseInt(customInc.text) || 0) * 1000
                        } else {
                            wMs = bMs = opt.timeMs; wInc = bInc = opt.incMs
                        }
                    }
                    let eloW = 0, eloB = 0
                    if (root.selectedMode === 1) {
                        // HvC: pass same limit; Main.qml assigns to engine's side
                        const e = root.limitStrength ? root.engineEloValue : 0
                        eloW = e; eloB = e
                    } else if (root.selectedMode === 2) {
                        eloW = root.limitStrengthWhite ? root.whiteEloValue : 0
                        eloB = root.limitStrengthBlack ? root.blackEloValue : 0
                    }
                    root.startGame(root.selectedMode, root.selectedColor, wMs, wInc, bMs, bInc, fenField.text.trim(), root.allowUndo, eloW, eloB)
                    root.close()
                }
                background: Rectangle { color: parent.hovered ? "#5a9a5a" : "#4a8a4a"; radius: 4 }
                contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 13 }
            }
        }
    }

    height: col.implicitHeight + 56

    FileDialog {
        id: blackEngineFileDlg
        title: "Select black engine executable"
        onAccepted: {
            blackEnginePathField.text = selectedFile.toString().replace("file://", "")
        }
    }

    FileDialog {
        id: whiteEngineFileDlg
        title: "Select white engine executable"
        onAccepted: {
            whiteEnginePathField.text = selectedFile.toString().replace("file://", "")
        }
    }
}
