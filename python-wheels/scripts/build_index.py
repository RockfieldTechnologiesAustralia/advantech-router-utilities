#!/usr/bin/env python3
import argparse
import shutil
import re
from pathlib import Path


def normalize_pkgname(name: str) -> str:
    """PEP 503 normalization: lowercase and collapse -, _, . into -"""
    return re.sub(r"[-_.]+", "-", name).lower()


def generate_indexes(src: Path, dest: Path):
    dest.mkdir(parents=True, exist_ok=True)
    top_index = ["<html><body><h1>Available Versions</h1><ul>"]

    for versiondir in sorted(src.iterdir()):
        if not versiondir.is_dir():
            continue
        version = versiondir.name
        print(f"Processing python package distribution version: {version}")

        # Create version root and simple dir
        version_root = dest / version
        version_root.mkdir(parents=True, exist_ok=True)
        version_simple = version_root / "simple"
        version_simple.mkdir(parents=True, exist_ok=True)

        # Add link to top-level index
        top_index.append(f'<li><a href="{version}/simple/">{version}</a></li>')

        # Collect package links for mid-level index
        version_index_lines = [f"<html><body><h1>Packages for {version}</h1><ul>"]

        for pkgdir in sorted(versiondir.iterdir()):
            if not pkgdir.is_dir():
                continue
            pkgname = pkgdir.name
            normname = normalize_pkgname(pkgname)
            print(f"  Found package: {pkgname} → normalized as {normname}")

            pkg_simple = version_simple / normname
            pkg_simple.mkdir(parents=True, exist_ok=True)

            # Add link to version/simple index
            version_index_lines.append(f'<li><a href="{normname}/">{pkgname}</a></li>')

            # Build package index
            pkg_index_lines = [f"<html><body><h1>{pkgname}</h1>"]
            for whl in sorted(pkgdir.glob("*.whl")):
                dest_whl = pkg_simple / whl.name
                print(f"    Copying wheel '{whl.name}' into '{dest_whl}'")
                shutil.copy2(whl, dest_whl)
                pkg_index_lines.append(f'<a href="{whl.name}">{whl.name}</a><br/>')
            pkg_index_lines.append("</body></html>")
            (pkg_simple / "index.html").write_text("\n".join(pkg_index_lines))

        version_index_lines.append("</ul></body></html>")
        (version_simple / "index.html").write_text("\n".join(version_index_lines))

        # Also add an index.html at version root pointing to simple/
        (version_root / "index.html").write_text(
            f"<html><body><h1>{version}</h1><a href=\"simple/\">simple index</a></body></html>"
        )

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
