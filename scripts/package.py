#!/usr/bin/env python3
"""Build SpoonInstall metadata and reproducible archives from explicit source files."""
import json
import re
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

ROOT = Path(__file__).resolve().parents[1]
DESCRIPTIONS = {
    'AirPodsMeet': 'Mute or unmute Safari Google Meet with your AirPods and spoken confirmation.',
    'PasteToPicker': 'Attach a clipboard image through a native macOS file picker.',
    'PersonalSafari': 'Shift-click links into a chosen Safari window across desktops.',
    'SafariTabGroups': 'Search and switch tab groups in the current Safari window.',
    'TorrentToQbit': 'Choose a qBittorrent category for newly downloaded torrent files.',
}
FILES = ('init.lua', 'README.md', 'LICENSE', 'tests/test.lua', 'docs.json')
EXTRA_FILES = {
    'AirPodsMeet': ('sounds/README.md', 'sounds/LICENSE.txt', 'sounds/muted.wav', 'sounds/unmuted.wav'),
}


def main():
    catalog = []
    (ROOT / 'Spoons').mkdir(exist_ok=True)
    (ROOT / 'docs').mkdir(exist_ok=True)
    for name, description in DESCRIPTIONS.items():
        source = ROOT / 'Source' / f'{name}.spoon'
        code = (source / 'init.lua').read_text()
        version = re.search(r'''version\s*=\s*["']([^"']+)["']''', code)
        if not version:
            raise ValueError(f'Missing version: {name}')
        entry = {
            'name': name, 'desc': description, 'doc': description,
            'type': 'Module', 'items': [], 'version': version.group(1),
        }
        # Repository metadata for SpoonInstall. Full usage lives in each README.
        (source / 'docs.json').write_text(json.dumps([entry], indent=2) + '\n')
        catalog.append(entry)
        with ZipFile(ROOT / 'Spoons' / f'{name}.spoon.zip', 'w') as archive:
            for relative in FILES + EXTRA_FILES.get(name, ()):
                original = source / relative
                if original.is_symlink() or not original.is_file():
                    raise ValueError(f'Not a regular source file: {name}/{relative}')
                info = ZipInfo(f'{name}.spoon/{relative}', date_time=(1980, 1, 1, 0, 0, 0))
                info.create_system = 3
                info.external_attr = 0o100644 << 16
                info.compress_type = ZIP_DEFLATED
                archive.writestr(info, original.read_bytes())
        print(f'Packaged {name} {version.group(1)}')
    (ROOT / 'docs/docs.json').write_text(json.dumps(catalog, indent=2) + '\n')


if __name__ == '__main__':
    main()
