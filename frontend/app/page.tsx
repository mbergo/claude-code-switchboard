"use client";

import { useEffect, useMemo, useState, type ReactNode } from "react";
import toolsData from "./tools.json";

type ToolManual = {
  install?: string;
  usage?: string[];
  notes?: string;
};

type Tool = {
  id: string;
  name: string;
  description: string;
  manual: ToolManual;
};

type Flags = Record<string, boolean>;

const STORAGE_KEY = "switchboard.flags";

const TOOLS: Tool[] = toolsData.tools as Tool[];

const DEFAULT_FLAGS: Flags = TOOLS.reduce<Flags>((acc, t) => {
  acc[t.id] = true;
  return acc;
}, {});

function ManualRow({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="manual-row">
      <span className="manual-key">{label}</span>
      <div style={{ flex: 1, minWidth: 0 }}>{children}</div>
    </div>
  );
}

function ManualPanel({ manual }: { manual: ToolManual }) {
  const { install, usage, notes } = manual;
  return (
    <>
      {install ? (
        <ManualRow label="Install">
          <code>{install}</code>
        </ManualRow>
      ) : null}
      {usage && usage.length > 0 ? (
        <ManualRow label="Usage">
          <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
            {usage.map((line, idx) =>
              line.includes("\n") ? (
                <pre key={idx} style={{ margin: 0 }}>{line}</pre>
              ) : (
                <code key={idx}>{line}</code>
              ),
            )}
          </div>
        </ManualRow>
      ) : null}
      {notes ? (
        <ManualRow label="Notes">
          <p style={{ margin: 0 }}>{notes}</p>
        </ManualRow>
      ) : null}
    </>
  );
}

function loadFlags(): Flags {
  if (typeof window === "undefined") return DEFAULT_FLAGS;
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return DEFAULT_FLAGS;
    const parsed = JSON.parse(raw) as Partial<Flags>;
    return { ...DEFAULT_FLAGS, ...parsed } as Flags;
  } catch {
    return DEFAULT_FLAGS;
  }
}

export default function Home() {
  const [flags, setFlags] = useState<Flags>(DEFAULT_FLAGS);
  const [openManual, setOpenManual] = useState<Record<string, boolean>>({});
  const [hydrated, setHydrated] = useState(false);

  useEffect(() => {
    setFlags(loadFlags());
    setHydrated(true);
  }, []);

  useEffect(() => {
    if (!hydrated) return;
    try {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(flags));
    } catch {
      /* ignore quota errors */
    }
  }, [flags, hydrated]);

  const enabledCount = useMemo(
    () => Object.values(flags).filter(Boolean).length,
    [flags],
  );

  const toggle = (id: string) => {
    setFlags((prev) => ({ ...prev, [id]: !prev[id] }));
  };

  const toggleManual = (id: string) => {
    setOpenManual((prev) => ({ ...prev, [id]: !prev[id] }));
  };

  return (
    <main className="app">
      <header className="header">
        <div className="header-text">
          <h1>Switchboard</h1>
          <p>Claude Code CLI toolkit dashboard</p>
        </div>
        <div className="counter" aria-live="polite">
          <span className="counter-dot" />
          <span className="counter-num">{enabledCount}</span>
          <span className="counter-label">/ {TOOLS.length} enabled</span>
        </div>
      </header>

      <section className="grid">
        {TOOLS.map((tool) => {
          const on = flags[tool.id] ?? true;
          const open = !!openManual[tool.id];
          return (
            <article key={tool.id} className={`card${on ? " active" : ""}`}>
              <div className="card-head">
                <div style={{ minWidth: 0 }}>
                  <h2 className="card-title">{tool.name}</h2>
                  <p className="card-desc">{tool.description}</p>
                </div>
                <button
                  type="button"
                  role="switch"
                  aria-checked={on}
                  aria-label={`Toggle ${tool.name}`}
                  className={`toggle${on ? " on" : ""}`}
                  onClick={() => toggle(tool.id)}
                />
              </div>

              <div className="card-foot">
                <button
                  type="button"
                  className="manual-btn"
                  aria-expanded={open}
                  aria-controls={`manual-${tool.id}`}
                  onClick={() => toggleManual(tool.id)}
                >
                  manual
                  <span className={`chev${open ? " open" : ""}`}>▾</span>
                </button>
                <span
                  style={{
                    fontSize: 11,
                    color: "var(--text-faint)",
                    fontFamily: "var(--font-mono)",
                    letterSpacing: "0.04em",
                  }}
                >
                  {on ? "ON" : "OFF"}
                </span>
              </div>

              <div
                id={`manual-${tool.id}`}
                className={`manual${open ? " open" : ""}`}
                aria-hidden={!open}
              >
                <div className="manual-inner">
                  <ManualPanel manual={tool.manual} />
                </div>
              </div>
            </article>
          );
        })}
      </section>

      <footer className="footer">
        Powered by <strong>zero-native</strong> + <strong>Zig</strong>
      </footer>
    </main>
  );
}
