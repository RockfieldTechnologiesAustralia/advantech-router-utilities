#!/usr/bin/env python3
import argparse
import shutil
from pathlib import Path


def generate_indexes(src: Path, dest: Path):
    dest.mkdir(parents=True, exist_ok=True)
    top_index = ["<html><body><h1>Available Versions</h1><ul>"]

    for versiondir in sorted(src.iterdir()):
        if not versiondir.is_dir():
            continue
        version = versiondir.name
        print(f"Processing python package distribution version: {version}")
        version_simple = dest / version / "simple"
        version_simple.mkdir(parents=True, exist_ok=True)

        top_index.append(f'<li><a href="{version}/simple/">{version}</a></li>')

        for pkgdir in sorted(versiondir.iterdir()):
            if not pkgdir.is_dir():
                continue
            pkgname = pkgdir.name
            print(f"  Found package: {pkgname}")
            pkg_simple = version_simple / pkgname
            pkg_simple.mkdir(parents=True, exist_ok=True)

            index_lines = [f"<html><body><h1>{pkgname}</h1>"]
            for whl in sorted(pkgdir.glob("*.whl")):
                dest_whl = pkg_simple / whl.name
                print(f"    Copying wheel '{whl.name}' into '{dest_whl}'")
                shutil.copy2(whl, dest_whl)
                index_lines.append(f'<a href="{whl.name}">{whl.name}</a><br/>')
            index_lines.append("</body></html>")
            (pkg_simple / "index.html").write_text("\n".join(index_lines))

    top_index.append("</ul></body></html>")
    (dest / "index.html").write_text("\n".join(top_index))

def main():
    parser = argparse.ArgumentParser(description="Generate PEP503 simple indexes for wheels")
    parser.add_argument("src", help="Source directory containing versioned wheel folders")
    parser.add_argument("dest", help="Destination directory to write HTML indexes and wheels")
    args = parser.parse_args()

    src = Path(args.src)
    dest = Path(args.dest)

    if not src.exists():
        raise SystemExit(f"Source directory {src} does not exist")

    generate_indexes(src, dest)

if __name__ == "__main__":
    main()
