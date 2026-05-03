#!/usr/bin/env python3
"""
database_llm.py — runs locally.

Pipeline:
  1. Load schema_subset.sql as context for the LLM.
  2. Use Ollama to run Phi-4-mini locally (no llama-cpp-python needed).
  3. Accept natural language questions in a loop.
  4. Build a prompt (instructions + schema + question) and query the LLM.
  5. Extract the SELECT query from the LLM's raw output.
  6. Send the query over SSH (paramiko) to ilab_script.py on ilab.
  7. Print the returned table to the user.

Setup:
  1. Install Ollama:
       curl -fsSL https://ollama.com/install.sh | sh
  2. Pull Phi-4-mini:
       ollama pull phi4-mini
  3. Install Python dependencies:
       pip install paramiko requests

  Make sure Ollama is running before starting this script:
       ollama serve
"""

import re
import sys
import getpass
import requests
import paramiko
import os
from dotenv import load_dotenv

load_dotenv()

# ─── Configuration ────────────────────────────────────────────────────────────

SCHEMA_FILE  = "./schema_subset.sql"
OLLAMA_URL   = "http://localhost:11434/api/generate"
OLLAMA_MODEL = "qwen2.5:3b"
CONTEXT_SIZE = 2048
MAX_TOKENS   = 200
ILAB_HOST    = "ilab.cs.rutgers.edu"
ILAB_PORT    = 22
ILAB_SCRIPT  = os.getenv("ILAB_SCRIPT")   # loaded from .env


# ─── Step 1: Load schema once at startup ───────────────────────────────────────

def load_schema(path: str) -> str:
    try:
        with open(path, "r") as f:
            return f.read()
    except FileNotFoundError:
        print(f"[Error] Schema file not found: {path}")
        print("Make sure schema_subset.sql is in the same directory as this script.")
        sys.exit(1)


# ─── Step 2: Check Ollama is reachable ─────────────────────────────────────────

def check_ollama() -> None:
    """
    Verify Ollama is running and the qwen model is available
    before entering the main loop.
    """
    try:
        resp = requests.get("http://localhost:11434/api/tags", timeout=5)
        models = [m["name"] for m in resp.json().get("models", [])]
        # Check for phi4-mini under any tag variant
        if not any(OLLAMA_MODEL in m for m in models):
            print(f"[Error] Model '{OLLAMA_MODEL}' not found in Ollama.")
            print(f"  Run:  ollama pull {OLLAMA_MODEL}")
            sys.exit(1)
    except requests.exceptions.ConnectionError:
        print("[Error] Cannot connect to Ollama. Is it running?")
        print("  Start it with:  ollama serve")
        sys.exit(1)


# ─── Step 3: Build the prompt ──────────────────────────────────────────────────

def build_prompt(schema: str, question: str) -> str:
    return (
        "<|system|>\n"
        "You are an expert PostgreSQL query writer. "
        "Given a database schema and a natural language question, "
        "write a single valid SELECT SQL query that answers the question. "
        "You MUST only use tables and columns that exist in the schema below. "
        "Do NOT invent tables, columns, aliases, or placeholder values. "
        "Do NOT include comments, explanations, or markdown. "
        "Output ONLY the raw SQL query and nothing else.\n"
        "<|end|>\n"
        "<|user|>\n"
        f"-- Database schema:\n{schema}\n\n"
        "-- Examples of correct queries:\n"
        "-- Q: How many mortgages have a loan value greater than the applicant income?\n"
        "-- A: SELECT COUNT(*) FROM Application WHERE loan_amount_000s > applicant_income_000s;\n\n"
        "-- Q: What is the average income of owner occupied applications?\n"
        "-- A: SELECT AVG(applicant_income_000s) FROM Application WHERE owner_occupancy = 1;\n\n"
        "-- Q: What is the most common loan denial reason?\n"
        "-- A: SELECT denial_reason_name, COUNT(*) AS count FROM Denial JOIN Denial_Reason ON Denial.denial_reason = Denial_Reason.denial_reason GROUP BY denial_reason_name ORDER BY count DESC LIMIT 1;\n\n"
        f"-- Q: {question}\n"
        "<|end|>\n"
        "<|assistant|>\n"
        "SELECT "
    )


# ─── Step 4: Query Ollama ──────────────────────────────────────────────────────

def query_ollama(prompt: str) -> str:
    """
    Send the prompt to the locally running Ollama instance and
    return the model's raw text response.
    """
    try:
        response = requests.post(
            OLLAMA_URL,
            json={
                "model": OLLAMA_MODEL,
                "prompt": prompt,
                "stream": False,          # wait for full response
                "options": {
                    "num_ctx": CONTEXT_SIZE,
                    "num_predict": MAX_TOKENS,
                    "stop": [
                        "<|end|>",        # Phi-4 end token
                        "```\n",          # closing code fence
                        "\n\n\n",         # triple blank line = model rambling
                    ],
                },
            },
            timeout=120,                  # LLMs can be slow, give it 2 minutes
        )
        response.raise_for_status()
        return response.json()["response"]

    except requests.exceptions.Timeout:
        print("[Ollama Error] Request timed out. The model may be overloaded.")
        return ""
    except requests.exceptions.ConnectionError:
        print("[Ollama Error] Lost connection to Ollama. Is 'ollama serve' still running?")
        return ""
    except Exception as e:
        print(f"[Ollama Error] Unexpected error: {e}")
        return ""


# ─── Step 5: Extract only the SQL query from LLM output ───────────────────────

def extract_sql(llm_output: str) -> str | None:
    # Strip markdown code fences
    llm_output = re.sub(r"```sql", "", llm_output, flags=re.IGNORECASE)
    llm_output = re.sub(r"```", "", llm_output)
    llm_output = llm_output.replace("deny_reason_name", "denial_reason_name")
    llm_output = llm_output.replace("deny_reason", "denial_reason")
    llm_output = llm_output.replace("denyal_reason", "denial_reason")

    # Fix single-quoted aliases → double-quoted
    llm_output = re.sub(r"AS\s+'([^']+)'", r'AS "\1"', llm_output)

    # Remove ALL leading SELECT keywords (handles SELECTSELECT, SELECT SELECT, etc.)
    stripped = llm_output.strip()
    stripped = re.sub(r"^(SELECT\s*)+", "", stripped, flags=re.IGNORECASE).strip()

    # Strip leading opening paren from wrapped subqueries e.g. (SELECT ...
    stripped = re.sub(r"^\(\s*SELECT\s+", "", stripped, flags=re.IGNORECASE).strip()
    # Strip any lone trailing closing paren left behind
    stripped = re.sub(r"\)\s*$", "", stripped).strip()
    # Strip trailing ) AS alias_name left behind by subquery wrapping
    stripped = re.sub(r"\)\s*AS\s+\w+\s*$", "", stripped, flags=re.IGNORECASE).strip()

    # Then strip any remaining lone trailing )
    if stripped.count("(") < stripped.count(")"):
        stripped = re.sub(r"\)\s*$", "", stripped).strip()

    # Prepend exactly one clean SELECT
    full_text = "SELECT " + stripped

    # Strategy 1: content inside ```sql ... ``` or ``` ... ``` fences
    match = re.search(r"```(?:sql)?\s*(SELECT[\s\S]+?)```", full_text, re.IGNORECASE)
    if match:
        return match.group(1).strip()

    # Strategy 2: SELECT ... ; (stop at the first semicolon)
    match = re.search(r"(SELECT[\s\S]+?);", full_text, re.IGNORECASE)
    if match:
        return match.group(1).strip() + ";"

    # Strategy 3: everything from SELECT to end of text, strip trailing noise
    match = re.search(r"(SELECT[\s\S]+)", full_text, re.IGNORECASE)
    if match:
        candidate = match.group(1).strip()
        lines = candidate.splitlines()
        sql_lines = []
        for line in lines:
            if sql_lines and line.strip() == "":
                break
            sql_lines.append(line)
        return "\n".join(sql_lines).strip()

    return None


# ─── Step 6: SSH tunnel — send query to ilab, get back results ─────────────────

def run_query_on_ilab(sql: str, username: str, password: str) -> str:
    """
    Opens an SSH connection to ilab, invokes ilab_script.py with the SQL
    query as a command-line argument, and returns the printed output.
    """
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    try:
        client.connect(
            hostname=ILAB_HOST,
            port=ILAB_PORT,
            username=username,
            password=password,
            timeout=30,
        )

        # Escape the SQL so it survives being passed as a shell argument:
        #   - collapse newlines to spaces
        #   - escape any double-quotes inside the query
        safe_sql = sql.replace("\n", " ").replace('"', '\\"')
        command = f'{ILAB_SCRIPT} "{safe_sql}"'

        _, stdout, stderr = client.exec_command(command)

        output = stdout.read().decode("utf-8", errors="replace").strip()
        errors = stderr.read().decode("utf-8", errors="replace").strip()

        if errors:
            return f"[ilab stderr]:\n{errors}"
        if not output:
            return "[No output returned from ilab. The query may have returned 0 rows.]"
        return output

    except paramiko.AuthenticationException:
        return "[SSH Error] Authentication failed. Check your username and password."
    except paramiko.SSHException as e:
        return f"[SSH Error] Connection problem: {e}"
    except Exception as e:
        return f"[SSH Error] Unexpected error: {e}"
    finally:
        client.close()


# ─── Step 7: Main interactive loop ────────────────────────────────────────────

def main():
    print("=" * 60)
    print("  HMDA Mortgage Database — Natural Language Query Tool")
    print("  Powered by Qwen2.5-3B via Ollama")
    print("=" * 60)
    print()

    # Load schema once at startup
    schema = load_schema(SCHEMA_FILE)

    # Confirm Ollama is running and model is available before proceeding
    print("Checking Ollama connection...")
    check_ollama()
    print(f"Ollama is running. Model '{OLLAMA_MODEL}' is ready.\n")

    # Collect SSH credentials once, securely (password is hidden via getpass)
    print("Enter your ilab SSH credentials.")
    ilab_user = input("  ilab username: ").strip()
    ilab_pass = getpass.getpass("  ilab password: ")   # input is NOT echoed to terminal
    print()

    print('Ready! Type a question about the mortgage database, or "exit" to quit.')
    print("-" * 60)

    while True:
        # Get question from user
        try:
            question = input("\nYour question: ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nGoodbye.")
            break

        # Exit condition — must match exactly per the project spec
        if question == "exit":
            print("Goodbye.")
            break

        question = input("\nYour question: ").strip()
        if not question:
            continue

        # ── Steps 3 & 4: Build prompt and query Ollama ────────────────────────
        print("  [LLM] Generating SQL query...", end="", flush=True)

        prompt   = build_prompt(schema, question)
        raw_text = query_ollama(prompt)

        if not raw_text:
            print(" failed.")
            print("  Could not get a response from Ollama. Try again.")
            continue

        print(" done.")

        # Show the raw LLM output for transparency / debugging
        print(f"\n  [LLM raw output]:\n  {'SELECT' + raw_text!r}")

        # ── Step 5: Extract the SQL ────────────────────────────────────────────
        sql = extract_sql(raw_text)

        if sql is None:
            print("\n  [Error] Could not extract a SELECT query from the LLM response.")
            print("  Try rephrasing your question.")
            continue

        # Safety guard: only allow SELECT statements through the tunnel
        if not sql.strip().upper().startswith("SELECT"):
            print("\n  [Rejected] LLM produced a non-SELECT statement — skipping for safety.")
            print(f"  Statement was: {sql[:100]}")
            continue

        print(f"\n  [Extracted SQL]:\n  {sql}\n")

        # ── Steps 6 & 7: Send to ilab over SSH, display result ────────────────
        print("  [ilab] Sending query over SSH...")
        result = run_query_on_ilab(sql, ilab_user, ilab_pass)

        print("\n" + "=" * 60)
        print("RESULT:")
        print("=" * 60)
        print(result)
        print("=" * 60)


if __name__ == "__main__":
    main()