import React, { useCallback, useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import { request, setCsrf, type AccountState } from "./api";
import { SiteContext } from "./site";
import { AccountDialog } from "./components/account";
import { Feed } from "./components/feed";
import { PostPage } from "./components/post";
import { CommunityPage, QuestionPage } from "./components/community";
import { AdminPage } from "./components/admin";
import { X } from "lucide-react";
function App() {
  const [state, setState] = useState<AccountState | null>(null);
  const [saved, setSaved] = useState<string[]>([]);
  const [account, setAccount] = useState(false);
  const [notice, setNotice] = useState("");
  const [saving, setSaving] = useState<string | null>(null);
  const refresh = useCallback(async () => {
    const result = await request<AccountState>("/community/session");
    setCsrf(result.token);
    setState(result);
    setSaved(
      result.user ? await request<string[]>("/community/bookmarks") : [],
    );
  }, []);
  useEffect(() => {
    refresh().catch((e) => setNotice(e.message));
  }, [refresh]);
  useEffect(() => {
    if (state && !state.user && location.pathname !== "/admin") {
      try {
        if (!sessionStorage.getItem("sourcecat-account-prompted")) {
          sessionStorage.setItem("sourcecat-account-prompted", "yes");
          setAccount(true);
        }
      } catch {}
    }
  }, [state]);
  async function save(id: string) {
    if (!state?.user) {
      setAccount(true);
      return;
    }
    if (saving) return;
    setSaving(id);
    try {
      setSaved(
        await request<string[]>(`/community/bookmarks/${id}`, {
          saved: saved.includes(id) ? "no" : "yes",
        }),
      );
    } catch (e) {
      setNotice((e as Error).message);
    } finally {
      setSaving(null);
    }
  }
  const pathname = decodeURIComponent(location.pathname);
  const page =
    pathname === "/admin" ? (
      <AdminPage />
    ) : pathname.startsWith("/posts/") ? (
      <PostPage id={pathname.split("/")[2]} />
    ) : pathname.startsWith("/community/thread/") ? (
      <QuestionPage id={pathname.split("/")[3]} />
    ) : pathname === "/community" ? (
      <CommunityPage />
    ) : (
      <Feed savedView={pathname === "/bookmarks"} />
    );
  return (
    <SiteContext.Provider
      value={{
        state,
        saved,
        refresh,
        account: () => setAccount(true),
        notify: setNotice,
        save,
      }}
    >
      {page}
      {account && <AccountDialog close={() => setAccount(false)} />}{" "}
      {notice && (
        <div className="site-toast" role="status">
          <span>{notice}</span>
          <button aria-label="Dismiss message" onClick={() => setNotice("")}>
            <X />
          </button>
        </div>
      )}
    </SiteContext.Provider>
  );
}
const root = document.getElementById("app");
if (root) createRoot(root).render(<App />);
