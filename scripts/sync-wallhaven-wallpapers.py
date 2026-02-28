#!/usr/bin/env python3
"""
Sync Wallhaven wallpapers for UmaOS and prepare a local manifest.

Default query: "uma musume" (SFW purity only).
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import shutil
import sys
import time
import urllib.parse
import urllib.request
from urllib.error import HTTPError, URLError
from dataclasses import dataclass
from pathlib import Path


API_URL = "https://wallhaven.cc/api/v1/search"
DEFAULT_QUERY = "uma musume"
USER_AGENT = "UmaOS-Wallhaven-Sync/1.0 (+https://github.com/pod32g/umaos)"
MAX_RETRIES = 8


@dataclass(frozen=True)
class Wallpaper:
    wallhaven_id: str
    width: int
    height: int
    url: str
    ext: str
    filename: str


@dataclass(frozen=True)
class FilterConfig:
    min_width: int
    min_height: int
    min_aspect: float
    max_aspect: float


def http_json(url: str) -> dict:
    delay = 1.5
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=60) as resp:
                return json.load(resp)
        except HTTPError as exc:
            if exc.code in {429, 500, 502, 503, 504} and attempt < MAX_RETRIES:
                retry_after = exc.headers.get("Retry-After")
                sleep_s = float(retry_after) if retry_after and retry_after.isdigit() else delay
                print(
                    f"[wallhaven] API retry {attempt}/{MAX_RETRIES} for {url} after HTTP {exc.code} (sleep {sleep_s:.1f}s)",
                    flush=True,
                )
                time.sleep(sleep_s)
                delay = min(delay * 2.0, 30.0)
                continue
            raise
        except URLError:
            if attempt < MAX_RETRIES:
                print(
                    f"[wallhaven] API retry {attempt}/{MAX_RETRIES} for {url} after network error (sleep {delay:.1f}s)",
                    flush=True,
                )
                time.sleep(delay)
                delay = min(delay * 2.0, 30.0)
                continue
            raise
    raise RuntimeError(f"Unable to fetch API data after retries: {url}")


def fetch_page(query: str, purity: str, page: int) -> dict:
    params = urllib.parse.urlencode(
        {
            "q": query,
            "purity": purity,
            "sorting": "favorites",
            "order": "desc",
            "page": str(page),
        }
    )
    return http_json(f"{API_URL}?{params}")


def normalize_item(item: dict) -> Wallpaper | None:
    wallhaven_id = str(item.get("id", "")).strip()
    url = str(item.get("path", "")).strip()
    width = int(item.get("dimension_x", 0) or 0)
    height = int(item.get("dimension_y", 0) or 0)
    if not wallhaven_id or not url:
        return None
    ext = Path(url).suffix.lower()
    if ext not in {".jpg", ".jpeg", ".png", ".webp"}:
        return None
    filename = f"wh-{wallhaven_id}{ext}"
    return Wallpaper(
        wallhaven_id=wallhaven_id,
        width=width,
        height=height,
        url=url,
        ext=ext,
        filename=filename,
    )


def keep_wallpaper(wp: Wallpaper, filters: FilterConfig) -> bool:
    if wp.width < filters.min_width or wp.height < filters.min_height:
        return False
    if wp.height <= 0:
        return False
    ratio = wp.width / wp.height
    if ratio < filters.min_aspect or ratio > filters.max_aspect:
        return False
    return True


def collect_wallpapers(
    query: str,
    purity: str,
    filters: FilterConfig,
    max_pages: int = 0,
    sleep_s: float = 0.0,
) -> tuple[list[Wallpaper], dict]:
    first = fetch_page(query, purity, 1)
    meta = first.get("meta", {})
    last_page = int(meta.get("last_page", 1) or 1)
    total = int(meta.get("total", 0) or 0)
    per_page = int(meta.get("per_page", 24) or 24)
    if max_pages > 0:
        last_page = min(last_page, max_pages)

    by_id: dict[str, Wallpaper] = {}
    seen_total = 0

    def ingest(page_data: dict) -> None:
        nonlocal seen_total
        for item in page_data.get("data", []):
            wp = normalize_item(item)
            if wp is not None:
                seen_total += 1
            if wp is not None and keep_wallpaper(wp, filters):
                by_id[wp.wallhaven_id] = wp

    ingest(first)
    print(f"[wallhaven] total={total} per_page={per_page} pages={last_page}", flush=True)

    for page in range(2, last_page + 1):
        data = fetch_page(query, purity, page)
        ingest(data)
        if sleep_s > 0:
            time.sleep(sleep_s)
        if page % 10 == 0 or page == last_page:
            print(f"[wallhaven] fetched page {page}/{last_page}", flush=True)

    wallpapers = sorted(by_id.values(), key=lambda w: w.wallhaven_id)
    run_meta = {
        "query": query,
        "purity": purity,
        "filters": {
            "min_width": filters.min_width,
            "min_height": filters.min_height,
            "min_aspect": filters.min_aspect,
            "max_aspect": filters.max_aspect,
        },
        "total_reported": total,
        "wallpapers_seen": seen_total,
        "pages_fetched": last_page,
        "wallpapers_unique": len(wallpapers),
        "generated_at_unix": int(time.time()),
    }
    return wallpapers, run_meta


def download_one(images_dir: Path, wp: Wallpaper) -> tuple[str, str]:
    dst = images_dir / wp.filename
    if dst.exists() and dst.stat().st_size > 0:
        return "skip", wp.filename

    delay = 1.5
    for attempt in range(1, MAX_RETRIES + 1):
        tmp = dst.with_suffix(dst.suffix + ".part")
        try:
            req = urllib.request.Request(wp.url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=120) as resp, tmp.open("wb") as fh:
                shutil.copyfileobj(resp, fh)
            tmp.replace(dst)
            return "download", wp.filename
        except HTTPError as exc:
            if tmp.exists():
                tmp.unlink(missing_ok=True)
            if exc.code in {429, 500, 502, 503, 504} and attempt < MAX_RETRIES:
                retry_after = exc.headers.get("Retry-After")
                sleep_s = float(retry_after) if retry_after and retry_after.isdigit() else delay
                time.sleep(sleep_s)
                delay = min(delay * 2.0, 30.0)
                continue
            raise
        except URLError:
            if tmp.exists():
                tmp.unlink(missing_ok=True)
            if attempt < MAX_RETRIES:
                time.sleep(delay)
                delay = min(delay * 2.0, 30.0)
                continue
            raise


def download_wallpapers(images_dir: Path, wallpapers: list[Wallpaper], workers: int) -> None:
    images_dir.mkdir(parents=True, exist_ok=True)

    downloaded = 0
    skipped = 0
    failed = 0

    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(download_one, images_dir, wp): wp for wp in wallpapers}
        total = len(futures)
        for idx, future in enumerate(concurrent.futures.as_completed(futures), start=1):
            wp = futures[future]
            try:
                status, _ = future.result()
                if status == "download":
                    downloaded += 1
                else:
                    skipped += 1
            except Exception as exc:  # noqa: BLE001
                failed += 1
                print(f"[wallhaven] failed {wp.filename}: {exc}", file=sys.stderr, flush=True)

            if idx % 50 == 0 or idx == total:
                print(
                    f"[wallhaven] progress {idx}/{total} (downloaded={downloaded} skipped={skipped} failed={failed})",
                    flush=True,
                )

    if failed > 0:
        print(f"[wallhaven] completed with failures: {failed}", file=sys.stderr, flush=True)
    else:
        print("[wallhaven] download complete with no failures", flush=True)


def write_manifest(path: Path, wallpapers: list[Wallpaper]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as fh:
        fh.write("id\twidth\theight\text\tfilename\turl\n")
        for wp in wallpapers:
            fh.write(
                f"{wp.wallhaven_id}\t{wp.width}\t{wp.height}\t{wp.ext}\t{wp.filename}\t{wp.url}\n"
            )


def prune_non_manifest_images(images_dir: Path, wallpapers: list[Wallpaper]) -> int:
    if not images_dir.exists():
        return 0
    keep = {wp.filename for wp in wallpapers}
    removed = 0
    for file in images_dir.iterdir():
        if not file.is_file():
            continue
        if file.name in keep:
            continue
        file.unlink(missing_ok=True)
        removed += 1
    return removed


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Sync Uma Musume wallpapers from Wallhaven")
    parser.add_argument("--query", default=DEFAULT_QUERY, help="Wallhaven search query")
    parser.add_argument("--purity", default="100", help="Wallhaven purity filter (default: 100 SFW)")
    parser.add_argument(
        "--dest",
        default="assets/wallpapers/wallhaven",
        help="Destination root for manifest/images",
    )
    parser.add_argument(
        "--max-pages",
        type=int,
        default=0,
        help="Limit API pages for testing (0 means all pages)",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=8,
        help="Parallel download workers",
    )
    parser.add_argument(
        "--sleep",
        type=float,
        default=0.0,
        help="Delay between API page requests (seconds)",
    )
    parser.add_argument(
        "--metadata-only",
        action="store_true",
        help="Only write manifest/meta, skip image downloads",
    )
    parser.add_argument("--min-width", type=int, default=0, help="Minimum width to keep")
    parser.add_argument("--min-height", type=int, default=0, help="Minimum height to keep")
    parser.add_argument("--min-aspect", type=float, default=0.0, help="Minimum width/height aspect ratio")
    parser.add_argument("--max-aspect", type=float, default=999.0, help="Maximum width/height aspect ratio")
    parser.add_argument(
        "--prune-images",
        action="store_true",
        help="Delete local image files that are not in the filtered manifest",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    dest = Path(args.dest).resolve()
    images_dir = dest / "images"
    manifest_path = dest / "manifest.tsv"
    meta_path = dest / "search-meta.json"

    filters = FilterConfig(
        min_width=max(0, args.min_width),
        min_height=max(0, args.min_height),
        min_aspect=max(0.0, args.min_aspect),
        max_aspect=max(0.0, args.max_aspect),
    )
    if filters.max_aspect < filters.min_aspect:
        raise SystemExit("--max-aspect must be greater than or equal to --min-aspect")

    wallpapers, meta = collect_wallpapers(
        query=args.query,
        purity=args.purity,
        filters=filters,
        max_pages=max(0, args.max_pages),
        sleep_s=max(0.0, args.sleep),
    )
    write_manifest(manifest_path, wallpapers)
    meta_path.write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print(f"[wallhaven] wrote manifest: {manifest_path}", flush=True)
    print(f"[wallhaven] wrote metadata: {meta_path}", flush=True)

    if not args.metadata_only:
        download_wallpapers(images_dir, wallpapers, workers=max(1, args.workers))

    if args.prune_images:
        removed = prune_non_manifest_images(images_dir, wallpapers)
        print(f"[wallhaven] pruned {removed} image(s) not matching current filter", flush=True)

    print("[wallhaven] Umazing!", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
