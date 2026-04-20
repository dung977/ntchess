import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Window {
    id: mainWindow
    visible: true
    title: qsTr("ntchess")
    color: "#1e1e1e"

    // ── square size: closest available piece resolution to Screen.height/12 ──
    property int squareSize: { const s = [32,64,96,128,256,512,1024]; const t = Screen.height / 12; for (let i = 0; i < s.length; i++) if (s[i] >= t) return s[i]; return s[s.length-1] }
    readonly property string pieceSizeFolder: {
        const sizes = [32, 64, 96, 128, 256, 512, 1024]
        let best = sizes[0], bestDiff = Math.abs(squareSize - best)
        for (let sz of sizes) {
            const d = Math.abs(squareSize - sz)
            if (d < bestDiff) { best = sz; bestDiff = d }
        }
        return best + "x" + best
    }

    // panel is wider now to hold history, clocks, controls
    readonly property int boardPx: squareSize * 8
    readonly property int panelW:  Math.max(260, Math.round(squareSize * 4.5))
    readonly property int sp:      Math.round(squareSize * 0.18)  // small spacing unit

    width:  boardPx + panelW
    height: boardPx
    minimumWidth:  width;  maximumWidth:  width
    minimumHeight: height; maximumHeight: height

    // current theme state
    property string activeBoardTheme: "brown"
    property string activePieceTheme: "cburnett"

    // engine display name (updated once engine initialises)
    property string computerName: chessboard.engineName !== "" ? chessboard.engineName : "Computer"

    // ── screen state: "menu" | "playing" ────────────────────────────────────
    property string appScreen: "menu"

    // ── player info ────────────────────────────────────────────────────────────
    property string whitePlayerName: "White"
    property string blackPlayerName: "Black"
    property int    whitePlayerElo:  0
    property int    blackPlayerElo:  0
    property int    resignedSide:    -1  // -1=none, 0=white resigned, 1=black resigned

    // ── helpers ─────────────────────────────────────────────────────────────
    // piece enum (1-12) → small image url using 32x32 folder
    function smallPieceUrl(pid) {
        if (pid <= 0) return ""
        const names = ["","wK","wQ","wR","wB","wN","wP","bK","bQ","bR","bB","bN","bP"]
        return assetsPath + "/piece/" + activePieceTheme + "/32x32/" + names[pid] + ".png"
    }

    function formatClock(ms) {
        if (ms < 0) return "--:--"
        const clamped = Math.max(0, ms)
        const totalSec = Math.floor(clamped / 1000)
        const m = Math.floor(totalSec / 60)
        const s = totalSec % 60
        const base = (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
        if (clamped < 10000) {
            const t = Math.floor((clamped % 1000) / 100)
            return base + "." + t
        }
        return base
    }

    // ── Chess board (left side) ─────────────────────────────────────────────
    ChessBoard {
        id: chessboard
        x: 0; y: 0
        squareSize:      mainWindow.squareSize
        boardTheme:      mainWindow.activeBoardTheme
        pieceTheme:      mainWindow.activePieceTheme
        pieceSizeFolder: mainWindow.pieceSizeFolder
        interactive:     appScreen === "playing" && chessboard.atLatestMove

        onResigned: function(loserColor) {
            mainWindow.resignedSide = loserColor
        }
    }

    // ── Right panel ─────────────────────────────────────────────────────────
    Item {
        id: panel
        x: boardPx; y: 0
        width: panelW; height: boardPx

        Rectangle { anchors.fill: parent; color: "#252525" }

        // ══════════════════════════════════════════════════════════════════
        // MENU PANEL  (visible only in "menu" screen)
        // ══════════════════════════════════════════════════════════════════
        Item {
            id: menuPanel
            anchors.fill: parent
            visible: appScreen === "menu"

            // Centred menu buttons
            Column {
                anchors.centerIn: parent
                spacing: Math.round(squareSize * 0.28)
                width: parent.width - sp * 4

                Repeater {
                    model: [
                        { label: "New Game",         action: "newgame"  },
                        { label: "Analysis",         action: "analysis" },
                        { label: "Settings",         action: "settings" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width:  parent.width
                        height: Math.round(squareSize * 0.78)
                        radius: 6
                        color:  mBtnMa.containsMouse ? "#3d3d3d" : "#303030"
                        border.color: mBtnMa.containsMouse ? "#555" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData.label
                            font.pixelSize: Math.round(squareSize * 0.28)
                            color: "#ddd"
                        }

                        MouseArea {
                            id: mBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const a = parent.modelData.action
                                if (a === "newgame") {
                                    newGameDialog.open()
                                } else if (a === "vspc") {
                                    // shortcut: open new game dialog pre-set to vs computer
                                    newGameDialog.open()
                                } else if (a === "settings") {
                                    settingsDialog.open()
                                }
                                // analysis: future
                            }
                        }
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════════
        // GAME PANEL  (visible only in "playing" screen)
        // ══════════════════════════════════════════════════════════════════
        Item {
            id: gamePanel
            anchors.fill: parent
            visible: appScreen === "playing"

        // ── Top bar (floating overlay – does not consume layout space) ───
        Item {
            id: topBar
            anchors { top: parent.top; right: parent.right }
            width: Math.round(squareSize * 0.80)
            height: Math.round(squareSize * 0.78)
            z: 1

            // Hamburger / stripe menu button
            Item {
                id: stripeBtn
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: sp * 2 }
                width:  Math.round(squareSize * 0.30)
                height: Math.round(squareSize * 0.22)

                // three horizontal bars
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        x: 0
                        y: index * Math.round(stripeBtn.height / 2.5)
                        width:  stripeBtn.width
                        height: Math.round(squareSize * 0.04)
                        radius: height
                        color:  stripeMa.containsMouse ? "white" : "#aaa"
                    }
                }

                MouseArea {
                    id: stripeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panelMenu.open()
                }

                Menu {
                    id: panelMenu
                    y: stripeBtn.height + 4

                    background: Rectangle {
                        color: "#2a2a2a"
                        radius: 4
                        border.color: "#555"
                    }

                    MenuItem {
                        text: "Settings"
                        contentItem: Text { text: parent.text; color: "#ddd"; font.pixelSize: Math.round(squareSize * 0.2); leftPadding: 8 }
                        background: Rectangle { color: parent.highlighted ? "#3a3a3a" : "transparent" }
                        onTriggered: settingsDialog.open()
                    }
                    MenuItem {
                        text: "Back to Menu"
                        contentItem: Text { text: parent.text; color: "#ddd"; font.pixelSize: Math.round(squareSize * 0.2); leftPadding: 8 }
                        background: Rectangle { color: parent.highlighted ? "#3a3a3a" : "transparent" }
                        onTriggered: appScreen = "menu"
                    }
                }
            }
        }

        // ── Middle content: centred between topBar and bottomBar ──────────
        Item {
            id: middleArea
            anchors {
                top:    topBar.bottom
                bottom: bottomBar.top
                left:   parent.left
                right:  parent.right
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 0

                // ── Black player bar ───────────────────────────────────────
                PlayerBar {
                    id: blackBar
                    width: parent.width
                    height: Math.round(squareSize * 1.1)
                    capturesOnTop: true
                    isActive:    chessboard.currentTurn === 1 && chessboard.gameStatus === "ongoing"
                    hasClock:    chessboard.hasClock
                    remainingMs: chessboard.blackRemainingMs
                    capturedPieces:         chessboard.capturedByBlack
                    opponentCapturedPieces: chessboard.capturedByWhite
                    pieceSizeUrl:           smallPieceUrl
                    clockText:      mainWindow.formatClock(chessboard.blackRemainingMs)
                    playerName:     mainWindow.blackPlayerName
                    playerElo:      mainWindow.blackPlayerElo
                }

                // ── Move history ───────────────────────────────────────────
                Rectangle {
                    id: historyArea
                    width: parent.width - sp * 2
                    x: sp
                    height: Math.round(squareSize * 2.8)
                    color: "#1e1e1e"
                    radius: 4

                    ListView {
                        id: moveList
                        anchors { fill: parent; margins: 4 }
                        clip: true
                        model: Math.ceil(chessboard.moveHistorySan.length / 2)

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle {
                                implicitWidth: 6
                                radius: 3
                                color: "#4a7ae8"
                            }
                            background: Rectangle { color: "#333"; radius: 3 }
                        }

                        onCountChanged: positionViewAtEnd()

                        delegate: Rectangle {
                            required property int index
                            width:  moveList.width - (moveList.ScrollBar.vertical.visible ? 10 : 0)
                            height: Math.round(squareSize * 0.32)
                            color: index % 2 === 0 ? "#272727" : "#222222"
                            radius: 2

                            property int moveNum:  index + 1
                            property string wMove: chessboard.moveHistorySan[index * 2]     ?? ""
                            property string bMove: chessboard.moveHistorySan[index * 2 + 1] ?? ""

                            readonly property bool wIsLast: (index * 2)     === chessboard.moveHistorySan.length - 1
                            readonly property bool bIsLast: (index * 2 + 1) === chessboard.moveHistorySan.length - 1

                            RowLayout {
                                anchors { fill: parent; leftMargin: 6; rightMargin: 4 }
                                spacing: 4

                                Text {
                                    text: moveNum + "."
                                    color: "#666"
                                    font.pixelSize: Math.round(squareSize * 0.18)
                                    Layout.preferredWidth: Math.round(squareSize * 0.5)
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: parent.height - 4
                                    color: wIsLast ? "#3a5a3a" : "transparent"
                                    radius: 2
                                    Text {
                                        anchors.centerIn: parent
                                        text: wMove
                                        color: "white"
                                        font.pixelSize: Math.round(squareSize * 0.18)
                                        font.bold: wIsLast
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: parent.height - 4
                                    color: bIsLast ? "#3a5a3a" : "transparent"
                                    radius: 2
                                    Text {
                                        anchors.centerIn: parent
                                        text: bMove
                                        color: "#ddd"
                                        font.pixelSize: Math.round(squareSize * 0.18)
                                        font.bold: bIsLast
                                    }
                                }
                            }
                        }
                    }
                }

                // ── White player bar + result banner (tight together) ─────
                Column {
                    width: parent.width
                    spacing: 0

                PlayerBar {
                    id: whiteBar
                    width: parent.width
                    height: Math.round(squareSize * 1.1)
                    isActive:    chessboard.currentTurn === 0 && chessboard.gameStatus === "ongoing"
                    hasClock:    chessboard.hasClock
                    remainingMs: chessboard.whiteRemainingMs
                    capturedPieces:         chessboard.capturedByWhite
                    opponentCapturedPieces: chessboard.capturedByBlack
                    pieceSizeUrl:           smallPieceUrl
                    clockText:      mainWindow.formatClock(chessboard.whiteRemainingMs)
                    playerName:     mainWindow.whitePlayerName
                    playerElo:      mainWindow.whitePlayerElo
                }

                // ── Result banner ──────────────────────────────────────────
                Item {
                    id: resultBar
                    width: parent.width
                    height: (chessboard.gameStatus !== "ongoing" || mainWindow.resignedSide >= 0)
                        ? Math.round(squareSize * 1.2) : 0
                    visible: height > 0

                    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: {
                                const s = chessboard.gameStatus
                                const loser = chessboard.currentTurn
                                if (mainWindow.resignedSide >= 0) {
                                    const winner = mainWindow.resignedSide === 0 ? "Black" : "White"
                                    return winner + " wins by resignation"
                                }
                                if (s === "checkmate")       return (loser === 0 ? "Black" : "White") + " wins by checkmate"
                                if (s === "stalemate")       return "½–½  Stalemate"
                                if (s === "draw_repetition") return "½–½  Threefold repetition"
                                if (s === "draw_fifty")      return "½–½  Fifty-move rule"
                                if (s === "draw_material")   return "½–½  Insufficient material"
                                if (s === "timeout")         return (chessboard.currentTurn === 0 ? "Black" : "White") + " wins on time"
                                return ""
                            }
                            color: (chessboard.gameStatus === "checkmate" || chessboard.gameStatus === "timeout" || mainWindow.resignedSide >= 0) ? "#e8e8e8" : "#aaddaa"
                            font.pixelSize: Math.round(squareSize * 0.23)
                            font.bold: true
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width:  Math.round(squareSize * 1.4)
                            height: Math.round(squareSize * 0.32)
                            radius: 4
                            color:  copyPgnMa.containsMouse ? "#3a6a3a" : "#2e522e"
                            border.color: "#6ab46a"
                            border.width: 1

                            property bool copied: false

                            Text {
                                anchors.centerIn: parent
                                text: parent.copied ? "✓ Copied!" : "Copy PGN"
                                color: "white"
                                font.pixelSize: Math.round(squareSize * 0.17)
                            }

                            MouseArea {
                                id: copyPgnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const pgn = chessboard.gamePgn(
                                        mainWindow.whitePlayerName,
                                        mainWindow.blackPlayerName
                                    )
                                    chessboard.copyToClipboard(pgn)
                                    parent.copied = true
                                    copyPgnResetTimer.restart()
                                }
                            }

                            Timer {
                                id: copyPgnResetTimer
                                interval: 2000
                                onTriggered: parent.copied = false
                            }
                        }
                    }
                }
                } // inner Column (whiteBar + resultBar)
            } // Column
        } // middleArea


        // ── Bottom bar: nav + actions combined ────────────────────────────
        Rectangle {
            id: bottomBar
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: Math.round(squareSize * 0.78)
            color: "#222"

            RowLayout {
                anchors { fill: parent; leftMargin: sp; rightMargin: sp }
                spacing: 0

                // New game
                IconBtn {
                    text: "⊕"
                    tooltip: "New Game"
                    onBtnClicked: newGameDialog.open()
                    Layout.fillWidth: true
                }

                // Prev move
                IconBtn {
                    text: "←"
                    tooltip: "Previous move"
                    enabled: chessboard.viewMoveIndex > 0
                    onBtnClicked: chessboard.stepBack()
                    Layout.fillWidth: true
                }

                // Next move
                IconBtn {
                    text: "→"
                    tooltip: "Next move"
                    enabled: !chessboard.atLatestMove
                    onBtnClicked: chessboard.stepForward()
                    Layout.fillWidth: true
                }

                // Undo
                IconBtn {
                    text: "↩"
                    tooltip: "Take back"
                    enabled: chessboard.undoAllowed
                             && chessboard.atLatestMove
                             && chessboard.viewMoveIndex > 0
                             && chessboard.gameStatus === "ongoing"
                    onBtnClicked: chessboard.takeBack()
                    Layout.fillWidth: true
                }

                // Resign
                IconBtn {
                    text: "🏳"
                    tooltip: "Resign"
                    enabled: chessboard.gameStatus === "ongoing"
                    onBtnClicked: resignConfirmPopup.open()
                    Layout.fillWidth: true
                }
            }
        }
        } // end gamePanel
    } // end panel

    // ── Resign confirmation ─────────────────────────────────────────────────
    Popup {
        id: resignConfirmPopup
        modal: true; focus: true
        anchors.centerIn: parent
        width: 280; padding: 24
        background: Rectangle { color: "#2a2a2a"; radius: 8; border.color: "#555" }
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        Column {
            spacing: 20; width: parent.width
            Text {
                text: "Resign?"
                font.pixelSize: 16; font.bold: true; color: "white"
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: (chessboard.currentTurn === 0 ? "White" : "Black") + " will forfeit the game."
                color: "#aaa"; font.pixelSize: 12; wrapMode: Text.WordWrap; width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }
            Row {
                spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                Button {
                    text: "Cancel"; width: 100
                    onClicked: resignConfirmPopup.close()
                    background: Rectangle { color: parent.hovered ? "#555" : "#3a3a3a"; radius: 4; border.color: "#666" }
                    contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 13 }
                }
                Button {
                    text: "Resign"; width: 100
                    onClicked: { resignConfirmPopup.close(); chessboard.resign() }
                    background: Rectangle { color: parent.hovered ? "#aa4444" : "#884444"; radius: 4 }
                    contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 13 }
                }
            }
        }
    }

    // ── Settings dialog ─────────────────────────────────────────────────────
    SettingsDialog {
        id: settingsDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        squareSize: mainWindow.squareSize
        onOpened: {
            boardTheme      = mainWindow.activeBoardTheme
            pieceTheme      = mainWindow.activePieceTheme
            enginePath      = chessboard.enginePath
            enginePathError = chessboard.enginePathError
            engineThreads   = chessboard.engineThreads
        }
        onApplied: {
            mainWindow.activeBoardTheme = settingsDialog.boardTheme
            mainWindow.activePieceTheme = settingsDialog.pieceTheme
            chessboard.setEnginePath(settingsDialog.enginePath)
            chessboard.setEngineThreads(settingsDialog.engineThreads)
        }
    }

    // Update engine path error live while settings dialog is open
    Connections {
        target: chessboard
        function onEnginePathErrorChanged() {
            if (settingsDialog.visible)
                settingsDialog.enginePathError = chessboard.enginePathError
        }
        function onEngineNameChanged() {
            mainWindow.computerName = chessboard.engineName !== "" ? chessboard.engineName : "Computer"
            // Update running game player names if applicable
            if (mainWindow.whitePlayerName === "Computer" || mainWindow.whitePlayerName === mainWindow.computerName)
                mainWindow.whitePlayerName = mainWindow.computerName
            if (mainWindow.blackPlayerName === "Computer" || mainWindow.blackPlayerName === mainWindow.computerName)
                mainWindow.blackPlayerName = mainWindow.computerName
        }
        function onEngineNameBlackChanged() {
            if (chessboard.engineNameBlack !== "")
                mainWindow.blackPlayerName = chessboard.engineNameBlack
        }
    }

    // ── New game dialog ─────────────────────────────────────────────────────
    NewGameDialog {
        id: newGameDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        onStartGame: function(mode, playerColor, timeMsW, incMsW, timeMsB, incMsB, fen, allowUndo, eloWhite, eloBlack) {
            chessboard.newGame(fen)
            chessboard.undoAllowed = allowUndo
            mainWindow.resignedSide = -1
            if (timeMsW > 0 || timeMsB > 0)
                chessboard.configureClock(timeMsW, timeMsB, incMsW, incMsB)
            if (mode === 0) {         // Human vs Human
                chessboard.setComputerSide(-1)
                chessboard.setEngineElos(0, 0)
                mainWindow.whitePlayerName = "White"
                mainWindow.blackPlayerName = "Black"
                mainWindow.whitePlayerElo  = 0
                mainWindow.blackPlayerElo  = 0
            } else if (mode === 1) {  // Human vs Computer
                let humanColor = playerColor === 2
                    ? (Math.random() < 0.5 ? 0 : 1)
                    : playerColor
                let engineColor = 1 - humanColor
                let engineElo = eloWhite  // same value passed for both in HvC
                let wElo = (engineColor === 0) ? engineElo : 0
                let bElo = (engineColor === 1) ? engineElo : 0
                chessboard.setEngineElos(wElo, bElo)
                chessboard.setComputerSide(engineColor)
                if (humanColor === 0) {
                    mainWindow.whitePlayerName = "Player"
                    mainWindow.blackPlayerName = mainWindow.computerName
                } else {
                    mainWindow.whitePlayerName = mainWindow.computerName
                    mainWindow.blackPlayerName = "Player"
                }
                mainWindow.whitePlayerElo = wElo
                mainWindow.blackPlayerElo = bElo
            } else {                 // Computer vs Computer
                chessboard.setEngineElos(eloWhite, eloBlack)
                chessboard.setEnginePathWhiteGame(newGameDialog.whiteEnginePath)
                chessboard.setEnginePathBlack(newGameDialog.blackEnginePath)
                mainWindow.whitePlayerName = mainWindow.computerName
                mainWindow.blackPlayerName = mainWindow.computerName
                mainWindow.whitePlayerElo  = eloWhite
                mainWindow.blackPlayerElo  = eloBlack
                chessboard.setComputerSide(2)  // starts engines; onEngineNameBlackChanged will update blackPlayerName
            }
            appScreen = "playing"
        }
    }

    // ── Inline component: player bar ────────────────────────────────────────
    component PlayerBar: Item {
        id: pb

        property bool   isActive:      false
        property bool   hasClock:      false
        property int    remainingMs:   -1
        property var    capturedPieces: []
        property var    opponentCapturedPieces: []
        property var    pieceSizeUrl   // function(pid) -> url

        // material value of a piece id (Q=9 R=5 B=3 N=3 P=1)
        function pieceValue(pid) {
            var v = [0,0,9,5,3,3,1,0,9,5,3,3,1]
            return (pid >= 0 && pid <= 12) ? v[pid] : 0
        }

        // net material advantage: my captures minus opponent captures
        property int materialDiff: {
            var s = 0
            for (var i = 0; i < capturedPieces.length; i++)         s += pieceValue(capturedPieces[i])
            for (var j = 0; j < opponentCapturedPieces.length; j++)  s -= pieceValue(opponentCapturedPieces[j])
            return s
        }
        property string clockText:     ""
        property string playerName:    ""
        property int    playerElo:     0
        property bool   capturesOnTop: false

        // Main layout column, vertically centred in the bar
        Column {
            anchors {
                left:           parent.left
                leftMargin:     10
                right:          parent.right
                rightMargin:    6
                verticalCenter: parent.verticalCenter
            }
            spacing: 3

            // Captured pieces ABOVE clock (used when capturesOnTop = true)
            Item {
                id: captureRowTop
                visible: pb.capturesOnTop
                width:  visible ? Math.round(squareSize * 1.7) : 0
                height: visible ? captureIconSzTop : 0

                readonly property int captureIconSzTop: Math.round(squareSize * 0.26)
                readonly property int captureStepTop:   Math.round(squareSize * 0.08)

                property var captureGroupsTop: {
                    var order = [2,3,4,5,6,8,9,10,11,12]
                    var counts = {}
                    for (var i = 0; i < pb.capturedPieces.length; i++) {
                        var p = pb.capturedPieces[i]; counts[p] = (counts[p] || 0) + 1
                    }
                    var result = []
                    for (var j = 0; j < order.length; j++) { var pid = order[j]; if (counts[pid]) result.push({pid: pid, count: counts[pid]}) }
                    return result
                }

                Row {
                    spacing: Math.round(squareSize * 0.01)
                    anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: captureRowTop.captureGroupsTop
                        delegate: Item {
                            id: groupItemT
                            required property var modelData
                            width:  captureRowTop.captureIconSzTop + Math.max(0, modelData.count - 1) * captureRowTop.captureStepTop
                            height: captureRowTop.captureIconSzTop
                            Repeater {
                                model: groupItemT.modelData.count
                                delegate: Image {
                                    required property int index
                                    x: index * captureRowTop.captureStepTop
                                    width: captureRowTop.captureIconSzTop; height: captureRowTop.captureIconSzTop
                                    source: pb.pieceSizeUrl(groupItemT.modelData.pid)
                                    fillMode: Image.PreserveAspectFit; smooth: true
                                }
                            }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pb.materialDiff > 0
                        text: "+" + pb.materialDiff
                        color: "#aaa"; font.pixelSize: Math.round(squareSize * 0.19)
                        leftPadding: Math.round(squareSize * 0.03)
                    }
                }
            }

            // Top row: clock box + name/elo side by side
            Row {
                spacing: 8
                // Clock box
                Rectangle {
                    id: clockBox
                    visible: pb.hasClock
                    width:   Math.round(squareSize * 1.75)
                    height:  Math.round(squareSize * 0.6)
                    radius:  4
                    readonly property bool lowTime: pb.isActive && pb.remainingMs >= 0 && pb.remainingMs < 10000
                    color:        lowTime ? "#3a0a0a" : (pb.isActive ? "#1a3a1a" : "#1e1e1e")
                    border.color: lowTime ? "#cc3333"  : (pb.isActive ? "#6ab46a" : "#444")
                    border.width: pb.isActive ? 2 : 1

                    Text {
                        anchors.centerIn: parent
                        text:             pb.clockText
                        font.pixelSize:   Math.round(squareSize * 0.36)
                        font.family:      "Monospace"
                        font.bold:        pb.isActive
                        color:            clockBox.lowTime ? "#ff6666" : (pb.isActive ? "#c8f0c8" : "#888")
                    }
                }

                // Name + elo, vertically centred next to clock
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Text {
                        text: pb.playerName
                        color: pb.isActive ? "#e8e8e8" : "#aaa"
                        font.pixelSize: Math.round(squareSize * 0.22)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        visible: pb.playerElo > 0
                        text: "(" + pb.playerElo + ")"
                        color: "#777"
                        font.pixelSize: Math.round(squareSize * 0.18)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Captured pieces BELOW clock (used when capturesOnTop = false)
            Item {
                id: captureRow
                visible: !pb.capturesOnTop
                width:  visible ? Math.round(squareSize * 1.7) : 0
                height: visible ? captureIconSz : 0

                readonly property int captureIconSz: Math.round(squareSize * 0.26)
                readonly property int captureStep:   Math.round(squareSize * 0.08)

                property var captureGroups: {
                    var order = [2,3,4,5,6,8,9,10,11,12]
                    var counts = {}
                    for (var i = 0; i < pb.capturedPieces.length; i++) {
                        var p = pb.capturedPieces[i]
                        counts[p] = (counts[p] || 0) + 1
                    }
                    var result = []
                    for (var j = 0; j < order.length; j++) {
                        var pid = order[j]
                        if (counts[pid]) result.push({pid: pid, count: counts[pid]})
                    }
                    return result
                }

                Row {
                    spacing: Math.round(squareSize * 0.01)
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: captureRow.captureGroups
                        delegate: Item {
                            id: groupItem
                            required property var modelData
                            width:  captureRow.captureIconSz + Math.max(0, modelData.count - 1) * captureRow.captureStep
                            height: captureRow.captureIconSz

                            Repeater {
                                model: groupItem.modelData.count
                                delegate: Image {
                                    required property int index
                                    x: index * captureRow.captureStep
                                    width:  captureRow.captureIconSz
                                    height: captureRow.captureIconSz
                                    source: pb.pieceSizeUrl(groupItem.modelData.pid)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }
                            }
                        }
                    }

                    // +N material advantage label
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pb.materialDiff > 0
                        text:    "+" + pb.materialDiff
                        color:   "#aaa"
                        font.pixelSize: Math.round(squareSize * 0.19)
                        font.bold: false
                        leftPadding: Math.round(squareSize * 0.03)
                    }
                }
            }
        }
    }

    // ── Inline component: icon button ───────────────────────────────────────
    component IconBtn: Item {
        id: ib
        property string text:    ""
        property string tooltip: ""
        property bool   enabled: true
        signal btnClicked()

        height: Math.round(squareSize * 0.65)
        Layout.fillWidth: true

        Rectangle {
            anchors.centerIn: parent
            width:  Math.round(squareSize * 0.65)
            height: Math.round(squareSize * 0.65)
            radius: Math.round(squareSize * 0.1)
            color:  ib.enabled && ibMa.containsMouse ? "#444" : "transparent"

            Text {
                anchors.centerIn: parent
                text:             ib.text
                font.pixelSize:   Math.round(squareSize * 0.32)
                color:            ib.enabled ? (ibMa.containsMouse ? "white" : "#bbb") : "#555"
            }
        }

        MouseArea {
            id: ibMa
            anchors.fill: parent
            hoverEnabled: true
            enabled:      ib.enabled
            cursorShape:  ib.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked:    ib.btnClicked()
        }

        // Simple tooltip
        ToolTip.visible:  ib.tooltip !== "" && ibMa.containsMouse
        ToolTip.text:     ib.tooltip
        ToolTip.delay:    600
    }
}

