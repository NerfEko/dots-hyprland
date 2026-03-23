#!/usr/bin/env python3
import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib
import requests
import threading
import time
import json

CIDER_API = "http://localhost:10767"
BUS_NAME = "org.mpris.MediaPlayer2.cider"
OBJECT_PATH = "/org/mpris/MediaPlayer2"


class MprisPlayer(dbus.service.Object):
    def __init__(self):
        dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
        self._bus = dbus.SessionBus()

        bus_name = dbus.service.BusName(BUS_NAME, bus=self._bus)
        super().__init__(bus_name, OBJECT_PATH)

        self._is_playing = False
        self._can_quit = False
        self._can_raise = False
        self._has_track_list = False
        self._identity = "Cider"
        self._desktop_entry = "cider"
        self._supported_uri_schemes = []
        self._supported_mime_types = []

        self._track_id = "/org/mpris/MediaPlayer2/TrackList/NoTrack"
        self._art_url = ""
        self._title = ""
        self._artist = ""
        self._album = ""
        self._length = 0
        self._position = 0
        self._shuffle = False
        self._loop_status = "None"

        self._poll_thread = threading.Thread(target=self._poll_cider)
        self._poll_thread.daemon = True
        self._poll_thread.start()

        self._mainloop = GLib.MainLoop()

    def _poll_cider(self):
        while True:
            try:
                resp = requests.get(
                    f"{CIDER_API}/api/v1/playback/now-playing", timeout=2
                )
                if resp.status_code == 200:
                    data = resp.json()
                    if data.get("status") == "ok" and "info" in data:
                        info = data["info"]
                        self._title = info.get("name", "")
                        self._artist = info.get("artistName", "")
                        self._album = info.get("albumName", "")
                        self._length = info.get("durationInMillis", 0) * 1000
                        self._position = info.get("currentPlaybackTime", 0)
                        self._shuffle = info.get("shuffleMode", 0) == 1
                        repeat = info.get("repeatMode", 0)
                        if repeat == 0:
                            self._loop_status = "None"
                        elif repeat == 1:
                            self._loop_status = "Track"
                        else:
                            self._loop_status = "Playlist"
                        self._art_url = (
                            info.get("artwork", {}).get("url", "")
                            if isinstance(info.get("artwork"), dict)
                            else ""
                        )

                        if self._art_url:
                            self._art_url = self._art_url.replace("{w}", "300").replace(
                                "{h}", "300"
                            )

                        resp2 = requests.get(
                            f"{CIDER_API}/api/v1/playback/is-playing", timeout=2
                        )
                        if resp2.status_code == 200:
                            self._is_playing = resp2.json().get("is_playing", False)

                        self._emit_changed()
            except:
                pass
            time.sleep(1)

    def _emit_changed(self):
        try:
            self.PropertiesChanged(
                "org.mpris.MediaPlayer2.Player",
                {
                    "PlaybackStatus": dbus.String(
                        "Playing" if self._is_playing else "Paused"
                    ),
                    "Position": dbus.Int64(int(self._position * 1000000)),
                    "Shuffle": dbus.Boolean(self._shuffle),
                    "LoopStatus": dbus.String(self._loop_status),
                    "Metadata": dbus.Dictionary(
                        {
                            "mpris:trackid": dbus.ObjectPath(self._track_id),
                            "mpris:length": dbus.Int64(self._length),
                            "mpris:artUrl": dbus.String(self._art_url),
                            "xesam:title": dbus.String(self._title),
                            "xesam:artist": dbus.Array(
                                [dbus.String(self._artist)], signature="s"
                            ),
                            "xesam:album": dbus.String(self._album),
                        },
                        signature="sv",
                    ),
                },
                [],
            )
        except Exception as e:
            pass

    @dbus.service.signal("org.mpris.MediaPlayer2.Player", signature="x")
    def Seeked(self, position):
        pass

    @dbus.service.method("org.mpris.MediaPlayer2", in_signature="", out_signature="")
    def Raise(self):
        self._can_raise = True

    @dbus.service.method("org.mpris.MediaPlayer2", in_signature="", out_signature="")
    def Quit(self):
        pass

    @dbus.service.method(
        "org.mpris.MediaPlayer2.Player", in_signature="", out_signature=""
    )
    def Next(self):
        try:
            requests.post(f"{CIDER_API}/api/v1/playback/next", timeout=2)
        except:
            pass

    @dbus.service.method(
        "org.mpris.MediaPlayer2.Player", in_signature="", out_signature=""
    )
    def Previous(self):
        try:
            requests.post(f"{CIDER_API}/api/v1/playback/previous", timeout=2)
        except:
            pass

    @dbus.service.method(
        "org.mpris.MediaPlayer2.Player", in_signature="", out_signature=""
    )
    def Pause(self):
        try:
            requests.post(f"{CIDER_API}/api/v1/playback/pause", timeout=2)
        except:
            pass

    @dbus.service.method(
        "org.mpris.MediaPlayer2.Player", in_signature="", out_signature=""
    )
    def PlayPause(self):
        try:
            requests.post(f"{CIDER_API}/api/v1/playback/playpause", timeout=2)
        except:
            pass

    @dbus.service.method(
        "org.mpris.MediaPlayer2.Player", in_signature="", out_signature=""
    )
    def Stop(self):
        try:
            requests.post(f"{CIDER_API}/api/v1/playback/stop", timeout=2)
        except:
            pass

    @dbus.service.method(
        "org.mpris.MediaPlayer2.Player", in_signature="", out_signature=""
    )
    def Play(self):
        try:
            requests.post(f"{CIDER_API}/api/v1/playback/play", timeout=2)
        except:
            pass

    @dbus.service.method(
        "org.mpris.MediaPlayer2.Player", in_signature="", out_signature=""
    )
    def Shuffle(self):
        try:
            requests.post(f"{CIDER_API}/api/v1/playback/toggle-shuffle", timeout=2)
        except:
            pass

    @dbus.service.method(
        "org.mpris.MediaPlayer2.Player", in_signature="d", out_signature=""
    )
    def Seek(self, offset):
        try:
            current = requests.get(
                f"{CIDER_API}/api/v1/playback/now-playing", timeout=2
            ).json()
            if current.get("status") == "ok" and "info" in current:
                pos_ms = int(current["info"].get("currentPlaybackTime", 0) * 1000)
                new_pos = max(0, pos_ms + int(offset * 1000))
                requests.post(
                    f"{CIDER_API}/api/v1/playback/seek",
                    json={"position": new_pos / 1000},
                    timeout=2,
                )
        except:
            pass

    @dbus.service.method(
        "org.mpris.MediaPlayer2.Player", in_signature="", out_signature="d"
    )
    def PositionGet(self):
        return dbus.Int64(int(self._position * 1000000))

    @dbus.service.method(
        "org.mpris.MediaPlayer2.Player", in_signature="sx", out_signature=""
    )
    def SetPosition(self, track_id, position):
        try:
            requests.post(
                f"{CIDER_API}/api/v1/playback/seek",
                json={"position": position / 1000000},
                timeout=2,
            )
        except:
            pass

    @dbus.service.method(
        "org.mpris.MediaPlayer2.Player", in_signature="s", out_signature=""
    )
    def OpenUri(self, uri):
        try:
            if uri.startswith("http"):
                requests.post(
                    f"{CIDER_API}/api/v1/playback/play-url",
                    json={"url": uri},
                    timeout=2,
                )
        except:
            pass

    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature="ss", out_signature="v")
    def Get(self, interface, prop):
        if interface == "org.mpris.MediaPlayer2":
            if prop == "CanQuit":
                return dbus.Boolean(True)
            elif prop == "CanRaise":
                return dbus.Boolean(self._can_raise)
            elif prop == "HasTrackList":
                return dbus.Boolean(False)
            elif prop == "Identity":
                return dbus.String(self._identity)
            elif prop == "DesktopEntry":
                return dbus.String(self._desktop_entry)
            elif prop == "SupportedUriSchemes":
                return dbus.Array(self._supported_uri_schemes, signature="s")
            elif prop == "SupportedMimeTypes":
                return dbus.Array(self._supported_mime_types, signature="s")
        elif interface == "org.mpris.MediaPlayer2.Player":
            if prop == "PlaybackStatus":
                return dbus.String("Playing" if self._is_playing else "Paused")
            elif prop == "LoopStatus":
                return dbus.String(self._loop_status)
            elif prop == "Rate":
                return dbus.Double(1.0)
            elif prop == "Volume":
                return dbus.Double(1.0)
            elif prop == "Position":
                return dbus.Int64(int(self._position * 1000000))
            elif prop == "MinimumRate":
                return dbus.Double(1.0)
            elif prop == "MaximumRate":
                return dbus.Double(1.0)
            elif prop == "CanGoNext":
                return dbus.Boolean(True)
            elif prop == "CanGoPrevious":
                return dbus.Boolean(True)
            elif prop == "CanPlay":
                return dbus.Boolean(True)
            elif prop == "CanPause":
                return dbus.Boolean(True)
            elif prop == "CanSeek":
                return dbus.Boolean(True)
            elif prop == "CanControl":
                return dbus.Boolean(True)
            elif prop == "Shuffle":
                return dbus.Boolean(self._shuffle)
            elif prop == "Metadata":
                return dbus.Dictionary(
                    {
                        "mpris:trackid": dbus.ObjectPath(self._track_id),
                        "mpris:length": dbus.Int64(self._length),
                        "mpris:artUrl": dbus.String(self._art_url),
                        "xesam:title": dbus.String(self._title),
                        "xesam:artist": dbus.Array(
                            [dbus.String(self._artist)], signature="s"
                        ),
                        "xesam:album": dbus.String(self._album),
                    },
                    signature="sv",
                )
        raise dbus.exceptions.DBusException(f"Unknown property {prop}")

    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        if interface == "org.mpris.MediaPlayer2":
            return dbus.Dictionary(
                {
                    "CanQuit": dbus.Boolean(True),
                    "CanRaise": dbus.Boolean(self._can_raise),
                    "HasTrackList": dbus.Boolean(False),
                    "Identity": dbus.String(self._identity),
                    "DesktopEntry": dbus.String(self._desktop_entry),
                    "SupportedUriSchemes": dbus.Array(
                        self._supported_uri_schemes, signature="s"
                    ),
                    "SupportedMimeTypes": dbus.Array(
                        self._supported_mime_types, signature="s"
                    ),
                },
                signature="sv",
            )
        elif interface == "org.mpris.MediaPlayer2.Player":
            return dbus.Dictionary(
                {
                    "PlaybackStatus": dbus.String(
                        "Playing" if self._is_playing else "Paused"
                    ),
                    "LoopStatus": dbus.String(self._loop_status),
                    "Rate": dbus.Double(1.0),
                    "Volume": dbus.Double(1.0),
                    "Position": dbus.Int64(int(self._position * 1000000)),
                    "MinimumRate": dbus.Double(1.0),
                    "MaximumRate": dbus.Double(1.0),
                    "CanGoNext": dbus.Boolean(True),
                    "CanGoPrevious": dbus.Boolean(True),
                    "CanPlay": dbus.Boolean(True),
                    "CanPause": dbus.Boolean(True),
                    "CanSeek": dbus.Boolean(True),
                    "CanControl": dbus.Boolean(True),
                    "ShuffleSupported": dbus.Boolean(True),
                    "Shuffle": dbus.Boolean(self._shuffle),
                    "LoopSupported": dbus.Boolean(True),
                    "Loop": dbus.Boolean(self._loop_status == "Loop"),
                    "Metadata": dbus.Dictionary(
                        {
                            "mpris:trackid": dbus.ObjectPath(self._track_id),
                            "mpris:length": dbus.Int64(self._length),
                            "mpris:artUrl": dbus.String(self._art_url),
                            "xesam:title": dbus.String(self._title),
                            "xesam:artist": dbus.Array(
                                [dbus.String(self._artist)], signature="s"
                            ),
                            "xesam:album": dbus.String(self._album),
                        },
                        signature="sv",
                    ),
                },
                signature="sv",
            )
        raise dbus.exceptions.DBusException(f"Unknown interface {interface}")

    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature="ssv", out_signature="")
    def Set(self, interface, prop, value):
        if interface == "org.mpris.MediaPlayer2.Player":
            if prop == "Volume":
                try:
                    requests.post(
                        f"{CIDER_API}/api/v1/playback/volume",
                        json={"volume": float(value)},
                        timeout=2,
                    )
                except:
                    pass
            elif prop == "Shuffle":
                try:
                    requests.post(
                        f"{CIDER_API}/api/v1/playback/toggle-shuffle", timeout=2
                    )
                except:
                    pass
            elif prop == "LoopStatus":
                try:
                    if value == "None":
                        new_mode = 0
                        self._loop_status = "None"
                    elif value == "Track":
                        new_mode = 1
                        self._loop_status = "Track"
                    else:
                        new_mode = 2
                        self._loop_status = "Playlist"
                    requests.post(
                        f"{CIDER_API}/api/v1/playback/set-repeat",
                        json={"repeatMode": new_mode},
                        timeout=2,
                    )
                except:
                    pass

    @dbus.service.signal(dbus.PROPERTIES_IFACE, signature="sa{sv}as")
    def PropertiesChanged(self, interface, properties, invalidated):
        pass

    def run(self):
        self._mainloop.run()


if __name__ == "__main__":
    player = MprisPlayer()
    print("Cider MPRIS bridge started")
    player.run()
