import React, { useState } from "react";
import {
  Menu,
  Search,
  LayoutDashboard,
  Bookmark,
  House,
  FileText,
  Video,
  MessagesSquare,
  Hash,
  ArrowLeft,
  ArrowRight,
  ExternalLink,
} from "lucide-react";
import { useSite } from "../site";
export function Logo({ studio = false }: { studio?: boolean }) {
  return (
    <a className="brand" href="/">
      <span className="brand-mark">
        <img
          className="sourcecat-mark"
          src="/images/sourcecat-solid.png"
          alt=""
          width="48"
          height="48"
        />
      </span>
      <span>
        SourceCat
        <span className="brand-sub">
          {studio ? "CREATOR STUDIO" : "MYANMAR"}
        </span>
      </span>
    </a>
  );
}
export function Header({
  search,
  setSearch,
  toggle,
  studio = false,
}: {
  search?: string;
  setSearch?: (s: string) => void;
  toggle?: () => void;
  studio?: boolean;
}) {
  const site = useSite();
  return (
    <header className="feed-header">
      <div className="header-brand">
        {toggle && (
          <button
            className="icon-button"
            onClick={toggle}
            aria-label="Toggle sidebar"
          >
            <Menu />
          </button>
        )}
        <Logo studio={studio} />
      </div>
      {setSearch && (
        <label className="feed-search">
          <input
            type="search"
            aria-label="Search posts"
            placeholder="Search programming, topics, videos…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          <Search />
        </label>
      )}
      <div className="header-actions">
        <a className="studio-link" href={studio ? "/" : "/community"}>
          {studio ? (
            <>
              <ExternalLink />
              View site
            </>
          ) : (
            <>
              <MessagesSquare />
              Community
            </>
          )}
        </a>
        {!studio && (
          <button className="account-button" onClick={site.account}>
            {site.state?.user?.name || "Join / Sign in"}
          </button>
        )}
      </div>
    </header>
  );
}
const jokes = [
  "Compiling… a nap.",
  "It works on my pillow.",
  "404: energy not found.",
  "One more bug. Then a nap.",
  "Have a stretch. Your code can wait.",
  "git commit -m 'take a break'",
];
export function Mascot() {
  const [index, setIndex] = useState(0);
  return (
    <div className="sidebar-cat">
      <button
        className="relax-cat"
        onClick={() => setIndex((i) => (i + 1) % jokes.length)}
        aria-label="Take a break with SourceCat"
      >
        <img
          src="/images/sourcecat-relax.png"
          alt="A sleepy cat taking a coding break"
          width="140"
          height="140"
        />
        <span className="cat-snores" aria-hidden="true">
          <span>z</span>
          <span>z</span>
          <span>Z</span>
        </span>
      </button>
      <p aria-live="polite">{jokes[index]}</p>
      <small>ခဏနားလို့ရပါတယ်။</small>
    </div>
  );
}
export function Sidebar({
  kind,
  setKind,
  topics,
  topic,
  setTopic,
  saved = false,
}: {
  kind: string;
  setKind: (s: string) => void;
  topics: string[];
  topic: string;
  setTopic: (s: string) => void;
  saved?: boolean;
}) {
  const site = useSite();
  return (
    <aside className="feed-sidebar">
      <nav aria-label="Main navigation">
        {[
          { id: "all", label: "Home", icon: House },
          { id: "article", label: "Articles", icon: FileText },
          { id: "video", label: "YouTube videos", icon: Video },
        ].map((x) => (
          <button
            key={x.id}
            className={`sidebar-item ${!saved && kind === x.id ? "selected" : ""}`}
            onClick={() => {
              setKind(x.id);
              setTopic("all");
            }}
          >
            <span>
              <x.icon />
            </span>
            {x.label}
          </button>
        ))}
        <a
          href="/bookmarks"
          className={`sidebar-item ${saved ? "selected" : ""}`}
        >
          <span>
            <Bookmark />
          </span>
          Saved posts <small>{site.saved.length}</small>
        </a>
        <a className="sidebar-item" href="/community">
          <span>
            <MessagesSquare />
          </span>
          Community
        </a>
        <Mascot />
        <div className="sidebar-divider" />
        <p className="sidebar-caption">Explore topics</p>
        {topics.map((t) => (
          <button
            key={t}
            className={`sidebar-topic ${t === topic ? "selected" : ""}`}
            onClick={() => setTopic(t)}
          >
            <span>
              <Hash />
            </span>
            {t}
          </button>
        ))}
        <div className="sidebar-divider" />
        <a className="sidebar-item" href="/admin">
          <span>
            <LayoutDashboard />
          </span>
          Creator Studio
        </a>
      </nav>
      <div className="sidebar-note">
        <p>လေ့လာမယ်။ တည်ဆောက်မယ်။ မျှဝေမယ်။</p>
        <small>A notebook for Myanmar developers.</small>
      </div>
    </aside>
  );
}
export function Pagination({
  page,
  pages,
  setPage,
  summary,
}: {
  page: number;
  pages: number;
  setPage: (n: number) => void;
  summary?: string;
}) {
  return (
    <nav className="comments-pagination" aria-label="Pagination">
      <button
        type="button"
        disabled={page <= 1}
        onClick={() => setPage(page - 1)}
      >
        <ArrowLeft /> Previous
      </button>
      <span>{summary || `Page ${page} of ${pages}`}</span>
      <button
        type="button"
        disabled={page >= pages}
        onClick={() => setPage(page + 1)}
      >
        Next <ArrowRight />
      </button>
    </nav>
  );
}
export function Message({ text }: { text: string }) {
  return text ? (
    <p className="form-message" role="alert">
      {text}
    </p>
  ) : null;
}
