import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

Item {
  id: root

  property var bar: null
  property string moduleName: "sync-tries"
  property var settings: null

  property string statusText: "🟢 2/2"
  property string statusTooltip: "Centro de Sincronización"
  property bool isSyncing: false
  property var syncItems: []
  property bool popupOpen: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: proc
    command: ["/home/tanjiro/.local/bin/sync-hub-bar"]
    stdout: StdioCollector {
      id: collector
      waitForEnd: true
      onStreamFinished: {
        try {
          var raw = collector.text || ""
          var clean = String(raw).trim()
          if (clean.startsWith("{") && clean.endsWith("}")) {
            var data = JSON.parse(clean)
            root.statusText = data.text || "🟢"
            root.statusTooltip = data.tooltip || "Centro de Sincronización"
            root.isSyncing = (data.class && data.class.indexOf("syncing") !== -1)
            root.syncItems = data.items || []
          }
        } catch (err) {
          // ignore parsing error
        }
      }
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!proc.running) {
        proc.running = true
      }
    }
  }

  Component.onCompleted: {
    if (!proc.running) proc.running = true
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.statusText
    tooltipText: root.statusTooltip
    active: root.isSyncing
    fontSize: Style.font.body
    horizontalMargin: 8

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) {
        Quickshell.execDetached(["foot", "-e", "bash", "-c", "sync-status; echo; read -p 'Presiona Enter para cerrar...'"])
      } else {
        root.popupOpen = !root.popupOpen
      }
    }
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(380))
    contentHeight: popup.fittedContentHeight(mainColumn.implicitHeight)

    Column {
      id: mainColumn
      width: parent.width
      spacing: Style.space(12)

      // Cabecera
      Row {
        width: parent.width
        spacing: Style.space(10)

        Text {
          text: "☁️"
          font.pixelSize: Style.font.title
          anchors.verticalCenter: parent.verticalCenter
        }

        Column {
          width: parent.width - Style.space(50)
          spacing: Style.space(2)

          Text {
            text: "Centro de Sincronización"
            font.pixelSize: Style.font.subtitle
            font.bold: true
            color: Color.foreground
          }

          Text {
            text: "Gestión unificada de respaldos y nube"
            font.pixelSize: Style.font.caption
            color: Color.muted
          }
        }
      }

      PanelSeparator {
        width: parent.width
      }

      // Lista de Tareas
      Column {
        width: parent.width
        spacing: Style.space(8)

        Repeater {
          model: root.syncItems

          delegate: BorderSurface {
            id: rowSurface
            required property var modelData
            width: parent.width
            implicitHeight: Style.space(62)
            radius: Style.cornerRadius
            color: Style.normalFill
            borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent)

            Row {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(10)

              // Icono
              Text {
                text: rowSurface.modelData.status_icon || "🟢"
                font.pixelSize: Style.font.title
                anchors.verticalCenter: parent.verticalCenter
              }

              // Info
              Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(120)
                spacing: Style.space(2)

                Row {
                  spacing: Style.space(6)
                  Text {
                    text: rowSurface.modelData.name || ""
                    font.pixelSize: Style.font.body
                    font.bold: true
                    color: Color.foreground
                  }
                  Text {
                    text: "• " + (rowSurface.modelData.status_text || "")
                    font.pixelSize: Style.font.caption
                    color: (rowSurface.modelData.status === "warning") ? Color.urgent : ((rowSurface.modelData.status === "syncing") ? Color.accent : Color.muted)
                  }
                }

                Text {
                  text: (rowSurface.modelData.path || "") + " ➔ " + (rowSurface.modelData.target || "")
                  font.pixelSize: Style.font.caption
                  color: Color.muted
                  elide: Text.ElideMiddle
                  width: parent.width
                }
              }

              // Botón individual de sync
              Button {
                anchors.verticalCenter: parent.verticalCenter
                text: "Sync"
                iconText: "󰑐"
                horizontalPadding: Style.space(8)
                verticalPadding: Style.space(4)
                onClicked: {
                  if (rowSurface.modelData.cmd_sync) {
                    Quickshell.execDetached([rowSurface.modelData.cmd_sync])
                  }
                }
              }
            }
          }
        }
      }

      PanelSeparator {
        width: parent.width
      }

      // Botones de acción global
      Row {
        width: parent.width
        spacing: Style.space(8)

        Button {
          width: (parent.width - Style.space(8)) / 2
          text: "Sincronizar Todo"
          iconText: "󰑐"
          horizontalPadding: Style.space(10)
          onClicked: {
            Quickshell.execDetached(["/home/tanjiro/.local/bin/sync-all"])
          }
        }

        Button {
          width: (parent.width - Style.space(8)) / 2
          text: "Terminal"
          iconText: "󰞷"
          horizontalPadding: Style.space(10)
          onClicked: {
            root.popupOpen = false
            Quickshell.execDetached(["foot", "-e", "bash", "-c", "sync-status; echo; read -p 'Presiona Enter para cerrar...'"])
          }
        }
      }
    }
  }
}
