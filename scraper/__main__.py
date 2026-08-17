"""
Entry point: python -m scraper

Runs both scraping and analysis in sequence,
or individual steps via subcommands.
"""

import argparse
import sys


def main():
    parser = argparse.ArgumentParser(
        prog="scraper",
        description=(
            "Ukrainian presidential speech scraper and securitisation "
            "discourse analyser (2018–2025)"
        ),
    )
    subparsers = parser.add_subparsers(dest="command")

    # Scrape subcommand
    sp_scrape = subparsers.add_parser("scrape", help="Scrape speeches from president.gov.ua")
    sp_scrape.add_argument("--category", choices=["speeches", "press_releases", "all"], default="all")
    sp_scrape.add_argument("--start", default="2018-01-01")
    sp_scrape.add_argument("--end", default="2025-12-31")
    sp_scrape.add_argument("--resume", action="store_true")

    # Analyse subcommand
    sp_analyse = subparsers.add_parser("analyse", help="Analyse scraped corpus")
    sp_analyse.add_argument("--corpus-dir", default="output/corpus")

    # Sample subcommand
    sp_sample = subparsers.add_parser("sample", help="Sample and inspect claims")
    sp_sample.add_argument("--claims-file", default="output/claims.json")
    sp_sample.add_argument("--category", default=None, help="Filter by coding category")
    sp_sample.add_argument("--term", default=None, help="Filter by matched term (substring)")
    sp_sample.add_argument("--n", type=int, default=5, help="Number of claims to show")
    sp_sample.add_argument("--random", action="store_true", help="Random sample (default: first N)")
    sp_sample.add_argument("--doc-id", default=None, help="Show claims from a specific document")

    # Verify subcommand — open a document's full text
    sp_verify = subparsers.add_parser("verify", help="View full text of a specific document")
    sp_verify.add_argument("doc_id", help="Document ID (from results)")
    sp_verify.add_argument("--corpus-dir", default="output/corpus")

    # Full run
    sp_run = subparsers.add_parser("run", help="Scrape + analyse in one go")
    sp_run.add_argument("--category", choices=["speeches", "press_releases", "all"], default="all")
    sp_run.add_argument("--start", default="2018-01-01")
    sp_run.add_argument("--end", default="2025-12-31")

    args = parser.parse_args()

    if args.command == "scrape":
        from .scrape import main as scrape_main
        sys.argv = ["scraper.scrape",
                     "--category", args.category,
                     "--start", args.start,
                     "--end", args.end]
        if args.resume:
            sys.argv.append("--resume")
        scrape_main()

    elif args.command == "analyse":
        from .analyse import main as analyse_main
        sys.argv = ["scraper.analyse", "--corpus-dir", args.corpus_dir]
        analyse_main()

    elif args.command == "sample":
        from .sample import main as sample_main
        sample_main(args)

    elif args.command == "verify":
        from .verify import verify_document
        verify_document(args.doc_id, args.corpus_dir)

    elif args.command == "run":
        from .scrape import main as scrape_main
        sys.argv = ["scraper.scrape",
                     "--category", args.category,
                     "--start", args.start,
                     "--end", args.end]
        scrape_main()
        from .analyse import main as analyse_main
        sys.argv = ["scraper.analyse"]
        analyse_main()

    else:
        parser.print_help()


if __name__ == "__main__":
    main()
