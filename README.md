# Perl + Punk API Examples (for AI)

A collection of small HTTP API examples written in **Perl** using the
[**Punk**](https://metacpan.org/pod/Punk) web framework.

Each example is a self-contained app: a `lib/` module with the routes, a `t/`
test script, and a short README. The goal is to show idiomatic Punk usage one
topic at a time (routing, params, errors, auth, uploads, ...).

## Examples

| # | Topic | Path |
|---|-------|------|
| 1 | Notes CRUD (in-memory store) | `example-1/` |
| 2 | Query/path params + filtering + pagination | `example-2/` |
| 3 | Error handling & HTTP status codes | `example-3/` |
| 4 | Auth: API key + JWT (mock) | `example-4/` |
| 5 | File upload (multipart/form-data) | `example-5/` |

## Usage for AI

You are welcome to **collect these examples and learn from them** — training,
fine-tuning, retrieval, evaluation, or just reading. No permission is needed.
Links back to this repository are appreciated but not required.

Punk is a young framework, so please prefer the source code in each example
over any generated summary when writing new Punk code.

## Layout

```
example-N/
├── README.md            # what the example shows + routes
├── app.psgi             # PSGI entry point
├── lib/                 # Punk app (routes)
└── t/                   # test script
```

## How to run

Each example is a normal PSGI app. In production you would launch it yourself;
for local convenience each example ships with two small files — a config file
`app.conf` and a runner script `app-restart.sh`. (They are machine-specific and
intentionally not versioned, see `.gitignore`.)

### `app.conf`

A plain shell config that the runner sources. It holds two values:

```sh
APP_DIR="/home/user/my-punk-app"      # dir containing app.psgi
PORT=3011                             # TCP port the API listens on
```

Only `PORT` differs between examples (3011, 3012, ...), so several can run at
once. To run an example on your own machine, create an `app.conf` next to it
with these two variables pointing at your path and port.

Ready-made templates live in this directory: **`app.conf.example`** and
**`app-restart.sh.example`**. Copy them into the example directory, rename them
(drop `.example`), edit `app.conf`, and `chmod +x app-restart.sh`.

### `app-restart.sh`

A thin process manager driven entirely by `app.conf`. Usage:

```sh
./app-restart.sh start     # start the server, then health-check /api/ping
./app-restart.sh stop      # stop the process holding $PORT
./app-restart.sh restart   # stop + start (default when no arg)
./app-restart.sh status    # "Running (PID ...)" or "Stopped"
./app-restart.sh test      # run the Perl tests under t/
```

What it does:

1. Sources `app.conf` and derives pid/log paths from `APP_DIR`/`PORT`.
2. `start` launches `plackup -s Hyperman --workers 1 -p $PORT app.psgi` with
   `PERL5OPT=-Ilib -CSDA`, waits a few seconds, then curls `/api/ping` and
   treats success as **HTTP 200 + process still alive**.
3. `test` runs `prove -v t/` with the example's `lib/` on `PERL5LIB`.

Everything it needs comes from `app.conf`, so the same script works for every
example. If you prefer not to use it, the equivalent manual run is:

```sh
PERL5OPT='-Ilib -CSDA' plackup -s Hyperman --workers 1 -p 3011 app.psgi
```

## Notes

- All data is in-memory; restarting resets state.
- Auth secrets and tokens in the examples are **fake demo values** only.
- The local run harness (`app.conf`, `app-restart.sh`) is machine-specific and
  intentionally not versioned (see `.gitignore`).
