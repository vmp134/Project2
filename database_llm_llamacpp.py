#!/usr/bin/env python3
"""
database_llm.py — runs locally.

Pipeline:
  1. Load schema_subset.sql as context for the LLM.
  2. Load Phi-4-mini-instruct (GGUF) via llama-cpp-python.
  3. Accept natural language questions in a loop.
  4. Build a prompt (instructions + schema + question) and query the LLM.
  5. Extract the SELECT query from the LLM's raw output.
  6. Send the query over SSH (paramiko) to ilab_script.py on ilab.
  7. Print the returned table to the user.

Requirements (install with pip):
    pip install llama-cpp-python huggingface_hub paramiko

Download the model once before running:
    python3 -c "
    from huggingface_hub import hf_hub_download
    hf_hub_download(
        repo_id='microsoft/Phi-4-mini-instruct-gguf',
        filename='Phi-4-mini-instruct-Q4_K_M.gguf',
        local_dir='./models'
    )"
"""

import re
import sys
import getpass

import paramiko
from llama_cpp import Llama


# ─── Configuration ─────────────────────────────────────────────────────────────

# Path to the downloaded GGUF model file
MODEL_PATH = "./models/Phi-4-mini-instruct-Q4_K_M.gguf"

# Subset SQL file fed to the LLM as schema context
SCHEMA_FILE = "./schema_subset.sql"

# ilab SSH settings
ILAB_HOST   = "ilab.cs.rutgers.edu"
ILAB_PORT   = 22

# Full path to ilab_script.py on the ilab machine (edit to match your ilab home dir)
ILAB_SCRIPT = "~/cs336/project3/ilab_script.py"

# LLM settings
CONTEXT_SIZE = 2048   # token context window (professor says 2048)
MAX_TOKENS   = 200    # max tokens the LLM will generate (professor says 200)


# ─── Step 1: Load schema once at startup ───────────────────────────────────────

def load_schema(path: str) -> str:
    try:
        with open(path, "r") as f:
            return f.read()
    except FileNotFoundError:
        print(f"[Error] Schema file not found: {path}")
        print("Make sure schema_subset.sql is in the same directory as this script.")
        sys.exit(1)


# ─── Step 2: Load Phi-4-mini ───────────────────────────────────────────────────

def load_model(model_path: str) -> Llama:
    print("Loading Phi-4-mini-instruct... (may take ~30 seconds the first time)")
    try:
        model = Llama(
            model_path=model_path,
            n_ctx=CONTEXT_SIZE,
            verbose=False,        # set True if you want llama.cpp debug output
        )
        print("Model loaded successfully.\n")
        return model
    except Exception as e:
        print(f"[Error] Failed to load model: {e}")
        print(f"Expected model at: {model_path}")
        print("Download it with huggingface_hub (see the docstring at the top of this file).")
        sys.exit(1)


# ─── Step 3: Build the prompt ──────────────────────────────────────────────────

def build_prompt(schema: str, question: str) -> str:
    """
    Phi-4-mini uses the ChatML format:
        <|system|> ... <|end|>
        <|user|>   ... <|end|>
        <|assistant|>

    Ending with ```sql nudges the model to immediately output SQL
    rather than explaining itself first (professor's tip).
    """
    return (
        "<|system|>\n"
        "You are an expert PostgreSQL query writer. "
        "Given a database schema and a natural language question, "
        "write a single valid SELECT SQL query that answers the question. "
        "Output ONLY the raw SQL query — no explanation, no markdown fences, "
        "no preamble, no extra text whatsoever.\n"
        "<|end|>\n"
        "<|user|>\n"
        f"-- Database schema:\n{schema}\n\n"
        f"-- Question: {question}\n"
        "<|end|>\n"
        "<|assistant|>\n"
        "SELECT"   # prime the model to start with SELECT immediately
    )


# ─── Step 5: Extract only the SQL query from LLM output ───────────────────────

def extract_sql(llm_output: str) -> str | None:
    """
    The LLM output may contain markdown, explanation text, or multiple
    statements. We try several strategies in order of preference to pull
    out exactly one clean SELECT query.
    """
    # The prompt already started with "SELECT", so prepend it back
    full_text = "SELECT" + llm_output

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
        # Cut off at any obvious non-SQL line (e.g. blank line or explanation)
        lines = candidate.splitlines()
        sql_lines = []
        for line in lines:
            # Stop if we hit a clearly non-SQL line after some SQL has been collected
            if sql_lines and line.strip() == "":
                break
            sql_lines.append(line)
        return "\n".join(sql_lines).strip()

    return None


# ─── Step 6: SSH tunnel — send query to ilab, get back results ─────────────────

def run_query_on_ilab(
    sql: str,
    username: str,
    password: str,
) -> str:
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
        command = f'python3 {ILAB_SCRIPT} "{safe_sql}"'

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


# ─── Step 4 & 7: Main interactive loop ────────────────────────────────────────

def main():
    print("=" * 60)
    print("  HMDA Mortgage Database — Natural Language Query Tool")
    print("  Powered by Phi-4-mini-instruct")
    print("=" * 60)
    print()

    # Load schema and model once at startup
    schema = load_schema(SCHEMA_FILE)
    llm    = load_model(MODEL_PATH)

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

        # Exit condition — must match exactly
        if question == "exit":
            print("Goodbye.")
            break

        if not question:
            continue

        # ── Step 3 & 4: Build prompt and run LLM ──────────────────────────────
        print("  [LLM] Generating SQL query...", end="", flush=True)

        prompt = build_prompt(schema, question)

        try:
            response = llm(
                prompt,
                max_tokens=MAX_TOKENS,
                stop=[
                    "<|end|>",   # Phi-4 end token
                    "```\n",     # closing code fence
                    "\n\n\n",    # triple blank line = model rambling
                ],
                echo=False,      # don't repeat the prompt in output
            )
        except Exception as e:
            print(f"\n  [LLM Error] {e}")
            continue

        raw_text = response["choices"][0]["text"]
        print(" done.")

        # Show the raw LLM output for transparency/debugging
        print(f"\n  [LLM raw output]:\n  {'SELECT' + raw_text!r}")

        # ── Step 5: Extract the SQL ────────────────────────────────────────────
        sql = extract_sql(raw_text)

        if sql is None:
            print("\n  [Error] Could not extract a SELECT query from the LLM's response.")
            print("  Try rephrasing your question, or ask it differently.")
            continue

        # Safety guard: only allow SELECT statements through the tunnel
        if not sql.strip().upper().startswith("SELECT"):
            print(f"\n  [Rejected] LLM produced a non-SELECT statement — skipping for safety.")
            print(f"  Statement was: {sql[:100]}")
            continue

        print(f"\n  [Extracted SQL]:\n  {sql}\n")

        # ── Steps 6 & 7: Run on ilab, display result ──────────────────────────
        print("  [ilab] Sending query over SSH...")
        result = run_query_on_ilab(sql, ilab_user, ilab_pass)

        print("\n" + "=" * 60)
        print("RESULT:")
        print("=" * 60)
        print(result)
        print("=" * 60)


if __name__ == "__main__":
    main()