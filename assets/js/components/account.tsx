import React, { useEffect, useRef, useState } from "react";
import { X, RefreshCw, Bookmark, ArrowRight } from "lucide-react";
import { request, setCsrf, type AccountState } from "../api";
import { useSite } from "../site";
import { Message } from "./common";
export function AccountDialog({ close }: { close: () => void }) {
  const site = useSite();
  const dialog = useRef<HTMLDialogElement>(null);
  const [tab, setTab] = useState("create");
  const [name, setName] = useState("");
  const [pin, setPin] = useState("");
  const [confirm, setConfirm] = useState("");
  const [current, setCurrent] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    dialog.current?.showModal();
  }, []);
  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    if (tab === "create" && pin !== confirm) {
      setError("The PINs do not match.");
      return;
    }
    setBusy(true);
    try {
      const s = await request<AccountState>(
        `/community/${tab === "create" ? "signup" : "login"}`,
        tab === "create" ? { secret: pin } : { name, secret: pin },
      );
      setCsrf(s.token);
      await site.refresh();
      close();
      site.notify(`Welcome, ${s.user?.name}!`);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }
  async function changePin(e: React.FormEvent) {
    e.preventDefault();
    if (pin !== confirm) {
      setError("The PINs do not match.");
      return;
    }
    setBusy(true);
    setError("");
    try {
      const s = await request<AccountState>("/community/credentials", {
        current_secret: current,
        secret: pin,
      });
      setCsrf(s.token);
      setCurrent("");
      setPin("");
      setConfirm("");
      await site.refresh();
      site.notify("PIN updated. Other signed-in devices have been signed out.");
      close();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }
  const pinField = (
    label: string,
    value: string,
    set: (v: string) => void,
    autocomplete: string,
  ) => (
    <label>
      {label}
      <input
        type="password"
        inputMode="numeric"
        pattern="[0-9]{6,12}"
        minLength={6}
        maxLength={12}
        autoComplete={autocomplete}
        required
        value={value}
        onChange={(e) => set(e.target.value)}
        placeholder="6–12 digits"
      />
    </label>
  );
  return (
    <dialog ref={dialog} className="account-dialog" onCancel={close}>
      <div className="account-dialog-head">
        <h2>{site.state?.user ? "Your account" : "Your developer corner"}</h2>
        <button type="button" aria-label="Close account dialog" onClick={close}>
          <X />
        </button>
      </div>
      {site.state?.user ? (
        <div id="account-profile">
          <p className="profile-caption">SIGNED IN AS</p>
          <strong>{site.state.user.name}</strong>
          <p>Comment, reply and save articles or videos for later.</p>
          <a className="profile-bookmarks" href="/bookmarks">
            <Bookmark />
            Saved posts <span>{site.saved.length}</span>
            <ArrowRight />
          </a>
          <form onSubmit={changePin} id="credentials-form">
            <h3>Change PIN</h3>
            {pinField("Current PIN", current, setCurrent, "current-password")}
            {pinField("New PIN", pin, setPin, "new-password")}
            {pinField("Confirm new PIN", confirm, setConfirm, "new-password")}
            <Message text={error} />
            <button className="secondary-button" disabled={busy}>
              Update PIN
            </button>
          </form>
          <button
            type="button"
            className="logout-button"
            disabled={busy}
            onClick={async () => {
              setBusy(true);
              try {
                await request("/community/logout", {});
                await site.refresh();
                close();
              } catch (e) {
                setError((e as Error).message);
              } finally {
                setBusy(false);
              }
            }}
          >
            Sign out
          </button>
        </div>
      ) : (
        <>
          <p className="account-intro">
            Guests can read everything. Create an account to ask, reply, and
            save posts.
          </p>
          <div className="account-tabs">
            <button
              type="button"
              className={tab === "create" ? "active" : ""}
              onClick={() => {
                setTab("create");
                setError("");
              }}
            >
              Create account
            </button>
            <button
              type="button"
              className={tab === "login" ? "active" : ""}
              onClick={() => {
                setTab("login");
                setError("");
              }}
            >
              Sign in
            </button>
          </div>
          <form id="account-form" onSubmit={submit}>
            {tab === "create" ? (
              <>
                <label>Your generated username</label>
                <div className="generated-name">
                  <strong>{site.state?.suggestion || "Generating…"}</strong>
                  <button
                    type="button"
                    aria-label="Generate another username"
                    disabled={busy}
                    onClick={async () => {
                      try {
                        await request("/community/name", {});
                        await site.refresh();
                      } catch (e) {
                        setError((e as Error).message);
                      }
                    }}
                  >
                    <RefreshCw />
                  </button>
                </div>
              </>
            ) : (
              <label>
                Username
                <input
                  autoComplete="username"
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="Bright Mango"
                />
              </label>
            )}
            {pinField(
              tab === "create" ? "Set your PIN" : "PIN",
              pin,
              setPin,
              tab === "create" ? "new-password" : "current-password",
            )}
            {tab === "create" &&
              pinField("Confirm PIN", confirm, setConfirm, "new-password")}
            <p className="account-hint">
              Save your username. You’ll need it with your PIN on another
              device.
            </p>
            <button className="primary-button" disabled={busy || !site.state}>
              {busy
                ? "Please wait…"
                : tab === "create"
                  ? "Create account & sign in"
                  : "Sign in"}
            </button>
            <Message text={error} />
          </form>
        </>
      )}
      <button type="button" className="browse-button" onClick={close}>
        Continue browsing
      </button>
    </dialog>
  );
}
