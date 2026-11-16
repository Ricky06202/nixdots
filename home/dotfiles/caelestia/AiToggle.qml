// Botón "IA local" para la zona de estado de la barra de Caelestia
// (donde van internet, bluetooth y batería).
//
// Se rellena y se ve nítido cuando llama-chat está activo; queda en outline
// atenuado cuando el modelo está apagado (GPU libre para juegos). Al hacer clic
// corre ~/.local/bin/ia-toggle, que prende/apaga Spark y avisa por notificación.
//
// Lo instala el postInstall del shell (flake.nix) en modules/bar/components/ y
// StatusIcons.qml lo registra como elemento "ai". El estado se consulta con
// `systemctl --user is-active` cada 8 s: no toca la GPU ni el modelo.
import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property color colour

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    property bool aiOn: false

    Process {
        id: check

        command: ["systemctl", "--user", "is-active", "llama-chat"]
        stdout: StdioCollector {
            onStreamFinished: root.aiOn = text.trim() === "active"
        }
        onExited: check.running = false
    }

    Timer {
        interval: 8000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!check.running)
            check.running = true
    }

    Process {
        id: toggle

        command: [Quickshell.env("HOME") + "/.local/bin/ia-toggle"]
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (toggle.running)
                return;
            toggle.running = true;
            // Optimista: ia-toggle tarda ~1 s en levantar el modelo. El Timer
            // corrige con el estado real en el próximo ciclo.
            root.aiOn = !root.aiOn;
        }
    }

    MaterialIcon {
        id: icon

        anchors.centerIn: parent

        text: "smart_toy"
        color: root.colour
        fontStyle: Tokens.font.icon.medium
        fill: root.aiOn ? 1 : 0
        opacity: root.aiOn ? 1 : 0.55
    }
}
