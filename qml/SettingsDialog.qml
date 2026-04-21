import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

Popup {
    id: root

    // ── Public properties ─────────────────────────────────────────────────
    property int  squareSize: 64
    property string boardTheme: ""
    property string pieceTheme: ""
    property string enginePath: ""
    property string enginePathError: ""
    property int    engineThreads: 0   // 0 = auto

    property var boardThemes: [
        "blue","blue-marble","blue2","blue3","brown","canvas2","green",
        "green-plastic","grey","horsey","ic","leather","maple","maple2",
        "marble","metal","olive","pink-pyramid","purple","purple-diag",
        "wood","wood2","wood3","wood4"
    ]
    property var pieceThemes: [
        "alpha","anarcandy","caliente","california","cardinal","cburnett",
        "celtic","chess7","chessnut","companion","cooke","dubrovny","fantasy",
        "fresca","gioco","governor","horsey","icpieces","kiwen-suwi","kosal",
        "leipzig","letter","maestro","merida","monarchy","mono","mpchess",
        "pirouetti","pixel","reillycraig","rhosgfx","riohacha","shapes",
        "spatial","staunty","tatiana","xkcd"
    ]
    property int selectedBoardIdx: 4   // brown
    property int selectedPieceIdx: 5   // cburnett
    property int activePage: 0

    onBoardThemeChanged: {
        var idx = boardThemes.indexOf(boardTheme)
        if (idx >= 0) selectedBoardIdx = idx
    }
    onPieceThemeChanged: {
        var idx = pieceThemes.indexOf(pieceTheme)
        if (idx >= 0) selectedPieceIdx = idx
    }

    signal applied()

    modal:       true
    focus:       true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    width:       Math.round(squareSize * 11.5)
    height:      Math.round(squareSize * 7)
    padding:     0

    // ── Palette ───────────────────────────────────────────────────────────
    readonly property color bgColor:       "#2a2a2a"
    readonly property color sidebarColor:  "#222222"
    readonly property color itemColor:     "#3a3a3a"
    readonly property color hoverColor:    "#4a4a4a"
    readonly property color borderColor:   "#555"
    readonly property color sepColor:      "#444"
    readonly property color textPrimary:   "white"
    readonly property color textSecondary: "#aaa"
    readonly property color textDim:       "#888"
    readonly property color accentColor:   "#4a8a4a"
    readonly property color accentHover:   "#5a9a5a"

    readonly property int fs:       Math.max(11, Math.round(squareSize * 0.18))
    readonly property int fsS:      Math.max(10, Math.round(squareSize * 0.15))
    readonly property int sp:       Math.max(6,  Math.round(squareSize * 0.14))
    readonly property int sideW:    Math.round(squareSize * 2.0)
    readonly property int tileSize: Math.round(squareSize * 0.62)
    readonly property int pickerW:  Math.round(squareSize * 3.2)
    readonly property int btnH:     Math.round(squareSize * 0.44)
    readonly property int btnW:     Math.round(squareSize * 1.2)

    background: Rectangle {
        color: root.bgColor; radius: 8
        border.color: root.borderColor; border.width: 1
    }

    // ── Root row: sidebar | pickers | preview ─────────────────────────────
    Row {
        anchors.fill: parent
        spacing: 0

        // ── Left sidebar ──────────────────────────────────────────────────
        Rectangle {
            width: root.sideW
            height: parent.height
            color: root.sidebarColor
            radius: 8
            Rectangle { color: parent.color; width: 10; height: parent.height; anchors.right: parent.right }

            Column {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                spacing: 2

                Text {
                    text: "Settings"
                    font.pixelSize: 16; font.bold: true
                    color: root.textPrimary
                    leftPadding: 16; topPadding: 18; bottomPadding: 14
                }

                Repeater {
                    model: ["Themes", "Engine"]
                    Rectangle {
                        required property string modelData
                        required property int    index
                        width: root.sideW - 12
                        height: Math.round(root.squareSize * 0.55)
                        radius: 5
                        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                        color: root.activePage === index ? root.itemColor
                             : (sideNavMa.containsMouse ? "#2e2e2e" : "transparent")

                        Rectangle {
                            visible: root.activePage === index
                            width: 3; height: Math.round(parent.height * 0.55); radius: 2
                            color: root.accentColor
                            anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
                        }

                        Text {
                            text: parent.modelData
                            font.pixelSize: root.fs
                            color: root.activePage === index ? root.textPrimary : root.textDim
                            anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 16 }
                        }

                        MouseArea {
                            id: sideNavMa; anchors.fill: parent; hoverEnabled: true
                            onClicked: root.activePage = parent.index
                        }
                    }
                }
            }

            Rectangle {
                width: 1; height: parent.height
                color: root.sepColor
                anchors.right: parent.right
            }
        }

        // ── Content area ─────────────────────────────────────────────────
        Item {
            id: contentArea
            width: parent.width - root.sideW
            height: parent.height

            StackLayout {
                id: pageStack
                currentIndex: root.activePage
                anchors { top: parent.top; left: parent.left; right: parent.right; bottom: btnRow.top }
                anchors.margins: root.sp * 2
                anchors.bottomMargin: root.sp

                // ── Themes page ───────────────────────────────────────────
                RowLayout {
                    spacing: root.sp * 2

                    // ── Picker column ─────────────────────────────────────────
                    ColumnLayout {
                        Layout.preferredWidth: root.pickerW
                        Layout.fillHeight: true
                        spacing: root.sp + 4

                        // Board theme
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: root.sp - 2

                            Text {
                                text: "Board theme"
                                color: root.textSecondary; font.pixelSize: root.fsS; font.bold: true
                            }

                            ScrollView {
                                id: boardScroll
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                                ScrollBar.vertical.policy:   ScrollBar.AsNeeded

                                Flow {
                                    width: boardScroll.availableWidth
                                    spacing: 4

                                    Repeater {
                                        model: root.boardThemes
                                        Rectangle {
                                            required property string modelData
                                            required property int    index
                                            property bool sel: root.selectedBoardIdx === index
                                            width: root.tileSize; height: root.tileSize
                                            radius: 4
                                            color: sel ? root.accentColor : "transparent"
                                            Item {
                                                anchors { fill: parent; margins: sel ? 2 : 1 }
                                                clip: true
                                                Image {
                                                    width: parent.width * 4; height: parent.height * 4
                                                    source: assetsPath + "/board/" + parent.parent.modelData
                                                            + "/" + parent.parent.modelData + ".png"
                                                    fillMode: Image.Stretch; smooth: true
                                                }
                                            }
                                            ToolTip.visible: bMa.containsMouse
                                            ToolTip.text: modelData
                                            ToolTip.delay: 300
                                            MouseArea {
                                                id: bMa; anchors.fill: parent; hoverEnabled: true
                                                onClicked: {
                                                    root.selectedBoardIdx = parent.index
                                                    root.boardTheme = parent.modelData
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Piece theme
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: root.sp - 2

                            Text {
                                text: "Piece theme"
                                color: root.textSecondary; font.pixelSize: root.fsS; font.bold: true
                            }

                            ScrollView {
                                id: pieceScroll
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                                ScrollBar.vertical.policy:   ScrollBar.AsNeeded

                                Flow {
                                    width: pieceScroll.availableWidth
                                    spacing: 4

                                    Repeater {
                                        model: root.pieceThemes
                                        Rectangle {
                                            required property string modelData
                                            required property int    index
                                            property bool sel: root.selectedPieceIdx === index
                                            width: root.tileSize; height: root.tileSize
                                            radius: 4
                                            color: sel ? root.accentColor : "transparent"
                                            Image {
                                                anchors { fill: parent; margins: sel ? 4 : 3 }
                                                source: assetsPath + "/piece/" + parent.modelData
                                                        + "/64x64/wQ.png"
                                                fillMode: Image.PreserveAspectFit; smooth: true
                                            }
                                            ToolTip.visible: pMa.containsMouse
                                            ToolTip.text: modelData
                                            ToolTip.delay: 300
                                            MouseArea {
                                                id: pMa; anchors.fill: parent; hoverEnabled: true
                                                onClicked: {
                                                    root.selectedPieceIdx = parent.index
                                                    root.pieceTheme = parent.modelData
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Preview pane ──────────────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: Math.round(root.squareSize * 4)
                        spacing: root.sp - 2

                        Text {
                            text: "Preview"
                            color: root.textSecondary; font.pixelSize: root.fsS; font.bold: true
                        }

                        Item {
                            id: previewOuter
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            readonly property int boardSz: Math.floor(Math.min(width, height) / 8) * 8
                            readonly property int cellSz:  boardSz / 8

                            readonly property var startPieces: [
                                [0,0,"bR"],[0,1,"bN"],[0,2,"bB"],[0,3,"bQ"],[0,4,"bK"],[0,5,"bB"],[0,6,"bN"],[0,7,"bR"],
                                [1,0,"bP"],[1,1,"bP"],[1,2,"bP"],[1,3,"bP"],[1,4,"bP"],[1,5,"bP"],[1,6,"bP"],[1,7,"bP"],
                                [6,0,"wP"],[6,1,"wP"],[6,2,"wP"],[6,3,"wP"],[6,4,"wP"],[6,5,"wP"],[6,6,"wP"],[6,7,"wP"],
                                [7,0,"wR"],[7,1,"wN"],[7,2,"wB"],[7,3,"wQ"],[7,4,"wK"],[7,5,"wB"],[7,6,"wN"],[7,7,"wR"]
                            ]

                            Item {
                                width:  previewOuter.boardSz
                                height: previewOuter.boardSz
                                anchors.centerIn: parent

                                // Board: single stretched image
                                Image {
                                    anchors.fill: parent
                                    source: assetsPath + "/board/"
                                            + root.boardThemes[root.selectedBoardIdx] + "/"
                                            + root.boardThemes[root.selectedBoardIdx] + ".png"
                                    fillMode: Image.Stretch; smooth: true
                                }

                                // Pieces
                                Repeater {
                                    model: previewOuter.startPieces
                                    Image {
                                        required property var modelData
                                        x: modelData[1] * previewOuter.cellSz
                                        y: modelData[0] * previewOuter.cellSz
                                        width:  previewOuter.cellSz
                                        height: previewOuter.cellSz
                                        source: assetsPath + "/piece/"
                                                + root.pieceThemes[root.selectedPieceIdx]
                                                + "/64x64/" + modelData[2] + ".png"
                                        fillMode: Image.PreserveAspectFit; smooth: true
                                    }
                                }
                            }
                        }
                    }
                }



                // ── Engine page ───────────────────────────────────────────
                ColumnLayout {
                    spacing: root.sp + 4

                    Column {
                        Layout.fillWidth: true
                        spacing: root.sp
                        Text { text: "Chess engine"; color: root.textSecondary; font.pixelSize: root.fsS; font.bold: true }
                        Text {
                            text: "Leave blank to use the built-in Stockfish."
                            color: root.textDim; font.pixelSize: root.fsS
                            wrapMode: Text.WordWrap; width: parent.width
                        }
                        RowLayout {
                            width: parent.width; spacing: root.sp
                            TextField {
                                id: enginePathField
                                Layout.fillWidth: true
                                text: root.enginePath
                                placeholderText: "Default (built-in Stockfish)"
                                color: root.textPrimary; placeholderTextColor: "#666"
                                font.pixelSize: root.fs
                                background: Rectangle { color: root.itemColor; radius: 4; border.color: root.borderColor }
                                onTextChanged: root.enginePath = text
                            }
                            Button {
                                text: "Browse"; width: 80; height: enginePathField.height
                                onClicked: engineFileDlg.open()
                                background: Rectangle { color: parent.hovered ? root.hoverColor : root.itemColor; radius: 4; border.color: root.borderColor }
                                contentItem: Text { text: parent.text; color: root.textPrimary; horizontalAlignment: Text.AlignHCenter; font.pixelSize: root.fs }
                            }
                        }
                        Text {
                            visible: root.enginePathError !== ""
                            text: root.enginePathError
                            color: "#ff7777"; font.pixelSize: root.fsS
                            wrapMode: Text.WordWrap; width: parent.width
                        }
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: root.sp
                        Text { text: "Engine threads"; color: root.textSecondary; font.pixelSize: root.fsS; font.bold: true }
                        Text {
                            text: "Number of CPU threads for the engine. Set to 0 for automatic."
                            color: root.textDim; font.pixelSize: root.fsS
                            wrapMode: Text.WordWrap; width: parent.width
                        }
                        RowLayout {
                            spacing: root.sp
                            SpinBox {
                                id: threadSpinBox
                                from: 0; to: 256; value: root.engineThreads
                                onValueChanged: root.engineThreads = value
                                background: Rectangle { color: root.itemColor; radius: 4; border.color: root.borderColor; implicitWidth: Math.round(root.squareSize * 1.8); implicitHeight: Math.round(root.squareSize * 0.44) }
                                contentItem: TextInput {
                                    text: threadSpinBox.textFromValue(threadSpinBox.value, threadSpinBox.locale)
                                    font.pixelSize: root.fs; color: root.textPrimary
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                    readOnly: !threadSpinBox.editable
                                    validator: threadSpinBox.validator
                                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                                }
                                up.indicator:   Rectangle { x: threadSpinBox.mirrored ? 0 : parent.width - width; height: parent.height; width: Math.round(root.squareSize * 0.44); color: threadSpinBox.up.pressed ? root.hoverColor : root.itemColor; radius: 4; border.color: root.borderColor; Text { text: "+"; anchors.centerIn: parent; color: root.textPrimary; font.pixelSize: root.fs } }
                                down.indicator: Rectangle { x: threadSpinBox.mirrored ? parent.width - width : 0;  height: parent.height; width: Math.round(root.squareSize * 0.44); color: threadSpinBox.down.pressed ? root.hoverColor : root.itemColor; radius: 4; border.color: root.borderColor; Text { text: "-"; anchors.centerIn: parent; color: root.textPrimary; font.pixelSize: root.fs } }
                            }
                            Text { text: threadSpinBox.value === 0 ? "(auto)" : "thread" + (threadSpinBox.value === 1 ? "" : "s"); color: root.textDim; font.pixelSize: root.fsS; Layout.alignment: Qt.AlignVCenter }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // ── Cancel / Apply ────────────────────────────────────────────
            Row {
                id: btnRow
                anchors { bottom: parent.bottom; right: parent.right
                          bottomMargin: root.sp + 4; rightMargin: root.sp * 2 }
                spacing: root.sp
                Button {
                    text: "Cancel"; width: root.btnW; height: root.btnH
                    onClicked: root.close()
                    background: Rectangle { color: parent.hovered ? root.hoverColor : root.itemColor; radius: 4; border.color: root.borderColor }
                    contentItem: Text { text: parent.text; color: root.textPrimary; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: root.fs }
                }
                Button {
                    text: "Apply"; width: root.btnW; height: root.btnH
                    onClicked: { root.applied(); root.close() }
                    background: Rectangle { color: parent.hovered ? root.accentHover : root.accentColor; radius: 4 }
                    contentItem: Text { text: parent.text; color: root.textPrimary; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: root.fs }
                }
            }
        }
    }

    FileDialog {
        id: engineFileDlg
        title: "Select engine executable"
        onAccepted: {
            enginePathField.text = selectedFile.toString().replace("file://", "")
        }
    }
}

