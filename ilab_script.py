#!/usr/bin/env python3
"""
ilab_script.py — runs on ilab.cs.rutgers.edu

Takes a SELECT SQL query as a command-line argument (or from stdin if no
argument is given), runs it against the Rutgers Postgres instance, and
prints a well-formatted table of results.

Usage (on ilab):
    python3 ilab_script.py "SELECT COUNT(*) FROM Application;"

Requirements (install with pip3 on ilab):
    pip3 install psycopg2-binary pandas tabulate --user
"""

import sys
import os
from dotenv import load_dotenv

import psycopg2
import pandas as pd
from tabulate import tabulate


# ─── Database connection settings ─────────────────────────────────────────────

load_dotenv()  # loads .env from the same directory

DB_HOST     = os.getenv("DB_HOST")
DB_PORT     = int(os.getenv("DB_PORT", 5432))
DB_NAME     = os.getenv("DB_NAME")
DB_USER     = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")

# ─── Get the query ─────────────────────────────────────────────────────────────

def get_query() -> str:
    """
    Accept the SQL query either as the first command-line argument
    or from stdin (for optional stdin support described in the project spec).
    """
    if len(sys.argv) > 1:
        # Passed as a quoted argument from database_llm.py via SSH
        return " ".join(sys.argv[1:]).strip()
    elif not sys.stdin.isatty():
        # Reading from stdin (optional path mentioned in the spec)
        return sys.stdin.read().strip()
    else:
        print("Usage: python3 ilab_script.py \"SELECT ...\"")
        sys.exit(1)


# ─── Safety check ─────────────────────────────────────────────────────────────

def is_safe_select(query: str) -> bool:
    """
    Only allow SELECT statements — reject anything that could
    mutate the database (INSERT, UPDATE, DROP, etc.).
    """
    first_word = query.strip().split()[0].upper()
    return first_word == "SELECT"


# ─── Run query and print results ───────────────────────────────────────────────

def run_query(query: str) -> None:
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            connect_timeout=10,
        )
    except psycopg2.OperationalError as e:
        print(f"[DB Connection Error] Could not connect to {DB_HOST}:")
        print(f"  {e}")
        sys.exit(1)

    try:
        # Use pandas to fetch results — handles column names automatically
        cursor = conn.cursor()
        cursor.execute(query)
        rows = cursor.fetchall()
        cols = [desc[0] for desc in cursor.description]
        df = pd.DataFrame(rows, columns=cols)

        if df.empty:
            print("Query returned 0 rows.")
            return

        # Print a clean, aligned table using tabulate
        # "psql" format matches what you'd see in the psql CLI
        print(tabulate(df, headers="keys", tablefmt="psql", showindex=False))
        print(f"\n({len(df)} row{'s' if len(df) != 1 else ''})")

    except Exception as e:
        print(f"[Query Error] {e}")
        sys.exit(1)

    finally:
        conn.close()


# ─── Main ──────────────────────────────────────────────────────────────────────

def main():
    query = get_query()

    if not query:
        print("[Error] Empty query received.")
        sys.exit(1)

    if not is_safe_select(query):
        print(f"[Error] Only SELECT queries are allowed. Received: {query[:80]}")
        sys.exit(1)

    run_query(query)


if __name__ == "__main__":
    main()