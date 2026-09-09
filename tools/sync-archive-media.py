#!/usr/bin/env python3
"""
Sync archive media that exists on the old Linode Object Storage bucket but is
missing from the new self-hosted Garage S3 bucket.

Intended to run on the VPS (ssh dwal.in), not locally - both endpoints must be
reachable from wherever this runs, and large scans are streamed old -> new
without ever touching local disk.

Requires: boto3 (pip install boto3, or `pip install -r requirements.txt`)

Credentials are read from environment variables only - never hardcode them
here or in any git-tracked file:

  OLD_S3_ENDPOINT    (default: https://eu-central-1.linodeobjects.com - the generic
                     regional endpoint; do NOT use the bucket-specific vhost URL
                     Linode shows in its dashboard, boto3 prefixes the bucket name
                     onto whatever host is given here)
  OLD_S3_REGION      (default: eu-central-1)
  OLD_S3_BUCKET      (default: schooner-archive)
  OLD_S3_PREFIX      (default: archive)
  OLD_S3_ACCESS_KEY  (required)
  OLD_S3_SECRET_KEY  (required)

  NEW_S3_ENDPOINT    (default: https://s3.dwal.in)
  NEW_S3_REGION      (default: garage)
  NEW_S3_BUCKET      (default: archive.seapractic.ru)
  NEW_S3_PREFIX      (default: media)
  NEW_S3_ACCESS_KEY  (required)
  NEW_S3_SECRET_KEY  (required)

You can instead put these in a `.env` file next to this script (KEY=VALUE per
line, `#` comments allowed). It is loaded automatically if present, and is
git-ignored - see .env.example. Never commit real credentials.

Usage:
  python3 sync-archive-media.py                    # dry run, writes a report only
  python3 sync-archive-media.py --apply            # actually copy missing files
  python3 sync-archive-media.py --apply --workers 8
  python3 sync-archive-media.py --apply --limit 20 # smoke test on a few files first
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from pathlib import Path
from threading import Lock

try:
    import boto3
    from botocore.config import Config
except ImportError:
    sys.exit("boto3 is required: pip install boto3")


def load_dotenv(path: Path) -> None:
    if not path.is_file():
        return
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


load_dotenv(Path(__file__).with_name(".env"))


def env(name: str, default: str | None = None, required: bool = False) -> str:
    value = os.environ.get(name, default)
    if required and not value:
        sys.exit(f"Missing required environment variable: {name}")
    return value


@dataclass
class Endpoint:
    label: str
    endpoint_url: str
    region: str
    bucket: str
    prefix: str
    access_key: str
    secret_key: str

    def client(self):
        return boto3.client(
            "s3",
            endpoint_url=self.endpoint_url,
            region_name=self.region,
            aws_access_key_id=self.access_key,
            aws_secret_access_key=self.secret_key,
            config=Config(retries={"max_attempts": 5, "mode": "standard"}),
        )


def is_thumbnail_key(key: str) -> bool:
    return any(part.lower() == "thumbnails" for part in key.split("/"))


def list_objects(client, bucket: str, prefix: str):
    """Yield (key, size) for every real object under prefix (folder markers skipped)."""
    norm_prefix = prefix.rstrip("/") + "/"
    paginator = client.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=bucket, Prefix=norm_prefix):
        for obj in page.get("Contents", []):
            key = obj["Key"]
            if key.endswith("/"):
                continue  # zero-byte "folder" marker, not real content
            yield key, obj["Size"]


def relative_path(key: str, prefix: str) -> str:
    norm_prefix = prefix.rstrip("/") + "/"
    return key[len(norm_prefix):]


_print_lock = Lock()


def log(msg: str) -> None:
    with _print_lock:
        print(msg, flush=True)


def copy_object(old_client, old_bucket: str, old_key: str,
                 new_client, new_bucket: str, new_key: str,
                 expected_size: int, attempts: int = 3) -> None:
    last_err: Exception | None = None
    for attempt in range(1, attempts + 1):
        try:
            body = old_client.get_object(Bucket=old_bucket, Key=old_key)["Body"]
            new_client.upload_fileobj(body, new_bucket, new_key)
            head = new_client.head_object(Bucket=new_bucket, Key=new_key)
            if head["ContentLength"] != expected_size:
                raise IOError(
                    f"size mismatch after upload: expected {expected_size}, "
                    f"got {head['ContentLength']}"
                )
            return
        except Exception as exc:
            last_err = exc
            log(f"  retry {attempt}/{attempts} for {old_key}: {exc}")
            time.sleep(2 ** attempt)
    raise RuntimeError(f"failed to copy {old_key} after {attempts} attempts: {last_err}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--apply", action="store_true",
                         help="Actually copy missing files. Without this flag, "
                              "only compares and writes a report (dry run).")
    parser.add_argument("--workers", type=int, default=4,
                         help="Parallel copy workers (default: 4)")
    parser.add_argument("--limit", type=int, default=None,
                         help="Only copy the first N missing files (for smoke-testing)")
    parser.add_argument("--report", type=Path,
                         default=Path(__file__).with_name(
                             f"sync-report-{time.strftime('%Y%m%d-%H%M%S')}.json"),
                         help="Where to write the JSON report")
    args = parser.parse_args()

    old = Endpoint(
        label="old (Linode)",
        endpoint_url=env("OLD_S3_ENDPOINT", "https://eu-central-1.linodeobjects.com"),
        region=env("OLD_S3_REGION", "eu-central-1"),
        bucket=env("OLD_S3_BUCKET", "schooner-archive"),
        prefix=env("OLD_S3_PREFIX", "archive"),
        access_key=env("OLD_S3_ACCESS_KEY", required=True),
        secret_key=env("OLD_S3_SECRET_KEY", required=True),
    )
    new = Endpoint(
        label="new (Garage)",
        endpoint_url=env("NEW_S3_ENDPOINT", "https://s3.dwal.in"),
        region=env("NEW_S3_REGION", "garage"),
        bucket=env("NEW_S3_BUCKET", "archive.seapractic.ru"),
        prefix=env("NEW_S3_PREFIX", "media"),
        access_key=env("NEW_S3_ACCESS_KEY", required=True),
        secret_key=env("NEW_S3_SECRET_KEY", required=True),
    )

    old_client = old.client()
    new_client = new.client()

    log(f"Listing {new.label} bucket s3://{new.bucket}/{new.prefix} ...")
    new_sizes = {relative_path(key, new.prefix): size
                 for key, size in list_objects(new_client, new.bucket, new.prefix)}
    log(f"  found {len(new_sizes)} objects on destination")

    log(f"Listing {old.label} bucket s3://{old.bucket}/{old.prefix} ...")
    missing, mismatched = [], []
    ok_count = thumbnails_skipped = total_old = 0

    for key, size in list_objects(old_client, old.bucket, old.prefix):
        if is_thumbnail_key(key):
            thumbnails_skipped += 1
            continue
        total_old += 1
        rel = relative_path(key, old.prefix)
        dest_size = new_sizes.get(rel)
        if dest_size is None:
            missing.append({"key": key, "relative_path": rel, "size": size})
        elif dest_size != size:
            mismatched.append({"key": key, "relative_path": rel,
                                "old_size": size, "new_size": dest_size})
        else:
            ok_count += 1

    log(f"  source objects (excl. thumbnails): {total_old}")
    log(f"  thumbnails skipped: {thumbnails_skipped}")
    log(f"  already synced: {ok_count}")
    log(f"  missing on destination: {len(missing)}")
    log(f"  size mismatch (not auto-copied): {len(mismatched)}")

    to_copy = missing if args.limit is None else missing[:args.limit]
    copied, failed = [], []

    if not args.apply:
        log(f"\nDRY RUN - no files were copied. Re-run with --apply to copy "
            f"{len(to_copy)} missing file(s).")
    elif to_copy:
        log(f"\nCopying {len(to_copy)} file(s) with {args.workers} worker(s)...")

        def worker(item):
            new_key = f"{new.prefix.rstrip('/')}/{item['relative_path']}"
            copy_object(old_client, old.bucket, item["key"],
                        new_client, new.bucket, new_key, item["size"])
            return item

        with ThreadPoolExecutor(max_workers=args.workers) as pool:
            futures = {pool.submit(worker, item): item for item in to_copy}
            for done_count, future in enumerate(as_completed(futures), start=1):
                item = futures[future]
                try:
                    future.result()
                    copied.append(item)
                    log(f"[{done_count}/{len(to_copy)}] copied {item['relative_path']}")
                except Exception as exc:
                    failed.append({**item, "error": str(exc)})
                    log(f"[{done_count}/{len(to_copy)}] FAILED {item['relative_path']}: {exc}")

        log(f"\nCopied: {len(copied)}  Failed: {len(failed)}")
    else:
        log("\nNothing to copy.")

    report = {
        "old_bucket": f"s3://{old.bucket}/{old.prefix}",
        "new_bucket": f"s3://{new.bucket}/{new.prefix}",
        "total_source_objects": total_old,
        "thumbnails_skipped": thumbnails_skipped,
        "already_synced": ok_count,
        "missing_count": len(missing),
        "size_mismatch_count": len(mismatched),
        "applied": args.apply,
        "copied_count": len(copied),
        "failed_count": len(failed),
        "missing": missing,
        "size_mismatches": mismatched,
        "copied": copied,
        "failed": failed,
    }
    args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False))
    log(f"\nReport written to {args.report}")

    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
