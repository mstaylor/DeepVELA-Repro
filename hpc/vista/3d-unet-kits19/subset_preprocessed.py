import argparse
import os
import pickle
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--target", required=True)
    parser.add_argument("--cases", nargs="+", required=True)
    return parser.parse_args()


def main():
    args = parse_args()
    source, target = Path(args.source), Path(args.target)
    with open(source / "preprocessed_files.pkl", "rb") as f:
        content = pickle.load(f)
    missing = [c for c in args.cases if c not in content["cases"]]
    if missing:
        raise SystemExit("cases not in preprocessed data: {}".format(missing))
    (target / "nifti").mkdir(parents=True, exist_ok=True)
    for case in args.cases:
        for link, real in ((target / f"{case}.pkl", source / f"{case}.pkl"),
                           (target / "nifti" / case, source / "nifti" / case)):
            if not link.exists():
                os.symlink(real, link)
    subset = {"file_list": list(args.cases),
              "cases": {c: content["cases"][c] for c in args.cases}}
    with open(target / "preprocessed_files.pkl", "wb") as f:
        pickle.dump(subset, f)
    print("subset of {} cases written to {}".format(len(args.cases), target))


if __name__ == "__main__":
    main()