# Sound packs

Event sounds for the shell (Settings → Sounds). Each folder is a pack: `<pack>/<event>.<ext>`, the events
are listed in `services/Sounds.qml`. A file of the same name in `~/.local/share/hi-shell/sounds/<pack>/` wins.

| Pack | Where the files come from | Rights |
| --- | --- | --- |
| `android` | AOSP, [platform_frameworks_base](https://github.com/aosp-mirror/platform_frameworks_base) `data/sounds` | Apache-2.0, The Android Open Source Project |
| `miui` | [p0358/magisk-miui-sounds](https://github.com/p0358/magisk-miui-sounds) | Xiaomi |
| `samsung` | [Magisk-Modules-Repo/OneUISounds](https://github.com/Magisk-Modules-Repo/OneUISounds) (One UI 1.1) | Samsung |
| `iphone` | [antoniomalheirs/Sound_And_Emoji_IOS](https://github.com/antoniomalheirs/Sound_And_Emoji_IOS) | Apple |
| `windows`, `win7`, `winxp` | [MCPlayer2015/all-windows-sounds](https://github.com/MCPlayer2015/all-windows-sounds) | Microsoft |

Except for `android`, these sounds are the property of their makers and are **not** covered by the
shell's licence (GPL-2.0). They are kept here for personal use, and a rights holder's request to remove
them is to be followed: delete the folder, the shell falls back to the system sound theme.
`sh/sound-packs.sh` fetches them again from the sources above.
