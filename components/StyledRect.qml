pragma ComponentBehavior: Bound

import QtQuick
import qs.services

Rectangle {
    color: Colours.palette.m3surfaceContainer

    Behavior on color {
        CAnim {}
    }
}
