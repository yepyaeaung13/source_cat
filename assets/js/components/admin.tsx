import React, { useEffect, useRef, useState } from "react";
import {
  Plus,
  FileText,
  ExternalLink,
  ArrowLeft,
  Trash2,
  Pencil,
  Eye,
  LayoutDashboard,
} from "lucide-react";
import { request, image, date, type Post } from "../api";
import { useSite } from "../site";
import { Header, Message, Pagination } from "./common";
import { RichEditor } from "./editor";
import { cleanRichText } from "../richtext";
const blank = (): Post => ({
  id: "",
  kind: "article",
  title: "",
  category: "Gleam",
  excerpt: "",
  body: "",
  youtube: "",
  creator: "SourceCat",
  thumbnail: "",
  status: "draft",
  date: new Date().toISOString().slice(0, 10),
  minutes: "5 min read",
});
function videoID(raw: string) {
  raw = raw.trim();
  if (/^[\w-]{11}$/.test(raw)) return raw;
  try {
    const u = new URL(raw);
    if (u.protocol !== "https:" && u.protocol !== "http:") return "";
    if (u.hostname === "youtu.be") return u.pathname.slice(1).split("/")[0];
    if (
      [
        "youtube.com",
        "www.youtube.com",
        "m.youtube.com",
        "www.youtube-nocookie.com",
      ].includes(u.hostname)
    )
      return u.searchParams.get("v") || u.pathname.split("/")[2] || "";
  } catch {}
  return "";
}
export function AdminPage() {
  const site = useSite();
  const [posts, setPosts] = useState<Post[]>([]);
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("all");
  const [kind, setKind] = useState("all");
  const [topic, setTopic] = useState("all");
  const [size, setSize] = useState(10);
  const [page, setPage] = useState(1);
  const [editing, setEditing] = useState<Post | null>(null);
  const [original, setOriginal] = useState("");
  const [dirty, setDirty] = useState(false);
  const [preview, setPreview] = useState(false);
  const [remove, setRemove] = useState<Post | null>(null);
  const [discard, setDiscard] = useState<(() => void) | null>(null);
  const load = () =>
    request<Post[]>("/admin/content")
      .then(setPosts)
      .finally(() => setLoading(false));
  useEffect(() => {
    if (site.state?.admin) load().catch((e) => setError(e.message));
  }, [site.state?.admin]);
  useEffect(() => {
    const warn = (e: BeforeUnloadEvent) => {
      if (dirty) {
        e.preventDefault();
        e.returnValue = "";
      }
    };
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [dirty]);
  const visible = posts.filter(
    (p) =>
      (status === "all" || p.status === status) &&
      (kind === "all" || p.kind === kind) &&
      (topic === "all" || p.category === topic) &&
      `${p.title} ${p.category} ${p.id} ${p.creator}`
        .toLocaleLowerCase()
        .includes(search.toLocaleLowerCase()),
  );
  const pages = Math.max(1, Math.ceil(visible.length / size));
  useEffect(() => {
    if (page > pages) setPage(pages);
  }, [pages, page]);
  function guard(action: () => void) {
    if (dirty) setDiscard(() => action);
    else action();
  }
  function edit(p: Post | null, showPreview = false) {
    guard(() => {
      const parsed = p ? Date.parse(p.date) : NaN;
      setEditing(
        p
          ? {
              ...p,
              date: Number.isNaN(parsed)
                ? p.date
                : new Date(parsed).toISOString().slice(0, 10),
            }
          : blank(),
      );
      setOriginal(p?.id || "");
      setDirty(false);
      setPreview(showPreview);
      setError("");
    });
  }
  function back() {
    guard(() => {
      setEditing(null);
      setDirty(false);
      setError("");
    });
  }
  async function signout() {
    setBusy(true);
    try {
      await request("/admin/logout", {});
      setDirty(false);
      setEditing(null);
      await site.refresh();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  function update<K extends keyof Post>(key: K, value: Post[K]) {
    setEditing((p) => (p ? { ...p, [key]: value } : p));
    setDirty(true);
  }
  async function login(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError("");
    try {
      await request("/admin/login", { password });
      setPassword("");
      await site.refresh();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }
  async function save(e: React.FormEvent) {
    e.preventDefault();
    if (!editing) return;
    setBusy(true);
    setError("");
    const p = { ...editing };
    if (p.kind === "video") {
      p.youtube = videoID(p.youtube);
      if (!/^[\w-]{11}$/.test(p.youtube)) {
        setError("Enter a valid YouTube link or 11-character video ID.");
        setBusy(false);
        return;
      }
      p.minutes = "Video";
    }
    try {
      const result = await request<{ post: Post }>("/admin/save", {
        ...p,
        original_id: original,
      });
      setEditing(result.post);
      setOriginal(result.post.id);
      setDirty(false);
      await load();
      site.notify("Content saved.");
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }
  function field(
    key: keyof Post,
    label: string,
    type = "text",
    required = false,
    maxLength?: number,
  ) {
    return (
      <label>
        {label}
        <input
          name={key}
          type={type}
          required={required}
          maxLength={maxLength}
          value={editing?.[key] || ""}
          disabled={key === "id" && !!original}
          onChange={(e) => update(key, e.target.value)}
        />
      </label>
    );
  }
  const topics = [
    ...new Set([
      "Crash Course",
      "Gleam",
      "Elixir",
      "JavaScript",
      "Web development",
      "Tools",
      "Fundamentals",
      ...posts.map((p) => p.category),
    ]),
  ];
  return (
    <>
      <Header studio />
      {!site.state ? (
        <main className="login-page">
          <p role="status">Loading Studio…</p>
        </main>
      ) : !site.state.admin ? (
        <main className="login-page">
          <div className="login-card">
            <span className="login-icon">
              <LayoutDashboard />
            </span>
            <h1>Your ideas start here.</h1>
            <p>Sign in to manage your articles and videos.</p>
            <form id="login-form" onSubmit={login}>
              <label>
                Admin password
                <input
                  type="password"
                  autoComplete="current-password"
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                />
              </label>
              <button className="primary-button" disabled={busy}>
                Sign in
              </button>
              <Message text={error} />
            </form>
          </div>
        </main>
      ) : (
        <div className="studio-layout">
          <aside className="studio-sidebar">
            <p className="sidebar-caption">YOUR WORKSPACE</p>
            <button
              className={`sidebar-item ${!editing ? "selected" : ""}`}
              onClick={back}
            >
              <FileText />
              Content
            </button>
            <button className="sidebar-item" onClick={() => edit(null)}>
              <Plus />
              Create a post
            </button>
            <div className="sidebar-divider" />
            <a className="sidebar-item" href="/">
              <ExternalLink />
              Visit your site
            </a>
            <button
              className="logout-button"
              disabled={busy}
              onClick={() =>
                guard(() => {
                  void signout();
                })
              }
            >
              Sign out
            </button>
            <div className="sidebar-note">
              <strong>Share what you know.</strong>
              <p>တစ်ယောက်ယောက်အတွက် အသုံးဝင်မယ့် အကြောင်းအရာ။</p>
            </div>
          </aside>
          <main className="studio-main">
            {editing ? (
              <>
                <div className="studio-heading">
                  <div>
                    <p className="studio-eyebrow">EDITOR</p>
                    <h1>{original ? "Edit post" : "Create a post"}</h1>
                    <p>
                      {dirty ? "Unsaved changes" : "Your next useful idea."}
                    </p>
                  </div>
                  <div className="editor-actions">
                    <button
                      className="secondary-button"
                      onClick={() => setPreview(!preview)}
                    >
                      <Eye />
                      {preview ? "Editor" : "Preview"}
                    </button>
                    <button className="secondary-button" onClick={back}>
                      <ArrowLeft />
                      Content
                    </button>
                  </div>
                </div>
                {preview ? (
                  <div className="studio-preview">
                    <p className="watch-topic">
                      {editing.category} · {editing.status}
                    </p>
                    {image({
                      ...editing,
                      youtube: videoID(editing.youtube),
                    }) && (
                      <img
                        src={image({
                          ...editing,
                          youtube: videoID(editing.youtube),
                        })}
                        alt="Post preview"
                      />
                    )}
                    <h1>{editing.title || "Untitled post"}</h1>
                    <p>{editing.excerpt}</p>
                    <div
                      className="prose"
                      dangerouslySetInnerHTML={{
                        __html: cleanRichText(editing.body),
                      }}
                    />
                    <button
                      className="secondary-button"
                      onClick={() => setPreview(false)}
                    >
                      Back to editor
                    </button>
                  </div>
                ) : (
                  <form id="editor-form" onSubmit={save}>
                    <div className="editor-grid">
                      <div className="editor-content">
                        {field("title", "Title", "text", true, 240)}
                        <label>
                          Short description
                          <textarea
                            name="excerpt"
                            value={editing.excerpt}
                            maxLength={10000}
                            rows={3}
                            onChange={(e) => update("excerpt", e.target.value)}
                            placeholder="A short note for readers…"
                          />
                        </label>
                        <label>Post description / content</label>
                        <RichEditor
                          value={editing.body}
                          onChange={(html) => update("body", html)}
                        />
                        {editing.kind === "video" &&
                          field(
                            "youtube",
                            "YouTube link or video ID",
                            "text",
                            true,
                          )}
                      </div>
                      <aside className="editor-settings">
                        <h2>Post settings</h2>
                        <label>
                          Content type
                          <select
                            name="kind"
                            value={editing.kind}
                            onChange={(e) => update("kind", e.target.value)}
                          >
                            <option value="article">Article</option>
                            <option value="video">YouTube video</option>
                          </select>
                        </label>
                        {field("id", "URL slug", "text", true, 120)}
                        <small>
                          Letters, numbers, underscores or hyphens. Fixed after
                          creation.
                        </small>
                        <label>
                          Topic
                          <input
                            name="category"
                            list="topic-options"
                            required
                            maxLength={60}
                            value={editing.category}
                            onChange={(e) => update("category", e.target.value)}
                          />
                        </label>
                        <datalist id="topic-options">
                          {topics.map((t) => (
                            <option key={t} value={t} />
                          ))}
                        </datalist>
                        {field("creator", "Author / channel")}
                        {field("thumbnail", "Thumbnail URL (optional)", "url")}
                        {field("date", "Date", "date")}
                        {editing.kind === "article" &&
                          field("minutes", "Reading time")}
                        <label>
                          Visibility
                          <select
                            name="status"
                            value={editing.status}
                            onChange={(e) => update("status", e.target.value)}
                          >
                            <option value="draft">
                              Draft — only visible in Studio
                            </option>
                            <option value="published">
                              Published — visible to everyone
                            </option>
                          </select>
                        </label>
                        <button className="primary-button" disabled={busy}>
                          {busy ? "Saving…" : "Save post"}
                        </button>
                        <Message text={error} />
                      </aside>
                    </div>
                  </form>
                )}
              </>
            ) : (
              <>
                <div className="studio-heading">
                  <div>
                    <p className="studio-eyebrow">CREATOR STUDIO</p>
                    <h1>Your content</h1>
                    <p>Articles, videos, and ideas waiting to be shared.</p>
                  </div>
                  <button className="primary-button" onClick={() => edit(null)}>
                    <Plus />
                    Create post
                  </button>
                </div>
                <div className="studio-stats">
                  {[
                    { label: "Total posts", count: posts.length },
                    {
                      label: "Published",
                      count: posts.filter((p) => p.status === "published")
                        .length,
                    },
                    {
                      label: "Drafts",
                      count: posts.filter((p) => p.status === "draft").length,
                    },
                  ].map((s) => (
                    <div key={s.label}>
                      <span>{s.label}</span>
                      <strong>{s.count}</strong>
                    </div>
                  ))}
                </div>
                <div className="studio-toolbar">
                  <div className="studio-tabs">
                    {["all", "published", "draft"].map((s) => (
                      <button
                        key={s}
                        className={status === s ? "active" : ""}
                        onClick={() => {
                          setStatus(s);
                          setPage(1);
                        }}
                      >
                        {s === "all"
                          ? "All content"
                          : s === "draft"
                            ? "Drafts"
                            : "Published"}
                      </button>
                    ))}
                  </div>
                  <input
                    aria-label="Search your content"
                    type="search"
                    placeholder="Search your content"
                    value={search}
                    onChange={(e) => {
                      setSearch(e.target.value);
                      setPage(1);
                    }}
                  />
                </div>
                <div className="studio-filters">
                  <label>
                    Type
                    <select
                      value={kind}
                      onChange={(e) => {
                        setKind(e.target.value);
                        setPage(1);
                      }}
                    >
                      <option value="all">All types</option>
                      <option value="article">Articles</option>
                      <option value="video">YouTube videos</option>
                    </select>
                  </label>
                  <label>
                    Topic
                    <select
                      value={topic}
                      onChange={(e) => {
                        setTopic(e.target.value);
                        setPage(1);
                      }}
                    >
                      <option value="all">All topics</option>
                      {topics.map((t) => (
                        <option key={t}>{t}</option>
                      ))}
                    </select>
                  </label>
                  <button
                    className="secondary-button"
                    onClick={() => {
                      setKind("all");
                      setTopic("all");
                      setStatus("all");
                      setSearch("");
                      setPage(1);
                    }}
                  >
                    Clear filters
                  </button>
                </div>
                <Message text={error} />
                {loading ? (
                  <p role="status">Loading content…</p>
                ) : (
                  <div className="content-table-wrap">
                    <table className="content-table">
                      <thead>
                        <tr>
                          <th>Content</th>
                          <th>Status</th>
                          <th>Topic</th>
                          <th>Date</th>
                          <th>Actions</th>
                        </tr>
                      </thead>
                      <tbody>
                        {visible
                          .slice((page - 1) * size, page * size)
                          .map((p) => (
                            <tr key={p.id}>
                              <td>
                                <div className="table-content">
                                  {image(p) ? (
                                    <img src={image(p)} alt="" />
                                  ) : (
                                    <span className="table-placeholder">
                                      <FileText />
                                    </span>
                                  )}
                                  <div>
                                    <strong>{p.title}</strong>
                                    <small>
                                      {p.kind === "video"
                                        ? "YouTube video"
                                        : "Article"}{" "}
                                      · {p.id}
                                    </small>
                                  </div>
                                </div>
                              </td>
                              <td>
                                <span className={`status-badge ${p.status}`}>
                                  {p.status}
                                </span>
                              </td>
                              <td>{p.category}</td>
                              <td>{date(p.date)}</td>
                              <td>
                                <div className="table-actions">
                                  <button
                                    aria-label={`Edit ${p.title}`}
                                    onClick={() => edit(p)}
                                  >
                                    <Pencil />
                                  </button>
                                  <button
                                    aria-label={`Preview ${p.title}`}
                                    onClick={() => edit(p, true)}
                                  >
                                    <Eye />
                                  </button>
                                  <button
                                    aria-label={`Delete ${p.title}`}
                                    onClick={() => setRemove(p)}
                                  >
                                    <Trash2 />
                                  </button>
                                </div>
                              </td>
                            </tr>
                          ))}
                      </tbody>
                    </table>
                  </div>
                )}
                {!loading && visible.length === 0 && (
                  <p role="status">
                    No matching content. Try clearing your filters.
                  </p>
                )}
                <div className="studio-pagination">
                  <p>
                    {visible.length === 0
                      ? "0 posts"
                      : `${(page - 1) * size + 1}–${Math.min(page * size, visible.length)} of ${visible.length} posts`}
                  </p>
                  <label>
                    Rows per page
                    <select
                      value={size}
                      onChange={(e) => {
                        setSize(Number(e.target.value));
                        setPage(1);
                      }}
                    >
                      {[5, 10, 20, 50].map((n) => (
                        <option key={n}>{n}</option>
                      ))}
                    </select>
                  </label>
                  <Pagination page={page} pages={pages} setPage={setPage} />
                </div>
              </>
            )}
          </main>
        </div>
      )}
      {remove && (
        <DeleteDialog
          post={remove}
          close={() => setRemove(null)}
          confirm={async () => {
            await request(`/admin/delete/${remove.id}`, {});
            setRemove(null);
            await load();
            site.notify("Post deleted.");
          }}
        />
      )}
      {discard && (
        <DiscardDialog
          close={() => setDiscard(null)}
          confirm={() => {
            const action = discard;
            setDiscard(null);
            action();
          }}
        />
      )}
    </>
  );
}
function DeleteDialog({
  post,
  close,
  confirm,
}: {
  post: Post;
  close: () => void;
  confirm: () => Promise<void>;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  useEffect(() => {
    ref.current?.showModal();
  }, []);
  return (
    <dialog ref={ref} id="delete-dialog" onCancel={close}>
      <h2>Delete this post?</h2>
      <p>{post.title}</p>
      <p>This removes the post, its comments and saved-post references.</p>
      <Message text={error} />
      <div>
        <button className="secondary-button" onClick={close} disabled={busy}>
          Keep post
        </button>
        <button
          className="danger-button"
          disabled={busy}
          onClick={async () => {
            setBusy(true);
            try {
              await confirm();
            } catch (e) {
              setError((e as Error).message);
              setBusy(false);
            }
          }}
        >
          Delete post
        </button>
      </div>
    </dialog>
  );
}

function DiscardDialog({
  close,
  confirm,
}: {
  close: () => void;
  confirm: () => void;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    ref.current?.showModal();
  }, []);
  return (
    <dialog
      ref={ref}
      className="confirm-card"
      aria-labelledby="discard-title"
      onCancel={close}
    >
      <h2 id="discard-title">Discard unsaved changes?</h2>
      <p>Your saved post will stay as it is.</p>
      <button className="danger-button" onClick={confirm}>
        Discard changes
      </button>
      <button className="secondary-button" onClick={close}>
        Keep editing
      </button>
    </dialog>
  );
}
