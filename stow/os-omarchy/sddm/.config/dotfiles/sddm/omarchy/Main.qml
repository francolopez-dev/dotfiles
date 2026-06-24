import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
  id: root
  width: 640
  height: 480
  color: "#101114"

  // Login clock format.
  // Example: 8:54 PM
  property string loginClockFormat: "h:mm AP"

  // Login date format.
  // Example: Tuesday, June 24
  property string loginDateFormat: "dddd, MMMM d"

  // User label shown above the password prompt.
  // The SDDM last-user value is the most reliable source here.
  property string userLabel: userModel.lastUser

  // Enable/disable hostname display.
  // Set to true for a small hostname label between date and username.
  property bool showHostname: false

  // Hostname label shown only when showHostname is true.
  // Example: nox
  property string hostnameLabel: "nox"

  property string currentUser: userModel.lastUser
  property bool loginFailed: false
  property date now: new Date()
  property int sessionIndex: {
    for (var i = 0; i < sessionModel.rowCount(); i++) {
      var name = (sessionModel.data(sessionModel.index(i, 0), Qt.DisplayRole) || "").toString()
      if (name.indexOf("uwsm") !== -1)
        return i
    }
    return sessionModel.lastIndex
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.now = new Date()
  }

  Connections {
    target: sddm
    function onLoginFailed() {
      root.loginFailed = true
      password.text = ""
      password.focus = true
    }
    function onLoginSucceeded() {
      root.loginFailed = false
    }
  }

  Column {
    anchors.centerIn: parent
    width: Math.min(parent.width * 0.86, 520)
    spacing: 18

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatTime(root.now, root.loginClockFormat)
      color: "#f5f5f7"
      font.family: "Sans Serif"
      font.pixelSize: Math.max(54, Math.min(root.width * 0.12, 84))
      font.weight: Font.Light
      horizontalAlignment: Text.AlignHCenter
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatDate(root.now, root.loginDateFormat)
      color: "#c7c8cc"
      font.family: "Sans Serif"
      font.pixelSize: 22
      font.weight: Font.Normal
      horizontalAlignment: Text.AlignHCenter
    }

    Text {
      visible: root.showHostname
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.hostnameLabel
      color: "#858895"
      font.family: "Sans Serif"
      font.pixelSize: 14
      font.capitalization: Font.AllUppercase
      letterSpacing: 1.4
      horizontalAlignment: Text.AlignHCenter
    }

    Item { width: 1; height: 10 }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.userLabel
      color: "#f5f5f7"
      font.family: "Sans Serif"
      font.pixelSize: 28
      font.weight: Font.Medium
      horizontalAlignment: Text.AlignHCenter
    }

    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.min(parent.width, 340)
      height: 48
      radius: 14
      color: root.loginFailed ? "#3a1f24" : "#1f2128"
      border.color: root.loginFailed ? "#ff6b7a" : "#3a3d48"
      border.width: 1

      TextInput {
        id: password
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        verticalAlignment: TextInput.AlignVCenter
        echoMode: TextInput.Password
        font.family: "Sans Serif"
        font.pixelSize: 18
        passwordCharacter: "\u2022"
        color: "#f5f5f7"
        selectionColor: "#4f7cff"
        selectedTextColor: "#ffffff"
        focus: true

        onTextChanged: root.loginFailed = false

        Keys.onPressed: {
          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            sddm.login(root.currentUser, password.text, root.sessionIndex)
            event.accepted = true
          }
        }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 18
        visible: password.text.length === 0 && !password.activeFocus
        text: "Password"
        color: "#858895"
        font.family: "Sans Serif"
        font.pixelSize: 16
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.loginFailed ? "Password incorrect. Try again." : ""
      color: "#ff8d9a"
      font.family: "Sans Serif"
      font.pixelSize: 13
      horizontalAlignment: Text.AlignHCenter
    }
  }

  Component.onCompleted: password.forceActiveFocus()
}
